# --------------------------
# EKS Cluster and Node Group
# --------------------------

# IAM Role for the EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name               = "eks_cluster_role"
  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "eks.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# IAM Role for the EKS Node Group
resource "aws_iam_role" "eks_node_role" {
  name               = "eks_node_role"
  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_read_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Create the EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = "eks-apps-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.32"
  vpc_config {
    subnet_ids = [
      aws_subnet.eks_public_subnet_a.id,
      aws_subnet.eks_public_subnet_b.id,
      aws_subnet.eks_private_subnet_a.id,
      aws_subnet.eks_private_subnet_b.id
    ]
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  # EKS Logging
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = {
    Name = "eks-apps-cluster"
  }

  # Create local exec provisioner to update kubeconfig.
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --profile=${var.aws_profile} --region ${var.aws_region} --name=${self.name}"
  }
}

# Create the EKS Node Group
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "eks-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids = [
    aws_subnet.eks_private_subnet_a.id,
    aws_subnet.eks_private_subnet_b.id
  ]
  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }
  instance_types = ["t3.medium"]
  tags = {
    Name = "eks-node-group"
  }
}

# Kubernetes configuration for frontend service
provider "kubernetes" {
  host                   = aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.eks_cluster.name, "--region", var.aws_region, "--profile", var.aws_profile]
    command     = "aws"
  }
}

# Create the namespace.
resource "kubernetes_namespace" "doc_query" {
  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_node_group
  ]

  metadata {
    name = var.k8s_namespace

    labels = {
      environment = "production"
      app         = var.k8s_namespace
    }

    annotations = {
      "created-by" = "terraform"
    }
  }
}

resource "kubernetes_service_account" "frontend_service" {
  depends_on = [
    kubernetes_namespace.doc_query
  ]

  metadata {
    name      = "doc-frontend-service"
    namespace = var.k8s_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
  }
}

# Security Group for Network Load Balancer
resource "aws_security_group" "nlb_sg" {
  name        = "nlb-security-group"
  description = "Security group for NLB"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 3003
    to_port     = 3003
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all IPs (or restrict to CloudFront IPs)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Brings up the Network Load Balancer on Kubernetes.
resource "kubernetes_service" "frontend" {
  depends_on = [
    kubernetes_namespace.doc_query
  ]

  metadata {
    name      = "doc-frontend-service"
    namespace = var.k8s_namespace
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"                        = "external"
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"             = "ip"
      "service.beta.kubernetes.io/aws-load-balancer-scheme"                      = "internet-facing"
      "service.beta.kubernetes.io/aws-load-balancer-target-group-attributes"     = "preserve_client_ip.enabled=false"
      "service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags"    = "Name=doc-frontend-nlb,ManagedBy=eks"
      "service.beta.kubernetes.io/aws-load-balancer-access-log-enabled"          = "true"
      "service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-name"   = aws_s3_bucket.nlb_logs.bucket
      "service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-prefix" = "nlb-logs"
    #  "service.beta.kubernetes.io/aws-load-balancer-security-groups"             = aws_security_group.nlb_sg.id
    }
  }

  spec {
    selector = {
      app = "doc-frontend"
    }

    port {
      port        = 3003
      target_port = 3003
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }
}

# For linking AWS to the Network Load Balancer created on Kubernetes.
data "aws_lb" "k8s_nlb" {
  tags = {
    Name = "doc-frontend-nlb"
  }
  depends_on = [kubernetes_service.frontend]
}

resource "null_resource" "build_images" {
  depends_on = [
    aws_ecr_repository.frontend,
    aws_ecr_repository.backend,
    aws_eks_cluster.eks_cluster
  ]

  # Build the docker images and install the apps.
  provisioner "local-exec" {
    command = <<-EOT
      echo 'INFO: Building docker images for ECR'
      ./ecr_login.sh
      cd kubernetes
      ./install.sh
      cd ..
      EOT
  }  
}

resource "null_resource" "update_cf_host" {
  depends_on = [
    aws_cloudfront_distribution.frontend_cf
  ]

  # Set up Statefulsets.
  provisioner "local-exec" {
    command = <<-EOT
      echo 'INFO: Updating Configmaps'
      cd kubernetes
      ./k8s_upd_cfhosts.sh
      cd ..
      EOT
  }
}


# ----
# OIDC
# ----
# Get the OIDC thumbprint
data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

# Create OIDC Provider
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

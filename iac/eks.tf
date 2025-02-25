#############################
# EKS Cluster and Node Group
#############################

# IAM Role for the EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks_cluster_role"
  assume_role_policy = <<EOF
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
  name = "eks_node_role"
  assume_role_policy = <<EOF
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
    subnet_ids              = [
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
  subnet_ids      = [
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
    name = "doc-query"
    
    # Optional: Add labels
    labels = {
      environment = "production"
      app         = "doc-query"
    }

    # Optional: Add annotations
    annotations = {
      "created-by" = "terraform"
    }
  }

  # Build the docker images.
  provisioner "local-exec" {
    command = "cd ecr; ecr_login.sh; cd .."
  }

  # Set up Statefulsets.
  provisioner "local-exec" {
    command = "cd kubernetes; install.sh; cd .."
  }
}

resource "kubernetes_service_account" "frontend_service" {
  depends_on = [
    kubernetes_namespace.doc_query
  ]

  metadata {
    name      = "doc-frontend-service"
    namespace = "doc-query"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
  }
}

resource "kubernetes_service" "frontend" {
  depends_on = [
    kubernetes_namespace.doc_query
  ]

  metadata {
    name = "doc-frontend-service"
    namespace = "doc-query"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type" = "external"
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
      "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
      "service.beta.kubernetes.io/aws-load-balancer-target-group-attributes" = "preserve_client_ip.enabled=true"
    }
  }

  spec {
    selector = {
      app = "frontend"
    }
    
    port {
      port        = 3003
      target_port = 3003
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }
}

#############################
# OIDC
#############################
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

#############################
# Provider Configuration
#############################
provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

# Secondary provider for CloudFront and WAF (must be in us-east-1)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  profile = var.aws_profile
}

#############################
# VPC for EKS Cluster
#############################
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "eks-vpc"
  }
}

resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "eks-igw"
  }
}

resource "aws_subnet" "eks_public_subnet_a" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags = {
    Name = "eks-public-subnet-a"
  }
}

resource "aws_subnet" "eks_private_subnet_a" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "eks-private-subnet-a"
  }
}

resource "aws_subnet" "eks_public_subnet_b" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}b"
  tags = {
    Name = "eks-public-subnet-b"
  }
}

resource "aws_subnet" "eks_private_subnet_b" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "eks-private-subnet-b"
  }
}

resource "aws_route_table" "eks_public_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }
  tags = {
    Name = "eks-public-rt"
  }
}

resource "aws_route_table_association" "eks_public_rta" {
  subnet_id      = aws_subnet.eks_public_subnet_a.id
  route_table_id = aws_route_table.eks_public_rt.id
}

resource "aws_route_table_association" "eks_public_rta_b" {
  subnet_id      = aws_subnet.eks_public_subnet_b.id
  route_table_id = aws_route_table.eks_public_rt.id
}

resource "aws_eip" "eks_nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "eks_nat" {
  allocation_id = aws_eip.eks_nat_eip.id
  subnet_id     = aws_subnet.eks_public_subnet_a.id
  tags = {
    Name = "eks-nat-gateway"
  }
}

resource "aws_route_table" "eks_private_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block    = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.eks_nat.id
  }
  tags = {
    Name = "eks-private-rt"
  }
}

resource "aws_route_table_association" "eks_private_rta" {
  subnet_id      = aws_subnet.eks_private_subnet_a.id
  route_table_id = aws_route_table.eks_private_rt.id
}

resource "aws_route_table_association" "eks_private_rtb" {
  subnet_id      = aws_subnet.eks_private_subnet_b.id
  route_table_id = aws_route_table.eks_private_rt.id
}

# Enable VPC Logging.
# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 30
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })
}

# IAM Role Policy for VPC Flow Logs
resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name = "vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
    }]
  })
}

# Enable VPC Flow Logs
resource "aws_flow_log" "vpc_flow_logs" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.eks_vpc.id
}

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


#############################
# ALB for Frontend Service
#############################
resource "aws_lb" "frontend_alb" {
  name               = "frontend-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.frontend_alb_sg.id]
  subnets            = [
    aws_subnet.eks_public_subnet_a.id,
    aws_subnet.eks_public_subnet_b.id
  ]
  tags               = { Name = "frontend-alb" }
}

resource "aws_security_group" "frontend_alb_sg" {
  name        = "frontend-alb-sg"
  description = "Allow only my laptop IP to access the frontend ALB"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    description = "Allow HTTP from laptop"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.laptop_ip]
  }

  ingress {
    description = "Allow HTTPS from laptop"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.laptop_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "frontend-alb-sg" }
}

# Target Group for Frontend Service
resource "aws_lb_target_group" "frontend_tg" {
  name        = "frontend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.eks_vpc.id
  target_type = "ip"  # Important for EKS pods

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 15
    matcher            = "200"
    path               = "/health"  # Adjust based on your frontend service health endpoint
    port               = "traffic-port"
    protocol           = "HTTP"
    timeout            = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "frontend-target-group"
  }
}

resource "aws_lb_listener" "frontend_listener" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

# IAM Policy for ALB Ingress Controller
resource "aws_iam_policy" "alb_ingress" {
  name        = "ALBIngressControllerIAMPolicy"
  description = "Policy for ALB Ingress Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule",
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyRule"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach ALB Ingress policy to EKS cluster role
resource "aws_iam_role_policy_attachment" "alb_ingress" {
  policy_arn = aws_iam_policy.alb_ingress.arn
  role       = aws_iam_role.eks_cluster_role.name
}

# Kubernetes configuration for frontend service
provider "kubernetes" {
  host                   = aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.eks_cluster.name]
    command     = "aws"
  }
}

resource "kubernetes_service" "frontend" {
  metadata {
    name = "frontend-service"
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
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    type = "NodePort"
  }
}

# Create IAM Role for AWS Load Balancer Controller
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "AWSLoadBalancerControllerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${var.account_id}:oidc-provider/${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud": "sts.amazonaws.com",
            "${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

# Create IAM Policy for AWS Load Balancer Controller
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name = "AWSLoadBalancerControllerPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateSecurityGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
  role       = aws_iam_role.aws_load_balancer_controller.name
}

#############################
# S3 Buckets for Logs
#############################

# Create the base bucket
resource "aws_s3_bucket" "cf_logs" {
  bucket = "doc-query-cloudfront-logs-${var.account_id}"
}
resource "aws_s3_bucket" "waf_logs" {
  bucket = "doc-query-waf-logs-${var.account_id}"
}

# Enable versioning
resource "aws_s3_bucket_versioning" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_versioning" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Set up bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
resource "aws_s3_bucket_ownership_controls" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Set up ACL for log delivery
resource "aws_s3_bucket_acl" "cf_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.cf_logs]
  
  bucket = aws_s3_bucket.cf_logs.id
  acl    = "log-delivery-write"
}
resource "aws_s3_bucket_acl" "waf_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.waf_logs]
  
  bucket = aws_s3_bucket.waf_logs.id
  acl    = "log-delivery-write"
}

# Configure lifecycle rule
resource "aws_s3_bucket_lifecycle_configuration" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id

  rule {
    id     = "log-expiration"
    status = "Enabled"

    expiration {
      days = 3
    }
  }
}
resource "aws_s3_bucket_lifecycle_configuration" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id

  rule {
    id     = "log-expiration"
    status = "Enabled"

    expiration {
      days = 3
    }
  }
}

#############################
# Kinesis Data Streams for Logs
#############################
resource "aws_kinesis_stream" "cf_realtime_logs" {
  name         = "cf-realtime-logs-stream"
  shard_count  = 1
  retention_period = 24  # retention period in hours; adjust as needed
}

# IAM Role for CloudFront Real-time Logging
resource "aws_iam_role" "cf_realtime_logs_role" {
  name = "cf-realtime-logs-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "cf_realtime_logs_policy" {
  name        = "cf-realtime-logs-policy"
  description = "Allow CloudFront to put records into the Kinesis stream for real-time logging"
  policy      = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ],
        "Resource": aws_kinesis_stream.cf_realtime_logs.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cf_realtime_logs_attach" {
  role       = aws_iam_role.cf_realtime_logs_role.name
  policy_arn = aws_iam_policy.cf_realtime_logs_policy.arn
}

# CloudFront Real-time Log Config
resource "aws_cloudfront_realtime_log_config" "cf_realtime_config" {
  name          = "cfRealtimeLogConfig"
  sampling_rate = 100  # sample 100% of requests; adjust as needed
  fields        = ["timestamp", "c-ip", "cs-method", "cs-uri-stem", "sc-status"]

  endpoint {
    stream_type = "Kinesis"
    kinesis_stream_config {
      role_arn   = aws_iam_role.cf_realtime_logs_role.arn
      stream_arn = aws_kinesis_stream.cf_realtime_logs.arn
    }
  }
}

# WAF
resource "aws_iam_role" "firehose_role" {
  provider    = aws.us_east_1
  name = "waf-firehose-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "firehose.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
EOF
}

resource "aws_iam_policy" "firehose_policy" {
  provider    = aws.us_east_1
  name        = "waf-firehose-policy"
  description = "Policy allowing Firehose to write to the WAF logs S3 bucket"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:AbortMultipartUpload"
        ],
        Resource = "${aws_s3_bucket.waf_logs.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "firehose_role_attach" {
  provider   = aws.us_east_1
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}

resource "aws_kinesis_firehose_delivery_stream" "waf_firehose" {
  provider    = aws.us_east_1
  name        = "aws-waf-logs-doc-query"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.waf_logs.arn
    buffering_interval = 300
    compression_format = "UNCOMPRESSED"
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "waf_logging" {
  provider = aws.us_east_1
  resource_arn = aws_wafv2_web_acl.frontend_acl.arn
  log_destination_configs = [
    aws_kinesis_firehose_delivery_stream.waf_firehose.arn
  ]
}

#############################
# CloudFront and WAF for Frontend Access Control
#############################
resource "aws_wafv2_ip_set" "laptop_ip_set" {
  provider           = aws.us_east_1
  name               = "laptop-ip-set"
  description        = "Allowed IP addresses for frontend access"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = [var.laptop_ip]
}

resource "aws_wafv2_web_acl" "frontend_acl" {
  provider    = aws.us_east_1
  name        = "frontend-acl"
  description = "Allow only laptop IP for frontend access"
  scope       = "CLOUDFRONT"

  default_action {
    block {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "frontendACL"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AllowLaptop"
    priority = 1
    action {
      allow {}
    }
    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.laptop_ip_set.arn
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowLaptopRule"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_cloudfront_distribution" "frontend_cf" {
  enabled             = true
  default_root_object = "/"

  origin {
    domain_name = aws_lb.frontend_alb.dns_name
    origin_id   = "alb-frontend-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id        = "alb-frontend-origin"
    viewer_protocol_policy  = "redirect-to-https"
    allowed_methods         = ["GET", "HEAD", "OPTIONS"]
    cached_methods          = ["GET", "HEAD", "OPTIONS"]
    realtime_log_config_arn = aws_cloudfront_realtime_log_config.cf_realtime_config.arn

    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Enable CloudFront logging
  logging_config {
    bucket          = aws_s3_bucket.cf_logs.bucket_regional_domain_name
    include_cookies = false
    prefix          = "cloudfront-logs/"
  }

  web_acl_id = aws_wafv2_web_acl.frontend_acl.arn

  tags = {
    Name = "frontend-cf-distribution"
  }
}

#############################
# AWS Secrets Manager for OpenAI Keys
#############################
resource "aws_secretsmanager_secret" "openai_keys" {
  name        = "doc_query_openai_keys"
  description = "OpenAI API keys for doc_query backend"
}

resource "aws_secretsmanager_secret_version" "openai_keys_version" {
  secret_id     = aws_secretsmanager_secret.openai_keys.id
  secret_string = jsonencode({
    OPENAI_API_KEY         = var.openai_api_key
    OPENAI_ORGANIZATION_ID = var.openai_org_id
  })
}


#############################
# AWS Systems Manager Parameter Store for Environment Variables
#############################

resource "aws_ssm_parameter" "backend_vector_db" {
  name        = "/doc_query/backend/VECTOR_DB"
  description = "Database type for backend"
  type        = "String"
  value       = "redis"
  
  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "backend_redis_host" {
  name        = "/doc_query/backend/REDIS_HOST"
  description = "Redis host for backend"
  type        = "String"
  #value       = aws_elasticache_cluster.redis_cluster.cache_nodes[0].address
  value       = "doc-redis.doc-query.svc.cluster.local"
  
  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "backend_redis_port" {
  name        = "/doc_query/backend/REDIS_PORT"
  description = "Redis port for backend"
  type        = "String"
  value       = "6379"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "frontend_backend_host" {
  name        = "/doc_query/frontend/BACKEND_HOST"
  description = "Backend host for frontend"
  type        = "String"
  value       = "doc-backend.doc-query.svc.cluster.local"
  
  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "frontend_backend_port" {
  name        = "/doc_query/frontend/BACKEND_PORT"
  description = "Backend port for frontend"
  type        = "String"
  value       = "8003"

  lifecycle {
    ignore_changes = [value]
  }
}

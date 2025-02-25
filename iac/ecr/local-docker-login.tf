# Obtain the login credentials so that docker can interact with ECR.
resource "null_resource" "docker_login" {
  # Creation provisioner
  provisioner "local-exec" {
    command  = "echo 'INFO: Set up docker login credentials for ECR' && aws ecr get-login-password --region ${var.aws_region} --profile ${var.aws_profile} | docker login --username AWS --password-stdin ${var.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  }

  # Build the docker images.
  provisioner "local-exec" {
    command = "echo 'INFO: Building docker images for ECR' && cd ecr && ecr_login.sh && cd .."
  }

}

# Added here but might not be needed if the deployment user already have access to ECR.
resource "aws_iam_policy" "ecr_push" {
  name = "ECRPushPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = [
          aws_ecr_repository.backend.arn,
          aws_ecr_repository.frontend.arn
        ]
      },
      {
        Effect = "Allow"
        Action = "ecr:GetAuthorizationToken"
        Resource = "*"
      }
    ]
  })
}
# --------------------------------------
# AWS Secrets Manager for OpenAI Keys
# --------------------------------------
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

resource "aws_iam_policy" "secrets_access" {
  name = "eks-secrets-access-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.openai_keys.arn
        ]
      }
    ]
  })
}

resource "kubernetes_service_account" "frontend_sa" {
  metadata {
    name      = "frontend-sa"
    namespace = kubernetes_namespace.doc_query.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.frontend_role.arn
    }
  }
}

resource "aws_iam_role" "frontend_role" {
  name = "frontend-eks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:${kubernetes_namespace.doc_query.metadata[0].name}:frontend-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "frontend_secrets" {
  policy_arn = aws_iam_policy.secrets_access.arn
  role       = aws_iam_role.frontend_role.name
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

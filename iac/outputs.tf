# -------
# Outputs
# -------

# Output the Cloudfront URL.
output "cloudfront_url" {
  description = "The CloudFront Distribution URL"
  value       = "https://${aws_cloudfront_distribution.frontend_cf.domain_name}"
}

# Output the Kubernetes NLB URL.
output "k8s_nlb_url" {
  description = "The external URL for the Network Load Balancer in the EKS Cluster"
  value       = "http://${data.aws_lb.k8s_nlb.dns_name}:3003"
}

# Output Buckets URLs.
output "s3_cf_logs" {
  description = "The external URL for the S3 bucket for Cloudfront logs."
  value = aws_s3_bucket.cf_logs.bucket_domain_name
}

output "s3_waf_logs" {
  description = "The external URL for the S3 bucket for WAF logs."
  value = aws_s3_bucket.waf_logs.bucket_domain_name
}

output "s3_nlb_logs" {
  description = "The external URL for the S3 bucket for Network Load Balancer logs."
  value = aws_s3_bucket.nlb_logs.bucket_domain_name
}
#############################
# CloudFront and WAF for Frontend Access Control
#############################

# Specify the external IP of the laptop accessing the frontend, so that we
# can limit all traffic accessing the frontend to this laptop.
resource "aws_wafv2_ip_set" "laptop_ip_set" {
  provider           = aws.us_east_1
  name               = "laptop-ip-set"
  description        = "Allowed IP addresses for frontend access"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = [var.laptop_ip]
}

# Set up the ACL for WAF.
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
    domain_name = data.aws_lb.k8s_nlb.dns_name
    origin_id   = "nlb-frontend-origin"

    custom_origin_config {
      http_port              = 3003
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id        = "nlb-frontend-origin"
    viewer_protocol_policy  = "redirect-to-https"
    allowed_methods         = ["GET", "HEAD", "OPTIONS"]
    cached_methods          = ["GET", "HEAD", "OPTIONS"]
    realtime_log_config_arn = aws_cloudfront_realtime_log_config.cf_realtime_config.arn

    # Use a CachingDisabled cache policy and the AllViewer origin request policy
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled policy ID
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3" # AllViewer policy ID
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
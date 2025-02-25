#############################
# CloudFront and WAF for Frontend Access Control
#############################

# Get the list of prefix IPs for CloudFront, so that they can be used to
# define rules in security groups.
data "aws_ip_ranges" "cloudfront" {
  services = ["cloudfront"]
  regions  = [var.aws_region]
}

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

# Output the Cloudfront URL.
output "cloudfront_url" {
  description = "The CloudFront Distribution URL"
  value       = aws_cloudfront_distribution.frontend_cf.domain_name
}
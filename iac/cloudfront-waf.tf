# ----------------------------------------------
# CloudFront and WAF for Frontend Access Control
# ----------------------------------------------

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



/*
resource "aws_cloudfront_distribution" "frontend_cf" {
  enabled             = true
  default_root_object = "/"
  http_version        = "http2"

  origin {
    domain_name = data.aws_lb.k8s_nlb.dns_name
    origin_id   = "nlb-frontend-origin"

    custom_origin_config {
      http_port              = 3003
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = 60
      origin_keepalive_timeout = 60
    }

    # For verifying CloudFront is the source
    custom_header {
      name  = "X-CloudFront-Source"
      value = "true"
    }

    custom_header {
      name  = "Host"
      value = data.aws_lb.k8s_nlb.dns_name
    }

    # Additional custom headers
    # custom_header {
    #   name  = "X-Forwarded-Host"
    #   value = data.aws_lb.k8s_nlb.dns_name
    # }
  }

  default_cache_behavior {
    target_origin_id        = "nlb-frontend-origin"
    viewer_protocol_policy  = "redirect-to-https"
    allowed_methods         = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods          = ["GET", "HEAD"]
    realtime_log_config_arn = aws_cloudfront_realtime_log_config.cf_realtime_config.arn

    # Use a CachingDisabled cache policy and the AllViewer origin request policy
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled policy ID
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3" # AllViewer policy ID
    
    # Ensure smooth function with WebSockets
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # Add ordered cache behavior for websocket paths if needed
  ordered_cache_behavior {
    #path_pattern     = "/_stcore/*"  # Streamlit core path pattern
    path_pattern     = "*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "nlb-frontend-origin"
    
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled policy ID
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3" # AllViewer policy ID
    
    viewer_protocol_policy = "redirect-to-https"
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # Set Geo-Restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Enable CloudFront logging
  logging_config {
    bucket          = aws_s3_bucket.cf_logs.bucket_regional_domain_name
    include_cookies = true
    prefix          = "cloudfront-logs/"
  }

  # Set WAFv2 ACLs
  web_acl_id = aws_wafv2_web_acl.frontend_acl.arn

  tags = {
    Name = "frontend-cf-distribution"
  }
}
*/

resource "aws_cloudfront_distribution" "frontend_cf" {
  enabled             = true
  default_root_object = "/"
  http_version        = "http2"
  
  # Basic origin configuration
  origin {
    domain_name = data.aws_lb.k8s_nlb.dns_name
    origin_id   = "nlb-frontend-origin"
    origin_path = ""
    
    custom_origin_config {
      http_port              = 3003
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = 60
      origin_keepalive_timeout = 60
    }

    custom_header {
      name  = "X-Forwarded-Host"
      value = "*.cloudfront.net"
    }
    custom_header {
      name  = "X-Forwarded-Proto"
      value = "https"
    }
    custom_header {
      name  = "X-Forwarded-Port"
      value = "3003"
    }
  }
  
  # Simple default cache behavior
  default_cache_behavior {
    target_origin_id       = "nlb-frontend-origin"
    viewer_protocol_policy = "allow-all"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    
    # Use the CachingDisabled policy ID to avoid any caching issues
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3" # AllViewer policy
  }
  
  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "nlb-frontend-origin"
    
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized policy ID
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3" # AllViewer policy ID
    
    viewer_protocol_policy = "allow-all"
    min_ttl     = 0
    default_ttl = 86400  # 1 day
    max_ttl     = 31536000  # 1 year
  }

  ordered_cache_behavior {
    path_pattern     = "/static/media/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "nlb-frontend-origin"
    
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized policy ID
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3" # AllViewer policy ID
    
    viewer_protocol_policy = "allow-all"
    min_ttl     = 0
    default_ttl = 86400  # 1 day
    max_ttl     = 31536000  # 1 year
  }

  ordered_cache_behavior {
    path_pattern     = "*.js"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "nlb-frontend-origin"
    
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized policy ID
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3" # AllViewer policy ID
    
    viewer_protocol_policy = "allow-all"
    min_ttl     = 0
    default_ttl = 86400  # 1 day
    max_ttl     = 31536000  # 1 year
  }

  ordered_cache_behavior {
    path_pattern     = "*.css"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "nlb-frontend-origin"
    
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized policy ID
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3" # AllViewer policy ID
    
    viewer_protocol_policy = "allow-all"
    min_ttl     = 0
    default_ttl = 86400  # 1 day
    max_ttl     = 31536000  # 1 year
  }

  ordered_cache_behavior {
    path_pattern     = "*.woff2"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "nlb-frontend-origin"
    
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized policy ID
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3" # AllViewer policy ID
    
    viewer_protocol_policy = "allow-all"
    min_ttl     = 0
    default_ttl = 86400  # 1 day
    max_ttl     = 31536000  # 1 year
  }

  # Simple certificate setup - using CloudFront default
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  
  # No geo-restriction
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  # Basic logging to track what's happening
  logging_config {
    bucket          = aws_s3_bucket.cf_logs.bucket_regional_domain_name
    include_cookies = true
    prefix          = "cloudfront-logs/"
  }
  
  # No WAF association

  tags = {
    Name = "frontend-cf-distribution"
  }
}

# Update the CloudFront Distributrion X-Forwarded-Host header with the CloudFront Distribution URL.
resource "null_resource" "update_cloudfront_header" {
  depends_on = [
    aws_cloudfront_distribution.frontend_cf
  ]
  
  provisioner "local-exec" {
    command = "echo 'INFO: Updating Cloudfront Custom Header X-Forwarded-Host' && ./cf_upd_xfwdhost_hdr.sh ${aws_cloudfront_distribution.frontend_cf.id} ${aws_cloudfront_distribution.frontend_cf.domain_name}"
  }
}
# -------------------
# S3 Buckets for Logs
# -------------------

# Create the base bucket
resource "aws_s3_bucket" "cf_logs" {
  bucket = "${var.k8s_namespace}-cloudfront-logs-${var.account_id}"
}
resource "aws_s3_bucket" "waf_logs" {
  bucket = "${var.k8s_namespace}-waf-logs-${var.account_id}"
}
resource "aws_s3_bucket" "nlb_logs" {
  bucket = "${var.k8s_namespace}-nlb-logs-${var.account_id}"
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
resource "aws_s3_bucket_versioning" "nlb_logs" {
  bucket = aws_s3_bucket.nlb_logs.id
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
resource "aws_s3_bucket_ownership_controls" "nlb_logs" {
  bucket = aws_s3_bucket.nlb_logs.id
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
resource "aws_s3_bucket_acl" "nlb_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.nlb_logs]

  bucket = aws_s3_bucket.nlb_logs.id
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

    filter {}
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

    filter {}
  }
}
resource "aws_s3_bucket_lifecycle_configuration" "nlb_logs" {
  bucket = aws_s3_bucket.nlb_logs.id

  rule {
    id     = "log-expiration"
    status = "Enabled"

    expiration {
      days = 3
    }

    filter {}
  }
}


# -------------------------------------
# Access Logs for Network Load Balancer
# -------------------------------------

# Create a bucket policy that allows the NLB to write logs to s3.
# The NLB access logs are delivered by AWS's log delivery service directly, not by the 
# NLB controller on Kubernetes.
resource "aws_s3_bucket_policy" "nlb_logs_policy" {
  bucket = aws_s3_bucket.nlb_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.nlb_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "s3:GetBucketAcl"
        ]
        Resource = aws_s3_bucket.nlb_logs.arn
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.elb_account_id}:root"
        }
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.nlb_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.elb_account_id}:root"
        }
        Action = [
          "s3:GetBucketAcl"
        ]
        Resource = aws_s3_bucket.nlb_logs.arn
      }
    ]
  })
}


# -----------------------------
# Kinesis Data Streams for Logs
# -----------------------------

resource "aws_kinesis_stream" "cf_realtime_logs" {
  name             = "cf-realtime-logs-stream"
  shard_count      = 1
  retention_period = 24 # retention period in hours; adjust as needed
}

# IAM Role for CloudFront Real-time Logging
resource "aws_iam_role" "cf_realtime_logs_role" {
  name               = "cf-realtime-logs-role"
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

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ],
        "Resource" : aws_kinesis_stream.cf_realtime_logs.arn
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
  sampling_rate = 100 # sample 100% of requests; adjust as needed
    fields      = [
    "timestamp", "c-ip", "cs-method", "cs-uri-stem", "sc-status", 
    "sc-bytes", "cs-protocol", "x-edge-location", "x-edge-result-type", 
    "x-edge-response-result-type", "x-edge-detailed-result-type"
  ]

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
  provider           = aws.us_east_1
  name               = "waf-firehose-role"
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
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
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
  name        = "aws-waf-logs-${var.k8s_namespace}"
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
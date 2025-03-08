# variables.tf

# Define the AWS region variable with a default value
variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

# Define the laptop IP address variable without a default value
variable "laptop_ip" {
  description = "Laptop's public IP address in CIDR notation."
  type        = string
  sensitive   = true
}

# Define your AWS account ID variable
variable "account_id" {
  description = "AWS account ID used for ECR repository image paths."
  type        = string
}

# Define your local AWS account profile
variable "aws_profile" {
  description = "Local AWS account profile."
  type        = string
}

# Define the name of the Kubernetes namespace for Kubernetes resources.
variable "k8s_namespace" {
  description = "Kubernetes namespace used to deploy Kubernetes resources."
  type        = string
  default     = "doc-query"
}

# OpenAI API Key variable
variable "openai_api_key" {
  description = "OpenAI API Key"
  type        = string
  sensitive   = true
}

# OpenAI API Key variable
variable "openai_org_id" {
  description = "OpenAI Organisation ID"
  type        = string
  sensitive   = true
}

# This is an AWS-owned account ID that's specific to the Elastic Load Balancing service 
# in each region. It's the account from which AWS's ELB service writes logs to an S3 bucket.
# These AWS service account IDs are fixed values provided by AWS for each region. They represent the 
# service principals that AWS uses behind the scenes to deliver logs from managed services like ELB.
# These IDs are published in the AWS documentation:
# Reference: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html#access-logging-bucket-permissions
variable "elb_account_id" {
  description = "AWS Elastic Load Balancing Account ID for the region"
  type        = string
  default     = "127311923021" # us-east-1 ELB account ID, change for other regions
}
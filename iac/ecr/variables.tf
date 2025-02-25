# variables.tf

# Define the AWS region variable with a default value
variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

# Define your AWS account ID variable
variable "account_id" {
  description = "AWS account ID used for ECR repository image paths."
  type        = string
  sensitive   = true
}

# Define your local AWS account profile
variable "aws_profile" {
  description = "Local AWS account profile."
  type        = string
}
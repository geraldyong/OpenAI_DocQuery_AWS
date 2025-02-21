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

# OpenAI API Key variable
variable "openai_api_key" {
  description = "OpenAI API Key"
  type        = string
}

# OpenAI API Key variable
variable "openai_org_id" {
  description = "OpenAI Organisation ID"
  type        = string
}
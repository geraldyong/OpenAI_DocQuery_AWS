#!/bin/bash

AWS_PROFILE=`cat ../terraform.tfvars | egrep "^aws_profile" | cut -f2 -d'"'`
AWS_ACCOUNT=`cat ../terraform.tfvars | egrep "^account_id" | cut -f2 -d'"'`
AWS_REGION=`cat ../terraform.tfvars | egrep "^aws_region" | cut -f2 -d'"'`
TARGET_ECR=${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
REPO_NAME=doc-query

# Set up docker credentials.
# echo "INFO: Set up docker login credentials for ECR"
# aws ecr get-login-password --region ${AWS_REGION} --profile ${AWS_PROFILE} | \
#   docker login --username AWS --password-stdin ${TARGET_ECR}

# Create repositories.
# echo "INFO: Creating ECR repository ${REPO_NAME}/backend"
# aws ecr create-repository --repository-name ${REPO_NAME}/backend  --region ${AWS_REGION} --profile ${AWS_PROFILE}
# echo "INFO: Creating ECR repository doc-query/frontend"
# aws ecr create-repository --repository-name ${REPO_NAME}/frontend --region ${AWS_REGION} --profile ${AWS_PROFILE}

# Build for cloud.
echo "INFO: Building images for AWS"
cd ../../backend
docker buildx build --builder linux -t ${TARGET_ECR}/${REPO_NAME}/backend:latest --push .
cd ../frontend
docker buildx build --builder linux -t ${TARGET_ECR}/${REPO_NAME}/frontend:latest --push .
cd ../iac/ecr
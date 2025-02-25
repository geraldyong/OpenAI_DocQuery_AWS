#!/bin/bash

# This script is only required if the kubeconfig needs to be manually updated.
AWS_PROFILE=acloudguru
AWS_ACCOUNT=`cat ../terraform.tfvars | egrep "^account_id" | cut -f2 -d'"'`
AWS_REGION=`cat ../terraform.tfvars | egrep "^aws_region" | cut -f2 -d'"'`
TARGET_ECR=${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Check for clusters.
echo "INFO: Looking for EKS clusters"
EKS_CLUSTER=`aws eks list-clusters --output text --profile ${AWS_PROFILE} --region ${AWS_REGION} | awk '{ print $2; }'`

# Update kubeconfig.
echo "INFO: Updating kubeconfig for EKS cluster ${EKS_CLUSTER}"
aws eks update-kubeconfig --profile=${AWS_PROFILE} --region ${AWS_REGION} --name=${EKS_CLUSTER}

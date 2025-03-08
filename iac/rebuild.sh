#!/bin/bash

# Clear Terraform State.
cleanup() {
  # Use this only when your cloud account is no longer available, otherwise use terraform destroy.
  echo "------------------------------"
  echo "INFO: Clearing Terraform state"
  echo "------------------------------"
  terraform state list | while read i; do terraform state rm $i; done
  # Clear out backups.
  rm -f terraform.tfstate.*
}

# Destroy existing resources if the cloud account is still active.
destroy() {
  echo "------------------------------"
  echo "INFO: Destroying all resources"
  echo "------------------------------"
  terraform init
  terraform plan
  terraform destroy -auto-approve
}

# Build Terraform.
setup() {
  echo "-------------------------------------"
  echo "INFO: Setting up cloud infrastructure"
  echo "-------------------------------------"
  terraform init
  terraform plan
  terraform apply -auto-approve
}

# Menu Management
_menu_troubleshoot() {
  local menuOpt=""

  # Source variables from Terraform variable file.
  local AWS_PROFILE=`cat terraform.tfvars | egrep "^aws_profile" | cut -f2 -d'"'`
  local AWS_REGION=`cat terraform.tfvars | egrep "^aws_region" | cut -f2 -d'"'`
  local ACCOUNT_ID=`cat terraform.tfvars | egrep "^account_id" | cut -f2 -d'"'`
  local LAPTOP_IP=`cat terraform.tfvars | egrep "^laptop_ip" | cut -f2 -d'"'`
  local NAMESPACE=`cat terraform.tfvars | egrep "^k8s_namespace" | cut -f2 -d'"'`
  export AWS_PROFILE AWS_REGION LAPTOP_IP ACCOUNT_ID

  while [ "${menuOpt}" != "x" ]; do
    # Displays the menu.
    echo
    echo "=========================="
    echo "  Troubleshooting Menu"
    echo "=========================="
    echo
    echo "  1) Kubernetes frontend logs"
    echo "  2) Kubernetes ALB logs"
    echo "  3) Cloudfront and WAF S3 Logs"
    echo "  4) Cloudfront Distributions"
    echo "  5) WAFv2 Get IP Set"
    echo "  6) WAFv2 Get ACL"
    echo "  7) VPC Flow logs"
    echo "  8) Show Target Groups and Target Group Health"
    echo "  9) Port Forward Frontend Service"
    echo "  x) Return"
    echo
    echo "Please select an option:"
    read menuOpt
    echo

    case "${menuOpt}" in
      1)  echo "----------------------------------"
          echo "INFO: Getting Kubernetes Resources"
          echo "----------------------------------"
          kubectl get all -n ${NAMESPACE}
          echo
          echo "---------------------------------"
          echo "INFO: Getting Kubernetes POD logs"
          echo "---------------------------------"
          kubectl logs -n ${NAMESPACE} -l app=doc-frontend
          echo
          echo "-------------------------------------------"
          echo "INFO: Getting Kubernetes Service event logs"
          echo "-------------------------------------------"
          kubectl describe service doc-frontend-service -n ${NAMESPACE}
          ;;
      2)  echo "-----------------------------------------"
          echo "INFO: Getting Kubernetes ALB Webhook logs"
          echo "-----------------------------------------"
          kubectl logs service/aws-load-balancer-webhook-service -n kube-system
          echo
          echo "-------------------------------------------------------"
          echo "INFO: Getting Kubernetes ALB Controller Deployment logs"
          echo "-------------------------------------------------------"
          kubectl describe deployment.apps/aws-load-balancer-controller -n kube-system
          echo
          echo "-------------------------------------"
          echo "INFO: Getting Kubernetes ALB Pod logs"
          echo "-------------------------------------"
          kubectl logs deployment.apps/aws-load-balancer-controller -n kube-system | grep error
          ;;
      3)  echo "---------------------------------------------------"
          echo "INFO: Checking CloudFront S3 Logs for Laptop access"
          echo "---------------------------------------------------"
          aws s3 ls s3://${NAMESPACE}-cloudfront-logs-${ACCOUNT_ID}/cloudfront-logs/ | awk '{ print $4 }' | while read i; do
            aws s3 cp s3://${NAMESPACE}-cloudfront-logs-${ACCOUNT_ID}/cloudfront-logs/$i .
            gunzip $i
            head -2 ${i::${#i}-3}
            egrep "${LAPTOP_IP}|Error" ${i::${#i}-3}
            rm ${i::${#i}-3}
          done
          echo
          echo "--------------------------------------------"
          echo "INFO: Checking WAF S3 Logs for Laptop access"
          echo "--------------------------------------------"
          aws s3 ls s3://${NAMESPACE}-waf-logs-${ACCOUNT_ID} --recursive | awk '{ print $4 }' | while read i; do
            local LOGFILE=`echo $i | sed "s/.*\///g"`
            aws s3 cp s3://${NAMESPACE}-waf-logs-${ACCOUNT_ID}/$i ${LOGFILE}
            egrep "Laptop|Error" ${LOGFILE}
            rm ${LOGFILE}
          done
          echo
          echo "--------------------------------------------"
          echo "INFO: Checking NLB S3 Logs for Laptop access"
          echo "--------------------------------------------"
          aws s3 ls s3://${NAMESPACE}-nlb-logs-${ACCOUNT_ID}/nlb-logs/AWSLogs/${ACCOUNT_ID}/0/ | awk '{ print $4 }' | while read i; do
            aws s3 cp s3://${NAMESPACE}-nlb-logs-${ACCOUNT_ID}/nlb-logs/AWSLogs/${ACCOUNT_ID}/0/$i .
            gunzip $i
            head -2 ${i::${#i}-3}
            egrep "${LAPTOP_IP}|Error" ${i::${#i}-3}
            rm ${i::${#i}-3}
          done
          ;;
      4)  echo "------------------------------------------"
          echo "INFO: Getting Cloudfront Distribution Info"
          echo "------------------------------------------"
          aws cloudfront list-distributions --region=${AWS_REGION}
          ;;
      5)  echo "--------------------------"
          echo "INFO: Getting WAFv2 IP Set"
          echo "--------------------------"
          local IPSET=`aws wafv2 list-ip-sets --scope=CLOUDFRONT --region=${AWS_REGION} | egrep "\"Name\":|\"Id\":"`
          local IPSET_NAME=`echo ${IPSET} | cut -f4 -d'"'`
          local IPSET_ID=`echo ${IPSET} | cut -f8 -d'"'`
          aws wafv2 get-ip-set --name ${IPSET_NAME} --id ${IPSET_ID} --scope=CLOUDFRONT --region=${AWS_REGION}
          ;;
      6)  echo "-----------------------"
          echo "INFO: Getting WAFv2 ACL"
          echo "-----------------------"
          local ACL=`aws wafv2 list-web-acls --scope=CLOUDFRONT --region=${AWS_REGION} | egrep "\"Name\":|\"Id\":"`
          local ACL_NAME=`echo ${ACL} | cut -f4 -d'"'`
          local ACL_ID=`echo ${ACL} | cut -f8 -d'"'`
          aws wafv2 get-web-acl --name ${ACL_NAME} --id ${ACL_ID} --scope=CLOUDFRONT --region=${AWS_REGION}
          ;;
      7)  echo "----------------------------"
          echo "INFO: Checking VPC Flow logs"
          echo "----------------------------"
          aws logs start-query \
            --log-group-name "/aws/vpc/flow-logs" \
            --start-time $(date -v-1H +%s) \
            --end-time $(date +%s) \
            --query-string "fields @timestamp, srcAddr, dstAddr, srcPort, dstPort, action | filter srcAddr = '${LAPTOP_IP}'"
          ;;
      8)  echo "-------------------------------"
          echo "INFO: Getting ELB Target Groups"
          echo "-------------------------------"
          aws elbv2 describe-target-groups
          echo
          echo "-------------------------------"
          echo "INFO: Getting ELB Target Health"
          echo "-------------------------------"
          local TG=`aws elbv2 describe-target-groups | grep "TargetGroupArn" | cut -f4 -d'"'`
          aws elbv2 describe-target-health --target-group-arn ${TG}
          ;;
      9)  echo "-------------------------------"
          echo "INFO: Creating Port Fwd Service"
          echo "-------------------------------"
          kubectl apply -f kubernetes/frontend-portfwd.yaml
          kubectl port-forward svc/doc-frontend-portfwd 3003:3003 -n ${NAMESPACE}
          kubectl delete svc/doc-frontend-portfwd -n ${NAMESPACE}
          ;;
      [eExXrRqQ]) echo "Returning to main menu."
          return;;
      *)  echo "Invalid option ${menuOpt}.";;
    esac

    # Waits for a key to return.
    echo
    echo "Please press ENTER to return to menu."
    read tmp
  done
}

menu_show() {
  local menuOpt=""

  while [ "${menuOpt}" != "x" ]; do
    # Displays the menu.
    echo
    echo "========================"
    echo "  Doc Query Build Menu"
    echo "========================"
    echo
    echo "AWS Account ID (from terraform.tfvars): "`cat terraform.tfvars | grep account_id | cut -f2 -d'"'`
    echo
    echo "  1) Terraform Destroy existing AWS setup (only if the account is still active)"
    echo "  2) Terraform Wipe Clean State File (if the account has been wiped but state is not cleared)"
    echo "  3) Terraform Setup and Deploy"
    echo "  4) Rebuild Images and Push to ECR"
    echo "  5) Deploy Kubernetes Resources on EKS"
    echo "  6) Troubleshooting"
    echo "  x) Exit"
    echo
    echo "Please select an option:"
    read menuOpt
    echo

    case "${menuOpt}" in
      1)  destroy ;;
      2)  cleanup ;;
      3)  setup ;;
      4)  cd kubernetes
          ./eks_updatekubeconfig.sh
          cd ..
          ./ecr_login.sh
          cd ..;;
      5)  cd kubernetes; 
          ./install.sh; 
          cd ..;; 
      6)  _menu_troubleshoot;;
      [xXqQ]) echo "Goodbye."
          exit 0;;
      *)  echo "Invalid option ${menuOpt}.";;
    esac

    # Waits for a key to return.
    echo
    echo "Please press ENTER to return to menu."
    read tmp
  done
}

# Main Program.
menu_show
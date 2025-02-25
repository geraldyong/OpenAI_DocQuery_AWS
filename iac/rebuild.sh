#!/bin/bash

# Clear Terraform State.
cleanup() {
  # Use this only when your cloud account is no longer available, otherwise use terraform destroy.
  echo "INFO: Clearing Terraform state"
  terraform state list | while read i; do terraform state rm $i; done
  # Clear out backups.
  rm -f terraform.tfstate.*
}

# Destroy existing resources if the cloud account is still active.
destroy() {
  echo "INFO: Destroying all resources"
  terraform init
  terraform plan
  terraform destroy -auto-approve
}

# Build Terraform.
setup() {
  echo "INFO: Setting up cloud infrastructure"
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
  export AWS_PROFILE AWS_REGION LAPTOP_IP ACCOUNT_ID

  while [ "${menuOpt}" != "x" ]; do
    # Displays the menu.
    echo
    echo "=========================="
    echo "  Troubleshooting Menu"
    echo "=========================="
    echo
    echo "1) WAFv2 Get IP Set"
    echo "2) WAFv2 Get ACL"
    echo "3) Cloudfront Distributions"
    echo "4) Kubernetes frontend logs"
    echo "5) VPC Flow logs"
    echo "6) Cloudfront S3 Logs"
    echo "x) Return"
    echo
    echo "Please select an option:"
    read menuOpt
    echo

    case "${menuOpt}" in
      1)  echo "------------------"
          echo "INFO: WAFv2 IP Set"
          echo "------------------"
          local IPSET=`aws wafv2 list-ip-sets --scope=CLOUDFRONT --region=${AWS_REGION} | egrep "\"Name\":|\"Id\":"`
          local IPSET_NAME=`echo ${IPSET} | cut -f4 -d'"'`
          local IPSET_ID=`echo ${IPSET} | cut -f8 -d'"'`
          aws wafv2 get-ip-set --name ${IPSET_NAME} --id ${IPSET_ID} --scope=CLOUDFRONT --region=us-east-1
          ;;
      2)  echo "---------------"
          echo "INFO: WAFv2 ACL"
          echo "---------------"
          local ACL=`aws wafv2 list-web-acls --scope=CLOUDFRONT --region=${AWS_REGION} | egrep "\"Name\":|\"Id\":"`
          local ACL_NAME=`echo ${ACL} | cut -f4 -d'"'`
          local ACL_ID=`echo ${ACL} | cut -f8 -d'"'`
          aws wafv2 get-web-acl --name ${ACL_NAME} --id ${ACL_ID} --scope=CLOUDFRONT --region=us-east-1
          ;;
      3)  echo "----------------------------------"
          echo "INFO: Cloudfront Distribution Info"
          echo "----------------------------------"
          aws cloudfront list-distributions --region=us-east-1
          ;;
      4)  echo "-------------------------"
          echo "INFO: Kubernetes POD logs"
          echo "-------------------------"
          kubectl logs -n doc-query -l app=doc-frontend
          echo
          echo "--------------------------------------------"
          echo "INFO: Kubernetes ALB Controller Service logs"
          echo "--------------------------------------------"
          kubectl describe service aws-load-balancer-webhook-service -n kube-system
          echo
          echo "------------------------------"
          echo "INFO: Kubernetes Service logs"
          echo "------------------------------"
          kubectl describe service doc-frontend-service -n doc-query
          ;;
      5)  echo "-------------------"
          echo "INFO: VPC Flow logs"
          echo "-------------------"
          aws logs start-query \
            --log-group-name "/aws/vpc/flow-logs" \
            --start-time $(date -v-1H +%s) \
            --end-time $(date +%s) \
            --query-string "fields @timestamp, srcAddr, dstAddr, srcPort, dstPort, action | filter srcAddr = '${LAPTOP_IP}'"
          ;;
      6)  echo "---------------------------------------------------"
          echo "INFO: Checking CloudFront S3 Logs for Laptop access"
          echo "---------------------------------------------------"
          aws s3 ls s3://doc-query-cloudfront-logs-${ACCOUNT_ID}/cloudfront-logs/ | cut -f2 -d',' | while read i; do
            aws s3 cp s3://doc-query-cloudfront-logs-${ACCOUNT_ID}/cloudfront-logs/$i .
            gunzip $i
            rm $i
            egrep "${LAPTOP_IP}" ${i:0:-3}
            rm ${i:0:-3}
          done
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
    echo "1) Destroy existing AWS setup (only if the account is still active)"
    echo "2) Cleanup (if the account has been wiped but state is not cleared)"
    echo "3) Setup and Deploy"
    echo "4) Setup ECR and Build Images"
    echo "5) Setup EKS Services"
    echo "6) Troubleshooting"
    echo "x) Exit"
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
          cd ../ecr
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

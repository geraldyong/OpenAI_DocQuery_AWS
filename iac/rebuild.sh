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
    echo "2) Cleanup (if the account is now inactive but state not cleared)"
    echo "3) Setup and Deploy"
    echo "4) Setup ECR and Build Images"
    echo "5) Setup EKS Services"
    echo "x) Exit"
    echo
    echo "Please select an option:"
    read menuOpt
    echo

    case "${menuOpt}" in
      1) destroy ;;
      2) cleanup ;;
      3) setup ;;
      4) ./aws_eks_updatekubeconfig.sh
         ./aws_ecr_login.sh ;;
      5) cd eks; ./install.sh; cd ..;; 
      [xXqQ]) echo "Goodbye."
        exit 0;;
      *) echo "Invalid option ${menuOpt}.";;
    esac

    # Waits for a key to return.
    echo
    echo "Please press ENTER to return to menu."
    read tmp
  done
}


# Main Program.
menu_show

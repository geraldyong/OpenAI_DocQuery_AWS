#!/bin/bash

NAMESPACE=doc-query
AWS_ACCOUNT=`cat ../terraform.tfvars | egrep "^account_id" | cut -f2 -d'"'`
AWS_REGION=`cat ../terraform.tfvars | egrep "^aws_region" | cut -f2 -d'"'`
AWS_PROFILE=`cat ../terraform.tfvars | egrep "^aws_profile" | cut -f2 -d'"'`

# Update ServerHost for Streamlit to point to Cloudfront Distribution URL.
CF_HOST=`aws cloudfront list-distributions --profile ${AWS_PROFILE} | grep DomainName | grep "cloudfront.net" | cut -f4 -d'"'`
if [ `uname` = "Darwin" ]; then
  # MacBook users need an additional parameter for sed.
  sed -i '' "s/STREAMLIT_BROWSER_SERVER_ADDRESS: .*/STREAMLIT_BROWSER_SERVER_ADDRESS: \"${CF_HOST}\"/" frontend-configmap.yaml
else
  sed -i "s/STREAMLIT_BROWSER_SERVER_ADDRESS: .*/STREAMLIT_BROWSER_SERVER_ADDRESS: \"${CF_HOST}\"/" frontend-configmap.yaml
fi
 
echo "INFO: Updating Kubernetes resources"
kubectl apply -f frontend-configmap.yaml
kubectl delete pod/doc-frontend-0 -n ${NAMESPACE}

# Wait for the pods to be ready.
echo "INFO: Checking resources"
while [ `kubectl get pods -n ${NAMESPACE} | awk '{ print $3 }'| egrep -v "Running|STATUS" | wc -l | tr -d ' '` -gt 0 ]; do
  echo "Waiting for pods to come up..."
  sleep 10
done
echo "INFO: Pods are up"
kubectl get all -n ${NAMESPACE}

# Optional: Port-forwarding to test.
# kubectl port-forward svc/doc-backend 8003:8003 -n doc-query
# kubectl port-forward svc/doc-frontend-service 3003:3003 -n doc-query

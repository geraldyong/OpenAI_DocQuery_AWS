#!/bin/bash

NAMESPACE=doc-query
AWS_ACCOUNT=`cat ../terraform.tfvars | egrep "^account_id" | cut -f2 -d'"'`
AWS_REGION=`cat ../terraform.tfvars | egrep "^aws_region" | cut -f2 -d'"'`
AWS_PROFILE=`cat ../terraform.tfvars | egrep "^aws_profile" | cut -f2 -d'"'`
TARGET_ECR=${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
VPC_ID=`aws eks describe-cluster --name eks-apps-cluster --query "cluster.resourcesVpcConfig.vpcId" --profile ${AWS_PROFILE} --region ${AWS_REGION} --output text`

# Update ECR image paths.
if [ `uname` = "Darwin" ]; then
  # MacBook users need an additional parameter for sed.
  sed -i '' "s/image: [0-9]*.*\.com/image: $TARGET_ECR/g" backend.yaml
  sed -i '' "s/image: [0-9]*.*\.com/image: $TARGET_ECR/g" frontend.yaml
  sed -i '' "s/iam::[0-9]*:/iam::${AWS_ACCOUNT}:/g" albc-serviceaccount.yaml
else
  sed -i "s/image: [0-9]*.*\.com/image: $TARGET_ECR/g" backend.yaml
  sed -i "s/image: [0-9]*.*\.com/image: $TARGET_ECR/g" frontend.yaml
  sed -i "s/iam::[0-9]*:/iam::${AWS_ACCOUNT}:/g" albc-serviceaccount.yaml
fi

# Add EKS Helm Charts
echo "INFO: Updating EKS Helm Charts"
helm repo add eks https://aws.github.io/eks-charts
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install resource for secrets.
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace

#kubectl apply -f albc-serviceaccount.yaml
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eks-apps-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=${AWS_REGION} \
  --set vpcId=${VPC_ID} 
  #\
  #--set podDisruptionBudget.maxUnavailable=1 \
  #--set enableServiceMutatorWebhook=false \
  #--set enableEndpointSlices=true \
  #--set serviceAnnotations."meta\.helm\.sh/release-name"=aws-load-balancer-controller \
  #--set serviceAnnotations."meta\.helm\.sh/release-namespace"=kube-system

echo "INFO: Creating Kubernetes resources"
#kubectl apply -f namespace.yaml
#kubectl apply -f albc-ingress.yaml
kubectl apply -f external-secrets.yaml
kubectl apply -f redis.yaml
#kubectl apply -f redis-master.yaml
#kubectl apply -f redis-slaves.yaml
kubectl apply -f backend-configmap.yaml
kubectl apply -f backend-secret.yaml
kubectl apply -f backend.yaml
kubectl apply -f frontend-configmap.yaml
kubectl apply -f frontend.yaml

# Wait for the pods to be ready.
echo "INFO: Checking resources"
while [ `kubectl get pods -n ${NAMESPACE} | grep "Running" | wc -l | tr -d ' '` -eq 0 ]; do
  echo "Waiting for pods to come up..."
  sleep 10
done
echo "INFO: Pods are up"
kubectl get all -n ${NAMESPACE}

# Optional: Port-forwarding to test.
# kubectl port-forward svc/doc-backend 8003:8003 -n doc-query
# kubectl port-forward svc/doc-frontend 3003:3003 -n doc-query
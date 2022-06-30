#!/bin/bash

echo "First set up aws-cli with your creds:"
aws configure

echo "Awailable VPCs:"
aws ec2 describe-vpcs --query "Vpcs[].VpcId" --output text

echo "Enter VPC id to deploy cluster to:"
read VPC_ID
perl -pi -e s,{REPLACE_WITH_VPC_ID},$VPC_ID,g variables.tf

echo "Applying terraform resources:"
terraform init
terraform apply -auto-approve

echo "Update service account with IAM role:"
ROLE_ID=$(terraform output -raw role_id)
perl -pi -e s,{REPLACE_WITH_ROLE},$ROLE_ID,g account.yaml

echo "Configure kubectl:"
REGION=$(terraform output -raw region_name)
CLUSTER_NAME=$(terraform output -raw cluster_name)
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

echo "Create kubernetes resources:"
kubectl create ns opsfleet
kubectl apply -f account.yaml
kubectl apply -f pod.yaml

echo "Trying to get access to S3 from deployed pod (access should be denied):"
kubectl -n opsfleet exec --stdin --tty s3-browser -- aws s3 ls

echo "Trying to get access to specific test S3 bucket (you should see a list of cat pics):"
kubectl -n opsfleet exec --stdin --tty s3-browser -- aws s3 ls opsfleet-test-bucket
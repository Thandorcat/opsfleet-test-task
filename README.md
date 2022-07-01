# Test task for Opsfleet

This repo contains terraform and kubernetes files that demonstrate the ability to create AWS EKS cluster and required infrastructure to deploy a pod with access to test S3 bucket via kubernetes service account.

# Setup

## What you need 

1. AWS account
2. AWS credentials for it. You can create then using this guide: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html
3. aws-cli installed on your machine, instruction: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
4. terraform installed, instructions: https://learn.hashicorp.com/tutorials/terraform/install-cli
5. kubectl installed, instructions: https://kubernetes.io/docs/tasks/tools/

## Using script

If you use linux or macos, you can set up the solution with the provided bash script *setup.sh*.

It will prompt your aws creds and region, and print available VPCs to deploy resources to. You can copy and paste VPC id and script will update *variables.tf*. After that, it will initialize terraform and apply templates. Also, it will update IAM Role created for service account in *account.yaml*. Kubectl will be configured to use newly created EKS cluster, service account and sample pod with amazon/aws-cli container will be created in EKS cluster from *account.yaml* and *pod.yaml* files. 

Created container allows you to test permissions for S3 bucket. Script will execute *aws s3 ls* command that should fail because IAM role connected to kubernetes service account only gives permissions to access *opsfleet-test-bucket* created by terraform.

After that, it will try to list objects in *opsfleet-test-bucket* itself, and you should see files uploaded from *testfiles* directory. Make sure to carefully inspect provided images to improve your mood.

## Manual way

1. First of all you need to configure aws-cli using *aws configure*
2. Then put correct VPC id in *variables.tf*
3. Before creating resources, you need to initialise terraform with *terraform init*.
4. Now you can deploy the infrastructure using *terraform apply*
5. *account.yaml* should be updated with created role, you can find ARN in the outputs of terraform template
6. Connect your kubectl wuth EKS cluster with *aws eks update-kubeconfig --region YOUR_REGION --name CLUSTER_NAME* command, correct values can be also found in the outputs
7. To create kubernetes recources you can use *kubectl apply -f FILENAME* command
8. You can execute commands on newly created pods using *kubectl -n opsfleet exec --stdin --tty POD_NAME -- COMMAND*
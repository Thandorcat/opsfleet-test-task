terraform {
 required_providers {
  aws = {
   source = "hashicorp/aws"
  }
 }
}

data "aws_subnets" "existing_subnets" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b"]
  }

}

resource "aws_iam_role" "eks-iam-role" {
 name = "opsfleet-test-eks-iam-role"

 path = "/"

 assume_role_policy = jsonencode({
   Statement = [{
    Action = "sts:AssumeRole"
    Effect = "Allow"
    Principal = {
     Service = "eks.amazonaws.com"
    }
   }]
   Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
 policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
 role = aws_iam_role.eks-iam-role.name
}
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly-EKS" {
 policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
 role = aws_iam_role.eks-iam-role.name
}

resource "aws_eks_cluster" "opsfleet_test_eks" {
 name = "opsfleet-test-cluster"
 role_arn = aws_iam_role.eks-iam-role.arn

 vpc_config {
  subnet_ids = data.aws_subnets.existing_subnets.ids
 }

 depends_on = [
  aws_iam_role.eks-iam-role,
 ]
}

data "tls_certificate" "tls_cert" {
  url = aws_eks_cluster.opsfleet_test_eks.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_iden_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.tls_cert.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.opsfleet_test_eks.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "eks_iden_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_iden_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:opsfleet:test-service-account"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks_iden_provider.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "eks_service_account_role" {
  assume_role_policy = data.aws_iam_policy_document.eks_iden_assume.json
  name               = "eks_service_account_role"
}


resource "aws_iam_policy" "test_bucket_access" {
  name = "test_bucket_access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:*"
        Effect   = "Allow"
        Resource = [
      aws_s3_bucket.test_bucket.arn,
      "${aws_s3_bucket.test_bucket.arn}/*",
    ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_service_bucket" {
  policy_arn = aws_iam_policy.test_bucket_access.arn
  role    = aws_iam_role.eks_service_account_role.name
}

resource "aws_iam_role" "workernodes" {
  name = "eks-node-group-example"
 
  assume_role_policy = jsonencode({
   Statement = [{
    Action = "sts:AssumeRole"
    Effect = "Allow"
    Principal = {
     Service = "ec2.amazonaws.com"
    }
   }]
   Version = "2012-10-17"
  })
 }
 
resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role    = aws_iam_role.workernodes.name
}
 
resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role    = aws_iam_role.workernodes.name
}
 
resource "aws_iam_role_policy_attachment" "EC2InstanceProfileForImageBuilderECRContainerBuilds" {
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
  role    = aws_iam_role.workernodes.name
}
 
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role    = aws_iam_role.workernodes.name
}

resource "aws_eks_node_group" "worker_node_group" {
  cluster_name  = aws_eks_cluster.opsfleet_test_eks.name
  node_group_name = "opsfleet-test-workernodes"
  node_role_arn  = aws_iam_role.workernodes.arn
  subnet_ids   = data.aws_subnets.existing_subnets.ids
  instance_types = ["t2.micro"]
 
  scaling_config {
    desired_size = 2
    max_size   = 3
    min_size   = 1
  }
 
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_s3_bucket" "test_bucket" {
  bucket = "opsfleet-test-bucket"
}

resource "aws_s3_object" "testfiles" {
  for_each = fileset("testfiles/", "*")
  bucket = aws_s3_bucket.test_bucket.id
  key = each.value
  source = "testfiles/${each.value}"
  etag = filemd5("testfiles/${each.value}")
}

output "role_id" {
  description = "Role for kuberneries service account"
  value       = aws_iam_role.eks_service_account_role.arn
}

output "cluster_name" {
  description = "Name of a EKS cluster"
  value       = aws_eks_cluster.opsfleet_test_eks.name
}

data "aws_region" "current" {}

output "region_name" {
  description = "Current AWS region"
  value       = data.aws_region.current.name
}
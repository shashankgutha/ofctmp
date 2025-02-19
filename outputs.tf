output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.name
}

output "eks_cluster_endpoint" {
  description = "The endpoint for the EKS cluster API server"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "eks_cluster_certificate_authority" {
  description = "Certificate authority data for the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}

output "eks_cluster_role_arn" {
  description = "The ARN of the IAM role used by the EKS cluster"
  value       = aws_iam_role.eks_cluster_role.arn
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.eks_vpc.id
}

output "subnet_ids" {
  description = "The IDs of the subnets used by the EKS cluster"
  value       = [aws_subnet.eks_subnet_1.id, aws_subnet.eks_subnet_2.id]
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for EKS cluster encryption"
  value       = aws_kms_key.eks_key.arn
}

output "kms_key_alias" {
  description = "The alias of the KMS key"
  value       = aws_kms_alias.eks_key_alias.name
}

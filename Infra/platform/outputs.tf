output "cluster_name" {
  description = "Created EKS cluster name."
  value       = module.eks.cluster_name
}

output "vpc_id" {
  description = "VPC ID used by the EKS platform stack."
  value       = module.vpc.vpc_id
}

output "ecr_repository_name" {
  description = "ECR repository name for application images."
  value       = aws_ecr_repository.llm_gateway.name
}

output "ecr_repository_url" {
  description = "ECR repository URL for application images."
  value       = aws_ecr_repository.llm_gateway.repository_url
}

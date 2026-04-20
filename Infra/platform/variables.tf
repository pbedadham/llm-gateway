# Variables 
variable "aws_region" {
  description = "AWS region for the EKS cluster."
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "llm-gateway-cluster"
}

variable "ecr_repository_name" {
  description = "ECR repository name for the llm-gateway container image."
  type        = string
  default     = "llm-gateway"
}

variable "cluster_admin_principal_arn" {
  description = "IAM principal ARN to grant EKS cluster admin access."
  type        = string
}

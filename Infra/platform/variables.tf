# Variables 
variable "aws_region" {
  description = "AWS region for the EKS cluster."
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "ai-infrastructure-2026"
}

variable "ecr_repository_name" {
  description = "ECR repository name for the llm-gateway container image."
  type        = string
  default     = "llm-gateway"
}

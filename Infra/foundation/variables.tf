variable "aws_region" {
  description = "AWS region for Terraform backend resources."
  type        = string
  default     = "us-west-2"
}

variable "tf_state_bucket" {
  description = "S3 bucket name for Terraform remote state."
  type        = string
}

variable "tf_lock_table" {
  description = "DynamoDB table name for Terraform state locking."
  type        = string
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_ecr_repository" "llm_gateway" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = "1.33"

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  eks_managed_node_groups = {
    gpu_nodes = {
      capacity_type  = "SPOT"
      instance_types = ["g4dn.xlarge", "g5.xlarge", "g6.xlarge"]
      ami_type       = "AL2023_x86_64_NVIDIA"

      min_size     = 1
      max_size     = 3
      desired_size = 1

      taints = {
        hardware = {
          key    = "hardware"
          value  = "gpu"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }
}

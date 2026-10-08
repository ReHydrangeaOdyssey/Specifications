resource "terraform_data" "manual_guard" {
  lifecycle {
    precondition {
      condition     = var.manual_aws_creation_confirmation == "CREATE_AWS_ENVIRONMENT_MANUALLY"
      error_message = "AWS環境は自動作成しない. manual_aws_creation_confirmationを明示的に設定すること."
    }
    precondition {
      condition     = var.node_min_size <= var.node_desired_size && var.node_desired_size <= var.node_max_size
      error_message = "node sizeは min <= desired <= max とする."
    }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr
  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  depends_on = [terraform_data.manual_guard]
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.26.0"

  name               = "${var.project_name}-eks"
  kubernetes_version = var.eks_kubernetes_version

  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.eks_admin_public_access_cidrs
  endpoint_private_access      = true
  enable_cluster_creator_admin_permissions = true
  enable_irsa = true
  deletion_protection = true

  compute_config = {
    enabled = false
  }

  addons = {
    coredns    = {}
    "kube-proxy" = {}
    "vpc-cni" = {
      before_compute = true
    }
    "aws-ebs-csi-driver" = {}
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    game = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      capacity_type  = "ON_DEMAND"
      iam_role_additional_policies = {
        ebs_csi = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
      labels = {
        workload = "game"
      }
      tags = {
        "k8s.io/cluster-autoscaler/enabled"                  = "true"
        "k8s.io/cluster-autoscaler/${var.project_name}-eks" = "owned"
      }
    }
  }

  depends_on = [terraform_data.manual_guard]
}

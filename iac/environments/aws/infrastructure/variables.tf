variable "manual_aws_creation_confirmation" {
  type        = string
  sensitive   = true
  description = "AWS作成を明示的に許可する確認文字列."
}

variable "project_name" {
  type    = string
  default = "game"
}

variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.80.0.0/16"
}

variable "availability_zones" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "eks_kubernetes_version" {
  type = string
}

variable "eks_admin_public_access_cidrs" {
  type = list(string)
}

variable "node_instance_types" {
  type    = list(string)
  default = ["m7i.large"]
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_desired_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "cluster_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_issuer_url" {
  type = string
}

variable "cluster_autoscaler_chart_version" {
  type = string
}

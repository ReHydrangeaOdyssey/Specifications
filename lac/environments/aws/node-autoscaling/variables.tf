variable "manual_node_autoscaling_confirmation" {
  type      = string
  sensitive = true
}

variable "aws_region" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "cluster_autoscaler_chart_version" {
  type = string

  validation {
    condition     = length(trimspace(var.cluster_autoscaler_chart_version)) > 0 && var.cluster_autoscaler_chart_version != "CHANGE_ME"
    error_message = "Cluster Autoscaler Chart Versionを明示的に固定すること."
  }
}

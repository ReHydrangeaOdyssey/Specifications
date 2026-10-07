variable "namespace" {
  type    = string
  default = "game"
}

variable "public_api_image" {
  type = string
}

variable "game_server_image" {
  type = string
}

variable "coordinator_image" {
  type = string
}

variable "game_server_scaler_image" {
  type = string
}

variable "public_api_port" {
  type = number
  validation {
    condition     = var.public_api_port > 0 && var.public_api_port <= 65535
    error_message = "public_api_portを1-65535で明示すること."
  }
}

variable "game_server_port" {
  type = number
  validation {
    condition     = var.game_server_port > 0 && var.game_server_port <= 65535
    error_message = "game_server_portを1-65535で明示すること."
  }
}

variable "game_server_control_port" {
  type = number
  validation {
    condition     = var.game_server_control_port > 0 && var.game_server_control_port <= 65535
    error_message = "game_server_control_portを1-65535で明示すること."
  }
}

variable "scaler_control_port" {
  type = number
  validation {
    condition     = var.scaler_control_port > 0 && var.scaler_control_port <= 65535
    error_message = "scaler_control_portを1-65535で明示すること."
  }
}

variable "private_api_port" {
  type = number
  validation {
    condition     = var.private_api_port > 0 && var.private_api_port <= 65535
    error_message = "private_api_portを1-65535で明示すること."
  }
}

variable "private_api_cidr" {
  type        = string
  description = "NetworkPolicyからPrivate APIへ到達を許可するCIDR. 可能な限り/32を使用する."
}


variable "kubernetes_api_cidr" {
  type        = string
  description = "Public API, Coordinator, ScalerからKubernetes APIへ到達を許可するCIDR."
}

variable "discord_bot_cidr" {
  type        = string
  default     = null
  nullable    = true
  description = "Discord通知を有効にする場合のBot到達先CIDR. nullの場合はBot向けEgressを作成しない."
}

variable "discord_bot_port" {
  type    = number
  default = 0
  validation {
    condition     = var.discord_bot_cidr == null || (var.discord_bot_port > 0 && var.discord_bot_port <= 65535)
    error_message = "discord_bot_cidrを設定する場合はdiscord_bot_portを1-65535で明示すること."
  }
}

variable "public_api_env" {
  type    = map(string)
  default = {}
}

variable "game_server_env" {
  type    = map(string)
  default = {}
}

variable "coordinator_env" {
  type    = map(string)
  default = {}
}

variable "game_server_scaler_env" {
  type    = map(string)
  default = {}
}

variable "replay_mount_path" {
  type = string
  validation {
    condition     = startswith(var.replay_mount_path, "/")
    error_message = "replay_mount_pathは絶対Pathで明示すること."
  }
}

variable "public_api_service_type" {
  type    = string
  default = "NodePort"

  validation {
    condition     = contains(["ClusterIP", "NodePort", "LoadBalancer"], var.public_api_service_type)
    error_message = "public_api_service_typeはClusterIP, NodePort, LoadBalancerのいずれかとする."
  }
}

variable "public_api_service_annotations" {
  type    = map(string)
  default = {}
}

variable "public_api_min_replicas" {
  type    = number
  default = 1
}

variable "public_api_max_replicas" {
  type    = number
  default = 4
}

variable "public_api_target_cpu_utilization" {
  type    = number
  default = 65
}

variable "enable_public_api_hpa" {
  type    = bool
  default = true
}

variable "game_server_initial_replicas" {
  type    = number
  default = 1
}


variable "public_api_cpu_request" {
  type    = string
  default = "250m"
}

variable "public_api_cpu_limit" {
  type    = string
  default = "1000m"
}

variable "public_api_memory_request" {
  type    = string
  default = "256Mi"
}

variable "public_api_memory_limit" {
  type    = string
  default = "1Gi"
}

variable "game_server_cpu_request" {
  type    = string
  default = "1000m"
}

variable "game_server_cpu_limit" {
  type    = string
  default = "2000m"
}

variable "game_server_memory_request" {
  type    = string
  default = "1Gi"
}

variable "game_server_memory_limit" {
  type    = string
  default = "2Gi"
}

variable "coordinator_cpu_request" {
  type    = string
  default = "100m"
}

variable "coordinator_cpu_limit" {
  type    = string
  default = "500m"
}

variable "coordinator_memory_request" {
  type    = string
  default = "128Mi"
}

variable "coordinator_memory_limit" {
  type    = string
  default = "512Mi"
}

variable "scaler_cpu_request" {
  type    = string
  default = "100m"
}

variable "scaler_cpu_limit" {
  type    = string
  default = "500m"
}

variable "scaler_memory_request" {
  type    = string
  default = "128Mi"
}

variable "scaler_memory_limit" {
  type    = string
  default = "512Mi"
}

variable "mtls_secret_public_api" {
  type = string
}

variable "mtls_secret_game_server" {
  type = string
}

variable "mtls_secret_coordinator" {
  type = string
}

variable "mtls_secret_scaler" {
  type = string
}

variable "replay_storage_size" {
  type    = string
  default = "5Gi"
}

variable "recovery_storage_size" {
  type    = string
  default = "1Gi"
}

variable "game_server_storage_class_name" {
  type     = string
  default  = null
  nullable = true
}

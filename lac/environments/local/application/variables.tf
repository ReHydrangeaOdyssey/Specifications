variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}

variable "kubeconfig_context" {
  type     = string
  default  = null
  nullable = true
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
}
variable "game_server_port" {
  type = number
}
variable "game_server_control_port" {
  type = number
}
variable "scaler_control_port" {
  type = number
}
variable "private_api_port" {
  type = number
}
variable "discord_bot_cidr" {
  type     = string
  default  = null
  nullable = true
}
variable "discord_bot_port" {
  type    = number
  default = 0
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
}

variable "private_api_cidr" {
  type = string
}

variable "kubernetes_api_cidr" {
  type = string
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

variable "public_api_max_replicas" {
  type    = number
  default = 4
}


variable "game_server_storage_class_name" {
  type     = string
  default  = null
  nullable = true
}

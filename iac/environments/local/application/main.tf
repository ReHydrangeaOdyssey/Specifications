module "game_platform" {
  source = "../../../modules/game-platform"

  namespace                    = "game"
  public_api_image             = var.public_api_image
  game_server_image            = var.game_server_image
  coordinator_image            = var.coordinator_image
  game_server_scaler_image     = var.game_server_scaler_image
  public_api_port              = var.public_api_port
  game_server_port             = var.game_server_port
  game_server_control_port     = var.game_server_control_port
  scaler_control_port          = var.scaler_control_port
  private_api_port             = var.private_api_port
  discord_bot_cidr             = var.discord_bot_cidr
  discord_bot_port             = var.discord_bot_port
  public_api_env               = var.public_api_env
  game_server_env              = var.game_server_env
  coordinator_env              = var.coordinator_env
  game_server_scaler_env       = var.game_server_scaler_env
  replay_mount_path            = var.replay_mount_path
  private_api_cidr             = var.private_api_cidr
  kubernetes_api_cidr          = var.kubernetes_api_cidr
  public_api_service_type      = "NodePort"
  public_api_min_replicas      = 1
  public_api_max_replicas      = var.public_api_max_replicas
  game_server_initial_replicas = 1
  game_server_storage_class_name = var.game_server_storage_class_name

  mtls_secret_public_api  = var.mtls_secret_public_api
  mtls_secret_game_server = var.mtls_secret_game_server
  mtls_secret_coordinator = var.mtls_secret_coordinator
  mtls_secret_scaler      = var.mtls_secret_scaler
}

output "namespace" {
  value = kubernetes_namespace_v1.game.metadata[0].name
}

output "public_api_service_name" {
  value = kubernetes_service_v1.public_api.metadata[0].name
}

output "game_server_statefulset_name" {
  value = kubernetes_stateful_set_v1.game_server.metadata[0].name
}

output "coordinator_name" {
  value = kubernetes_deployment_v1.coordinator.metadata[0].name
}

output "scaler_name" {
  value = kubernetes_deployment_v1.game_server_scaler.metadata[0].name
}

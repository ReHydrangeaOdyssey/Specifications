locals {
  labels = {
    "app.kubernetes.io/part-of" = "game-platform"
  }
}

resource "kubernetes_namespace_v1" "game" {
  metadata {
    name = var.namespace
    labels = merge(local.labels, {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    })
  }
}

resource "kubernetes_service_account_v1" "public_api" {
  metadata {
    name      = "public-api"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
  }
  automount_service_account_token = true
}

resource "kubernetes_service_account_v1" "game_server" {
  metadata {
    name      = "game-server"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
  }
  automount_service_account_token = false
}

resource "kubernetes_service_account_v1" "coordinator" {
  metadata {
    name      = "guild-battle-coordinator"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
  }
  automount_service_account_token = true
}

resource "kubernetes_service_account_v1" "scaler" {
  metadata {
    name      = "game-server-scaler"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
  }
  automount_service_account_token = true
}

resource "kubernetes_deployment_v1" "public_api" {
  metadata {
    name      = "public-api"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
    labels    = merge(local.labels, { app = "public-api" })
  }

  spec {
    replicas = var.enable_public_api_hpa ? null : var.public_api_min_replicas

    selector {
      match_labels = { app = "public-api" }
    }

    template {
      metadata {
        labels = merge(local.labels, { app = "public-api" })
      }

      spec {
        service_account_name = kubernetes_service_account_v1.public_api.metadata[0].name

        security_context {
          run_as_non_root = true
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = "public-api"
          image = var.public_api_image

          dynamic "env" {
            for_each = var.public_api_env
            content {
              name  = env.key
              value = env.value
            }
          }

          port {
            container_port = var.public_api_port
            name           = "https"
          }

          resources {
            requests = {
              cpu    = var.public_api_cpu_request
              memory = var.public_api_memory_request
            }
            limits = {
              cpu    = var.public_api_cpu_limit
              memory = var.public_api_memory_limit
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "mtls"
            mount_path = "/run/secrets/mtls"
            read_only  = true
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "mtls"
          secret {
            secret_name = var.mtls_secret_public_api
          }
        }

        volume {
          name = "tmp"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "public_api" {
  metadata {
    name        = "public-api"
    namespace   = kubernetes_namespace_v1.game.metadata[0].name
    annotations = var.public_api_service_annotations
  }

  spec {
    selector = { app = "public-api" }

    port {
      name        = "https"
      port        = var.public_api_port
      target_port = "https"
      protocol    = "TCP"
    }

    type = var.public_api_service_type
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "public_api" {
  count = var.enable_public_api_hpa ? 1 : 0

  metadata {
    name      = "public-api"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
  }

  spec {
    min_replicas = var.public_api_min_replicas
    max_replicas = var.public_api_max_replicas

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.public_api.metadata[0].name
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = var.public_api_target_cpu_utilization
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "game_server_headless" {
  metadata {
    name      = "game-server-headless"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
  }

  spec {
    cluster_ip = "None"
    selector   = { app = "game-server" }

    port {
      name        = "game"
      port        = var.game_server_port
      target_port = "game"
    }

    port {
      name        = "control"
      port        = var.game_server_control_port
      target_port = "control"
    }
  }
}

resource "kubernetes_stateful_set_v1" "game_server" {
  metadata {
    name      = "game-server"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
    labels    = merge(local.labels, { app = "game-server" })
  }

  spec {
    service_name = kubernetes_service_v1.game_server_headless.metadata[0].name
    replicas     = var.game_server_initial_replicas

    selector {
      match_labels = { app = "game-server" }
    }

    template {
      metadata {
        labels = merge(local.labels, { app = "game-server" })
      }

      spec {
        service_account_name = kubernetes_service_account_v1.game_server.metadata[0].name

        security_context {
          run_as_non_root = true
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = "game-server"
          image = var.game_server_image

          dynamic "env" {
            for_each = var.game_server_env
            content {
              name  = env.key
              value = env.value
            }
          }

          port {
            container_port = var.game_server_port
            name           = "game"
          }

          port {
            container_port = var.game_server_control_port
            name           = "control"
          }

          resources {
            requests = {
              cpu    = var.game_server_cpu_request
              memory = var.game_server_memory_request
            }
            limits = {
              cpu    = var.game_server_cpu_limit
              memory = var.game_server_memory_limit
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "mtls"
            mount_path = "/run/secrets/mtls"
            read_only  = true
          }

          volume_mount {
            name       = "replay"
            mount_path = var.replay_mount_path
          }

          volume_mount {
            name       = "recovery"
            mount_path = "/var/lib/game-server/recovery"
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "mtls"
          secret {
            secret_name = var.mtls_secret_game_server
          }
        }

        volume {
          name = "tmp"
          empty_dir {}
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "replay"
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.game_server_storage_class_name
        resources {
          requests = { storage = var.replay_storage_size }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "recovery"
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.game_server_storage_class_name
        resources {
          requests = { storage = var.recovery_storage_size }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [spec[0].replicas]
  }
}

resource "kubernetes_deployment_v1" "coordinator" {
  metadata {
    name      = "guild-battle-coordinator"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
    labels    = merge(local.labels, { app = "guild-battle-coordinator" })
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = { app = "guild-battle-coordinator" }
    }

    template {
      metadata {
        labels = merge(local.labels, { app = "guild-battle-coordinator" })
      }

      spec {
        service_account_name = kubernetes_service_account_v1.coordinator.metadata[0].name

        security_context {
          run_as_non_root = true
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = "guild-battle-coordinator"
          image = var.coordinator_image

          dynamic "env" {
            for_each = var.coordinator_env
            content {
              name  = env.key
              value = env.value
            }
          }

          resources {
            requests = {
              cpu    = var.coordinator_cpu_request
              memory = var.coordinator_memory_request
            }
            limits = {
              cpu    = var.coordinator_cpu_limit
              memory = var.coordinator_memory_limit
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "mtls"
            mount_path = "/run/secrets/mtls"
            read_only  = true
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "mtls"
          secret {
            secret_name = var.mtls_secret_coordinator
          }
        }

        volume {
          name = "tmp"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_deployment_v1" "game_server_scaler" {
  metadata {
    name      = "game-server-scaler"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
    labels    = merge(local.labels, { app = "game-server-scaler" })
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "game-server-scaler" }
    }

    template {
      metadata {
        labels = merge(local.labels, { app = "game-server-scaler" })
      }

      spec {
        service_account_name = kubernetes_service_account_v1.scaler.metadata[0].name

        security_context {
          run_as_non_root = true
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = "game-server-scaler"
          image = var.game_server_scaler_image

          dynamic "env" {
            for_each = var.game_server_scaler_env
            content {
              name  = env.key
              value = env.value
            }
          }

          port {
            container_port = var.scaler_control_port
            name           = "control"
          }

          resources {
            requests = {
              cpu    = var.scaler_cpu_request
              memory = var.scaler_memory_request
            }
            limits = {
              cpu    = var.scaler_cpu_limit
              memory = var.scaler_memory_limit
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "mtls"
            mount_path = "/run/secrets/mtls"
            read_only  = true
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "mtls"
          secret {
            secret_name = var.mtls_secret_scaler
          }
        }

        volume {
          name = "tmp"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "game_server_scaler" {
  metadata {
    name      = "game-server-scaler"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
  }

  spec {
    selector = { app = "game-server-scaler" }

    port {
      name        = "control"
      port        = var.scaler_control_port
      target_port = "control"
    }

    type = "ClusterIP"
  }
}

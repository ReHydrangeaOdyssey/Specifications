resource "kubernetes_network_policy_v1" "default_deny" {
  metadata {
    name      = "default-deny"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}

resource "kubernetes_network_policy_v1" "public_api" {
  metadata {
    name      = "public-api"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = { app = "public-api" }
    }
    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
      ports {
        port     = tostring(var.public_api_port)
        protocol = "TCP"
      }
    }

    egress {
      to {
        pod_selector {
          match_labels = { app = "game-server" }
        }
      }
      ports {
        port     = tostring(var.game_server_port)
        protocol = "TCP"
      }
    }

    egress {
      to {
        ip_block {
          cidr = var.private_api_cidr
        }
      }
      ports {
        port     = tostring(var.private_api_port)
        protocol = "TCP"
      }
    }


    egress {
      to {
        ip_block {
          cidr = var.kubernetes_api_cidr
        }
      }
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "kube-system" }
        }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "game_server" {
  metadata {
    name      = "game-server"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = { app = "game-server" }
    }
    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        pod_selector {
          match_labels = { app = "public-api" }
        }
      }
      ports {
        port     = tostring(var.game_server_port)
        protocol = "TCP"
      }
    }

    ingress {
      from {
        pod_selector {
          match_labels = { app = "guild-battle-coordinator" }
        }
      }
      ports {
        port     = tostring(var.game_server_control_port)
        protocol = "TCP"
      }
    }

    egress {
      to {
        ip_block {
          cidr = var.private_api_cidr
        }
      }
      ports {
        port     = tostring(var.private_api_port)
        protocol = "TCP"
      }
    }

    dynamic "egress" {
      for_each = var.discord_bot_cidr == null ? [] : [var.discord_bot_cidr]
      content {
        to {
          ip_block {
            cidr = egress.value
          }
        }
        ports {
          port     = tostring(var.discord_bot_port)
          protocol = "TCP"
        }
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "kube-system" }
        }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "coordinator" {
  metadata {
    name      = "guild-battle-coordinator"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = { app = "guild-battle-coordinator" }
    }
    policy_types = ["Ingress", "Egress"]

    egress {
      to {
        pod_selector {
          match_labels = { app = "game-server" }
        }
      }
      ports {
        port     = tostring(var.game_server_control_port)
        protocol = "TCP"
      }
    }

    egress {
      to {
        pod_selector {
          match_labels = { app = "game-server-scaler" }
        }
      }
      ports {
        port     = tostring(var.scaler_control_port)
        protocol = "TCP"
      }
    }

    egress {
      to {
        ip_block {
          cidr = var.private_api_cidr
        }
      }
      ports {
        port     = tostring(var.private_api_port)
        protocol = "TCP"
      }
    }

    dynamic "egress" {
      for_each = var.discord_bot_cidr == null ? [] : [var.discord_bot_cidr]
      content {
        to {
          ip_block {
            cidr = egress.value
          }
        }
        ports {
          port     = tostring(var.discord_bot_port)
          protocol = "TCP"
        }
      }
    }


    egress {
      to {
        ip_block {
          cidr = var.kubernetes_api_cidr
        }
      }
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "kube-system" }
        }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "scaler" {
  metadata {
    name      = "game-server-scaler"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = { app = "game-server-scaler" }
    }
    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        pod_selector {
          match_labels = { app = "guild-battle-coordinator" }
        }
      }
      ports {
        port     = tostring(var.scaler_control_port)
        protocol = "TCP"
      }
    }


    egress {
      to {
        ip_block {
          cidr = var.kubernetes_api_cidr
        }
      }
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "kube-system" }
        }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }
  }
}

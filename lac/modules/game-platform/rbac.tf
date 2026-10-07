resource "kubernetes_role_v1" "endpoint_slice_reader" {
  metadata {
    name      = "game-server-endpointslice-reader"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
  }

  rule {
    api_groups = ["discovery.k8s.io"]
    resources  = ["endpointslices"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "public_api_endpoint_slice_reader" {
  metadata {
    name      = "public-api-endpointslice-reader"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.endpoint_slice_reader.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.public_api.metadata[0].name
    namespace = var.namespace
  }
}

resource "kubernetes_role_binding_v1" "coordinator_endpoint_slice_reader" {
  metadata {
    name      = "coordinator-endpointslice-reader"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.endpoint_slice_reader.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.coordinator.metadata[0].name
    namespace = var.namespace
  }
}

resource "kubernetes_role_v1" "game_server_scaler" {
  metadata {
    name      = "game-server-scaler"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
  }

  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets/scale"]
    verbs      = ["get", "update", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "game_server_scaler" {
  metadata {
    name      = "game-server-scaler"
    namespace = kubernetes_namespace_v1.game.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.game_server_scaler.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.scaler.metadata[0].name
    namespace = var.namespace
  }
}

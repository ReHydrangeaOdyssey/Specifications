resource "terraform_data" "manual_guard" {
  lifecycle {
    precondition {
      condition     = var.manual_node_autoscaling_confirmation == "ENABLE_BOUNDED_AWS_NODE_AUTOSCALING"
      error_message = "AWS Worker Nodeの自動増減は既定で無効. 有効化する場合だけ確認文字列を明示すること."
    }
  }
}

module "cluster_autoscaler" {
  source = "../../../modules/aws-node-autoscaler"

  cluster_name                     = var.eks_cluster_name
  aws_region                       = var.aws_region
  oidc_provider_arn                = var.oidc_provider_arn
  oidc_issuer_url                  = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  cluster_autoscaler_chart_version = var.cluster_autoscaler_chart_version

  depends_on = [terraform_data.manual_guard]
}

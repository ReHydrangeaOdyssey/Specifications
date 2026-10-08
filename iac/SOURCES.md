# 情報源

作成時点: 2026-10-07

## Terraform / Provider

* HashiCorp Terraform Install
  * https://developer.hashicorp.com/terraform/install
  * 作成時点のTerraform最新Versionは1.16.5.
* HashiCorp Kubernetes Provider
  * https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
  * 作成時点のVersionは3.2.1.
* HashiCorp AWS Provider
  * https://registry.terraform.io/providers/hashicorp/aws/latest
  * 作成時点のVersionは6.62.0.
* HashiCorp Helm Provider
  * https://registry.terraform.io/providers/hashicorp/helm/latest/docs
  * 作成時点のVersionは3.3.0.

## Terraform Module

* terraform-aws-modules/vpc/aws
  * https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
  * 作成時点のVersionは6.7.3.
* terraform-aws-modules/eks/aws
  * https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
  * 作成時点のVersionは21.26.0.

## Kubernetes / AWS

* Kubernetes Horizontal Pod Autoscaling
  * https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
* Amazon EKS Managed Node Groups
  * https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html
* Amazon EKS Cluster Autoscaler Best Practices
  * https://docs.aws.amazon.com/eks/latest/best-practices/cas.html
* Amazon EKS Load Balancing
  * https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html

## 設計上の注意

`terraform-aws-modules/eks/aws`はCluster Autoscaler等が外部からManaged Node Groupのdesired sizeを変更する場合, Terraform Planで`desired_size`差分が生じ得ることをKnown limitationとして記載している. Node自動増減有効後はInfrastructureの再Apply前に必ずPlanを確認する.

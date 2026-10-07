# ゲーム基盤 Terraform

本構成は以下の3段階を分離する.

1. Local環境内のPod増減
   - 物理Server 1台のKubernetes Cluster内で行う.
   - Public APIはHPAで増減可能とする.
   - GameServerは`GuildBattleCoordinator -> GameServerScaler`の専用Control Pathで増減する.
   - 物理ServerのCPU・Memoryを超えてNodeを増やす処理は存在しない.
2. Local環境からAWS環境への移行
   - 完全手動とする.
   - LocalとAWSはTerraform Root, State, Providerを分離する.
   - Local側TerraformからAWS Resourceを作成する経路を持たない.
   - AWS側は確認文字列を指定しない限り`terraform plan/apply`を失敗させる.
3. AWS環境内のWorker Node増減
   - 既定では手動とする.
   - `environments/aws/node-autoscaling`を別途明示的に適用した場合だけCluster Autoscalerを導入する.
   - Node Groupの`max_size`を上限として使用する.
   - Local -> AWSの自動移行は行わない.

## Directory

```text
.
├── modules
│   ├── game-platform
│   └── aws-node-autoscaler
└── environments
    ├── local
    │   └── application
    └── aws
        ├── infrastructure
        ├── application
        └── node-autoscaling
```

## 前提

* Localは既存のsingle-node Kubernetes Clusterへ接続する. k3s, kubeadm等のCluster bootstrap自体はTerraform管理対象外とする.
* LocalのPrivate API ServerおよびDatabaseは同一物理Server上で稼働してよい. 本TerraformではPrivate APIを外部Endpointとして扱い, Databaseへは接続しない.
* AWSではEKSを作成する. Private API ServerおよびDatabaseは既存設計どおりKubernetes Cluster外の単一Serverとして扱う. Terraformは接続先のApplication固有設定Keyを仮定せず, 接続先は各Componentの`*_env`へ明示し, NetworkPolicy用に`private_api_cidr`を渡す.
* mTLS秘密鍵, Database Password, Discord Bot Token等をTerraform Stateへ格納しない. Kubernetes Secret名だけをTerraformへ渡し, Secret本体は別のSecret管理手段で作成する.
* `kubernetes_api_cidr`にはPodから見えるKubernetes API Service/Endpointの実CIDRを設定する. 環境依存値のためExampleでは固定しない.
* GameServerScalerはゲーム固有ControllerであるためApplication Imageを別途用意する. TerraformはDeployment, ServiceAccount, RBACだけを作成する.
* Application固有の環境変数名およびPort番号は仕様書で確定していないためTerraform Moduleでは仮定しない. 各Environmentのtfvarsで明示する.

## Level 1: Local

```bash
cd environments/local/application
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Local RootにはAWS Providerを定義していないため, この操作からAWS Resourceは作成されない.

Public API HPAを使用する場合はClusterでResource Metrics APIが利用可能であることを確認する. GameServerは通常HPAでscale downせず, 専用GameServerScalerが`draining`を確認した後にreplica数を変更する.

## Level 2: AWSへ手動移行

AWS Infrastructureは確認文字列を明示しない限りPlanを通さない.

```bash
cd environments/aws/infrastructure
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars内のmanual_aws_creation_confirmationを明示的に変更する
terraform init
terraform plan
terraform apply
```

Applicationも別Rootとする.

```bash
cd ../application
cp terraform.tfvars.example terraform.tfvars
# manual_aws_application_confirmationを明示的に変更する
terraform init
terraform plan
terraform apply
```

Local側の負荷, Pending Pod, GameServer Capacity不足等を契機としてAWS Terraformを自動実行する処理は作成しない.

## Level 3: AWS Worker Node増減

既定状態ではEKS Managed Node Groupは自動でdesired sizeを増減しない. Worker Nodeを増やす場合はInfrastructureの`node_desired_size`を変更して手動Applyする.

上限付き自動増減を使用すると判断した場合だけ次を適用する.

```bash
cd environments/aws/node-autoscaling
cp terraform.tfvars.example terraform.tfvars
# manual_node_autoscaling_confirmationとchart versionを明示的に設定する
terraform init
terraform plan
terraform apply
```

Cluster AutoscalerはEKS Managed Node Groupの`min_size`から`max_size`の範囲だけで動作する. 料金上限そのものを保証する仕組みではないため, AWS Budget/Cost Anomaly Detection等の課金監視は別途設定する.

Cluster Autoscaler有効後はNode Groupの`desired_size`を外部Controllerが変更する. `environments/aws/infrastructure`を再ApplyするとTerraform側の`node_desired_size`へ戻す差分が出る場合があるため, Node Autoscaling有効後のInfrastructure Applyでは必ずPlanで`desired_size`差分を確認する.

AWSのPublic API `LoadBalancer`はEKSのLoad Balancer実装に依存する. 本番ではAWS Load Balancer Controller等の採用方針を確定し, Service Annotationを環境に合わせて設定する.

## State

Local, AWS Infrastructure, AWS Application, AWS Node Autoscalingは相互にStateを共有しない.

本番ではAWSの各StateをS3 Backend等へ移してよいが, Local Stateと同じBackend Keyを使用しない.

## Version

作成時点で確認したProvider/Moduleを固定している.

* hashicorp/aws: `6.62.0`
* hashicorp/kubernetes: `3.2.1`
* hashicorp/helm: `3.3.0`
* terraform-aws-modules/vpc/aws: `6.7.3`
* terraform-aws-modules/eks/aws: `21.26.0`

Version更新時は`terraform plan`の差分を確認してから更新する.

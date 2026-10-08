# LocalからAWSへの移行方針

LocalからAWSへの切り替えは自動化しない.

## 移行判断前

* LocalのGameServer Capacity不足はError Logおよび運営通知へ出す.
* Pending Podを検出してもAWS APIを呼び出さない.
* GuildBattleCoordinatorおよびGameServerScalerはAWS Resourceを作成しない.

## 手動移行

1. 運営者がAWS移行を判断する.
2. AWS Infrastructure RootのPlanを確認する.
3. 確認文字列`CREATE_AWS_ENVIRONMENT_MANUALLY`を設定してApplyする.
4. Private API / DatabaseのAWS側配置とデータ移行を別手順で完了する.
5. mTLS SecretをAWS EKS側へ安全なSecret管理手段で配置する.
6. AWS Application RootのPlanを確認する.
7. 確認文字列`DEPLOY_AWS_APPLICATION_MANUALLY`を設定してApplyする.
8. 動作確認後にDNS等の外部入口を手動で切り替える.

このRepositoryはLocalからAWSへのDNS切替, Database Migration, Secret Material移送を自動実行しない.

## AWS Node自動増減

AWS移行直後もNode増減は手動でよい.

自動増減が必要と判断した場合だけ`environments/aws/node-autoscaling`を適用する. Cluster AutoscalerはNode Groupの`max_size`を超えられないが, AWS利用料金の総額上限を保証するものではない.

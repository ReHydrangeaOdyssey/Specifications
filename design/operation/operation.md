# 運用設計

## 目的

本書は自動処理だけでは完結せず, 運営判断または手動操作が必要になる状態の運用手順を定義する.
本プロジェクトは個人または極少人数での運用を前提とし, 常時監視要員や24時間対応を前提としない.
通常のゲーム処理は自動化し, 運営操作は仕様上明示された異常状態と復旧操作に限定する.

ゲームルールそのものは本書で変更しない.
状態遷移とAPIの正本は「[GuildBattle設計](../server/guild_battle.md)」, 「[GuildBattleCoordinator](../server/guild_battle_coordinator.md)」, 「[Private API](../server/private_api.md)」とする.

## 基本方針

* Bot通知は運営判断が必要な状態を知らせる補助手段とする.
* `DiscordNotificationEnabled=false`でもError Logおよび状態遷移は継続する.
* 運営判断前に対象`GuildBattleID`, GuildID, 状態, Error Code, GameServerInstanceIDを確認する.
* 通常の復旧ではDatabaseを直接更新しない.
* 仕様で定義された運営APIまたはCoordinator操作を優先する.
* Recoveryファイルを手動削除しない. Databaseへの再送が全件成功した場合だけ削除する.
* Credential, Token, Password, mTLS秘密鍵を運営記録へ貼り付けない.
* 手動対応を行った場合は対象ID, 実施時刻, 原因, 実施操作, 結果を簡単な運営記録へ残す.

## 運用設定の推奨初期値

以下を運用設定の推奨初期値とする. 運用環境で変更する場合も無制限値にはせず, 各Componentで明示的に設定する.

| 項目 | 推奨初期値 | 適用単位・補足 |
|---|---|---|
| RequestSequence不一致ログの集約期間 | 60秒 | `GuildBattleID`, `PlayerID`, 拒否理由単位 |
| Security Event集約期間 | 60秒 | 最初の1件は即時記録し, 以降を集約する |
| Trace Sampling Rate | 正常系1% / Error 100% / Slow Request 100% | ErrorとSlow Requestは必ず保持する |
| Slow Request判定閾値 | 100ms | Server側処理時間 |
| Argon2id最大同時実行数 | 2 | Private API Serverの認証処理 |
| GameServer割当候補の選択順 | Ready判定 → 負荷判定 → Capacity使用率 → 最終割当時刻 → InstanceID | 左から順に判定・比較する |
| Scale-out待機時間 | 30秒 | 新規`ready` GameServer確保待ち |
| Endpoint不在判定時間 | 15秒連続 | `scheduled`かつ割当済み騎士団戦の再割当判定 |
| Source IP Rate Limit閾値 | 認証系合計20 requests/min/IP, burst 5 | `CreateAccount`と`Login`の合計 |
| Recovery領域 | 2 GiB / 1,000 files / GameServer Instance | `/var/lib/game-server/recovery` |

GameServer割当候補の「負荷判定」は, `GetGameServerCapacityResponse.AvailableGuildBattleThreadCount`で返す「騎士団戦に使用していない空き専用スレッド数」を使用する. 空き専用スレッド数が多い候補を優先し, 同数の場合は次の`Capacity使用率`比較へ進む. `Capacity使用率 = (TotalGuildBattleThreadCount - AvailableGuildBattleThreadCount) / TotalGuildBattleThreadCount`とし, 低い候補を優先する. さらに同値の場合はGuildBattleCoordinatorがInstanceごとに保持する`LastAssignedAt`が古い候補, さらに同値の場合は`GameServerInstanceID`昇順を優先する. `LastAssignedAt`はCoordinatorが新規割当成功を確認したUNIX epochからの経過マイクロ秒で保持し, Coordinator起動後に未割当の0は最も古い値として扱う.

## 運営確認に使用する識別子

障害調査では該当する範囲で以下を使用する.

* GuildBattleID.
* GuildID.
* PlayerID.
* GameServerInstanceID.
* Request ID.
* Trace ID.
* Operation ID.
* Error Code.
* Version.
* 発生時刻.

Token本体やPasswordは識別子として使用しない.

## Bot通知

`DiscordNotificationEnabled=true`の場合, 以下は運営確認対象とする.

| 通知 | 初期確認 | 通常の対応 |
|---|---|---|
| GuildBattle Preload失敗 | GuildBattleID, 失敗Player取得処理, Error Log | 原因解消後に再Preload, 再抽籤, 中止のいずれかを判断する |
| 0人候補エラー | 対象日, 開始時刻, 対象Guild | 自動でロック解除済みであることを確認する. 通常は追加操作不要 |
| GameServer水平スケーリング失敗 | 未割当Battle数, ready GameServer数, Controller状態 | 原因解消後に未割当Battle再割当を実行する. 継続不能なら未割当Battleを削除する |
| GuildBattle最終結果保存失敗 | GuildBattleID, Error Log, Database状態 | 自動で`completed`になっていないことを確認し, 手動復旧対象として扱う |
| その他Error Log連動通知 | Error Codeと対象Component | 対象仕様に従って原因調査する |

Bot通知に失敗してもゲーム状態を巻き戻さない.

## Preload失敗

### 状態

いずれか1人のPlayerデータ取得に失敗したGuildを含む当該1対戦は`GUILD_BATTLE_STATUS_PRELOAD_FAILED`となる.
他のGuildBattleは継続する.

### 運営判断

原因確認後に以下のいずれかを選択する.

| 条件 | 運営判断 | 操作 |
|---|---|---|
| 原因が解消済みで, 同じ2Guildの対戦を維持する | 同一ペア再開 | `RetryPreloadFailedGuildBattle`へ新しい`RestartAt`を指定する |
| 原因が解消済みで, 対戦組み合わせを変更する | 再抽籤 | GuildBattleCoordinatorへ再抽籤を要求し, `RematchPreloadFailedGuildBattles`で結果を保存する |
| 対戦を実施しない | 中止 | 対象Guildの`membership_locked=false`へ戻す |

### 同一ペア再開

1. Error LogからPreload失敗原因を確認する.
2. 原因が解消済みであることを確認する.
3. 新しい開戦時刻`RestartAt`を決定する.
4. `RetryPreloadFailedGuildBattle`を実行する.
5. 対象Battleが`scheduled`かつ未割当へ戻ったことを確認する.
6. GuildBattleCoordinatorが通常のGameServer割当とPreloadを再実行することを確認する.
7. 再度`PRELOAD_FAILED`となった場合は同じ判断手順へ戻る.

### 再抽籤

1. 再抽籤対象となる`PRELOAD_FAILED` Battleを確定する.
2. GuildBattleCoordinatorへ再抽籤を要求する.
3. GuildBattleCoordinatorが対象GuildをGuildID昇順へ並べ, 新しい時刻ベースSeedでShuffleする.
4. `RematchPreloadFailedGuildBattles`保存後に対象Battleが`scheduled`かつ未割当へ戻ったことを確認する.
5. 通常の割当とPreloadへ戻ることを確認する.

### 中止

中止時は対象Guildの所属変更禁止を解除する.
Databaseを直接編集せず`SetGuildMembershipLock`を使用する.
中止後に残す`GUILD_BATTLE`レコードの最終状態について仕様に追加定義がない場合は, 状態値を運営判断だけで変更しない.

## 未割当GuildBattleと水平スケーリング失敗

### 自動処理

全ready GameServerの容量が不足する場合, GuildBattleCoordinatorはKubernetes ControllerへGameServer水平スケーリングを要求する.
新しいGameServerがreadyになった場合は未割当Battleを自動で再割当する.

### 運営判断が必要になる条件

以下の場合はBot通知対象となる.

* 水平スケーリング要求自体が失敗した.
* 運用設定されたScale-out待機時間内に新しいready GameServerを確保できなかった.

### 再割当

原因解消後に`RetryUnassignedGuildBattleAssignment`を実行する.
運営側から割当先GameServerを指定しない.
GuildBattleCoordinatorがready状態と空き容量から割当先を決定する.

### 削除

対戦を実施しないと判断した場合は`DeleteUnassignedGuildBattles`を使用する.
本APIは`scheduled`かつ未割当のBattleだけを削除対象とする.
削除後のGuild lock解除および0人除外Guildの解除はAPI仕様に従う.
Databaseから`GUILD_BATTLE`を直接DELETEしない.

## 0人Guild

マッチング候補除外後に通常候補が0件となった場合は自動処理とする.

* GuildBattleを生成しない.
* 除外Guildの`membership_locked=false`へ戻す.
* Error Logを保存する.
* Bot通知が有効なら通知する.
* 保存済み除外Guild一覧を削除する.

正常に上記処理が完了している場合は運営操作を不要とする.
ロックが残っている場合だけ異常として調査する.

## Database障害とRecovery

### 自動切替

GuildBattle中のDatabase送信失敗時は同一要求を1回だけ再試行する.
再試行も失敗した場合はDB障害発生状態へ遷移し, 以後の対象GuildBattleのDatabase送信内容をRecoveryファイルへ保存する.

Recovery保存先は`/var/lib/game-server/recovery`とする.
本番Kubernetes環境ではGameServer専用Persistent Volumeを使用する.

### Recoveryファイル

ファイル名は以下とする.

```text
guild_battle_<GuildBattleID>_<GameServerInstanceID>.json
```

各Recordは元Private API名, Operation ID, Request Payload, 保存順序を保持する.
再試行, GuildBattle終了時再送, GameServer起動時再送では同じOperation IDを使用する.

### 自動再送

以下のタイミングで保存順に再送する.

* 当該GuildBattle終了時.
* GameServer起動時.

全Record成功時だけファイルを削除する.
1件でも失敗した場合はファイルを残す.

### 運営確認

Recoveryファイルが長時間残る場合は以下を確認する.

1. Databaseが正常に応答することを確認する.
2. Private API ServerがDatabaseへ接続可能であることを確認する.
3. mTLS通信が成功していることを確認する.
4. Operation ID重複が正常に冪等成功として扱われていることを確認する.
5. GameServer再起動またはGuildBattle終了による再送結果を確認する.

Recoveryファイルを手作業で編集しない.
成功確認前に削除しない.

## GuildBattle最終結果保存失敗

`SaveGuildBattleResult`は初回失敗時に1回だけ再試行する.
2回とも失敗した場合はError Log保存とBot通知を行い, `completed`へ遷移しない.
Player勝敗数も更新しない.

運営は以下を確認する.

1. GuildBattleIDを特定する.
2. Replay Logが存在し, 最終状態を再現可能であることを確認する.
3. Database上の`GUILD_BATTLE_RESULT`と`GUILD_BATTLE.status`を確認する.
4. 同一GuildBattleについて勝敗数更新が行われていないことを確認する.
5. 原因を解消する.

現行仕様には最終結果を運営から再送する専用APIが定義されていない.
専用復旧APIが追加されるまでは, 本項を「運営による手動復旧対象」として扱い, 通常運用API以外の変更を行う場合は必ず対象ID, 変更前状態, 変更内容を記録する.

## GameServer異常終了

進行中GuildBattleを別GameServerへ自動復旧する処理は現行仕様では定義しない.
GameServer Pod異常終了を検知した場合は以下を確認する.

* 対象GameServerInstanceID.
* 所有していたGuildBattleID.
* 対象BattleのDatabase status.
* Replay LogおよびDatabase Replay Eventの保存位置.
* Recoveryファイルの有無.

`in_progress`以降のBattleを別GameServerへ自動再割当しない.
復旧方法が仕様化されるまでは個別の運営判断対象とする.

## GuildBattleCoordinator再起動

GuildBattleCoordinatorは永続状態の正本をMemoryだけに持たない.
再起動時は`GetGuildBattleCoordinationState`から`scheduled` BattleをReconcileする.

確認項目は以下とする.

* 未割当`scheduled` Battleが通常割当へ戻る.
* 割当済み`scheduled` Battleへ`StartGuildBattlePreload`を再送しても二重Preloadにならない.
* 割当先Endpointが不在判定時間を超えて存在しない場合だけ割当解除して再割当する.
* `in_progress`以降は割当を変更しない.

## Guild lock確認

GuildBattle開始前処理ではDatabaseの`GUILD.membership_locked`を正本とする.
異常対応後は対象Guildのlockが仕様どおり解除されていることを確認する.

特に以下を確認する.

* 0人候補のみでBattle生成なしとなった場合.
* 未割当Battleを運営削除した場合.
* Preload失敗Battleを中止した場合.
* GuildBattle正常終了後.

## 運営APIの取扱い

運営Componentからの運用操作はmTLSを必須とする.
通常のClientから呼び出さない.

現行仕様で主に使用する運営操作は以下とする.

| 操作 | API / Component | 使用条件 |
|---|---|---|
| Preload失敗の同一ペア再開 | `RetryPreloadFailedGuildBattle` | 対象が`PRELOAD_FAILED`で原因解消済み |
| Preload失敗の再抽籤 | GuildBattleCoordinator + `RematchPreloadFailedGuildBattles` | 対象が`PRELOAD_FAILED`で再抽籤を選択 |
| 未割当Battle再割当 | `RetryUnassignedGuildBattleAssignment` | `scheduled`かつ未割当 |
| 未割当Battle削除 | `DeleteUnassignedGuildBattles` | `scheduled`かつ未割当で実施しないと判断 |
| Guild lock変更 | `SetGuildMembershipLock` | 仕様で定義された中止・終了・開戦前処理 |

運営操作のためにDatabaseを直接更新することを通常手順としない.

## 確認に使用するログ・Metric

最低限以下を見る.

### Log

* GuildBattleマッチング生成開始・完了・失敗.
* GameServer割当・未割当.
* 水平スケーリング要求・失敗.
* GuildBattle開始・終了.
* Database送信失敗.
* Recoveryファイル作成・再送成功・再送失敗.
* Replay保存失敗.
* GameServer内部例外.

### Metric

* 進行中GuildBattle数.
* 未割当`scheduled` GuildBattle数.
* 割当可能GameServer数.
* GameServer所有GuildBattle数.
* ReplayQueue現在要素数.
* ReplayQueue高水位到達回数.
* Database送信失敗件数.
* Recoveryファイル件数.

PlayerIDやGuildBattleID等の高Cardinality値をMetric Labelへ使用しない.

## 運営記録

手動対応を行った場合は最低限以下を記録する.

| 項目 | 内容 |
|---|---|
| 対応時刻 | JSTで記録する |
| 対象 | GuildBattleID, GuildID, GameServerInstanceID等 |
| 発生事象 | Preload失敗, Scale-out失敗, DB障害等 |
| Error Code | 存在する場合に記録する |
| 判断 | 再Preload, 再抽籤, 中止, 再割当, 削除等 |
| 実行操作 | 実行した運営APIまたは確認作業 |
| 結果 | 成功, 再失敗, 継続調査等 |

大規模なチケット管理システムを必須としない. 個人開発ではMarkdown, Issue等の追跡可能な方法でよい.

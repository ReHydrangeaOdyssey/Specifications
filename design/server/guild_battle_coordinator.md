# 騎士団戦コーディネーター

* `GuildBattleCoordinator`は騎士団戦の生成, マッチング, GameServer割当および開戦前Preload開始指示を担当する.
* `GuildBattleCoordinator`は騎士団戦のControl Path専用Componentとし, Clientからの通常ゲーム要求の中継経路には配置しない.
* 本番Kubernetes環境では`replicas=1`の専用Workloadとして稼働させる.
* 更新時に新旧Instanceが同時稼働しないようWorkloadの更新方式は`Recreate`とし, 同時に複数の`GuildBattleCoordinator`をActiveにしない.
* Clientから直接接続させない.
* Databaseへ直接接続せず, Database保存・取得はPrivate API Server経由で行う.
* 騎士団戦の戦闘状態, `RequestSequence`, ReplayQueue, 戦闘計算結果は保持しない.
* Arena処理は担当しない.
* 固定シード値はGameServerと同じ`202205311459`とする.
  - これは機密情報ではないので公開されても問題ない.
  - コード内に直接埋め込む.
* 騎士団戦マッチング用Seedは`GenerateTimeBasedSeed`で生成する.
  - `GenerateTimeBasedSeed`は`固定シード値 ^ サーバーの時刻`を返す.
  - 時刻はUNIX時刻を採用する.
  - マイクロ秒単位とする.
  - 型は「[型定義](../shared/types.md)」の`GameServerTime`を参照する.

## 騎士団戦生成

`CreateScheduledGuildBattles`は`GuildBattleCoordinator`内部のマッチング処理とし, Private APIメソッドにはしない.

* 開戦5分前に対象開始時刻の騎士団戦開戦前処理を開始する.
* Private APIの`GetGuildsForBattleMatching`で対象GuildIDと所属人数を取得し, `SetGuildMembershipLock`で対象騎士団の`membership_locked=true`へ更新する.
* 所属固定後に`GetGuildsForBattleMatching`で候補を再取得する.
* 同一`TargetDate`・`StartTime`の既存騎士団戦をPrivate APIの`GetScheduledGuilds`で確認し, 既存データがある場合は再生成せずそのデータを使用する.
* 既存データがない場合は所属人数0の騎士団を除外し, 除外GuildID一覧を`SaveGuildBattleExcludedGuilds`でDatabaseへ保存する.
* 除外後の通常候補が0件の場合は騎士団戦を生成せず, 除外Guildの`membership_locked=false`へ戻してロックを解除し, Error Logへ記録する. `DiscordNotificationEnabled=true`の場合はDiscord Botへ0人候補エラーを通知し, 保存済み除外一覧を削除して処理を終了する.
* 候補騎士団をGuildID昇順に並べる.
* `GenerateTimeBasedSeed`でマッチング用Seedを生成する.
* 生成したSeedで候補一覧をシャッフルし, 先頭から2騎士団ずつペアを作成する.
* `PairIndex`は0から開始する.
* 生成済みの`ScheduledGuildBattle[]`をPrivate APIの`SaveScheduledGuildBattles`へ渡して保存する.

## GameServer検出・容量確認

* 本番Kubernetes環境ではGameServer用EndpointSliceをwatchし, `endpoint.targetRef.uid`とEndpoint Addressの対応をメモリ上に保持する.
* `endpoint.targetRef.uid`を`GameServerInstanceID`として扱う.
* Endpointが存在するGameServerへmTLSで`GetGameServerCapacity`を要求する.
* `AcceptNewGuildBattle=true`かつ`AvailableGuildBattleCount > 0`のGameServerだけを新規割当候補とする.
* `draining`状態のGameServerへ新しい騎士団戦を割り当てない.
* 複数の割当候補が存在する場合も各GameServerの`AvailableGuildBattleCount`を超えて割り当てない. 候補間の選択順は運用設定とし, 推奨初期順序を`Ready判定 → 負荷判定 → Capacity使用率 → 最終割当時刻 → InstanceID`とする. 左側の判定・比較を優先し, 同値の場合に次の項目を使用する. GameServer内部の戦闘ロジックには影響させない.
* 負荷判定は`GetGameServerCapacityResponse.AvailableGuildBattleThreadCount`を使用し, 騎士団戦に使用していない空き専用スレッド数が多いGameServerを優先する. 同数の場合は次の`Capacity使用率`比較へ進む.
* 物理Worker NodeのCPU・Memory配置先は`GuildBattleCoordinator`が決定しない. GameServer PodをどのWorker Nodeへ配置するかはKubernetes Schedulerへ任せる.

## 騎士団戦割当

* 騎士団戦の割当は`GuildBattleCoordinator`だけが通常処理として実行する.
* 空き容量を持つGameServerごとに割当対象`GuildBattleID[]`を選択し, Private APIの`AssignScheduledGuildBattles(GameServerInstanceID, GuildBattleID[])`を実行する.
* 1回の要求に含める`GuildBattleID[]`件数は対象GameServerから取得した`AvailableGuildBattleCount`以下とする.
* 1回の割当処理中はPrivate APIで割当成功した件数を当該GameServerの空き容量から直ちに差し引いて管理し, `StartGuildBattlePreload`反映前の容量応答を再利用して処理容量を超過させない.
* Private APIによる割当成功後の`GUILD_BATTLE.game_server_instance_id`を割当の正本とする.
* `AssignScheduledGuildBattlesResponse.Battles`に含まれる騎士団戦だけを割当先GameServerへ`StartGuildBattlePreload`で通知する.
* `StartGuildBattlePreload`は同一`GuildBattleID`について再送可能な冪等処理とする. すでにPreload中またはPreload済みの場合は二重に状態を生成しない.
* GameServerは`StartGuildBattlePreload`受信時にPrivate APIの`GetGuildBattleAssignment`で自身が所有GameServerであることを確認し, 一致しない騎士団戦を処理しない.
* 割当およびPreload開始後, `GuildBattleCoordinator`は当該騎士団戦の通常ゲーム要求経路には入らない.

## 容量不足と水平スケーリング

* 全`ready` GameServerの空き容量だけでは未割当騎士団戦を処理できない場合, 未割当騎士団戦はDatabase上で`scheduled`かつ`game_server_instance_id = NULL`のまま維持する.
* `GuildBattleCoordinator`は専用Kubernetes ControllerへGameServer水平スケーリングを要求する.
* `GuildBattleCoordinator`自身へDeploymentまたはStatefulSetのreplica変更権限を付与しない.
* 新しいGameServer Podが`ready`となりEndpointSliceへ反映された場合, GameServer容量を取得して未割当騎士団戦の割当を再実行する.
* 水平スケーリング要求自体が失敗した場合, または運用設定されたScale-out待機時間内に新規`ready` GameServerを確保できない場合は水平スケーリング失敗とする. Scale-out待機時間の推奨初期値は30秒とする.
* 水平スケーリング失敗はError Logへ記録し, `DiscordNotificationEnabled=true`の場合はDiscord Botへ通知する.
* 運営はGuildBattleCoordinatorの`RetryUnassignedGuildBattleAssignment`で未割当対戦の再割当を要求できる. 再割当先GameServerの選択とPrivate APIの`AssignScheduledGuildBattles`呼び出しはGuildBattleCoordinatorが行う.
* 未割当対戦の削除は運営がPrivate APIの`DeleteUnassignedGuildBattles`を実行できる.

## 再起動時

* `GuildBattleCoordinator`は永続状態の正本をメモリだけに保持しない.
* 起動時および定期Reconcile時にPrivate APIの`GetGuildBattleCoordinationState`を使用してDatabase上のすべての`scheduled`騎士団戦と割当状態を確認する. `RetryPreloadFailedGuildBattle`で固定開始時刻以外の`RestartAt`へ変更された対戦も対象とする.
* `scheduled`かつ未割当の騎士団戦は通常の割当対象へ戻す.
* `scheduled`かつ割当済みの騎士団戦は割当先GameServerへ`StartGuildBattlePreload`を再送してよい. `StartGuildBattlePreload`の冪等性により二重Preloadを防止する.
* `scheduled`かつ割当済みで, 割当先`GameServerInstanceID`に対応するEndpointが運用設定された不在判定時間を超えて連続して存在しない場合は, Private APIの`ReleaseScheduledGuildBattleAssignments`で当該割当を解除して未割当へ戻し, 別の`ready` GameServerへ再割当する. Endpoint不在判定時間の推奨初期値は15秒連続とする.
* `in_progress`以降の騎士団戦についてEndpoint不在を理由とした割当解除・再割当は行わない.
* `in_progress`, `resolving`, `completed`の騎士団戦についてGameServer割当を変更しない.
* GameServer Podの異常終了により進行中騎士団戦を別GameServerへ自動復旧する処理は本仕様では定義しない.

## Preload失敗後の再処理

* `GUILD_BATTLE_STATUS_PRELOAD_FAILED`の同一ペア再開は運営がPrivate APIの`RetryPreloadFailedGuildBattle`を実行し, `scheduled`かつ未割当へ戻した後に通常のCoordinator割当・Preload開始処理へ戻す.
* 運営が再抽籤を選択した場合, 再抽籤ロジックは`GuildBattleCoordinator`が実行する.
* 再抽籤対象GuildをGuildID昇順へ並べ, `GenerateTimeBasedSeed`でSeedを新規生成してShuffleする.
* `PRELOAD_FAILED`のGuildBattleIDを昇順へ並べて新しいペアを割り当て, Private APIの`RematchPreloadFailedGuildBattles`へ保存を要求する.
* 保存後は`scheduled`かつ未割当となるため, 通常のCoordinator割当・Preload開始処理へ戻す.

## 運営操作

* 運営ComponentからGuildBattleCoordinatorへ送信する騎士団戦再割当・再抽籤等のCoordinator固有操作はmTLSを必須とする.
* `RetryUnassignedGuildBattleAssignment`は要求`GuildBattleID[]`のうちDatabase上で`scheduled`かつ未割当の対戦について通常の容量確認・割当処理を直ちに実行する. 再割当先GameServerを運営Componentから指定しない.
* 要求・レスポンスは「[API Payload](api_payload.md)」の`RetryUnassignedGuildBattleAssignmentRequest` / `RetryUnassignedGuildBattleAssignmentResponse`を参照する.
* 運営が`PRELOAD_FAILED`対戦の再抽籤を要求した場合, GuildBattleCoordinatorが再抽籤を実行してPrivate APIの`RematchPreloadFailedGuildBattles`へ保存を要求する.
* Databaseの直接更新は行わない.

## Discord Bot通知

* `DiscordNotificationEnabled=true`の場合, `GuildBattleCoordinator`からDiscord Botへ運営通知を送信する.
* 0人候補により騎士団戦を生成できない場合はDiscord Botへ通知する.
* GameServer水平スケーリング失敗時はDiscord Botへ通知する.
* `DiscordNotificationEnabled=false`の場合はDiscord Botへの通知を行わない. 通知以外のError Log保存および処理結果には影響させない.

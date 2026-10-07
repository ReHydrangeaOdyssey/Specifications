# ゲームサーバー

* キャッシュとしてのDBの一部情報保持する.
  - 毎回問い合わせるとゲームの実行速度に影響するためである.
* 保有対象はID値と純粋なロジックのみとする.
  - 画像などのデータは持たない.
* 固定シード値は`202205311459`
  - これは機密情報ではないので公開されても問題ない.
  - コード内に直接埋め込む.
* GameServerは時刻ベースSeed生成を共通内部API`GenerateTimeBasedSeed`として提供する.
  - `GenerateTimeBasedSeed`は`固定シード値 ^ サーバーの時刻`を返す.
  - 時刻はUNIX時刻を採用する.
  - マイクロ秒単位とする.
  - 型は「[型定義](../shared/types.md)」の`GameServerTime`を参照する.
  - Arenaの対戦開始Seedに使用する.
* 騎士団戦は16騎士団戦を1単位として1単位当たり1つの専用スレッド上で行う.
	- CPUが扱えるスレッド数が4以下の場合は1スレッドとする.
	- CPUが扱えるスレッド数が5以上の場合は最小1, 最大`CPUが扱えるスレッド数 - 4`まで拡張可能とする.
* GameServerは自身へ割り当て済みの騎士団戦だけをPreload・実行する.
* 騎士団戦の生成, マッチング, GameServer選択, 未割当騎士団戦の割当および水平スケール開始判断は「[騎士団戦コーディネーター](guild_battle_coordinator.md)」が担当する.
* GameServer自身は未割当騎士団戦を取得して自己割当しない.
* このGameServerの計算結果を正とする.
* GameServerは自身が使用する`Version`を保持し, 戦闘計算およびリプレイログへ使用する. Login時のClientVersion検証はPublic API Serverが行い, Arena対戦開始時および騎士団戦参加時は各GameServer自身のVersionとClientVersionを再検証する.


## ログ・メトリクス処理

* 騎士団戦のログ・Metric・Trace処理は「[ログ仕様](../system/log.md)」に従う.
* 騎士団戦専用スレッドは, 正常な要求ごとのApplication Log出力, Replay EventのProtocol Buffers Serialize, ファイル書き込み, `stdout` / `stderr`書き込み, 外部Telemetry送信を直接行わない.
* 処理成立時のReplay Eventは状態反映および`RequestSequence`更新後にReplayQueueへ追加し, Replay Workerがファイル書き込みおよびPrivate API Serverへの保存を行う.
* ReplayQueueとSystem Log Queueは分離する.
* 正常なゲームルール拒否は要求単位のLogを生成せず, Memory上のMetricへ集約する.
* `RequestSequence`不一致および不正ID等のSecurity EventはMemory上で集約し, 最初の発生および一定期間ごとのSummaryを非同期Log Queueへ追加する.
* 本番環境の詳細TraceはSamplingを行い, GameServer内部の戦闘計算関数単位では常時Spanを生成しない.


## Database Recoveryファイルの起動時処理

* GameServerは起動時に`/var/lib/game-server/recovery`を走査する.
* `guild_battle_<GuildBattleID>_<GameServerInstanceID>.json`形式のRecoveryファイルを検出した場合, ファイル内の保存順序に従って元のPrivate API要求を再送する.
* 再送時は各レコードへ保存済みの`X-Operation-ID`をそのまま使用し, 同一Database更新を二重適用しない.
* 1ファイル内の全レコード再送に成功した場合だけそのファイルを削除する. 1件でも失敗した場合は削除せず, 次回起動時または当該騎士団戦終了時の再送対象として残す.


## 複数GameServer構成

* Kubernetes上で複数GameServer Instanceを稼働可能とする.
* 各GameServerは起動時に自身を一意に識別する`GameServerInstanceID`を保持する.
  - 本番Kubernetes環境ではPod UIDを`GameServerInstanceID`として使用する.
  - テスト環境ではProcess起動ごとに一意となるUUIDを使用する.
* 騎士団戦は`GuildBattleID`単位で1つのGameServer Instanceだけが所有する.
* `GuildBattleCoordinator`がPrivate APIの`AssignScheduledGuildBattles`を使用して未割当騎士団戦をGameServerへ割り当てる.
* 割当成功後, `GUILD_BATTLE.game_server_instance_id`を割当の正本とする.
* `GuildBattleCoordinator`から`StartGuildBattlePreload`を受信したGameServerはPrivate APIの`GetGuildBattleAssignment`で自身への割当を確認してからPreloadを開始する.
* Public API Serverは`GetGuildBattleAssignment`で所有GameServerを解決し, 当該GameServerへ要求を中継する. Public API Serverは解決結果をローカルキャッシュしてよい.
* 本番Kubernetes環境ではPublic API ServerがGameServer用EndpointSliceをwatchし, `endpoint.targetRef.uid`とEndpoint Addressの対応をメモリ上に保持する. `GameServerInstanceID`に一致するPod UIDのEndpointへ直接中継する.
* 騎士団戦要求を通常のKubernetes Service Load Balancingへ渡して所有GameServer以外へ到達させない.
* 所有していないGameServerは対象`GuildBattleID`の状態変更要求を処理しない.
* 同一騎士団戦の状態を複数GameServer間で共有メモリ同期する方式とはしない.

### GuildBattleCoordinator向け内部API

#### GameServer容量取得

`GetGameServerCapacity`

* 現在の`GameServerInstanceID`, 新規騎士団戦割当可否, 所有中騎士団戦数, 新規割当可能な騎士団戦数を返す.
* 騎士団戦処理容量は`専用スレッド数 * 16`件とし, `AvailableGuildBattleCount = 処理容量 - 所有中のscheduled・in_progress・resolving騎士団戦数`で求める. 計算結果が0未満になる場合は0とする. `preload_failed`および`completed`は処理容量へ含めない.
* `draining`状態では新規割当可能数を0として返す.
* 本APIは状態参照だけを行い, 騎士団戦を割り当てない.
* 要求・レスポンスは「[API Payload](api_payload.md)」の`GetGameServerCapacityRequest` / `GetGameServerCapacityResponse`を参照する.

#### 騎士団戦Preload開始

`StartGuildBattlePreload`

* `GuildBattleCoordinator`から割当済み`ScheduledGuildBattle[]`を受け取る.
* 各`GuildBattleID`についてPrivate APIの`GetGuildBattleAssignment`を使用し, `GameServerInstanceID`が自身と一致することを確認する.
* 自身へ割り当てられていない騎士団戦はPreloadしない.
* 同一`GuildBattleID`がすでにPreload中, Preload済み, `in_progress`, `resolving`または`completed`の場合は二重に状態を生成しない.
* 新規対象だけをPreload対象Queueへ追加し, 実際の開戦前Preloadは「[騎士団戦](guild_battle.md)」に従って実行する.
* Preload結果をDatabaseへ反映する前と開戦時にPrivate APIの`GetGuildBattleAssignment`で所有権を再確認する. 自身への割当が解除または変更されている場合は`preload_failed`への状態更新, InitialSeed・Replay作成ログ保存および開戦を行わず保持データを破棄する.
* 本APIは同一要求を再送可能な冪等処理とする.
* 要求・レスポンスは「[API Payload](api_payload.md)」の`StartGuildBattlePreloadRequest` / `StartGuildBattlePreloadResponse`を参照する.

### 水平スケーリングとScale down

* GameServer自身はGameServer水平スケーリングを要求しない.
* 未割当騎士団戦に対するscale up開始判断は`GuildBattleCoordinator`が行い, 実際のreplica変更は専用Kubernetes Controllerが行う.
* GameServerのscale downは通常のHPAによるreplica数減少を直接使用せず, 対象Instanceを先に`draining`へ遷移させるControllerを介して行う.
* GameServerは新規騎士団戦を割当可能な`ready`状態と, 新規割当を停止する`draining`状態を持つ.
* scale down対象になったGameServerは`draining`へ遷移し, `GetGameServerCapacity`で新規割当可能数0を返す.
* `draining`状態でも所有中騎士団戦のPublic API要求は処理し続ける.
* `draining`状態で所有する進行中騎士団戦が0件になった場合のみ終了可能とし, Controllerは0件を確認してからPodを削除する.
* CPU使用率だけを条件として進行中騎士団戦を所有するGameServer Podを削除しない.
* GameServer Podの異常終了時に進行中騎士団戦を別Instanceへ自動復旧する処理は本仕様では定義しない.

## Discord Bot通知

* `DiscordNotificationEnabled=true`の場合, GameServerからDiscord Botへ運営通知を送信する.
* 騎士団戦開戦前Preload失敗時は, 当該対戦を`GUILD_BATTLE_STATUS_PRELOAD_FAILED`へ遷移させた後, Discord BotへPreload失敗メッセージを送信する.
* `DiscordNotificationEnabled=false`の場合はDiscord Botへの通知を行わない. 通知以外のErrorLog保存および処理結果には影響させない.

* アリーナの`StartArenaBattle`ではAccessToken・PlayerID等の検証完了後に共通内部API`GenerateTimeBasedSeed`でSeedを生成し, そのSeedでランダム対戦相手を抽選する.
* ランダムアリーナ候補はPrivateAPIの`GetAllPlayerIDs`でDatabaseから取得・同期する.

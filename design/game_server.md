# ゲームサーバー

* キャッシュとしてのDBの一部情報保持する.
  - 毎回問い合わせるとゲームの実行速度に影響するためである.
* 保有対象はID値と純粋なロジックのみとする.
  - 画像などのデータは持たない.
* 固定シード値は`202205311459`
  - これは機密情報ではないので公開されても問題ない.
  - コード内に直接埋め込む.
* GameServerは時刻ベースSeed生成を共通内部API`GenerateTimeBasedSeed`として提供する. Arena専用処理にはしない.
  - `GenerateTimeBasedSeed`は`固定シード値 ^ サーバーの時刻`を返す.
  - 時刻はUNIX時刻を採用する.
  - マイクロ秒単位とする.
  - 型は「[型定義](types.md)」の`GameServerTime`を参照する.
  - Arenaの対戦開始Seedおよび騎士団戦マッチング用Seedは本共通内部APIを使用する.
* 騎士団戦は16騎士団戦を1単位として1単位当たり1つの専用スレッド上で行う.
	- CPUが扱えるスレッド数が4以下の場合は1スレッドとする.
	- CPUが扱えるスレッド数が5以上の場合は最小1, 最大`CPUが扱えるスレッド数 - 4`まで拡張可能とする.
* 騎士団戦の処理容量上限に到達している場合, 新たな騎士団戦をClaimしない.
  - 待機キューへの追加や自動再試行は行わない.
  - 未Claimの騎士団戦はDatabase上で`scheduled`かつ`game_server_instance_id = NULL`のまま維持する.
  - 上限到達時は`DiscordNotificationEnabled=true`の場合, Discord Botへ処理容量上限到達メッセージを送信する.
* このGameServerの計算結果を正とする.
* GameServerは自身が使用する`Version`を保持し, 戦闘計算およびリプレイログへ使用する. Login時のClientVersion検証はPublic API Serverが行う.


## 複数GameServer構成

* Kubernetes上で複数GameServer Instanceを稼働可能とする.
* 各GameServerは起動時に自身を一意に識別する`GameServerInstanceID`を保持する.
  - 本番Kubernetes環境ではPod UIDを`GameServerInstanceID`として使用する.
  - テスト環境ではProcess起動ごとに一意となるUUIDを使用する.
* 騎士団戦は`GuildBattleID`単位で1つのGameServer Instanceだけが所有する.
* 所有GameServerはPrivate APIの`ClaimScheduledGuildBattles`で未割当の騎士団戦を原子的にClaimする.
* Claim成功後, `GUILD_BATTLE.game_server_instance_id`を割当の正本とする.
* Public API Serverは`GetGuildBattleAssignment`で所有GameServerを解決し, 当該GameServerへ要求を中継する. Public API Serverは解決結果をローカルキャッシュしてよい.
* 本番Kubernetes環境ではPublic API ServerがGameServer用EndpointSliceをwatchし, `endpoint.targetRef.uid`とEndpoint Addressの対応をメモリ上に保持する. `GameServerInstanceID`に一致するPod UIDのEndpointへ直接中継する.
* 騎士団戦要求を通常のKubernetes Service Load Balancingへ渡して所有GameServer以外へ到達させない.
* 所有していないGameServerは対象`GuildBattleID`の状態変更要求を処理しない.
* 同一騎士団戦の状態を複数GameServer間で共有メモリ同期する方式とはしない.

### 騎士団戦マッチング実行

* Kubernetes上で複数GameServerが稼働する場合, `CreateScheduledGuildBattles`を実行するInstanceはKubernetes LeaseによるLeader Electionで1つに限定する.
* Leader以外のGameServerは騎士団戦マッチング生成を行わない.
* Leader変更後は既存の`GetScheduledGuilds`確認規則に従い, 既存データがある場合は再生成しない.
* マッチング生成後の騎士団戦処理は各GameServerが`ClaimScheduledGuildBattles`で取得した騎士団戦だけを対象とする.

### Scale down

* GameServerのscale upは負荷および未処理騎士団戦数に応じて行ってよい.
* GameServerのscale downは通常のHPAによるreplica数減少を直接使用せず, 対象Instanceを先に`draining`へ遷移させるControllerを介して行う.
* GameServerは新規騎士団戦をClaim可能な`ready`状態と, 新規Claimを停止する`draining`状態を持つ.
* scale down対象になったGameServerは`draining`へ遷移し, 新規騎士団戦をClaimしない.
* `draining`状態でも所有中騎士団戦のPublic API要求は処理し続ける.
* `draining`状態で所有する進行中騎士団戦が0件になった場合のみ終了可能とし, Controllerは0件を確認してからPodを削除する.
* CPU使用率だけを条件として進行中騎士団戦を所有するGameServer Podを削除しない.
* GameServer Podの異常終了時に進行中騎士団戦を別Instanceへ自動復旧する処理は本仕様では定義しない.

## Discord Bot通知

* `DiscordNotificationEnabled=true`の場合, GameServerからDiscord Botへ運営通知を送信する.
* 容量上限到達時はDiscord Botへ処理容量上限到達メッセージを送信する.
* `DiscordNotificationEnabled=false`の場合はDiscord Botへの通知を行わない. 通知以外のErrorLog保存および処理結果には影響させない.

* アリーナの`StartArenaBattle`ではAccessToken・PlayerID等の検証完了後に共通内部API`GenerateTimeBasedSeed`でSeedを生成し, そのSeedでランダム対戦相手を抽選する.
* ランダムアリーナ候補はPrivateAPIの`GetAllPlayerIDs`でDatabaseから取得・同期する.

## 騎士団戦マッチング生成

`CreateScheduledGuildBattles`はGameServer内部のマッチング処理とし, Private APIメソッドにはしない.

* 同一`TargetDate`・`StartTime`の既存騎士団戦をPrivate APIの`GetScheduledGuilds`で確認し, 既存データがある場合は再生成せずそのデータを使用する.
* 既存データがない場合はPrivate APIの`GetGuildsForBattleMatching`でGuildIDと所属人数を取得する.
* 所属人数0の騎士団を除外する.
* 候補騎士団をGuildID昇順に並べる.
* 共通内部API`GenerateTimeBasedSeed`でマッチング用Seedを生成する.
* 生成したSeedで候補一覧をシャッフルし, 先頭から2騎士団ずつペアを作成する.
* `PairIndex`は0から開始する.
* 生成済みの`ScheduledGuildBattle[]`をPrivate APIの`SaveScheduledGuildBattles`へ渡して保存する.

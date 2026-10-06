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
* 騎士団戦の処理容量上限に到達している場合, 新たな騎士団戦については何も処理しない.
  - 待機キューへの追加や自動再試行は行わない.
  - Databaseの騎士団戦状態も更新せず, `scheduled` のまま維持する.
  - 上限到達時はDiscord Webhookを使用して処理容量上限到達メッセージを送信する.
* このGameServerの計算結果を正とする.
* GameServerは現在要求する`Version`を保持し, Login時に`LoginRequest.ClientVersion`との一致を検証する.

## Discord Webhook通知

* GameServerからDiscordへの容量上限通知はDiscord Webhookを使用する.
* 容量上限到達時にWebhookへ処理容量上限到達メッセージをPOSTする.

* アリーナの`StartArenaBattle`ではSessionID・PlayerID等の検証完了後に共通内部API`GenerateTimeBasedSeed`でSeedを生成し, そのSeedでランダム対戦相手を抽選する.
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

# ログ仕様

ログは用途ごとにシステムログ, 騎士団戦リプレイログ, 騎士団戦システムログへ分離する.
騎士団戦の実行速度を優先し, GameServerの騎士団戦処理スレッドではログのファイル書き込み, `stdout` / `stderr`書き込み, JSONまたはProtocol BuffersのSerialize, 外部ログ基盤への送信, Private API Serverへのログ保存要求を直接待機しない.

システムログおよび騎士団戦システムログは1行1JSON形式（UTF-8）の構造化ログとし, `stdout` / `stderr`へ出力する. 本番Kubernetes環境ではContainer RuntimeおよびNode上のログ収集Agentが非同期に収集する. GameServerは外部ログ基盤へ同期送信しない.
騎士団戦リプレイログだけは完全再現用データとして`./log/guild_battle`配下へ専用ファイルを生成し, Databaseにも保存する.

## 共通項目

システムログおよび騎士団戦システムログは, 該当する範囲で以下を保持する.

* 発生時刻.
* Log Level.
* Event名.
* Service名.
* Service Instance ID.
* Version.
* Trace ID.
* Request ID.
* AccountID.
* PlayerID.
* GuildBattleID.
* 処理結果.
* Error Code.
* 処理時間.

Public API ServerはClientから受信した各要求にRequest IDを付与する. Trace対象要求ではTrace IDも付与し, GameServerおよびPrivate API Serverへの内部要求Metadataとして伝播する.
Clientが指定したRequest IDまたはTrace IDを正本として使用しない.

## Credentialのログ出力禁止

* `Password`, `AccessToken`, `RefreshToken`, `DiscordAuthorizationToken`, Cookie全体, Authorization相当Header, mTLS秘密鍵をログへ出力しない.
* 上記Credentialを含むRequest/Responseを構造化ログへ保存する場合は, ログ出力前に対象フィールドを削除または固定文字列へ置換する.
* 認証・Session単位の追跡が必要な場合はCredentialそのものではなく, Credentialから独立して生成したCorrelation IDを使用する.

## 非同期ログ処理

GameServerはシステムログ用Queueと騎士団戦リプレイログ用ReplayQueueを分離する.
各Queueは上限を持つbounded queueとし, 無制限にMemoryを使用しない.

### システムログ用Queue

* 騎士団戦処理スレッドは構造化前のLog EventをQueueへ追加するだけとし, JSON Serializeおよび`stdout` / `stderr`出力は専用Workerが行う.
* 正常な騎士団戦要求について, GameServerは要求単位のApplication Logを出力しない.
* `DEBUG`および`TRACE`は本番環境では既定で無効とする.
* Queue高負荷時は`DEBUG`および`INFO`を破棄可能とする. `WARN`および`ERROR`を優先して格納できる領域を確保する.
* Log Eventを破棄した場合は破棄件数をMetricで保持する. Log Queue待機を理由として騎士団戦処理スレッドを停止させない.

### ReplayQueue

* 騎士団戦で処理が成立した場合, GameServerは状態反映および`RequestSequence`更新後に対応Replay EventをReplayQueueへ追加する.
* Replay Event追加順は騎士団戦処理成立順と一致させる.
* GameServerの騎士団戦処理スレッドはReplay EventのProtocol Buffers Serialize, ファイル書き込み, Private API Server送信, Database保存完了を待機しない.
* Replay WorkerはReplayQueueを成立順に読み出し, リプレイログファイルへの追記およびPrivate API Server経由のDatabase保存を行う.
* Replay Logは完全再現に使用するためReplay Eventを破棄しない.
* ReplayQueueはbounded queueとし, 高水位到達をMetricへ記録する. Queue上限へ到達し新しいReplay Eventを格納できない場合だけ, Replay Eventを破棄せず空きができるまで要求処理を待機する.
* ReplayQueueとシステムログ用Queueは独立させ, システムログの大量発生によってReplay Event保存を阻害しない.
* 騎士団戦作成ログは開戦時初期状態の正本となるため例外として, `GUILD_BATTLE_REPLAY_LOG`への保存完了後に`GUILD_BATTLE.status=in_progress`へ遷移する.

## システムログ

### Access Log

Public API ServerはClientから受信したAPI要求についてAccess Logを記録する.
Access LogにはAPI名, Request ID, Trace ID, PlayerID, GuildBattleID, Response結果, Error Code, 処理時間, Request Size, Response Sizeを該当する範囲で記録する.
Source IPを記録する場合はIngress/Gateway等の信頼したProxyから得た値を使用し, Clientが任意指定したForwarded/X-Forwarded-For相当Headerをそのまま使用しない.

GameServerは正常な騎士団戦要求について要求単位のAccess Logを出力しない. Public API ServerのAccess Logおよび騎士団戦リプレイログを使用して追跡する.

### 認証・Security Log

以下をSecurity Eventとして記録する.

* Account作成成功・失敗.
* Login成功・失敗.
* Logout.
* AccessToken検証失敗.
* RefreshToken検証失敗.
* RefreshToken再利用検知.
* Discord追加認可成功・失敗.
* Discord Role喪失によるSession失効.
* Rate Limit超過.
* mTLS認証・Service認可失敗.
* 所有していないGuildBattleIDへの状態変更要求.
* GameServer保持値と一致しない`RequestSequence`.
* 不正CharacterID.
* 不正TacticsID.

Clientへ返すError Codeを共通化する場合でも, 内部Security Logでは検証失敗理由を区別してよい.
Token本体およびPasswordは記録しない.

## 騎士団戦ログ負荷制御

### 低頻度Event

以下は発生時にLog Eventを追加する.

* GameServer起動・終了.
* GameServerの`ready`・`draining`遷移.
* 騎士団戦割当・開始・終了・解放.
* GuildBattleIDとGameServerInstanceIDの所有不一致.
* Database送信失敗およびDB障害発生状態への遷移.
* Recoveryファイル作成・再送成功・再送失敗.
* リプレイ保存失敗.
* mTLS認証失敗.
* AccessToken署名・Claim検証異常.
* GameServer内部例外.

### 正常なゲームルール拒否

BP不足, CT中, 使用回数不足, 治療・復活状態等による正常なゲームルール上の拒否は原則としてGameServerのApplication Logへ要求単位で出力しない.
必要な集計はMetricで行う.

### RequestSequence不一致

GameServer保持値と一致しない`RequestSequence`は要求ごとにログ出力しない.
`GuildBattleID`, `PlayerID`, 拒否理由単位でMemory上の件数を集約し, 最初の発生および一定期間ごとのSummaryだけを騎士団戦システムログへ出力する.
集約期間は運用設定とする.
Summaryには期待した`RequestSequence`, 受信した`RequestSequence`, 件数を含めてよい.

### 不正ゲーム要求

不正CharacterID, 不正TacticsID, 所有していないGuildBattleID等のSecurity Eventは, 同一主体から大量発生した場合にログ増幅を防ぐため集約する.
最初の発生を記録し, 以降は一定期間Memory上で件数を加算してSummaryを出力する.
集約期間は運用設定とする.

## Metric

騎士団戦の正常系集計はLogではなくMetricを優先する.
Metric更新はMemory上のCounterまたはHistogram更新で完結させ, 騎士団戦処理スレッドから外部監視基盤へ同期送信しない.

最低限以下を取得する.

* API要求数.
* API拒否数および拒否理由.
* 進行中騎士団戦数.
* GameServerが所有する騎士団戦数.
* 騎士団戦要求処理時間.
* `RequestSequence`不一致件数.
* GuildBattle所有不一致件数.
* ReplayQueue現在要素数.
* ReplayQueue高水位到達回数.
* システムログ破棄件数.
* Database送信失敗件数.
* Recoveryファイル件数.

PlayerID, GuildBattleID, Request ID等の高Cardinality値をMetric Labelへ使用しない.

## Trace

分散Traceは常時全要求を保存せずSamplingを行う.
通常成功要求のSampling Rateは運用設定とする.
Errorとなった要求および処理時間が運用設定の閾値を超えた要求は調査対象として保持できる構成とする.
本番GameServerではDamage計算, Ability適用, Tactics効果適用等の内部関数単位で常時Spanを生成しない.
Public API ServerからGameServer, 必要な場合はPrivate API Serverまでの粗い処理単位をTrace対象とする.
Trace Exportは騎士団戦処理スレッドから同期実行しない.

## 騎士団戦リプレイログ

ファイル名は`./log/guild_battle/<生成時刻(YYYY_MMDD_HHMMSS)(JST)>_<騎士団戦ID>_replay.pb`とする.
リプレイログのwire形式は「[guild_battle_replay.proto](guild_battle_replay.proto)」を正本とする.
ファイルは`GuildBattleReplayEnvelope`をProtocol BuffersでSerializeし, 各Messageの前へprotobuf varintのMessage長を付与したlength-delimited Message列として処理成立順に追記する.
JSONへ変換して保存しない. Databaseの`GUILD_BATTLE_REPLAY_LOG.payload`にも同じ`GuildBattleReplayEnvelope`のSerialize済みバイナリを保存する.
`GuildBattleReplayEnvelope.process_type`と`oneof payload`は必ず対応する組み合わせを設定する.
処理が成立した場合のみReplay Eventを生成する(失敗は含まれない).
成立した処理はReplayQueueへ追加し, Replay Workerが本リプレイログへ書き出すとともに, Private API Server経由でDatabaseへ保存する.
ログの最初から辿ることで特定地点まで完全に再現可能にする.
騎士団戦作成ログには, 開戦時点で確定した騎士団レベル, 所属メンバー一覧, GameServerが当該騎士団戦の騎士団戦データとして保持するプレイヤーの最大BP・編成・所持アイテム等の可変初期状態を`GuildBattleInitialSnapshot`として保存する.
再現時は`GuildBattleInitialSnapshot`を初期状態として使用し, Databaseの現在値は初期状態の復元に使用しない.
再現時は対象の騎士団戦で使用されたものと同一のマスターデータおよびゲームロジックを使用する.
バージョンはセマンティックバージョニング形式の`Version`文字列で識別する.
`Version`は対象リプレイで使用したマスターデータとゲームロジックの組み合わせを一意に識別する.

### 騎士団戦作成時

GameServer受信時刻, `GuildBattleID`, `GuildBattleReplayProcessType`, InitialSeed, GuildID[2], `GuildBattleInitialSnapshot`, Version.

### 参加時

GameServer受信時刻, `GuildBattleID`, `GuildBattleReplayProcessType`, PlayerID. リプレイ時はこの成立順で騎士団戦本体PRNGを1回消費し, RequestSequence生成時と同じ乱数消費を再現する.

### 出撃時

GameServer受信時刻, `GuildBattleID`, `GuildBattleReplayProcessType`, Sequence, PlayerID, SelectID[5]

### タクティクス使用時

GameServer受信時刻, `GuildBattleID`, `GuildBattleReplayProcessType`, PlayerID, TacticsID.

### 治療時

GameServer受信時刻, `GuildBattleID`, `GuildBattleReplayProcessType`, PlayerID, HealState.

### 復活時

GameServer受信時刻, `GuildBattleID`, `GuildBattleReplayProcessType`, PlayerID, ReviveState.

### アイテム回復時

GameServer受信時刻, `GuildBattleID`, `GuildBattleReplayProcessType`, PlayerID, ItemID.

## 騎士団戦システムログ

騎士団戦システムログはGameServerの構造化System/Security Logとして`stdout` / `stderr`へ出力する. 騎士団戦ごとの専用System Logファイルは生成しない.

以下を対象とする.

* GameServer lifecycleおよび騎士団戦lifecycle.
* Database障害・Recovery処理.
* GuildBattle所有不一致.
* 無効SessionまたはToken検証異常.
* 集約後の無効`RequestSequence`.
* 集約後の不正CharacterID.
* 集約後の不正TacticsID.

BP不足等の正常なゲームルール拒否は本ログへ要求単位で保存せずMetricへ集約する.

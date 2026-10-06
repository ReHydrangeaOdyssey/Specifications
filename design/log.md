# ログ仕様

それぞれ専用のログファイルを生成する.
ログファイルはすべて`./log`配下に生成される.

すべてのログファイルはJSON形式（UTF-8）とする.

## システムログ

* サーバーへのアクセスログ.
* ログインログ.
* `Password`, `AccessToken`, `RefreshToken`, `DiscordAuthorizationToken`, Cookie全体, Authorization相当Header, mTLS秘密鍵をログへ出力しない.
* 上記Credentialを含むRequest/Responseを構造化ログへ保存する場合は, ログ出力前に対象フィールドを削除または固定文字列へ置換する.
* 認証・Session単位の追跡が必要な場合はCredentialそのものではなく, Credentialから独立して生成したCorrelation IDを使用する.


## 騎士団戦リプレイログ

ファイル名は`./log/guild_battle/<生成時刻(YYYY_MMDD_HHMMSS)(JST)>_<騎士団戦ID>_replay.log`とする.
リプレイログファイルはJSON形式（UTF-8）とし, ファイル全体を1つのJSON配列とする. 配列要素は処理成立順に追加するJSONオブジェクトで, 各オブジェクトは[API Payload](api_payload.md)で定義された対応Payloadの項目名・型に従う. `ProcessType`の値から対応するPayloadを判定する.
処理が成立した場合のみ書き出される(失敗は含まれない).
成立した処理は本リプレイログへ書き出すとともに, Private API Server経由でDatabaseへ保存する.
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

ファイル名は`./log/guild_battle/<生成時刻(YYYY_MMDD_HHMMSS)(JST)>_<騎士団戦ID>_system.log`とする.
以下のようなログを保管する.

* BP不足による拒否.
* 無効Session.
* GameServer保持値と一致しない無効な`RequestSequence`による要求.
* 不正CharacterID.
* 不正TacticsID.



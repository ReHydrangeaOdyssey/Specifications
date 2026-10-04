# ログ仕様

それぞれ専用のログファイルを生成する
ログファイルは全て`./log`配下に生成される

騎士団戦リプレイログのみバイナリ形式とし、それ以外のログファイルはJSON形式（UTF-8）とする。

## システムログ

* サーバーへのアクセスログ
* ログインログ


## 騎士団戦リプレイログ

ファイル名は`./log/guild_battle/<生成時刻(YYYY_MMDD_HHMMSS)(JST)>_<騎士団戦ID>_replay.log`とする
リプレイログファイルはバイナリ形式とする。各レコードは先頭に`GuildBattleReplayProcessType`を持ち、そのEnum値に対応する構造体をバイナリとして書き込み、読み込み時も同じEnum値から対応構造体を決定する。
処理が成立した場合のみ書き出される(失敗は含まれない).
成立した処理は本リプレイログへ書き出すとともに、Private API Server経由でDatabaseへ保存する.
ログの最初から辿ることで特定地点まで完全に再現可能にする
騎士団戦作成ログには、開戦時点で確定した騎士団レベル、所属メンバー一覧、参加対象プレイヤーの最大BP・編成・所持アイテム等の可変初期状態を`GuildBattleInitialSnapshot`として保存する.
再現時は`GuildBattleInitialSnapshot`を初期状態として使用し、Databaseの現在値は初期状態の復元に使用しない.
再現時は対象の騎士団戦で使用されたものと同一のマスターデータ及びゲームロジックを使用する
バージョンはセマンティックバージョニング形式の`Version`文字列で識別する
`Version`は対象リプレイで使用したマスターデータとゲームロジックの組み合わせを一意に識別する

### 騎士団戦作成時

GameServer受信時刻, `GuildBattleID`, `GuildBattleReplayProcessType`, InitialSeed, GuildID[2], `GuildBattleInitialSnapshot`, Version

### 出撃時

GameServer受信時刻, `GuildBattleID`, `GuildBattleReplayProcessType`, Sequence, PlayerID, SelectID[5]

### タクティクス使用時

GameServer受信時刻, `GuildBattleID`, `GuildBattleReplayProcessType`, PlayerID, TacticsID

### 治療時

GameServer受信時刻, `GuildBattleID`, `GuildBattleReplayProcessType`, PlayerID, HealState

### 復活時

GameServer受信時刻, `GuildBattleID`, `GuildBattleReplayProcessType`, PlayerID, ReviveState

### アイテム回復時

GameServer受信時刻, `GuildBattleID`, `GuildBattleReplayProcessType`, PlayerID, ItemID


## 騎士団戦システムログ

ファイル名は`./log/guild_battle/<生成時刻(YYYY_MMDD_HHMMSS)(JST)>_<騎士団戦ID>_system.log`とする
以下のようなログを保管する

* BP不足による拒否
* 無効Session
* GameServer保持値と一致しない無効な`RequestSequence`による要求
* 不正CharacterID
* 不正TacticsID



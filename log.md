# ログ仕様

それぞれ専用のログファイルを生成する
ログファイルは全て`./log`配下に生成される

## システムログ

* サーバーへのアクセスログ
* ログインログ


## 騎士団戦リプレイログ

ファイル名は`./log/guild_battle/<生成時刻(YYYY_MMDD_HHMMSS)(JST)>_<騎士団戦ID>_replay.log`とする
処理が成立した場合のみ書き出される(失敗は含まれない)
ログの最初から辿ることで特定地点まで完全に再現可能にする
再現時は対象の騎士団戦で使用されたものと同一のマスターデータ及びゲームロジックを使用する
バージョンはセマンティックバージョニング形式の`Version`文字列で識別する
`Version`は対象リプレイで使用したマスターデータとゲームロジックの組み合わせを一意に識別する

### 騎士団戦作成時

GameServer受信時刻, `GuildBattleReplayProcessType`, InitialSeed, GuildID[2], Version

### 出撃時

GameServer受信時刻, `GuildBattleReplayProcessType`, Sequence, PlayerID, SelectID[5]

### タクティクス使用時

GameServer受信時刻, `GuildBattleReplayProcessType`, PlayerID, TacticsID

### 治療時

GameServer受信時刻, `GuildBattleReplayProcessType`, PlayerID, HealState

### 復活時

GameServer受信時刻, `GuildBattleReplayProcessType`, PlayerID, ReviveState

### アイテム回復時

GameServer受信時刻, `GuildBattleReplayProcessType`, PlayerID, ItemID


## 騎士団戦システムログ

ファイル名は`./log/guild_battle/<生成時刻(YYYY_MMDD_HHMMSS)(JST)>_<騎士団戦ID>_system.log`とする
以下のようなログを保管する

* BP不足による拒否
* 無効Session
* 同じ要求の再送
* 不正CharacterID
* 不正TacticsID



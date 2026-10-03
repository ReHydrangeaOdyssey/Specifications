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

### 騎士団戦作成時

GameServer受信時刻, 処理の種類, InitialSeed, GuildBattleID[2]

### 出撃時

GameServer受信時刻, 処理の種類, Sequence, PlayerID, CharacterID[5]

### タクティクス使用時

GameServer受信時刻, 処理の種類, PlayerID, TacticsID

### 治療時

GameServer受信時刻, 処理の種類, PlayerID, HealState

### 復活時

GameServer受信時刻, 処理の種類, PlayerID, HealState

### アイテム回復時

GameServer受信時刻, 処理の種類, PlayerID, ItemID


## 騎士団戦システムログ

ファイル名は`./log/guild_battle/<生成時刻(YYYY_MMDD_HHMMSS)(JST)>_<騎士団戦ID>_system.log`とする
以下のようなログを保管する

* BP不足による拒否
* 無効Session
* 同じ要求の再送
* 不正CharacterID
* 不正TacticsID




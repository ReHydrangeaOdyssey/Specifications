# 型定義

各仕様書で共通して使用する型はこの仕様書を正とする.
各仕様書ではプリミティブ型を直接定義せず, この仕様書に定義された論理型を参照する.

## 基本方針

* Rust実装で使用する型, Protocol Buffersで使用する型, PostgreSQLで使用する型の対応を定義する.
* `u64`を使用する論理型はPostgreSQLの`bigint`では全範囲を表現できないため`numeric(20,0)`を使用する.
* Protocol Buffersに`u8`および`u16`は存在しないため, wire上では`uint32`を使用し, 受信時に論理型の範囲チェックを行う.
* 32bit浮動小数点数を使用する値はIEEE-754に従う.

## ID

| 論理型 | Rust | Protocol Buffers | PostgreSQL | 内容 |
|---|---|---|---|---|
| `PlayerID` | `u64` | `uint64` | `numeric(20,0)` | プレイヤーID |
| `GuildID` | `u64` | `uint64` | `numeric(20,0)` | 騎士団ID |
| `GuildBattleID` | `u64` | `uint64` | `numeric(20,0)` | 騎士団戦ID |
| `SessionID` | `u64` | `uint64` | `numeric(20,0)` | セッションID |
| `RecordID` | `u64` | `uint64` | `numeric(20,0)` | DB内部レコードID |
| `CharacterID` | `u32` | `uint32` | `bigint` | キャラクターID |
| `SkillID` | `u32` | `uint32` | `bigint` | スキルID |
| `AbilityID` | `u32` | `uint32` | `bigint` | アビリティID |
| `TacticsID` | `u32` | `uint32` | `bigint` | タクティクスID |
| `FormationID` | `u32` | `uint32` | `bigint` | フォーメーションID |
| `ItemID` | `u32` | `uint32` | `bigint` | アイテムID |
| `EffectID` | `u32` | `uint32` | `bigint` | 効果ID |
| `ConditionID` | `u32` | `uint32` | `bigint` | 条件ID |
| `CorrectionID` | `u32` | `uint32` | `bigint` | 補正ID |
| `FormationSlotID` | `u8` | `uint32` | `smallint` | 編成内の選択ID/位置ID。未使用値は最大値`255` |
| `SlotIndex` | `u8` | `uint32` | `smallint` | スロット番号 |

## 認証・セッション

| 論理型 | Rust | Protocol Buffers | PostgreSQL | 内容 |
|---|---|---|---|---|
| `Token` | `String` | `string` | `char(64)` | GameServer起動時にBotが生成して引数で渡すトークン。`[a-zA-Z0-9_]{64}` |
| `AccessToken` | `u64` | `uint64` | `numeric(20,0)` | アクセストークン |
| `DateTime` | `u64` | `uint64` | `timestamp` | UNIX epochからの経過マイクロ秒で表す日時 |
| `SessionExpiresAt` | `u64` | `uint64` | `timestamp` | UNIX epochからの経過マイクロ秒で表すセッション有効期限 |

## ゲーム内数値

| 論理型 | Rust | Protocol Buffers | PostgreSQL | 内容 |
|---|---|---|---|---|
| `HP` | `u32` | `uint32` | `bigint` | HP |
| `Attack` | `u16` | `uint32` | `integer` | 攻撃力 |
| `Defense` | `u16` | `uint32` | `integer` | 防御力 |
| `BP` | `u8` | `uint32` | `smallint` | BP |
| `TP` | `u8` | `uint32` | `smallint` | TP |
| `Score` | `u64` | `uint64` | `numeric(20,0)` | pt/スコア |
| `Sequence` | `u64` | `uint64` | `numeric(20,0)` | 騎士団戦シーケンス番号 |
| `Seed` | `u64` | `uint64` | `numeric(20,0)` | 疑似乱数シード |
| `Count` | `u32` | `uint32` | `bigint` | 回数/個数 |
| `Stage` | `u32` | `uint32` | `bigint` | 段階 |
| `DurationSeconds` | `u32` | `uint32` | `bigint` | 秒単位の時間 |
| `GameServerTime` | `u64` | `uint64` | `numeric(20,0)` | UNIX epochからの経過マイクロ秒 |
| `Float32` | `f32` | `float` | `real` | IEEE-754 32bit浮動小数点数 |
| `Rate` | `f32` | `float` | `real` | 確率/倍率 |
| `CorrectionValue` | `f32` | `float` | `real` | 補正値 |

## 文字列

| 論理型 | Rust | Protocol Buffers | PostgreSQL | 内容 |
|---|---|---|---|---|
| `UserName` | `String` | `string` | `varchar` | ユーザー名 |
| `Name` | `String` | `string` | `varchar` | 名称 |
| `Title` | `String` | `string` | `varchar` | 肩書 |
| `Description` | `String` | `string` | `text` | 説明文 |
| `Version` | `String` | `string` | `varchar` | 対象リプレイで使用したマスターデータとゲームロジックの組み合わせを一意に識別するセマンティックバージョニング形式のバージョン文字列 |
| `Bool` | `bool` | `bool` | `boolean` | 真偽値 |

## 列挙型

### ArenaMode

| 値 | 内容 |
|---|---|
| `random` | ランダム対戦 |
| `friend` | 任意の相手との対戦 |

### Rarity

```proto
enum Rarity {
  RARITY_N = 0;
  RARITY_R = 1;
  RARITY_SR = 2;
  RARITY_SSR = 3;
  RARITY_UR = 4;
}
```

### CharacterAttribute

```proto
enum CharacterAttribute {
  CHARACTER_ATTRIBUTE_SLASH = 0;
  CHARACTER_ATTRIBUTE_PIERCE = 1;
  CHARACTER_ATTRIBUTE_STRIKE = 2;
  CHARACTER_ATTRIBUTE_RANGED = 3;
}
```

### SpeedRank

```proto
enum SpeedRank {
  SPEED_RANK_SS9 = 0;
  SPEED_RANK_SS8 = 1;
  SPEED_RANK_SS7 = 2;
  SPEED_RANK_SS6 = 3;
  SPEED_RANK_SS5 = 4;
  SPEED_RANK_SS4 = 5;
  SPEED_RANK_SS3 = 6;
  SPEED_RANK_SS2 = 7;
  SPEED_RANK_SS1 = 8;
  SPEED_RANK_SS_PLUS = 9;
  SPEED_RANK_SS = 10;
  SPEED_RANK_SS_MINUS = 11;
  SPEED_RANK_S_PLUS = 12;
  SPEED_RANK_S = 13;
  SPEED_RANK_S_MINUS = 14;
  SPEED_RANK_A_PLUS = 15;
  SPEED_RANK_A = 16;
  SPEED_RANK_A_MINUS = 17;
  SPEED_RANK_B_PLUS = 18;
  SPEED_RANK_B = 19;
  SPEED_RANK_B_MINUS = 20;
  SPEED_RANK_C_PLUS = 21;
  SPEED_RANK_C = 22;
  SPEED_RANK_C_MINUS = 23;
  SPEED_RANK_D_PLUS = 24;
  SPEED_RANK_D = 25;
  SPEED_RANK_D_MINUS = 26;
  SPEED_RANK_E_PLUS = 27;
  SPEED_RANK_E = 28;
  SPEED_RANK_E_MINUS = 29;
  SPEED_RANK_F_PLUS = 30;
  SPEED_RANK_F = 31;
  SPEED_RANK_F_MINUS = 32;
}
```

## 共通データ構造型

Protocol Buffersでは以下を使用する.
論理型の範囲制約は上記の型定義に従う.

```proto
syntax = "proto3";

message Player {
  uint64 id = 1; // PlayerID
  string name = 2; // UserName
  uint64 guild_id = 3; // GuildID
}

message CharacterMasterData {
  uint32 id = 1; // CharacterID
  string title = 2; // Title
  string name = 3; // Name
  Rarity rarity = 4;
  CharacterAttribute attribute = 5;
  uint32 hp = 6; // HP
  uint32 attack = 7; // Attack
  uint32 defense = 8; // Defense
  SpeedRank speed = 9;
  uint32 bp = 10; // BP
  repeated uint32 skill_ids = 11; // SkillID
  repeated uint32 ability_ids = 12; // AbilityID
  repeated uint32 tactics_ids = 13; // TacticsID
}

message CharacterBattle {
  uint32 id = 1; // CharacterID
  CharacterAttribute attribute = 2;
  HitPoints hp = 3;
  uint32 attack = 4; // Attack
  uint32 defense = 5; // Defense
  SpeedRank speed = 6;
  uint32 bp = 7; // BP
  repeated uint32 skill_ids = 8; // SkillID
  repeated uint32 tactics_ids = 9; // TacticsID
  repeated uint32 ability_ids = 10; // AbilityID
}

message HitPoints {
  uint32 max_hp = 1; // HP
  uint32 current_hp = 2; // HP
}

message TacticsEffect {
  uint32 available_uses = 1; // Count
  uint32 tp_cost = 2; // TP
}

message TacticsBattleState {
  uint32 available_uses = 1; // Count
  uint32 tp_cost = 2; // TP
}
```

## 疑似乱数内部型

* PRNGのstateは`u64`.
* seedは`Seed`.
* `next_u32`の戻り値は`u32`.
* `next_bounded`のboundおよび戻り値は`u32`.
* 確率計算で使用する浮動小数点数は`Float32`.

### TacticsCategory

タクティクス分類を表す列挙型.

| 値 | 内容 |
|---|---|
| `buff` | バフ |
| `debuff` | デバフ |
| `score_up` | スコアアップ |
| `heal` | 回復 |
| `special` | 特殊 |

### ItemType

アイテム種類を表す列挙型.
具体的な列挙値はアイテム仕様で定義する.

### GuildBattleStatus

騎士団戦状態を表す列挙型.

| 値 | 内容 |
|---|---|
| `scheduled` | 開戦予定 |
| `in_progress` | 開戦中かつ新規処理受付中 |
| `resolving` | 30:00到達後、新規受付を停止し既存キューを解決中 |
| `completed` | 騎士団戦終了 |

### GuildBattleResult

騎士団戦の勝敗結果を表す列挙型.

| 値 | 内容 |
|---|---|
| `win` | 勝ち |
| `lose` | 負け |
| `draw` | 引き分け |


### GuildBattleReplayProcessType

騎士団戦リプレイログの処理種別を表す列挙型.

| 値 | 内容 |
|---|---|
| `create` | 騎士団戦作成 |
| `sortie` | 出撃 |
| `tactics` | タクティクス使用 |
| `heal` | 治療 |
| `revive` | 復活 |
| `item` | アイテム使用 |

### HealState

治療状態を表す列挙型.

| 値 | 内容 |
|---|---|
| `none` | 回復状態ではない |
| `healing` | 回復中状態 |
| `completed` | 回復完了状態 |

### ReviveState

復活状態を表す列挙型.

| 値 | 内容 |
|---|---|
| `annihilated` | 全滅状態 |
| `reviving` | 復活中状態 |
| `completed` | 復活完了状態 |
| `normal` | 全滅状態を解除した通常状態 |

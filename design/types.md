# 型定義

各仕様書で共通して使用する型はこの仕様書を正とする.
各仕様書ではプリミティブ型を直接定義せず, この仕様書に定義された論理型を参照する.

## 基本方針

* Rust実装で使用する型, Protocol Buffersで使用する型, PostgreSQLで使用する型の対応を定義する.
* `u64`を使用する論理型はPostgreSQLの`bigint`では全範囲を表現できないため`numeric(20,0)`を使用する.
* Protocol Buffersに`u8`および`u16`は存在しないため, wire上では`uint32`を使用し, 受信時に論理型の範囲チェックを行う.
* 32bit浮動小数点数を使用する値はIEEE-754に従う.
* Protocol Buffersの`.proto`ファイル自体は、仕様および設計が確定した後に作成する。本書では現時点で確定しているwire型と列挙値のみを定義する.
* PostgreSQLで列挙型を保存する場合は`smallint`を使用し、本書に定義するProtocol Buffers数値と同じ数値を保存する.

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
| `SkillEffectID` | `u32` | `SkillEffectID` | `smallint` | スキル効果ID。値は本書の`SkillEffectID`列挙型を参照 |
| `AbilityEffectID` | `u32` | `AbilityEffectID` | `smallint` | アビリティ効果ID。値は本書の`AbilityEffectID`列挙型を参照 |
| `TacticsEffectID` | `u32` | `TacticsEffectID` | `smallint` | タクティクス効果ID。値は本書の`TacticsEffectID`列挙型を参照 |
| `ConditionID` | `u32` | `ConditionID` | `smallint` | 条件ID。値は本書の`ConditionID`列挙型を参照 |
| `FormationSlotID` | `u8` | `uint32` | `smallint` | 編成内の選択ID/位置ID。`255`は未使用を表す予約値とし、通常の配置位置として使用しない |
| `SlotIndex` | `u8` | `uint32` | `smallint` | スロット番号 |



### ID予約値

* `PlayerID` は `0` と `u64::MAX` を予約済み無効値とし、有効なPlayerIDとして使用しない.
  - ClientがPlayerIDを未取得の場合の初期値は`0`とする.
* 固定長配列の空きを表現するため、`CharacterID`、`SkillID`、`AbilityID` はそれぞれの基底型の最大値`u32::MAX`を予約済み無効値とし、有効IDとして使用しない.
* `FormationSlotID` の予約済み無効値は既定どおり`255`とする.

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
| `TP` | `u8` | `uint32` | `smallint` | TP。型としての絶対上限は255。騎士団戦での通常最大値は100で、最大TP補正適用後も255を超えない |
| `Score` | `u64` | `uint64` | `numeric(20,0)` | pt/スコア |
| `Sequence` | `u64` | `uint64` | `numeric(20,0)` | 騎士団戦全体の処理順を表すシーケンス番号 |
| `RequestSequence` | `u64` | `uint64` | `numeric(20,0)` | 騎士団戦参加プレイヤーごとの要求検証用シーケンス番号 |
| `Seed` | `u64` | `uint64` | `numeric(20,0)` | 疑似乱数シード |
| `Count` | `u32` | `uint32` | `bigint` | 回数/個数 |
| `Stage` | `u32` | `uint32` | `bigint` | 段階 |
| `DurationSeconds` | `u32` | `uint32` | `bigint` | 秒単位の時間 |
| `GameServerTime` | `u64` | `uint64` | `numeric(20,0)` | UNIX epochからの経過マイクロ秒 |
| `Float32` | `f32` | `float` | `real` | IEEE-754 32bit浮動小数点数 |
| `Rate` | `f32` | `float` | `real` | 確率/倍率 |
| `CorrectionValue` | `f32` | `float` | `real` | 補正値 |
| `ConditionValue` | `u32` | `uint32` | `bigint` | 条件に付随する値。`every_n_turns`のターン数、`hp_at_or_below_threshold`の閾値等に使用 |
| `BinaryData` | `Vec<u8>` | `bytes` | `bytea` | バイナリデータ |

## 文字列

| 論理型 | Rust | Protocol Buffers | PostgreSQL | 内容 |
|---|---|---|---|---|
| `UserName` | `String` | `string` | `varchar` | ユーザー名 |
| `Name` | `String` | `string` | `varchar` | 名称 |
| `Title` | `String` | `string` | `varchar` | 肩書 |
| `Description` | `String` | `string` | `text` | 説明文 |
| `Version` | `String` | `string` | `varchar` | 対象リプレイで使用したマスターデータとゲームロジックの組み合わせを一意に識別するセマンティックバージョニング形式のバージョン文字列 |
| `ErrorLogMessage` | `String` | `string` | `text` | エラーログ文字列 |
| `Bool` | `bool` | `bool` | `boolean` | 真偽値 |

## 列挙型

### ArenaMode

```proto
enum ArenaMode {
  ARENA_MODE_RANDOM = 0;
  ARENA_MODE_FRIEND = 1;
}
```

| 値 | 内容 |
|---|---|
| `ARENA_MODE_RANDOM` | ランダム対戦 |
| `ARENA_MODE_FRIEND` | 任意の相手との対戦 |

### ArenaBattleErrorCode

アリーナ戦闘開始時のエラーを表す列挙型。PublicAPI共通の`ApiErrorCode`では`API_ERROR_NO_OPPONENT_AVAILABLE`に対応する。

```proto
enum ArenaBattleErrorCode {
  ARENA_BATTLE_ERROR_NO_OPPONENT_AVAILABLE = 0;
}
```


### SkillEffectID

`SkillEffectID`はスキルの効果種別を表す。列挙値は仕様上の分類と1対1に対応する。

```proto
enum SkillEffectID {
  SKILL_EFFECT_BUFF = 0;
  SKILL_EFFECT_DEBUFF = 1;
  SKILL_EFFECT_STATUS_ABNORMALITY = 2;
  SKILL_EFFECT_HEAL = 3;
  SKILL_EFFECT_ATTACK = 4;
}
```

### AbilityEffectID

`AbilityEffectID`はアビリティの効果種別を表す。列挙値は仕様上の分類と1対1に対応する。

```proto
enum AbilityEffectID {
  ABILITY_EFFECT_BUFF = 0;
  ABILITY_EFFECT_DEBUFF = 1;
  ABILITY_EFFECT_AVOIDANCE = 2;
  ABILITY_EFFECT_COUNTER = 3;
  ABILITY_EFFECT_AVOIDANCE_DISABLE = 4;
  ABILITY_EFFECT_COUNTER_DISABLE = 5;
  ABILITY_EFFECT_STATUS_ABNORMALITY_ATTACK = 6;
  ABILITY_EFFECT_DAMAGE_INCREASE = 7;
  ABILITY_EFFECT_FIXED_DAMAGE_INCREASE = 8;
  ABILITY_EFFECT_HEAL = 9;
  ABILITY_EFFECT_COVER = 10;
  ABILITY_EFFECT_DRAW_AGGRO = 11;
  ABILITY_EFFECT_PURSUIT = 12;
}
```

### TacticsEffectID

`TacticsEffectID`はタクティクスの効果種別を表す。列挙値は仕様上の分類と1対1に対応する。

```proto
enum TacticsEffectID {
  TACTICS_EFFECT_ATTACK_CORRECTION = 0;
  TACTICS_EFFECT_DEFENSE_CORRECTION = 1;
  TACTICS_EFFECT_SPEED_CORRECTION = 2;
  TACTICS_EFFECT_SCORE_CORRECTION = 3;
  TACTICS_EFFECT_CASTLE_DEFENSE_CORRECTION = 4;
  TACTICS_EFFECT_SCORE_LIMIT_CORRECTION = 5;
  TACTICS_EFFECT_MAX_TP_CORRECTION = 6;
  TACTICS_EFFECT_BP_RECOVERY = 7;
  TACTICS_EFFECT_HP_RECOVERY = 8;
  TACTICS_EFFECT_ASSAULT_CASTLE_BREAK_RATE_CORRECTION = 9;
  TACTICS_EFFECT_BATTLE_SPECIAL = 10;
  TACTICS_EFFECT_OPPONENT_SORTIE_SELECTION_RATE_CORRECTION = 11;
}
```

### ConditionID

`ConditionID`は条件種別を表す。利用箇所ごとに以下の値を使用する。

```proto
enum ConditionID {
  CONDITION_NONE = 0;
  CONDITION_SLASH_ONLY = 1;
  CONDITION_PIERCE_ONLY = 2;
  CONDITION_STRIKE_ONLY = 3;
  CONDITION_RANGED_ONLY = 4;
  CONDITION_BATTLE_START = 5;
  CONDITION_INCAPACITATED = 6;
  CONDITION_NORMAL_ATTACK = 7;
  CONDITION_EVERY_N_TURNS = 8;
  CONDITION_ATTACKED = 9;
  CONDITION_HP_AT_OR_BELOW_THRESHOLD = 10;
  CONDITION_CASTLE_BREAK = 11;
}
```

* フォーメーション位置条件では`none`、`slash_only`、`pierce_only`、`strike_only`、`ranged_only`のみを使用する.
* アビリティ発動条件では`battle_start`、`incapacitated`、`normal_attack`、`every_n_turns`、`attacked`、`hp_at_or_below_threshold`、`castle_break`を使用する.
* `every_n_turns`および`hp_at_or_below_threshold`の具体値は`ConditionValue`で保持する.

### TacticsTarget

タクティクス効果対象を表す。

```proto
enum TacticsTarget {
  TACTICS_TARGET_SELF_PARTY = 0;
  TACTICS_TARGET_ALLY_GUILD_ALL_PARTIES = 1;
  TACTICS_TARGET_ENEMY_GUILD_ALL_PARTIES = 2;
}
```

### GuildBattleStartTime

騎士団戦の固定開始時刻をJSTで表す。

```proto
enum GuildBattleStartTime {
  GUILD_BATTLE_START_1130 = 0;
  GUILD_BATTLE_START_1215 = 1;
  GUILD_BATTLE_START_1300 = 2;
  GUILD_BATTLE_START_2100 = 3;
  GUILD_BATTLE_START_2200 = 4;
  GUILD_BATTLE_START_2300 = 5;
}
```

| 値 | JST |
|---|---|
| `GUILD_BATTLE_START_1130` | 11:30 |
| `GUILD_BATTLE_START_1215` | 12:15 |
| `GUILD_BATTLE_START_1300` | 13:00 |
| `GUILD_BATTLE_START_2100` | 21:00 |
| `GUILD_BATTLE_START_2200` | 22:00 |
| `GUILD_BATTLE_START_2300` | 23:00 |

### ApiErrorCode

PublicAPIの共通エラーコード。現行仕様で判明している失敗条件のみを定義する。

```proto
enum ApiErrorCode {
  API_ERROR_UNSPECIFIED = 0;
  API_ERROR_INVALID_TOKEN = 1;
  API_ERROR_INVALID_ACCESS_TOKEN = 2;
  API_ERROR_INVALID_USER_NAME = 3;
  API_ERROR_INVALID_PLAYER_ID = 4;
  API_ERROR_INVALID_SESSION = 5;
  API_ERROR_NO_OPPONENT_AVAILABLE = 6;
  API_ERROR_GUILD_BATTLE_JOIN_NOT_ALLOWED = 7;
  API_ERROR_GUILD_BATTLE_PARTY_UPDATE_NOT_ALLOWED = 8;
  API_ERROR_GUILD_BATTLE_SORTIE_NOT_ALLOWED = 9;
  API_ERROR_TACTICS_NOT_AVAILABLE = 10;
  API_ERROR_ITEM_NOT_AVAILABLE = 11;
  API_ERROR_HEAL_NOT_AVAILABLE = 12;
  API_ERROR_HEAL_CANCEL_NOT_ALLOWED = 13;
  API_ERROR_HEAL_COMPLETE_NOT_ALLOWED = 14;
  API_ERROR_REVIVE_NOT_AVAILABLE = 15;
  API_ERROR_REVIVE_CANCEL_NOT_ALLOWED = 16;
  API_ERROR_REVIVE_COMPLETE_NOT_ALLOWED = 17;
  API_ERROR_INVALID_GUILD_BATTLE_SEQUENCE = 18;
  API_ERROR_GUILD_FULL = 19;
}
```

### SaveSessionIDErrorCode

Private APIの`SaveSessionID`で発生し得るエラーを表す。

```proto
enum SaveSessionIDErrorCode {
  SAVE_SESSION_ID_ERROR_SESSION_ID_CONFLICT = 0;
}
```

| 値 | 内容 |
|---|---|
| `SAVE_SESSION_ID_ERROR_SESSION_ID_CONFLICT` | `PLAYER_SESSION.session_id`のUNIQUE制約に衝突した |

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
  float attack = 4; // Float32。戦闘計算用攻撃力
  float defense = 5; // Float32。戦闘計算用防御力
  SpeedRank speed = 6;
  uint32 bp = 7; // BP
  uint32 main_skill_id = 8; // SkillID。戦闘で使用するメインスキル
  repeated uint32 tactics_ids = 9; // TacticsID
  repeated uint32 ability_ids = 10; // AbilityID
}

message HitPoints {
  float max_hp = 1; // Float32。戦闘計算用最大HP
  float current_hp = 2; // Float32。戦闘計算用現在HP
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

`CharacterMasterData` の `hp` / `attack` / `defense` はマスターデータ上の基礎値であり整数型とする。
`CharacterBattle` の `hp` / `attack` / `defense` は従者等の補正適用後に戦闘計算で使用する値であるため、戦闘仕様に従い `Float32` とする。プレイヤーへ表示する際の丸めは各仕様書の表示規則に従う。

## 疑似乱数内部型

* PRNGのstateは`u64`.
* seedは`Seed`.
* `next_u32`の戻り値は`u32`.
* `next_bounded`のboundおよび戻り値は`u32`.
* 確率計算で使用する浮動小数点数は`Float32`.

### TacticsCategory

```proto
enum TacticsCategory {
  TACTICS_CATEGORY_BUFF = 0;
  TACTICS_CATEGORY_DEBUFF = 1;
  TACTICS_CATEGORY_SCORE_UP = 2;
  TACTICS_CATEGORY_HEAL = 3;
  TACTICS_CATEGORY_SPECIAL = 4;
}
```

### ItemType

```proto
enum ItemType {
  ITEM_TYPE_BP_50_RECOVERY = 0;
  ITEM_TYPE_BP_FULL_RECOVERY = 1;
}
```

### GuildBattleStatus

```proto
enum GuildBattleStatus {
  GUILD_BATTLE_STATUS_SCHEDULED = 0;
  GUILD_BATTLE_STATUS_IN_PROGRESS = 1;
  GUILD_BATTLE_STATUS_RESOLVING = 2;
  GUILD_BATTLE_STATUS_COMPLETED = 3;
}
```

| 値 | 内容 |
|---|---|
| `scheduled` | 開戦予定 |
| `in_progress` | 開戦中かつ新規処理受付中 |
| `resolving` | 30:00到達後、新規受付を停止し既存キューを解決中 |
| `completed` | 騎士団戦終了 |

### GuildBattleResult

```proto
enum GuildBattleResult {
  GUILD_BATTLE_RESULT_WIN = 0;
  GUILD_BATTLE_RESULT_LOSE = 1;
  GUILD_BATTLE_RESULT_DRAW = 2;
}
```

### GuildBattleReplayProcessType

```proto
enum GuildBattleReplayProcessType {
  GUILD_BATTLE_REPLAY_CREATE = 0;
  GUILD_BATTLE_REPLAY_SORTIE = 1;
  GUILD_BATTLE_REPLAY_TACTICS = 2;
  GUILD_BATTLE_REPLAY_HEAL = 3;
  GUILD_BATTLE_REPLAY_REVIVE = 4;
  GUILD_BATTLE_REPLAY_ITEM = 5;
}
```

この数値をリプレイログの処理種別として使用する。

### HealState

```proto
enum HealState {
  HEAL_STATE_NONE = 0;
  HEAL_STATE_HEALING = 1;
  HEAL_STATE_COMPLETED = 2;
}
```

### ReviveState

```proto
enum ReviveState {
  REVIVE_STATE_ANNIHILATED = 0;
  REVIVE_STATE_REVIVING = 1;
  REVIVE_STATE_COMPLETED = 2;
  REVIVE_STATE_NORMAL = 3;
}
```

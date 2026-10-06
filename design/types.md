# 型定義

各仕様書で共通して使用する型はこの仕様書を正とする.
各仕様書ではプリミティブ型を直接定義せず, この仕様書に定義された論理型を参照する.

## 基本方針

* Rust実装で使用する型, Protocol Buffersで使用する型, PostgreSQLで使用する型の対応を定義する.
* `u64`を使用する論理型はPostgreSQLの`bigint`では全範囲を表現できないため`numeric(20,0)`を使用する.
* Protocol Buffersに`u8`および`u16`は存在しないため, wire上では`uint32`を使用し, 受信時に論理型の範囲チェックを行う.
* 32bit浮動小数点数を使用する値はIEEE-754に従う.
* Protocol Buffersの`.proto`ファイル自体は, 仕様および設計が確定した後に作成する. 本書では現時点で確定しているwire型と列挙値のみを定義する.
* PostgreSQLで列挙型を保存する場合は`smallint`を使用し, 本書に定義するProtocol Buffers数値と同じ数値を保存する.

## ID

| 論理型 | Rust | Protocol Buffers | PostgreSQL | 内容 |
|---|---|---|---|---|
| `AccountID` | `u64` | `uint64` | `numeric(20,0)` | 認証アカウントID |
| `DiscordUserID` | `u64` | `uint64` | `numeric(20,0)` | Discord上のユーザーID. Discordロール追加認可時だけ使用する外部ID |
| `PlayerID` | `u64` | `uint64` | `numeric(20,0)` | プレイヤーID |
| `GuildID` | `u64` | `uint64` | `numeric(20,0)` | 騎士団ID |
| `GuildBattleID` | `u64` | `uint64` | `numeric(20,0)` | 騎士団戦ID |
| `SessionID` | `[u8; 16]` | `bytes` | `uuid` | Refresh Sessionを識別する128bitのセッションID |
| `RecordID` | `u64` | `uint64` | `numeric(20,0)` | DB内部レコードID |
| `CharacterID` | `u32` | `uint32` | `bigint` | キャラクターID |
| `SkillID` | `u32` | `uint32` | `bigint` | スキルID |
| `AbilityID` | `u32` | `uint32` | `bigint` | アビリティID |
| `TacticsID` | `u32` | `uint32` | `bigint` | タクティクスID |
| `FormationID` | `u32` | `uint32` | `bigint` | フォーメーションID |
| `ItemID` | `u32` | `uint32` | `bigint` | アイテムID |
| `SkillEffectID` | `u32` | `SkillEffectID` | `smallint` | スキル効果ID. 値は本書の`SkillEffectID`列挙型を参照 |
| `AbilityEffectID` | `u32` | `AbilityEffectID` | `smallint` | アビリティ効果ID. 値は本書の`AbilityEffectID`列挙型を参照 |
| `TacticsEffectID` | `u32` | `TacticsEffectID` | `smallint` | タクティクス効果ID. 値は本書の`TacticsEffectID`列挙型を参照 |
| `StatusAbnormalityID` | `u32` | `StatusAbnormalityID` | `smallint` | 状態異常ID. 値は本書の`StatusAbnormalityID`列挙型を参照 |
| `SkillTargetConditionID` | `u32` | `SkillTargetConditionID` | `smallint` | 単体スキルの優先対象条件. 値は本書の`SkillTargetConditionID`列挙型を参照 |
| `FormationConditionID` | `u32` | `FormationConditionID` | `smallint` | フォーメーション位置条件. 値は本書の`FormationConditionID`列挙型を参照 |
| `AbilityConditionID` | `u32` | `AbilityConditionID` | `smallint` | アビリティ発動条件. 値は本書の`AbilityConditionID`列挙型を参照 |
| `FormationSlotID` | `u8` | `uint32` | `smallint` | 編成内の選択ID/位置ID. `255`は未使用を表す予約値とし, 通常の配置位置として使用しない |
| `SlotIndex` | `u8` | `uint32` | `smallint` | スロット番号 |



### ID予約値

* `AccountID`および`PlayerID`は `0` と `u64::MAX` を予約済み無効値とし, 有効なIDとして使用しない.
* `PlayerID`について, ClientがPlayerIDを未取得の場合の初期値は`0`とする.
* 固定長配列の空きを表現するため, `CharacterID`, `SkillID`, `AbilityID` はそれぞれの基底型の最大値`u32::MAX`を予約済み無効値とし, 有効IDとして使用しない.
* `FormationSlotID` の予約済み無効値は既定どおり`255`とする.

## 認証・セッション

| 論理型 | Rust | Protocol Buffers | PostgreSQL | 内容 |
|---|---|---|---|---|
| `AccessToken` | `String` | `string` | - | Ed25519署名付きJWT Compact Serialization形式の短寿命アクセストークン |
| `DiscordAuthorizationToken` | `String` | `string` | - | Discord Role保持確認後にBot経由で発行する5分有効のEd25519署名付きJWT. Discord追加認可が無効な構成では使用しない |
| `RefreshToken` | `[u8; 32]` | `bytes` | - | AccessToken更新に使用する32byteの暗号学的乱数Token. 平文はDatabaseへ保存しない |
| `RefreshTokenHash` | `[u8; 32]` | `bytes` | `bytea` | `SHA-256(RefreshToken)` |
| `Password` | `String` | `string` | - | Login時だけ送受信するPassword. Databaseへ平文保存しない |
| `PasswordHash` | `String` | `string` | `text` | Argon2idのPasswordHash |
| `DateTime` | `u64` | `uint64` | `timestamp` | UNIX epochからの経過マイクロ秒で表す日時 |
| `SessionExpiresAt` | `u64` | `uint64` | `timestamp` | UNIX epochからの経過マイクロ秒で表すRefresh Session有効期限 |

## ゲーム内数値

| 論理型 | Rust | Protocol Buffers | PostgreSQL | 内容 |
|---|---|---|---|---|
| `HP` | `u32` | `uint32` | `bigint` | HP |
| `Attack` | `u16` | `uint32` | `integer` | 攻撃力 |
| `Defense` | `u16` | `uint32` | `integer` | 防御力 |
| `BP` | `u8` | `uint32` | `smallint` | BP |
| `TP` | `u8` | `uint32` | `smallint` | TP. 型としての絶対上限は255. 騎士団戦での通常最大値は100で, 最大TP補正適用後も255を超えない |
| `Score` | `u64` | `uint64` | `numeric(20,0)` | pt/スコア |
| `Sequence` | `u64` | `uint64` | `numeric(20,0)` | 騎士団戦全体の処理順を表すシーケンス番号 |
| `RequestSequence` | `u64` | `uint64` | `numeric(20,0)` | 騎士団戦参加プレイヤーごとの要求検証用シーケンス番号 |
| `Seed` | `u64` | `uint64` | `numeric(20,0)` | 疑似乱数シード |
| `Count` | `u32` | `uint32` | `bigint` | 回数/個数. 回数上限で`u32::MAX`を指定した場合は回数無制限を表す |
| `Int32` | `i32` | `sint32` | `integer` | 符号付き32bit整数. 城Lv等の正負を持つ整数補正に使用 |
| `Stage` | `u32` | `uint32` | `bigint` | 段階 |
| `DurationSeconds` | `u32` | `uint32` | `bigint` | 秒単位の時間 |
| `GameServerTime` | `u64` | `uint64` | `numeric(20,0)` | UNIX epochからの経過マイクロ秒 |
| `Float32` | `f32` | `float` | `real` | IEEE-754 32bit浮動小数点数 |
| `Rate` | `f32` | `float` | `real` | 確率/倍率 |
| `CorrectionValue` | `f32` | `float` | `real` | 補正値 |
| `ConditionValue` | `u32` | `uint32` | `bigint` | アビリティ発動条件に付随する値. `ABILITY_CONDITION_EVERY_N_TURNS`ではターン数, `ABILITY_CONDITION_HP_AT_OR_BELOW_THRESHOLD`では最大HPに対する整数パーセント値として使用 |
| `BinaryData` | `Vec<u8>` | `bytes` | `bytea` | バイナリデータ |
| `JsonData` | `serde_json::Value` | `string` | `jsonb` | UTF-8 JSONデータ. Protocol Buffers上ではJSON文字列として扱う |

## 文字列

| 論理型 | Rust | Protocol Buffers | PostgreSQL | 内容 |
|---|---|---|---|---|
| `LoginID` | `String` | `string` | `varchar` | ログイン認証に使用するユーザーID |
| `UserName` | `String` | `string` | `varchar` | ゲーム内表示用ユーザー名 |
| `Name` | `String` | `string` | `varchar` | 名称 |
| `Title` | `String` | `string` | `varchar` | 肩書 |
| `Description` | `String` | `string` | `text` | 説明文 |
| `Version` | `String` | `string` | `varchar` | 対象リプレイで使用したマスターデータとゲームロジックの組み合わせを一意に識別するセマンティックバージョニング形式のバージョン文字列 |
| `GameServerInstanceID` | `String` | `string` | `varchar` | 稼働中GameServer Instanceを一意に識別するID |
| `ErrorLogMessage` | `String` | `string` | `text` | エラーログ文字列 |
| `Bool` | `bool` | `bool` | `boolean` | 真偽値 |

## 列挙型

### ArenaMode

```proto
enum ArenaMode {
  ARENA_MODE_RANDOM = 0; // 全プレイヤー候補からランダムに対戦相手を選ぶモード.
  ARENA_MODE_FRIEND = 1; // 指定したプレイヤーと対戦するモード.
}
```

### ArenaBattleErrorCode

アリーナ戦闘開始時の個別エラーを表す列挙型. ランダム対戦の候補なし, フレンド対戦のPlayer不存在・ArenaParty未登録, 要求元PlayerのArenaParty未登録を区別する.

```proto
enum ArenaBattleErrorCode {
  ARENA_BATTLE_ERROR_NO_OPPONENT_AVAILABLE = 0; // ランダム対戦で対戦可能な相手プレイヤーが存在しない.
  ARENA_BATTLE_ERROR_PLAYER_NOT_FOUND = 1; // フレンド対戦で指定したPlayerIDが存在しない.
  ARENA_BATTLE_ERROR_ARENA_PARTY_NOT_REGISTERED = 2; // フレンド対戦で指定したOpponentIDは存在するがArenaPartyが未登録である.
  ARENA_BATTLE_ERROR_REQUESTER_ARENA_PARTY_NOT_REGISTERED = 3; // 対戦要求元PlayerIDのArenaPartyが未登録である.
}
```

### SkillEffectID

`SkillEffectID`はスキルの効果種別を表す. 列挙値は仕様上の分類と1対1に対応する.

```proto
enum SkillEffectID {
  SKILL_EFFECT_BUFF = 0; // 対象へバフを付与する.
  SKILL_EFFECT_DEBUFF = 1; // 対象へデバフを付与する.
  SKILL_EFFECT_STATUS_ABNORMALITY = 2; // 対象へ状態異常を付与する.
  SKILL_EFFECT_HEAL = 3; // 対象のHPを割合回復する.
  SKILL_EFFECT_ATTACK = 4; // 対象へ攻撃ダメージを与える.
}
```

### StatusAbnormalityID

`StatusAbnormalityID`は状態異常の種類を表す.

```proto
enum StatusAbnormalityID {
  STATUS_ABNORMALITY_POISON = 0; // 毒.
  STATUS_ABNORMALITY_BLINDNESS = 1; // 暗闇.
  STATUS_ABNORMALITY_SILENCE = 2; // 沈黙.
  STATUS_ABNORMALITY_RANGE_ATTACK_DISABLED = 3; // 範囲攻撃不可.
  STATUS_ABNORMALITY_COMA = 4; // 昏睡.
}
```

### SkillTargetRange

`SkillTargetRange`はスキルの対象範囲を表す.

```proto
enum SkillTargetRange {
  SKILL_TARGET_RANGE_ALL = 0; // 対象全体を選択する.
  SKILL_TARGET_RANGE_SINGLE = 1; // 単体を選択する.
  SKILL_TARGET_RANGE_RANDOM = 2; // ランダム対象へ複数回攻撃する.
  SKILL_TARGET_RANGE_VERTICAL_COLUMN = 3; // 縦1列を選択する.
  SKILL_TARGET_RANGE_HORIZONTAL_ROW = 4; // 横1列を選択する.
  SKILL_TARGET_RANGE_X_SHAPE = 5; // X字範囲を選択する.
  SKILL_TARGET_RANGE_CROSS_SHAPE = 6; // 十字範囲を選択する.
}
```

### SkillTargetConditionID

`SkillTargetConditionID`は単体スキルの優先対象条件を表す. `SKILL_TARGET_CONDITION_STATUS_ABNORMALITY`の場合は加工済みスキルマスターデータに保持する`StatusAbnormalityID`で対象とする状態異常を特定する.

```proto
enum SkillTargetConditionID {
  SKILL_TARGET_CONDITION_NONE = 0; // 優先条件なし.
  SKILL_TARGET_CONDITION_BUFFED = 1; // バフ状態の対象を優先する.
  SKILL_TARGET_CONDITION_DEBUFFED = 2; // デバフ状態の対象を優先する.
  SKILL_TARGET_CONDITION_HP_25_PERCENT_OR_BELOW = 3; // 現在HPが最大HPの25%以下の対象を優先する.
  SKILL_TARGET_CONDITION_STATUS_ABNORMALITY = 4; // 指定した状態異常に該当する対象を優先する.
}
```

### SkillStatTarget

バフ・デバフスキルが補正する能力を表す.

```proto
enum SkillStatTarget {
  SKILL_STAT_TARGET_NONE = 0; // 能力補正対象なし.
  SKILL_STAT_TARGET_ATTACK = 1; // 攻撃力を補正する.
  SKILL_STAT_TARGET_DEFENSE = 2; // 防御力を補正する.
}
```

### AbilityEffectID

`AbilityEffectID`はアビリティの効果種別を表す. 列挙値は仕様上の分類と1対1に対応する.

```proto
enum AbilityEffectID {
  ABILITY_EFFECT_BUFF = 0; // バフ効果.
  ABILITY_EFFECT_DEBUFF = 1; // デバフ効果.
  ABILITY_EFFECT_AVOIDANCE = 2; // 回避効果.
  ABILITY_EFFECT_COUNTER = 3; // 反撃効果.
  ABILITY_EFFECT_AVOIDANCE_DISABLE = 4; // 相手の回避を無効化する効果.
  ABILITY_EFFECT_COUNTER_DISABLE = 5; // 相手の反撃を無効化する効果.
  ABILITY_EFFECT_STATUS_ABNORMALITY_ATTACK = 6; // 状態異常を伴う攻撃効果.
  ABILITY_EFFECT_DAMAGE_INCREASE = 7; // ダメージを割合増加させる効果.
  ABILITY_EFFECT_FIXED_DAMAGE_INCREASE = 8; // ダメージを固定値で増加させる効果.
  ABILITY_EFFECT_HEAL = 9; // 回復効果.
  ABILITY_EFFECT_COVER = 10; // かばう効果.
  ABILITY_EFFECT_DRAW_AGGRO = 11; // ひきつけ効果.
  ABILITY_EFFECT_PURSUIT = 12; // 追撃効果.
}
```

### TacticsEffectID

`TacticsEffectID`はタクティクスの効果種別を表す. 列挙値は仕様上の分類と1対1に対応する.

```proto
enum TacticsEffectID {
  TACTICS_EFFECT_ATTACK_CORRECTION = 0; // 攻撃力補正.
  TACTICS_EFFECT_DEFENSE_CORRECTION = 1; // 防御力補正.
  TACTICS_EFFECT_SPEED_CORRECTION = 2; // 速度補正.
  TACTICS_EFFECT_SCORE_CORRECTION = 3; // スコア補正.
  TACTICS_EFFECT_CASTLE_DEFENSE_CORRECTION = 4; // 城防御補正.
  TACTICS_EFFECT_SCORE_LIMIT_CORRECTION = 5; // スコア上限補正.
  TACTICS_EFFECT_MAX_TP_CORRECTION = 6; // 最大TP補正.
  TACTICS_EFFECT_BP_RECOVERY = 7; // BP回復.
  TACTICS_EFFECT_HP_RECOVERY = 8; // HP回復.
  TACTICS_EFFECT_ASSAULT_CASTLE_BREAK_RATE_CORRECTION = 9; // 強襲キャッスルブレイク率補正.
  TACTICS_EFFECT_BATTLE_SPECIAL = 10; // 戦闘時特殊効果.
  TACTICS_EFFECT_OPPONENT_SORTIE_SELECTION_RATE_CORRECTION = 11; // 相手出撃時の選択重み補正.
}
```

### TacticsHpRecoveryType

`TACTICS_EFFECT_HP_RECOVERY`の回復方式を表す.

```proto
enum TacticsHpRecoveryType {
  TACTICS_HP_RECOVERY_INCAPACITATED_FULL = 0; // HP0のキャラクターだけを対象とし, 最大HPの100%まで回復する.
  TACTICS_HP_RECOVERY_POSITIVE_HP_RATE = 1; // HP1以上のキャラクターだけを対象とし, マスターデータの割合だけ回復する.
}
```

### TacticsBattleSpecialType

`TACTICS_EFFECT_BATTLE_SPECIAL`の特殊効果系列を表す.

```proto
enum TacticsBattleSpecialType {
  TACTICS_BATTLE_SPECIAL_ACCELERATOR = 0; // アクセラレーター系.
  TACTICS_BATTLE_SPECIAL_ASSAULT = 1; // アサルト系.
  TACTICS_BATTLE_SPECIAL_ERASE = 2; // イレイス系.
  TACTICS_BATTLE_SPECIAL_ACE = 3; // エース系.
  TACTICS_BATTLE_SPECIAL_EXTERLIZE = 4; // エクスターライズ系.
  TACTICS_BATTLE_SPECIAL_EX_DRIVE = 5; // エクスドライブ系.
  TACTICS_BATTLE_SPECIAL_EDGE_NOTE = 6; // エッジノート系.
  TACTICS_BATTLE_SPECIAL_ELYSION = 7; // エリュシオン系.
  TACTICS_BATTLE_SPECIAL_ENDER_BREAK = 8; // エンダーブレイク系.
  TACTICS_BATTLE_SPECIAL_ORACLE = 9; // オラクル系.
  TACTICS_BATTLE_SPECIAL_ORATORIO = 10; // オラトリオ系.
  TACTICS_BATTLE_SPECIAL_CURSE = 11; // カーズ系.
  TACTICS_BATTLE_SPECIAL_COUNTER = 12; // カウンター系.
  TACTICS_BATTLE_SPECIAL_CASTLE_WEAKNESS = 13; // キャッスルウィークネス系.
  TACTICS_BATTLE_SPECIAL_CASTLE_VEIL = 14; // キャッスルヴェール系.
  TACTICS_BATTLE_SPECIAL_CLAUSTRUM = 15; // クラウストルム系.
  TACTICS_BATTLE_SPECIAL_GRAVITY_ASSAULT = 16; // グラビティアサルト系.
  TACTICS_BATTLE_SPECIAL_CLEVER_NOTE = 17; // クレバーノート系.
  TACTICS_BATTLE_SPECIAL_JUGGERNAUT = 18; // ジャガーノート系.
  TACTICS_BATTLE_SPECIAL_SHADOW = 19; // シャドウ系.
  TACTICS_BATTLE_SPECIAL_STEALTH = 20; // ステルス系.
  TACTICS_BATTLE_SPECIAL_STREAM = 21; // ストリーム系.
  TACTICS_BATTLE_SPECIAL_SLASHER = 22; // スラッシャー系.
  TACTICS_BATTLE_SPECIAL_SLOW_RATE = 23; // スロウレート系.
  TACTICS_BATTLE_SPECIAL_TARANTELLA = 24; // タランテラ系.
  TACTICS_BATTLE_SPECIAL_DIVINE_ACTIVE = 25; // ディバインアクティブ系.
  TACTICS_BATTLE_SPECIAL_DIVINE_ETOILE = 26; // ディバインエトワール系.
  TACTICS_BATTLE_SPECIAL_DIVINE_THRUST = 27; // ディバインスラスト系.
  TACTICS_BATTLE_SPECIAL_DIVINE_RAPID = 28; // ディバインラピッド系.
  TACTICS_BATTLE_SPECIAL_BERSERK = 29; // バーサク系.
  TACTICS_BATTLE_SPECIAL_HIDE = 30; // ハイド系.
  TACTICS_BATTLE_SPECIAL_PANZER = 31; // パンツァー系.
  TACTICS_BATTLE_SPECIAL_HEAL = 32; // ヒール系.
  TACTICS_BATTLE_SPECIAL_PHALANX = 33; // ファランクス系.
  TACTICS_BATTLE_SPECIAL_FORCE_OF_WISH = 34; // フォースオブウィッシュ系.
  TACTICS_BATTLE_SPECIAL_FORCE_OF_PLAY = 35; // フォースオブプレイ系.
  TACTICS_BATTLE_SPECIAL_FORTRESS = 36; // フォートレスオーダー系.
  TACTICS_BATTLE_SPECIAL_BLITZ = 37; // ブリッツ系.
  TACTICS_BATTLE_SPECIAL_PROVOKE = 38; // プロヴォーク系.
  TACTICS_BATTLE_SPECIAL_POINT_RISE = 39; // ポイントライズ系.
  TACTICS_BATTLE_SPECIAL_MENACE = 40; // メナス系.
  TACTICS_BATTLE_SPECIAL_RAMPAGE = 41; // ランページ系.
  TACTICS_BATTLE_SPECIAL_REVIVE = 42; // リヴァイブ系.
  TACTICS_BATTLE_SPECIAL_RECONTRACT = 43; // リコントラクト系.
  TACTICS_BATTLE_SPECIAL_RESURRECTION = 44; // リザレクション系.
  TACTICS_BATTLE_SPECIAL_RECT_NOTE = 45; // レクトノート系.
  TACTICS_BATTLE_SPECIAL_WISE_NOTE = 46; // ワイズノート系.
  TACTICS_BATTLE_SPECIAL_ASSAULT_ORDER = 47; // アサルトオーダー系.
  TACTICS_BATTLE_SPECIAL_ACE_ORDER = 48; // エースオーダー系.
  TACTICS_BATTLE_SPECIAL_SHADOW_ORDER = 49; // シャドウオーダー系.
}
```

### TacticsBattleSpecialApplyTarget

戦闘時特殊効果を適用する箇所を表す.

```proto
enum TacticsBattleSpecialApplyTarget {
  TACTICS_BATTLE_SPECIAL_APPLY_ALLY_GUILD = 0; // 味方騎士団へ適用する.
  TACTICS_BATTLE_SPECIAL_APPLY_ENEMY_GUILD = 1; // 相手騎士団へ適用する.
  TACTICS_BATTLE_SPECIAL_APPLY_BATTLE_ALLY_PARTY = 2; // 戦闘時の味方パーティへ適用する.
  TACTICS_BATTLE_SPECIAL_APPLY_BATTLE_ENEMY_PARTY = 3; // 戦闘時の相手パーティへ適用する.
  TACTICS_BATTLE_SPECIAL_APPLY_CASTLE_BREAK = 4; // キャッスルブレイク処理へ適用する.
}
```

### TacticsBattleSpecialTrigger

戦闘時特殊効果の発動条件を表す.

```proto
enum TacticsBattleSpecialTrigger {
  TACTICS_BATTLE_SPECIAL_TRIGGER_NONE = 0; // 追加の発動条件を持たない.
  TACTICS_BATTLE_SPECIAL_TRIGGER_BATTLE = 1; // 戦闘時に発動する.
  TACTICS_BATTLE_SPECIAL_TRIGGER_ENEMY_ANNIHILATED = 2; // 敵全滅時に発動する.
  TACTICS_BATTLE_SPECIAL_TRIGGER_CASTLE_BREAK = 3; // キャッスルブレイク時に発動する.
  TACTICS_BATTLE_SPECIAL_TRIGGER_ASSAULT_CASTLE_BREAK = 4; // 強襲キャッスルブレイク時に発動する.
  TACTICS_BATTLE_SPECIAL_TRIGGER_INTERCEPTION = 5; // 迎撃（被弾）時に発動する.
}
```

### FormationConditionID

`FormationConditionID`はフォーメーション位置の補正適用条件を表す.

```proto
enum FormationConditionID {
  FORMATION_CONDITION_NONE = 0; // 属性条件なし.
  FORMATION_CONDITION_SLASH_ONLY = 1; // 斬属性キャラクターのみ条件一致.
  FORMATION_CONDITION_PIERCE_ONLY = 2; // 突属性キャラクターのみ条件一致.
  FORMATION_CONDITION_STRIKE_ONLY = 3; // 打属性キャラクターのみ条件一致.
  FORMATION_CONDITION_RANGED_ONLY = 4; // 遠属性キャラクターのみ条件一致.
}
```

### AbilityConditionID

`AbilityConditionID`はアビリティの発動条件を表す.

```proto
enum AbilityConditionID {
  ABILITY_CONDITION_BATTLE_START = 0; // 戦闘開始時に条件成立.
  ABILITY_CONDITION_INCAPACITATED = 1; // 戦闘不能時に条件成立.
  ABILITY_CONDITION_NORMAL_ATTACK = 2; // 通常攻撃時に条件成立.
  ABILITY_CONDITION_EVERY_N_TURNS = 3; // 指定ターン間隔ごとに条件成立.
  ABILITY_CONDITION_ATTACKED = 4; // 被攻撃時に条件成立.
  ABILITY_CONDITION_HP_AT_OR_BELOW_THRESHOLD = 5; // 指定HP閾値以下で条件成立.
  ABILITY_CONDITION_CASTLE_BREAK = 6; // キャッスルブレイク時に条件成立.
}
```

`ABILITY_CONDITION_EVERY_N_TURNS`および`ABILITY_CONDITION_HP_AT_OR_BELOW_THRESHOLD`の具体値は, 加工済みアビリティマスターデータの`AbilityMasterData.activation_condition.condition_value`で保持する.

### TacticsTarget

タクティクス効果対象を表す.

```proto
enum TacticsTarget {
  TACTICS_TARGET_SELF_PARTY = 0; // 使用プレイヤー自身のパーティを対象とする.
  TACTICS_TARGET_OPPONENT_PARTY = 1; // 出撃後に戦闘へ入った時点の対戦相手パーティを対象とする. 使用時点で特定Playerへ固定しない.
  TACTICS_TARGET_ALLY_GUILD = 2; // 味方騎士団を対象とする.
  TACTICS_TARGET_ENEMY_GUILD = 3; // 敵騎士団を対象とする.
}
```

### TacticsEndType

タクティクス効果の終了方式を表す.

```proto
enum TacticsEndType {
  TACTICS_END_TYPE_DURATION = 0; // 指定時間の経過で終了する.
  TACTICS_END_TYPE_COUNT = 1; // 指定イベントの発生回数を消費し終えると終了する.
  TACTICS_END_TYPE_ON_ACTIVATION = 2; // 発動時の1回のみ適用して終了する.
}
```

### TacticsCountConsumeTrigger

`TACTICS_END_TYPE_COUNT`で残り回数を1消費するイベントを表す.

```proto
enum TacticsCountConsumeTrigger {
  TACTICS_COUNT_CONSUME_TRIGGER_CASTLE_BREAK = 0; // キャッスルブレイク発生時に1回消費する.
  TACTICS_COUNT_CONSUME_TRIGGER_ANNIHILATION = 1; // 殲滅発生時に1回消費する.
  TACTICS_COUNT_CONSUME_TRIGGER_ANNIHILATION_ALL_ENEMIES = 2; // 殲滅で相手を全滅させた場合に1回消費する.
  TACTICS_COUNT_CONSUME_TRIGGER_SORTIE = 3; // 出撃時に1回消費する.
}
```

* `TACTICS_END_TYPE_DURATION`は`DurationSeconds`を使用する.
* `TACTICS_END_TYPE_COUNT`は`effect_count`と`TacticsCountConsumeTrigger`を使用する.
* `TACTICS_END_TYPE_ON_ACTIVATION`は発動時の1回のみ効果を適用し, 継続状態を保持しない.

### GuildBattleStartTime

騎士団戦の固定開始時刻をJSTで表す.

```proto
enum GuildBattleStartTime {
  GUILD_BATTLE_START_1130 = 0; // 昼時間帯11:30開始.
  GUILD_BATTLE_START_1215 = 1; // 昼時間帯12:15開始.
  GUILD_BATTLE_START_1300 = 2; // 昼時間帯13:00開始.
  GUILD_BATTLE_START_2100 = 3; // 夜時間帯21:00開始.
  GUILD_BATTLE_START_2200 = 4; // 夜時間帯22:00開始.
  GUILD_BATTLE_START_2300 = 5; // 夜時間帯23:00開始.
}
```

### ApiErrorCode

PublicAPIの共通エラーコード. 現行仕様で判明している失敗条件のみを定義する.

```proto
enum ApiErrorCode {
  API_ERROR_UNSPECIFIED = 0; // 未分類のAPIエラー.
  API_ERROR_INVALID_TOKEN = 1; // 旧Startup Token方式で使用していた予約済みエラー. 現行仕様では使用しない.
  API_ERROR_INVALID_ACCESS_TOKEN = 2; // AccessTokenが不正.
  API_ERROR_INVALID_USER_NAME = 3; // UserNameが不正.
  API_ERROR_INVALID_PLAYER_ID = 4; // PlayerIDが不正.
  API_ERROR_INVALID_SESSION = 5; // 旧SessionID PublicAPI方式で使用していた予約済みエラー. 現行仕様では使用しない.
  API_ERROR_NO_OPPONENT_AVAILABLE = 6; // 対戦可能な相手が存在しない.
  API_ERROR_GUILD_BATTLE_JOIN_NOT_ALLOWED = 7; // 騎士団戦への参加条件を満たさない.
  API_ERROR_GUILD_BATTLE_PARTY_UPDATE_NOT_ALLOWED = 8; // 騎士団戦編成を変更できない.
  API_ERROR_GUILD_BATTLE_SORTIE_NOT_ALLOWED = 9; // 出撃条件を満たさない.
  API_ERROR_TACTICS_NOT_AVAILABLE = 10; // タクティクスを使用できない.
  API_ERROR_ITEM_NOT_AVAILABLE = 11; // アイテムを使用できない.
  API_ERROR_HEAL_NOT_AVAILABLE = 12; // 治療を開始できない.
  API_ERROR_HEAL_CANCEL_NOT_ALLOWED = 13; // 治療をキャンセルできない.
  API_ERROR_HEAL_COMPLETE_NOT_ALLOWED = 14; // 治療を完了できない.
  API_ERROR_REVIVE_NOT_AVAILABLE = 15; // 復活を開始できない.
  API_ERROR_REVIVE_CANCEL_NOT_ALLOWED = 16; // 復活をキャンセルできない.
  API_ERROR_REVIVE_COMPLETE_NOT_ALLOWED = 17; // 復活を完了できない.
  API_ERROR_INVALID_GUILD_BATTLE_SEQUENCE = 18; // 騎士団戦RequestSequenceが不正.
  API_ERROR_GUILD_FULL = 19; // 騎士団の所属上限に到達している.
  API_ERROR_GUILD_MEMBERSHIP_CHANGE_NOT_ALLOWED = 20; // 騎士団加入・脱退が禁止されている.
  API_ERROR_INVALID_PARTY = 21; // 編成制約を満たしていない.
  API_ERROR_RATE_LIMIT_EXCEEDED = 22; // PublicAPIのレート制限を超過した.
  API_ERROR_INVALID_GUILD_NAME = 23; // GuildNameがUTF-8・最大10文字・空文字不可の制約を満たさない.
  API_ERROR_CLIENT_VERSION_MISMATCH = 24; // ClientVersionがGameServerの要求Versionと一致しない.
  API_ERROR_GUILD_LEADERSHIP_CHANGE_NOT_ALLOWED = 25; // 団長以外が団長・副団長変更を要求した.
  API_ERROR_INVALID_CREDENTIALS = 26; // LoginID不存在またはPassword不一致.
  API_ERROR_INVALID_LOGIN_ID = 27; // LoginIDが不正.
  API_ERROR_INVALID_PASSWORD = 28; // Passwordが不正.
  API_ERROR_LOGIN_ID_ALREADY_EXISTS = 29; // LoginIDが既に登録済み.
  API_ERROR_INVALID_REFRESH_TOKEN = 30; // RefreshTokenが不正または期限切れ.
  API_ERROR_GAME_SERVER_UNAVAILABLE = 31; // 対象騎士団戦を所有するGameServerへ到達できない.
  API_ERROR_DISCORD_AUTHORIZATION_REQUIRED = 32; // 現在の構成でDiscord追加認可が必須だがDiscordAuthorizationTokenが指定されていない.
  API_ERROR_INVALID_DISCORD_AUTHORIZATION_TOKEN = 33; // DiscordAuthorizationTokenが不正または期限切れ.
  API_ERROR_GUILD_JOIN_APPLICATION_NOT_FOUND = 34; // 指定された未承認加入申請が存在しない.
  API_ERROR_GUILD_JOIN_APPROVAL_NOT_ALLOWED = 35; // 加入申請の承認権限を持たないPlayerが承認を要求した.
  API_ERROR_GUILD_INVITATION_NOT_ALLOWED = 36; // 団長・副団長以外が招待を送信した.
  API_ERROR_GUILD_INVITATION_NOT_FOUND = 37; // 指定Player向けの未承諾招待が存在しない.
  API_ERROR_INVALID_GUILD_LEADERSHIP_TARGET = 38; // 団長・副団長候補が対象Guild所属ではない, または団長と副団長が同一PlayerIDである.
  API_ERROR_GUILD_LEADER_MOVE_NOT_ALLOWED = 39; // 団長以外のメンバーが存在する騎士団の団長が加入申請または招待によって別Guildへ移動しようとした.
}
```

### Rarity

```proto
enum Rarity {
  RARITY_N = 0; // Nレアリティ.
  RARITY_R = 1; // Rレアリティ.
  RARITY_SR = 2; // SRレアリティ.
  RARITY_SSR = 3; // SSRレアリティ.
  RARITY_UR = 4; // URレアリティ.
}
```

### CharacterAttribute

```proto
enum CharacterAttribute {
  CHARACTER_ATTRIBUTE_SLASH = 0; // 斬属性.
  CHARACTER_ATTRIBUTE_PIERCE = 1; // 突属性.
  CHARACTER_ATTRIBUTE_STRIKE = 2; // 打属性.
  CHARACTER_ATTRIBUTE_RANGED = 3; // 遠属性.
}
```

### SpeedRank

```proto
enum SpeedRank {
  SPEED_RANK_SS9 = 0; // 速度ランクSS9.
  SPEED_RANK_SS8 = 1; // 速度ランクSS8.
  SPEED_RANK_SS7 = 2; // 速度ランクSS7.
  SPEED_RANK_SS6 = 3; // 速度ランクSS6.
  SPEED_RANK_SS5 = 4; // 速度ランクSS5.
  SPEED_RANK_SS4 = 5; // 速度ランクSS4.
  SPEED_RANK_SS3 = 6; // 速度ランクSS3.
  SPEED_RANK_SS2 = 7; // 速度ランクSS2.
  SPEED_RANK_SS1 = 8; // 速度ランクSS1.
  SPEED_RANK_SS_PLUS = 9; // 速度ランクSS+.
  SPEED_RANK_SS = 10; // 速度ランクSS.
  SPEED_RANK_SS_MINUS = 11; // 速度ランクSS-.
  SPEED_RANK_S_PLUS = 12; // 速度ランクS+.
  SPEED_RANK_S = 13; // 速度ランクS.
  SPEED_RANK_S_MINUS = 14; // 速度ランクS-.
  SPEED_RANK_A_PLUS = 15; // 速度ランクA+.
  SPEED_RANK_A = 16; // 速度ランクA.
  SPEED_RANK_A_MINUS = 17; // 速度ランクA-.
  SPEED_RANK_B_PLUS = 18; // 速度ランクB+.
  SPEED_RANK_B = 19; // 速度ランクB.
  SPEED_RANK_B_MINUS = 20; // 速度ランクB-.
  SPEED_RANK_C_PLUS = 21; // 速度ランクC+.
  SPEED_RANK_C = 22; // 速度ランクC.
  SPEED_RANK_C_MINUS = 23; // 速度ランクC-.
  SPEED_RANK_D_PLUS = 24; // 速度ランクD+.
  SPEED_RANK_D = 25; // 速度ランクD.
  SPEED_RANK_D_MINUS = 26; // 速度ランクD-.
  SPEED_RANK_E_PLUS = 27; // 速度ランクE+.
  SPEED_RANK_E = 28; // 速度ランクE.
  SPEED_RANK_E_MINUS = 29; // 速度ランクE-.
  SPEED_RANK_F_PLUS = 30; // 速度ランクF+.
  SPEED_RANK_F = 31; // 速度ランクF.
  SPEED_RANK_F_MINUS = 32; // 速度ランクF-.
}
```

### BuffDebuffState

`BuffDebuffState`は戦闘中キャラクターのバフ・デバフ付与状態を表す. スキルおよびアビリティによるバフ・デバフだけを対象とし, フォーメーションおよびタクティクスの補正は含めない.

```proto
enum BuffDebuffState {
  BUFF_DEBUFF_STATE_NONE = 0; // バフもデバフも付与されていない.
  BUFF_DEBUFF_STATE_BUFF = 1; // バフだけが付与されている.
  BUFF_DEBUFF_STATE_DEBUFF = 2; // デバフだけが付与されている.
  BUFF_DEBUFF_STATE_BUFF_DEBUFF = 3; // バフとデバフの両方が付与されている.
}
```

### PartyRank

`PartyRank`はHP, 攻撃, 防御の各ランクおよび最終的なパーティランクで使用する33段階のランクを表す. 値と算出規則は「[パーティランク](../specification/party_rank.md)」を参照する.

```proto
enum PartyRank {
  PARTY_RANK_SS9 = 0; // パーティランクSS9.
  PARTY_RANK_SS8 = 1; // パーティランクSS8.
  PARTY_RANK_SS7 = 2; // パーティランクSS7.
  PARTY_RANK_SS6 = 3; // パーティランクSS6.
  PARTY_RANK_SS5 = 4; // パーティランクSS5.
  PARTY_RANK_SS4 = 5; // パーティランクSS4.
  PARTY_RANK_SS3 = 6; // パーティランクSS3.
  PARTY_RANK_SS2 = 7; // パーティランクSS2.
  PARTY_RANK_SS1 = 8; // パーティランクSS1.
  PARTY_RANK_SS_PLUS = 9; // パーティランクSS+.
  PARTY_RANK_SS = 10; // パーティランクSS.
  PARTY_RANK_SS_MINUS = 11; // パーティランクSS-.
  PARTY_RANK_S_PLUS = 12; // パーティランクS+.
  PARTY_RANK_S = 13; // パーティランクS.
  PARTY_RANK_S_MINUS = 14; // パーティランクS-.
  PARTY_RANK_A_PLUS = 15; // パーティランクA+.
  PARTY_RANK_A = 16; // パーティランクA.
  PARTY_RANK_A_MINUS = 17; // パーティランクA-.
  PARTY_RANK_B_PLUS = 18; // パーティランクB+.
  PARTY_RANK_B = 19; // パーティランクB.
  PARTY_RANK_B_MINUS = 20; // パーティランクB-.
  PARTY_RANK_C_PLUS = 21; // パーティランクC+.
  PARTY_RANK_C = 22; // パーティランクC.
  PARTY_RANK_C_MINUS = 23; // パーティランクC-.
  PARTY_RANK_D_PLUS = 24; // パーティランクD+.
  PARTY_RANK_D = 25; // パーティランクD.
  PARTY_RANK_D_MINUS = 26; // パーティランクD-.
  PARTY_RANK_E_PLUS = 27; // パーティランクE+.
  PARTY_RANK_E = 28; // パーティランクE.
  PARTY_RANK_E_MINUS = 29; // パーティランクE-.
  PARTY_RANK_F_PLUS = 30; // パーティランクF+.
  PARTY_RANK_F = 31; // パーティランクF.
  PARTY_RANK_F_MINUS = 32; // パーティランクF-.
}
```

## 共通データ構造型

Protocol Buffersでは以下を使用する.
論理型の範囲制約は上記の型定義に従う.
加工済みマスターデータの構造は「[マスターデータ](master_data.md)」を正とする.

```proto
syntax = "proto3";

message Player {
  uint64 id = 1; // プレイヤーID. 論理型PlayerID.
  string name = 2; // プレイヤー名. 論理型UserName.
  uint64 guild_id = 3; // 現在所属している騎士団ID. 論理型GuildID.
}

message PartyCharacterStatus {
  uint32 id = 1; // キャラクターID. 論理型CharacterID.
  float max_hp = 2; // 従者補正適用後の編成時最大HP. 現在HPは保持しない. 論理型Float32.
  float attack = 3; // 従者補正適用後の編成時攻撃力. 論理型Float32.
  float defense = 4; // 従者補正適用後の編成時防御力. 論理型Float32.
  SpeedRank speed = 5; // 編成時の速度ランク. Enum数値を速度レベルとして平均計算に使用する. 従者による速度補正は存在しない.
}

message BuffDebuffEffectState {
  float attack_buff = 1; // スキル・アビリティによる攻撃バフ補正値の合計. 論理型CorrectionValue.
  float attack_debuff = 2; // スキル・アビリティによる攻撃デバフ補正値の合計. 論理型CorrectionValue.
  float defense_buff = 3; // スキル・アビリティによる防御バフ補正値の合計. 論理型CorrectionValue.
  float defense_debuff = 4; // スキル・アビリティによる防御デバフ補正値の合計. 論理型CorrectionValue.
}

message StatusAbnormalityState {
  StatusAbnormalityID status_id = 1; // 現在付与されている状態異常ID.
  uint32 elapsed_turns = 2; // 状態異常付与ターンを1として数える経過ターン数. 同一状態異常の再付与時は1へ戻す.
  uint32 poison_cycle_turns = 3; // 毒ダメージの3ターン周期を管理する経過カウント. 毒以外では0. 毒再付与時はリセットしない.
}

message SkillBattleState {
  uint32 skill_id = 1; // 戦闘で使用するメインスキルID. 論理型SkillID.
  uint32 activation_count = 2; // 当該戦闘中にこのSkillIDが発動した累計回数. 論理型Count.
}

message AbilityBattleState {
  uint32 ability_id = 1; // Abilityスロットに設定されたアビリティID. 論理型AbilityID.
  uint32 activation_count = 2; // 当該戦闘中にこのAbilityIDが発動した累計回数. 論理型Count.
  bool activated_this_turn = 3; // 現在ターン内でこのAbilityIDがすでに発動済みの場合true. ターン開始時にfalseへ戻す.
}

message CharacterBattle {
  uint32 id = 1; // キャラクターID. 論理型CharacterID.
  CharacterAttribute attribute = 2; // キャラクター属性.
  HitPoints hp = 3; // 戦闘中の最大HPと現在HP.
  float attack = 4; // 従者等の補正適用後の戦闘計算用攻撃力. 論理型Float32.
  float defense = 5; // 従者等の補正適用後の戦闘計算用防御力. 論理型Float32.
  SpeedRank speed = 6; // 戦闘で使用する速度ランク.
  uint32 bp = 7; // キャラクターBP.wire上はuint32, 論理型BP.
  SkillBattleState skill_state = 8; // 戦闘中のメインスキルIDと累計発動回数.
  repeated uint32 tactics_ids = 9; // 戦闘で使用可能なタクティクスID一覧. 各要素は論理型TacticsID.
  repeated AbilityBattleState ability_states = 10; // Abilityスロット順の戦闘中アビリティ状態一覧. AbilityIDごとに累計発動回数とターン内発動済み状態を保持する.
  uint64 owner_player_id = 11; // このキャラクターを編成しているプレイヤーID. 同順位抽選の初期順序決定に使用する. 論理型PlayerID.
  BuffDebuffState buff_debuff_state = 12; // スキル・アビリティによる現在のバフ・デバフ付与状態.
  BuffDebuffEffectState buff_debuff_effect = 13; // スキル・アビリティによる現在の攻撃・防御バフ/デバフ実値.
  repeated StatusAbnormalityState status_abnormalities = 14; // 現在付与されている状態異常の実行時状態一覧. 複数状態異常を同時に保持できる.
}

message HitPoints {
  float max_hp = 1; // 戦闘計算用最大HP. 論理型Float32.
  float current_hp = 2; // 戦闘計算用現在HP. 論理型Float32.
}

message TacticsEffect {
  uint32 available_uses = 1; // 当該タクティクスを使用できる残り回数. 論理型Count.
  uint32 tp_cost = 2; // 当該タクティクスの使用に必要なTP.wire上はuint32, 論理型TP.
}

message TacticsBattleState {
  uint32 available_uses = 1; // 騎士団戦中に残っているタクティクス使用可能回数. 論理型Count.
  uint32 tp_cost = 2; // タクティクス使用時に消費するTP.wire上はuint32, 論理型TP.
}

message TacticsBattleSpecialParameters {
  float attack = 1; // 攻撃力補正値. 論理型CorrectionValue.
  float defense = 2; // 防御力補正値. 論理型CorrectionValue.
  float speed = 3; // 速度補正値. 論理型CorrectionValue.
  float skill_activation_rate = 4; // スキル発動率補正値. 論理型CorrectionValue.
  float max_tp = 5; // 最大TP補正値. 論理型CorrectionValue.
  float battle_score = 6; // バトルで獲得する騎士団戦スコア補正値. 論理型CorrectionValue.
  float guild_battle_score = 7; // 騎士団戦で獲得するスコア全般の補正値. 論理型CorrectionValue.
  float castle_break_score = 8; // キャッスルブレイク獲得スコア補正値. 論理型CorrectionValue.
  float assault_castle_break_rate = 9; // 強襲CB発生率補正値. 論理型CorrectionValue.
  float assault_castle_break_score = 10; // 強襲CB時獲得スコア補正値. 論理型CorrectionValue.
  float hate = 11; // ヘイト補正値. 論理型CorrectionValue.
  sint32 castle_level = 12; // 城Lv補正値. 正値は上昇, 負値は低下.
  uint32 bp_recovery = 13; // 敵全滅等の発動条件成立時に回復するBP固定値.
  uint32 tp_recovery = 14; // 発動条件成立時に回復するTP固定値.
  float attack_count_score = 15; // 攻撃回数に応じたバトル獲得スコア増加に使用する補正値. 論理型CorrectionValue.
  float castle_break_score_limit = 16; // キリ番キャッスルブレイクのスコア上限増加値. 論理型CorrectionValue.
  float hp_recovery_value = 17; // 生存キャラクターHP回復で使用する効果値. 具体的な回復式は別途仕様で定義する. 論理型CorrectionValue.
  float revive_rate = 18; // 戦闘不能キャラクター復帰判定で使用する発動確率. 論理型Rate.
  float attack_target_rate = 19; // 攻撃対象として選択される確率への補正値. HIDE / PROVOKEで使用する. 論理型CorrectionValue.
}

message TacticsBattleSpecialData {
  TacticsBattleSpecialType special_type = 1; // 特殊効果系列.
  TacticsBattleSpecialParameters parameters = 2; // special_typeの具体効果で使用する各数値パラメータ.
  TacticsBattleSpecialApplyTarget apply_target = 3; // 効果を適用する箇所.
  TacticsBattleSpecialTrigger trigger = 4; // 効果を発動する条件.
}

message TacticsHpRecoveryData {
  TacticsHpRecoveryType recovery_type = 1; // HP回復方式.
  float recovery_rate = 2; // HP1以上回復方式で対象最大HPへ乗算する割合. HP0全回復方式では1.0として扱う. 論理型Rate.
}

message TacticsActiveEffectState {
  TacticsEffectID effect_id = 1; // 継続中の効果種別.
  TacticsTarget target = 2; // 継続中の効果対象. OPPONENT_PARTYは出撃ごとにその時点の対戦相手パーティへ再Bindする.
  float effect_value = 3; // スカラー値で表現する効果の現在値. 論理型CorrectionValue.
  uint64 expires_at = 4; // DURATION型の絶対終了時刻. UNIX epochからの経過マイクロ秒. 論理型GameServerTime. DURATION以外では0.
  uint32 remaining_count = 5; // 残り効果回数. 論理型Count.
  TacticsBattleSpecialData battle_special = 6; // effect_idがBATTLE_SPECIALの場合に保持する特殊効果データ.
  TacticsCountConsumeTrigger count_consume_trigger = 7; // COUNT型効果の残り回数を消費するイベント. COUNT以外では参照しない.
  TacticsEndType end_type = 8; // 継続中効果の終了方式.
  bool erase_consumed = 9; // ERASEが最初の通常攻撃ダメージを0にする効果をすでに消費した場合true. ERASE以外ではfalse.
}

```

`PartyCharacterStatus`は編成時専用の状態とし, 現在HPを保持しない. `max_hp` / `attack` / `defense`には従者補正だけを適用した値を保持する. パーティランク算出ではこの構造を使用する.
`SkillBattleState`および`AbilityBattleState`は戦闘中だけ使用する実行時状態とし, Databaseへ永続化しない. `AbilityBattleState`の発動済み管理はAbilityID単位で行い, Effect単位では共有しない.
`CharacterBattle` の `hp` / `attack` / `defense` は従者等の補正適用後に戦闘計算で使用する値であるため, 戦闘仕様に従い `Float32` とする. プレイヤーへ表示する際の丸めは各仕様書の表示規則に従う. `buff_debuff_state`は`buff_debuff_effect`に含まれるスキル・アビリティ由来のバフ・デバフ有無から更新する. `status_abnormalities`は状態異常ごとの経過ターンおよび毒周期カウントを保持する.
`TacticsActiveEffectState`は騎士団戦中にGameServerが保持する継続中タクティクス効果の状態とする. DURATION型は`expires_at`へ絶対終了時刻を保持し, 現在時刻が`expires_at`以上の場合に無効化して削除する. 残り秒数を定期減算しない. COUNT型では`count_consume_trigger`を使用し, `end_type`に従って終了判定する. `TacticsBattleSpecialData`は`TACTICS_EFFECT_BATTLE_SPECIAL`の具体的な特殊効果を表す.

## 疑似乱数内部型

* PRNGのstateは`u64`とする.
* seedは`Seed`とする.
* `next_u32`の戻り値は`u32`とする.
* `next_bounded`のboundおよび戻り値は`u32`とする.
* 確率計算で使用する浮動小数点数は`Float32`とする.

### TacticsCategory

```proto
enum TacticsCategory {
  TACTICS_CATEGORY_BUFF = 0; // バフ分類.
  TACTICS_CATEGORY_DEBUFF = 1; // デバフ分類.
  TACTICS_CATEGORY_SCORE_UP = 2; // スコアアップ分類.
  TACTICS_CATEGORY_HEAL = 3; // 回復分類.
  TACTICS_CATEGORY_SPECIAL = 4; // 特殊分類.
}
```

### ItemType

```proto
enum ItemType {
  ITEM_TYPE_BP_50_RECOVERY = 0; // BPを50回復するアイテム.
  ITEM_TYPE_BP_FULL_RECOVERY = 1; // BPを最大まで回復するアイテム.
}
```

### GuildBattleStatus

```proto
enum GuildBattleStatus {
  GUILD_BATTLE_STATUS_SCHEDULED = 0; // 開戦予定.
  GUILD_BATTLE_STATUS_IN_PROGRESS = 1; // 開戦中かつ新規処理受付中.
  GUILD_BATTLE_STATUS_RESOLVING = 2; // 30:00到達後, 新規受付停止済みで既存キュー解決中.
  GUILD_BATTLE_STATUS_COMPLETED = 3; // 騎士団戦終了.
  GUILD_BATTLE_STATUS_PRELOAD_FAILED = 4; // 開戦前Preload失敗により当該対戦を取りやめ, 運営判断待ちとなっている.
}
```

### GuildBattleResult

```proto
enum GuildBattleResult {
  GUILD_BATTLE_RESULT_WIN = 0; // 勝利.
  GUILD_BATTLE_RESULT_LOSE = 1; // 敗北.
  GUILD_BATTLE_RESULT_DRAW = 2; // 引き分け.
}
```

### GuildBattleReplayProcessType

```proto
enum GuildBattleReplayProcessType {
  GUILD_BATTLE_REPLAY_CREATE = 0; // 騎士団戦作成・初期スナップショット.
  GUILD_BATTLE_REPLAY_SORTIE = 1; // 出撃処理.
  GUILD_BATTLE_REPLAY_TACTICS = 2; // タクティクス使用処理.
  GUILD_BATTLE_REPLAY_HEAL = 3; // 治療処理.
  GUILD_BATTLE_REPLAY_REVIVE = 4; // 復活処理.
  GUILD_BATTLE_REPLAY_ITEM = 5; // アイテム使用処理.
  GUILD_BATTLE_REPLAY_JOIN = 6; // 騎士団戦参加処理. RequestSequence生成による本体PRNG消費を再現する.
}
```

この数値をリプレイログの処理種別として使用する.

### HealState

```proto
enum HealState {
  HEAL_STATE_NONE = 0; // 治療状態ではない.
  HEAL_STATE_HEALING = 1; // 治療中.
  HEAL_STATE_COMPLETED = 2; // 治療完了待ち.
}
```

### ReviveState

```proto
enum ReviveState {
  REVIVE_STATE_ANNIHILATED = 0; // 全滅状態.
  REVIVE_STATE_REVIVING = 1; // 復活処理中.
  REVIVE_STATE_COMPLETED = 2; // 復活完了待ち.
  REVIVE_STATE_NORMAL = 3; // 通常状態.
}
```

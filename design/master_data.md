# マスターデータ

本書では元データの完全な構造は定義せず, ゲームで使用するために加工済みのマスターデータ構造のみを定義する.
加工済みマスターデータの正規表現はProtocol Buffersとし, 各フィールドの論理型・列挙型は「[型定義](types.md)」を参照する.
本リポジトリにはマスターデータの実データを配置しない. 実データが存在しないこと自体は未定義仕様として扱わない.
画像やUVデータはClientが保持し, Serverでは保管しない.

## 加工済みマスターデータ構造

```proto
syntax = "proto3";

message ProcessedMasterData {
  repeated CharacterMasterData characters = 1; // 加工済みキャラクターマスターデータ一覧.
  repeated SkillMasterData skills = 2; // 加工済みスキルマスターデータ一覧.
  repeated AbilityMasterData abilities = 3; // 加工済みアビリティマスターデータ一覧.
  repeated TacticsMasterData tactics = 4; // 加工済みタクティクスマスターデータ一覧.
  repeated FormationMasterData formations = 5; // 加工済みフォーメーションマスターデータ一覧.
  repeated ItemMasterData items = 6; // 加工済みアイテムマスターデータ一覧.
  repeated GuildMasterData guilds = 7; // 加工済み騎士団データ一覧.
}

message CharacterMasterData {
  uint32 id = 1; // キャラクターID. 論理型CharacterID.
  string title = 2; // キャラクターの肩書. 論理型Title.
  string name = 3; // キャラクター名. 論理型Name.
  Rarity rarity = 4; // キャラクターのレアリティ.
  CharacterAttribute attribute = 5; // キャラクター属性.
  uint32 hp = 6; // 基礎HP. 論理型HP.
  uint32 attack = 7; // 基礎攻撃力.wire上はuint32, 論理型Attack.
  uint32 defense = 8; // 基礎防御力.wire上はuint32, 論理型Defense.
  SpeedRank speed = 9; // 基礎速度ランク.
  uint32 bp = 10; // キャラクターBP.0～99.wire上はuint32, 論理型BP.
  repeated uint32 skill_ids = 11; // 所持スキルID一覧. 最低1件. 各要素は論理型SkillID.
  repeated uint32 ability_ids = 12; // 所持アビリティID一覧. 各要素は論理型AbilityID.
  repeated uint32 tactics_ids = 13; // 所持タクティクスID一覧.0～2件. 各要素は論理型TacticsID.
}

message SkillTargetConditionData {
  SkillTargetConditionID condition_id = 1; // 単体スキルの優先対象条件.
  StatusAbnormalityID status_abnormality_id = 2; // condition_idがSTATUS_ABNORMALITYの場合に対象とする状態異常ID.
}

message SkillRandomAttackData {
  uint32 hit_count = 1; // ランダム攻撃の攻撃回数. 論理型Count.
}

message SkillStatusAbnormalityData {
  StatusAbnormalityID status_abnormality_id = 1; // 付与する状態異常ID.
  float application_rate = 2; // 状態異常付与率. 論理型Rate.
}

message SkillStatCorrectionData {
  SkillStatTarget stat_target = 1; // バフ・デバフで補正する能力.
}

message SkillHealData {
  bool can_heal_incapacitated = 1; // HP0のキャラクターを回復対象にできる場合true.
  float heal_rate = 2; // 対象の最大HPに対する回復割合. 論理型Rate.
}

message SkillMasterData {
  uint32 id = 1; // スキルID. 論理型SkillID.
  string name = 2; // スキル名. 論理型Name.
  string description = 3; // スキル効果説明文. 論理型Description.
  SkillEffectID effect_id = 4; // スキル効果種別.
  float activation_rate = 5; // 基本スキル発動率0.2へ加算する値. 論理型Rate.
  float correction_value = 6; // 攻撃威力やバフ・デバフ量等, 共有体に含まれないスキル効果の基本補正値. 論理型CorrectionValue. 回復スキルでは使用しない.
  SkillTargetRange target_range = 7; // スキルの対象範囲.
  SkillTargetConditionData target_condition = 8; // 単体対象で使用する優先対象条件.

  oneof effect_data {
    SkillRandomAttackData random_attack = 9; // ランダム攻撃スキルで使用する固有データ.
    SkillStatusAbnormalityData status_abnormality = 10; // 状態異常付与スキルで使用する固有データ.
    SkillStatCorrectionData stat_correction = 11; // バフ・デバフスキルで使用する固有データ.
    SkillHealData heal = 12; // 回復スキルで使用する固有データ.
  }
}

message AbilityCorrectionData {
  float correction_value = 1; // 単一の補正値で表現するアビリティ効果値. 論理型CorrectionValue.
}

message AbilityStatusAbnormalityData {
  StatusAbnormalityID status = 1; // 状態異常攻撃で付与する状態異常ID.
}

message AbilityConditionCorrectionData {
  uint32 condition_value = 1; // 発動条件に必要な具体値. 論理型ConditionValue.
  float correction_value = 2; // 当該アビリティの効果補正値. 論理型CorrectionValue.
}

message AbilityStatCorrectionData {
  float attack = 1; // 攻撃に対する補正値. 論理型CorrectionValue.
  float defense = 2; // 防御に対する補正値. 論理型CorrectionValue.
}

message AbilityMasterData {
  uint32 id = 1; // アビリティID. 論理型AbilityID.
  string name = 2; // アビリティ名. 論理型Name.
  string description = 3; // アビリティ効果説明文. 論理型Description.
  AbilityEffectID effect_id = 4; // アビリティ効果種別.effect_dataの解釈を決定する.
  AbilityConditionID condition_id = 5; // アビリティ発動条件.
  reserved 6; // 旧condition_value. 共有体へ移行したため再利用しない.
  repeated CharacterAttribute allowed_attributes = 7; // セット可能なキャラクター属性一覧.
  float activation_rate = 8; // アビリティ発動率. 論理型Rate.
  uint32 max_activation_count = 9; // 1戦闘中に発動可能な最大回数. 論理型Count.
  reserved 10; // 旧correction_value. 共有体へ移行したため再利用しない.

  oneof effect_data {
    AbilityCorrectionData correction = 11; // 単一の補正値を持つ効果で使用する.
    AbilityStatusAbnormalityData status_abnormality = 12; // 状態異常攻撃で使用する.
    AbilityConditionCorrectionData condition_correction = 13; // 条件値と補正値の両方を必要とする効果で使用する.
    AbilityStatCorrectionData stat_correction = 14; // 攻撃・防御を同時または個別に補正するバフ・デバフで使用する.
  }
}

`AbilityMasterData.effect_data`は`AbilityEffectID`に応じて使用する共有体フィールドを切り替える.

* `ABILITY_EFFECT_BUFF` / `ABILITY_EFFECT_DEBUFF`: `stat_correction`を使用する.
* `ABILITY_EFFECT_STATUS_ABNORMALITY_ATTACK`: `status_abnormality`を使用する.
* 単一補正値だけを必要とする効果: `correction`を使用する.
* 発動条件の具体値と効果補正値の両方を同時に保持する必要がある効果: `condition_correction`を使用する.
* `condition_value`と`correction_value`は`AbilityMasterData`直下には保持しない.


message TacticsStageEffectData {
  uint32 stage = 1; // 効果上昇量を適用する段階. 論理型Stage.
  TacticsEffectID effect_id = 2; // 段階効果の対象となる効果種別.
  TacticsTarget target = 3; // 段階効果の対象.
  float increase_value = 4; // スカラー値で表現する効果の当該段階上昇量. 論理型CorrectionValue.
  TacticsBattleSpecialParameters battle_special_increase = 5; // effect_idがBATTLE_SPECIALの場合の攻撃・防御・速度の段階上昇量.
}

message TacticsEffectData {
  TacticsEffectID effect_id = 1; // タクティクス効果種別.
  TacticsTarget target = 2; // タクティクス効果対象.
  float effect_value = 3; // スカラー値で表現する基本効果値. 論理型CorrectionValue. BP回復では固定回復値として使用する.
  TacticsHpRecoveryData hp_recovery = 4; // effect_idがHP_RECOVERYの場合のHP回復方式・割合.
  TacticsBattleSpecialData battle_special = 5; // effect_idがBATTLE_SPECIALの場合の特殊効果定義.
}

message TacticsMasterData {
  uint32 id = 1; // タクティクスID. 論理型TacticsID.
  string name = 2; // タクティクス名. 論理型Name.
  string description = 3; // タクティクス効果説明文. 論理型Description.
  TacticsCategory category = 4; // タクティクス分類. Client側のアイコン分類にも使用する.
  uint32 tp_cost = 5; // 使用時に消費するTP.wire上はuint32, 論理型TP.
  repeated TacticsStageEffectData stage_effects = 6; // 段階ごとの効果上昇量一覧.
  TacticsEndType end_type = 7; // 効果終了方式.
  uint32 duration_seconds = 8; // end_typeがDURATIONの場合の効果時間. 論理型DurationSeconds.
  uint32 effect_count = 9; // end_typeがCOUNTの場合の効果回数. 論理型Count.
  TacticsCountConsumeTrigger count_consume_trigger = 10; // end_typeがCOUNTの場合に残り回数を消費するイベント.
  repeated TacticsEffectData effects = 11; // タクティクスが持つ基本効果一覧.
}

message FormationPositionMasterData {
  uint32 position_no = 1; // フォーメーション内の位置番号.wire上はuint32, 論理型FormationSlotID.
  FormationConditionID condition_id = 2; // この位置の補正を適用する属性条件.
  float attack_correction = 3; // 攻撃力補正値. 論理型CorrectionValue.
  float defense_correction = 4; // 防御力補正値. 論理型CorrectionValue.
  float speed_correction = 5; // 速度補正値. 論理型CorrectionValue.
  float skill_correction = 6; // スキル発動率補正値. 論理型CorrectionValue.
}

message FormationMasterData {
  uint32 id = 1; // フォーメーションID. 論理型FormationID.
  string name = 2; // フォーメーション名. 論理型Name.
  string description = 3; // フォーメーション効果説明文. 論理型Description.
  repeated FormationPositionMasterData positions = 4; // 使用マスと各位置の条件・補正値一覧.
}

message ItemMasterData {
  uint32 id = 1; // アイテムID. 論理型ItemID.
  string name = 2; // アイテム名. 論理型Name.
  string description = 3; // アイテム効果説明文. 論理型Description.
  ItemType type = 4; // アイテム種別.
  float effect_value = 5; // アイテム効果値. 論理型CorrectionValue.
}
message GuildMasterData {
  uint64 id = 1; // 騎士団ID. 論理型GuildID.
  string name = 2; // 騎士団名. 論理型Name.
  uint64 leader_player_id = 3; // 団長PlayerID. 論理型PlayerID.
  repeated uint64 member_player_ids = 4; // 所属メンバーのPlayerID一覧. 各要素は論理型PlayerID.
  uint32 castle_level = 5; // 城レベル.
  uint32 armory_level = 6; // 武器庫レベル.
  uint32 food_storage_level = 7; // 食糧庫レベル.
  uint32 blacksmith_level = 8; // 鍛冶屋レベル.
  uint32 tactics_room_level = 9; // 兵法所レベル.
  uint32 tavern_level = 10; // 酒場レベル.
  GuildBattleStartTime daytime_start_time = 11; // 昼時間帯の騎士団戦開始時刻.11:30 / 12:15 / 13:00のいずれか.
  GuildBattleStartTime nighttime_start_time = 12; // 夜時間帯の騎士団戦開始時刻.21:00 / 22:00 / 23:00のいずれか.
}

```

## スキル固有データの共有体

`SkillMasterData.effect_data`はProtocol Buffersの`oneof`を使用する.
以下のデータは同一スキルについて同時には保持せず, 該当する効果・対象範囲に対応する1種類だけを保持する.

* ランダム攻撃回数: `SkillRandomAttackData`
* 状態異常ID・状態異常付与率: `SkillStatusAbnormalityData`
* バフ・デバフ対象能力: `SkillStatCorrectionData`
* HP0回復可否・回復割合: `SkillHealData`

単体対象条件が`SKILL_TARGET_CONDITION_STATUS_ABNORMALITY`の場合は, `SkillTargetConditionData.status_abnormality_id`から対象とする具体的な状態異常を特定する.
回復量はすべて割合で保持し, `SkillHealData.heal_rate`は対象の最大HPに対する割合とする. `SkillEffectID=SKILL_EFFECT_HEAL`では`heal_rate`を使用し, `SkillMasterData.correction_value`は使用しない.

## アビリティ固有データの共有体

`AbilityMasterData.effect_data`はProtocol Buffersの`oneof`を使用する. `AbilityEffectID`と必要な効果パラメータに応じて1種類だけを保持する. 旧`condition_value`および旧`correction_value`は直下フィールドとして保持しない.

## タクティクス特殊データ

* `TACTICS_EFFECT_BP_RECOVERY`では`TacticsEffectData.effect_value`を固定BP回復値として扱い, 最大BPを超えて回復しない.
* `TACTICS_EFFECT_HP_RECOVERY`では`TacticsEffectData.hp_recovery`を使用する. HP0全回復型はHP0のみ, 割合回復型はHP1以上のみを対象とし, いずれも最大HPを超えない.
* `TACTICS_EFFECT_BATTLE_SPECIAL`では`TacticsEffectData.battle_special`を使用し, 特殊効果系列, 攻撃・防御・速度パラメータ, 適用箇所, 発動条件を保持する.

## 効果値の合算規則

* スキル, アビリティ, タクティクス, フォーメーションの効果値は加工済みマスターデータに保持する.
* 同一系列の効果値はすべて加算する.
* スキルは同じ`SkillEffectID`系列, アビリティは同じ`AbilityEffectID`系列, タクティクスは同じ`TacticsEffectID`系列として扱う.
* `SkillEffectID`, `AbilityEffectID`, `TacticsEffectID`は相互に別の列挙型であり, 異なる種別間で列挙値を共有しない.

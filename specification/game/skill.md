# スキル仕様

## 概要

スキルはキャラクターが保有し,戦闘中のキャラクター行動時に発動し得る要素である.


## 分類

主に以下分類される. この分類はマスターデータの`SkillEffectID`で表現する.

* バフ.
* デバフ.
* 状態異常付与.
* 回復.
* 攻撃.



## マスターデータ表現

スキル固有の挙動は「[マスターデータ](../../design/game/master_data.md)」のスキル構造で保持する.

* 対象陣営は`SkillTargetSide`で保持し, 味方パーティ・敵パーティ・発動者自身のいずれかを明示する.
* 対象範囲は`SkillTargetRange`で保持する.
* 攻撃スキルのダメージ値形式は`SkillDamageValueType`で保持し, 割合ダメージと固定ダメージを識別する.
* 単体対象の優先条件は`SkillTargetConditionID`で保持する.
  - `SKILL_TARGET_CONDITION_NONE`: 条件なし.
  - `SKILL_TARGET_CONDITION_BUFFED`: `BuffDebuffState`が`BUFF`または`BUFF_DEBUFF`の対象を優先する.
  - `SKILL_TARGET_CONDITION_DEBUFFED`: `BuffDebuffState`が`DEBUFF`または`BUFF_DEBUFF`の対象を優先する.
  - `SKILL_TARGET_CONDITION_HP_25_PERCENT_OR_BELOW`: 現在HPが最大HPの25%以下の対象を優先する.
  - `SKILL_TARGET_CONDITION_STATUS_ABNORMALITY`: 指定状態異常を優先し, 具体的な状態異常は`StatusAbnormalityID`で特定する.
* ランダム攻撃の回数は`SkillMasterData.effect_data.random_attack.hit_count`で保持する.
* 状態異常付与スキルは`StatusAbnormalityID`と状態異常付与率を保持する.
* バフ・デバフは`SkillStatTarget`で攻撃または防御のどちらへ作用するかを保持する.
* 回復スキルは回復割合とHP0回復可否を保持する. 回復割合は対象の最大HPに対する割合とする.
* 1戦闘中の最大発動回数は`SkillMasterData.max_activation_count`で保持する. `Count`型の最大値`u32::MAX`は回数無制限を表す. 戦闘中の累計発動回数は`SkillBattleState.activation_count`として保持する.

## バフ・デバフ状態

戦闘中キャラクターは「[型定義](../../design/shared/types.md)」の`BuffDebuffState`を保持し, 以下4状態のいずれかとする.

* `BUFF_DEBUFF_STATE_NONE`: バフもデバフも付与されていない状態.
* `BUFF_DEBUFF_STATE_BUFF`: バフだけが付与されている状態.
* `BUFF_DEBUFF_STATE_DEBUFF`: デバフだけが付与されている状態.
* `BUFF_DEBUFF_STATE_BUFF_DEBUFF`: バフとデバフの両方が付与されている状態.

この状態の判定対象はスキルおよびアビリティによるバフ・デバフだけとする.
フォーメーション補正およびタクティクス補正は`BuffDebuffState`へ影響しない.
スキルの`SKILL_TARGET_CONDITION_BUFFED`および`SKILL_TARGET_CONDITION_DEBUFFED`はこの状態を用いて判定する.

## 発動条件

* 「[沈黙状態](status_abnormality.md#沈黙)」ではない.
  - 詳細は[状態異常](status_abnormality.md)を参照する.

## スキル発動率

発動判定には「[疑似乱数](../../design/game/pseudorandom.md)」の「[確率計算](../../design/game/pseudorandom.md#確率計算)」を使用する.

### 騎士団戦

```
基本スキル発動率 = 0.2
スキル補正 = マスターデータの発動率. 基本スキル発動率0.2への加算値
フォーメーション補正 = Databaseの`FORMATION_POSITION`に定義されたスキル発動率のフォーメーション補正値合計
タクティクス補正 = 適用対象となる`TACTICS_EFFECT_BATTLE_SPECIAL`の`parameters.skill_activation_rate`を「[タクティクス](tactics.md#効果値の統合規則)」に従って系列統合した値. 対象効果がない場合は0

スキル発動率 = 基本スキル発動率 + スキル補正 + フォーメーション補正 + タクティクス補正
スキル発動率 = clamp(スキル発動率, 0, 1)
```

### アリーナ

```
基本スキル発動率 = 0.2
スキル補正 = マスターデータの発動率. 基本スキル発動率0.2への加算値
フォーメーション補正 = Databaseの`FORMATION_POSITION`に定義されたスキル発動率のフォーメーション補正値合計

スキル発動率 = 基本スキル発動率 + スキル補正 + フォーメーション補正
スキル発動率 = clamp(スキル発動率, 0, 1)
```

## 発動回数制限

* バフおよびデバフスキルの発動回数は, 1「[戦闘](battle.md)」につき1回とする.

## 威力

### ダメージ値形式

攻撃スキルは`SkillMasterData.damage_value_type`でダメージ値形式を識別する.

* `SKILL_DAMAGE_VALUE_TYPE_RATE`: `SkillMasterData.correction_value`を攻撃力へ乗算するスキル補正として使用する.
* `SKILL_DAMAGE_VALUE_TYPE_FIXED`: `SkillMasterData.correction_value`を固定ダメージ値として使用する. 攻撃力・防御力による補正および`1.0～1.03`のダメージ乱数は適用しない. `ABILITY_EFFECT_FIXED_DAMAGE_INCREASE`が発動した場合はこの固定ダメージ値へ当該アビリティの`correction_value`を加算する.

`SKILL_DAMAGE_VALUE_TYPE_RATE`のダメージ上限はない. `SKILL_DAMAGE_VALUE_TYPE_FIXED`は後述の固定ダメージ規則に従い99,999を上限とする.

### 割合ダメージ

#### 騎士団戦

詳細は[戦闘](battle.md)の「騎士団戦攻撃者攻撃力」を参照する.

```
スキル補正 = SkillMasterData.correction_value

最小ダメージ = 250
ダメージ = <騎士団戦攻撃者攻撃力> * スキル補正 - <騎士団戦攻撃対象防御力> / 3
ダメージ = ダメージ * 1.0~1.03の乱数(0.0001刻み)
ダメージ = max(ダメージ, 最小ダメージ)
```

#### アリーナ

```
スキル補正 = SkillMasterData.correction_value

最小ダメージ = 250
ダメージ = <アリーナ攻撃者攻撃力> * スキル補正 - <アリーナ攻撃対象防御力> / 3
ダメージ = ダメージ * 1.0~1.03の乱数(0.0001刻み)
ダメージ = max(ダメージ, 最小ダメージ)
```

割合ダメージでは各対象・各HITごとにダメージ乱数を個別に1回取得する. 複数対象攻撃では対象ごとに, 複数HIT攻撃ではHITごとに`1.0～1.03`の乱数を取得し, 同じ乱数値を複数対象・複数HITで共有しない.

### 固定ダメージ

```
固定ダメージ = SkillMasterData.correction_value
固定ダメージ増加 = 発動したABILITY_EFFECT_FIXED_DAMAGE_INCREASEのAbilityMasterData.effect_data.correction.correction_value
ダメージ = 固定ダメージ + 固定ダメージ増加
ダメージ = clamp(ダメージ, 250, 99999)
```

`SKILL_DAMAGE_VALUE_TYPE_FIXED`の`SkillMasterData.correction_value`は250以上99,999以下とする. `ABILITY_EFFECT_FIXED_DAMAGE_INCREASE`適用後も固定ダメージは250以上99,999以下へクランプする.
固定ダメージでは攻撃力・防御力および`1.0～1.03`のダメージ乱数を使用しない.

## 効果

* バフ, デバフスキルの効果値は加算する.
* 回復時は最大HPを超えて回復しない.
* `SkillHealData.can_heal_incapacitated=false`の回復スキルはHP1以上のキャラクターだけを対象候補とし, HP0のキャラクターを対象候補へ含めない.
* `SkillHealData.can_heal_incapacitated=true`の回復スキルはHP0のキャラクターだけを対象候補とし, HP1以上のキャラクターを対象候補へ含めない. HP0から回復させるスキルはこの方式だけを使用する.
* HP0/HP1以上による候補絞り込みは`SkillTargetSide`で陣営候補を作成した直後, `SkillTargetRange`および単体優先条件を評価する前に行う.
* 回復量はすべて割合計算とし, マスターデータの回復割合を対象の最大HPへ乗算して求める.


## 効果時間

* バフおよびデバフの効果時間は永続とする.
* 状態異常は「[状態異常](status_abnormality.md)」を参照する.

## 発動回数

バフおよびデバフスキルは`max_activation_count = 1`とする.
それ以外は`max_activation_count = u32::MAX`とし, 回数無制限として扱う.

## 対象

### 対象陣営

`SkillTargetSide`で対象候補を確定する.

* `SKILL_TARGET_SIDE_ALLY`: 味方パーティを対象候補とする.
* `SKILL_TARGET_SIDE_ENEMY`: 敵パーティを対象候補とする.
* `SKILL_TARGET_SIDE_SELF`: 発動キャラクター自身だけを対象候補とする.

対象候補を確定した後, `SkillTargetRange`に従って対象範囲を決定する.

### SkillEffectID × SkillTargetRange

許可する組み合わせは以下だけとする. 表にない組み合わせはマスターデータ不正とする.

| SkillEffectID | 許可するSkillTargetRange |
|---|---|
| `SKILL_EFFECT_BUFF` | `SKILL_TARGET_RANGE_ALL`, `SKILL_TARGET_RANGE_SINGLE` |
| `SKILL_EFFECT_DEBUFF` | `SKILL_TARGET_RANGE_ALL`, `SKILL_TARGET_RANGE_SINGLE` |
| `SKILL_EFFECT_STATUS_ABNORMALITY` | `SKILL_TARGET_RANGE_ALL`, `SKILL_TARGET_RANGE_SINGLE` |
| `SKILL_EFFECT_HEAL` | `SKILL_TARGET_RANGE_ALL`, `SKILL_TARGET_RANGE_SINGLE` |
| `SKILL_EFFECT_ATTACK` | `SKILL_TARGET_RANGE_ALL`, `SKILL_TARGET_RANGE_RANDOM`, `SKILL_TARGET_RANGE_VERTICAL_COLUMN`, `SKILL_TARGET_RANGE_HORIZONTAL_ROW`, `SKILL_TARGET_RANGE_X_SHAPE`, `SKILL_TARGET_RANGE_CROSS_SHAPE` |

### 対象範囲

バフ, デバフ, 状態異常, 回復スキルの対象範囲は以下に分かれる.

* 全体.
* 単体.
  - 条件を満たす対象を優先する.
  - 条件付きスキルで条件一致対象が0体の場合は全対象を候補とする.
  - 条件がない場合, 条件一致対象が0体の場合, または候補が複数いる場合は「[疑似乱数](../../design/game/pseudorandom.md)」の「抽選」で1体を決定する.
  - 抽選候補リストはフォーメーション内部番号の小さい順に並べる.

攻撃スキルの攻撃範囲は以下に分かれる.

* 全体攻撃.
* ランダム攻撃.
  - 回数はスキルごとに定義する.
  - 攻撃対象全体をフォーメーション内部番号の小さい順で1つの候補リストへ追加し, その要素数を`bound`として各HITごとに「[疑似乱数](../../design/game/pseudorandom.md)」の`next_bounded(bound)`を1回呼び出す.
  - `next_bounded`が返したインデックスで候補リストへアクセスし, その対象へ当該HITを適用する.
  - 各HITで候補リストを作り直したり対象を削除したりしないため, 同じ敵に複数回当たる可能性がある.
    - このスキルによってHPが0になった場合でも抽選対象に残る.
* 縦1列攻撃.
  - 最もヒットする列が選択される.
	- 複数候補がある場合は攻撃キャラクターと同じ列が優先される.
	  - そうでない場合は左から順に優先する.
* 横1列攻撃.
  - 命中対象数が最も多い横1列（行）を選択する.
  - 同数の候補が複数ある場合は手前の横1列（行）から順に優先する.
* X字攻撃.
* 十字攻撃.

### X字攻撃範囲

|   | 左列 | 中列 | 右列 |
| :---: | :---: | :---: | :---: |
| 奥 | 〇 |  | 〇 |
| 中央 |  | 〇 |  |
| 手前 | 〇 |  | 〇 |

### 十字攻撃範囲

|   | 左列 | 中列 | 右列 |
| :---: | :---: | :---: | :---: |
| 奥 |  | 〇 |  |
| 中央 | 〇 | 〇 | 〇 |
| 手前 |  | 〇 |  |

## アビリティ効果との関係

スキル発動時は`ABILITY_EFFECT_AVOIDANCE`, `ABILITY_EFFECT_AVOIDANCE_COUNTER`, `ABILITY_EFFECT_COUNTER`, `ABILITY_EFFECT_COVER`, `ABILITY_EFFECT_DRAW_AGGRO`, `ABILITY_EFFECT_PURSUIT`を無視する. これらの回避, 回避＆反撃, 反撃, かばう, ひきつけ, 追撃処理は通常攻撃にだけ適用する. `ABILITY_EFFECT_AVOIDANCE`は`status_abnormality.status`の設定有無を問わず無視するため, 状態異常Skillに対して状態異常回避Abilityも発動しない.
`ABILITY_EFFECT_FIXED_DAMAGE_INCREASE`は固定ダメージスキル専用の加算効果として例外的にスキルダメージへ適用する.

## 成功率

* 状態異常以外の効果は必中とする.
* 状態異常系の成功率はスキルごとに異なる.
  - 「[疑似乱数](../../design/game/pseudorandom.md)」の「[確率計算](../../design/game/pseudorandom.md#確率計算)」を使用する.






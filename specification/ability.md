# アビリティ仕様

* 属性に応じてセットできるアビリティが決まる.
  - セット可能属性はアビリティのマスターデータから取得する.

アビリティの効果はマスターデータの`AbilityEffectID`で表現し, 以下のいずれかとする.

* バフ.
* デバフ.
* 回避.
* 反撃.
* 追撃.
* 回避無効化.
* 反撃無効化.
* 状態異常攻撃.
* ダメージ増加.
* 固定ダメージ増加.
* 回復.
* かばう.
* ひきつけ.

バフおよびデバフで影響するのは攻撃, 防御のみ.


## 発動条件

発動条件はマスターデータの`AbilityMasterData.activation_condition.condition_id`に保持する`AbilityConditionID`で表現する. 発動条件に具体値が必要なアビリティでは, `AbilityMasterData.activation_condition.condition_value`へ保持する. 発動条件データと`effect_data`は独立して保持するため, 発動条件の具体値と効果固有値を同時に保持できる.

* 「[戦闘](battle.md)」開始時に発動する.
* 戦闘不能時に発動する.
* 通常攻撃時に発動する.
* 一定ターン毎に発動する.
* 被攻撃時に発動する.
* 一定HP以下で発動する.
* 「[キャッスルブレイク](guild_battle.md#キャッスルブレイク)」時に発動する.

`ABILITY_CONDITION_HP_AT_OR_BELOW_THRESHOLD`の`condition_value`は最大HPに対する割合を整数のパーセント値で保持する. 例えば`25`は最大HPの25%を表す.

各アビリティは1ターンに1回しか発動しない.
1ターン1アビリティ発動までという意味ではない.
1ターン内で複数回アビリティ発動条件を満たしても最初の1度しか発動しない.

## 同時成立時の処理順

同一キャラクターで同一タイミングに複数アビリティの発動条件が成立した場合はAbilityスロット番号の小さい順に処理する.

複数キャラクターのアビリティが同一タイミングに成立した場合は以下の順に処理する.

1. 戦闘計算上の速度が速いキャラクターを先に処理する.
2. 同一速度の場合はフォーメーション内部値が小さいキャラクターを先に処理する.
3. 同一速度かつフォーメーション内部値も同一の場合は「[疑似乱数](../design/pseudorandom.md)」の「抽選」で処理順を決定する.
   * 抽選対象リストの初期順序は, 各キャラクターを編成しているプレイヤーのPlayerID昇順とする.

キャラクター間の順序を決定した後, 各キャラクター内ではAbilityスロット番号の小さい順に処理する.

## 発動確率

アビリティによって変わる.

「[疑似乱数](../design/pseudorandom.md)」の「[確率計算](../design/pseudorandom.md#確率計算)」によって判定.


## 発動回数

基本的に1戦闘につき1度のみだが, アビリティによって変わる.
最大発動回数はアビリティのマスターデータに保持する.


## 効果

効果種別は`AbilityEffectID`に従う. 効果固有値は「[マスターデータ](../design/master_data.md)」の`AbilityMasterData.effect_data`共有体から取得する. `AbilityEffectID`と共有体フィールドの対応は「[マスターデータ](../design/master_data.md)」を正とする. `ABILITY_EFFECT_AVOIDANCE`は`status_abnormality.status`が未設定の場合に攻撃回避, 設定されている場合に指定状態異常の回避を表す. `ABILITY_EFFECT_STATUS_ABNORMALITY_ATTACK`では`status_abnormality.status`を必須とし, 付与する状態異常を表す.

`ABILITY_EFFECT_COUNTER`, `ABILITY_EFFECT_AVOIDANCE_DISABLE`, `ABILITY_EFFECT_COUNTER_DISABLE`, `ABILITY_EFFECT_COVER`, `ABILITY_EFFECT_DRAW_AGGRO`, `ABILITY_EFFECT_PURSUIT`は効果固有の数値パラメータを使用しない. 加工済みマスターデータでは`effect_data.no_parameter`を設定する.

### 追撃

ダメージ計算式は通常攻撃と同じ.


### 反撃

ダメージ計算式は通常攻撃と同じ.

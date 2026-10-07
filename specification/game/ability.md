# アビリティ仕様

* 属性に応じてセットできるアビリティが決まる.
  - セット可能属性はアビリティのマスターデータから取得する.
* 同一キャラクターに同一アビリティを複数セットしない.
* 同一キャラクターに同一系統のアビリティを複数セットしない.
  - アビリティの系統は`AbilityEffectID`で識別する.

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
アビリティによるバフおよびデバフは戦闘終了まで永続し, スキルによるバフおよびデバフと同じ`BuffDebuffEffectState`へ統合して保持する.


## 発動条件

発動条件はマスターデータの`AbilityMasterData.activation_condition.condition_id`に保持する`AbilityConditionID`で表現する. 発動条件に具体値が必要なアビリティでは, `AbilityMasterData.activation_condition.condition_value`へ保持する. 発動条件データと`effect_data`は独立して保持するため, 発動条件の具体値と効果固有値を同時に保持できる.

* 「[戦闘](battle.md)」開始時に発動する.
* 戦闘不能時に発動する.
* 通常攻撃時に発動する.
* 一定ターン毎に発動する.
  - `AbilityActivationConditionData.turn_timing`で, ターン開始・行動前・行動後・ターン終了のいずれで評価するかを指定する.
* 被攻撃時に発動する.
* 一定HP以下で発動する.
* 「[キャッスルブレイク](guild_battle.md#キャッスルブレイク)」時に発動する.

`ABILITY_CONDITION_EVERY_N_TURNS`の`condition_value`は発動間隔となるターン数を表し, `turn_timing`に設定したタイミングで現在ターン数が指定間隔の倍数の場合に条件成立とする.
`ABILITY_CONDITION_HP_AT_OR_BELOW_THRESHOLD`の`condition_value`は最大HPに対する割合を整数のパーセント値で保持する. 例えば`25`は最大HPの25%を表す.

各アビリティは1ターンに1回しか発動しない. 発動済み判定はEffect単位ではなくAbilityID単位で行う.
1ターン1アビリティ発動までという意味ではない.
1ターン内で複数回同一AbilityIDの発動条件を満たしても最初の1度しか発動しない.

## 同時成立時の処理順

同一キャラクターで同一タイミングに複数アビリティの発動条件が成立した場合はAbilityスロット番号の小さい順に処理する.

複数キャラクターのアビリティが同一タイミングに成立した場合は以下の順に処理する.

1. 戦闘計算上の速度が速いキャラクターを先に処理する.
2. 同一速度の場合はフォーメーション内部値が小さいキャラクターを先に処理する.
3. 同一速度かつフォーメーション内部値も同一の場合は「[疑似乱数](../../design/game/pseudorandom.md)」の「抽選」で処理順を決定する.
   * 抽選対象リストの初期順序は, 各キャラクターを編成しているプレイヤーのPlayerID昇順とする.

キャラクター間の順序を決定した後, 各キャラクター内ではAbilityスロット番号の小さい順に処理する.

## 発動確率

アビリティによって変わる. 発動確率には`AbilityMasterData.activation_rate`を使用する. 戦闘フロー上の回避率, 状態異常回避率, 回避無効化率, 状態異常付与率, 追撃率, 反撃率, 反撃無効化率は, 対応するアビリティの`AbilityMasterData.activation_rate`を意味する.

「[疑似乱数](../../design/game/pseudorandom.md)」の「[確率計算](../../design/game/pseudorandom.md#確率計算)」によって判定.


## 発動回数

基本的に1戦闘につき1度のみだが, アビリティによって変わる.
最大発動回数はアビリティのマスターデータに保持する. 戦闘中の累計発動回数およびターン内発動済み状態は`AbilityBattleState`としてAbilityID単位で保持する.


## 効果

効果種別は`AbilityEffectID`に従う. 効果固有値は「[マスターデータ](../../design/game/master_data.md)」の`AbilityMasterData.effect_data`共有体から取得する. `AbilityEffectID`と共有体フィールドの対応は「[マスターデータ](../../design/game/master_data.md)」を正とする. `ABILITY_EFFECT_AVOIDANCE`は`status_abnormality.status`が未設定の場合に攻撃回避, 設定されている場合に指定状態異常の回避を表す. `ABILITY_EFFECT_STATUS_ABNORMALITY_ATTACK`では`status_abnormality.status`を必須とし, 付与する状態異常を表す.

`ABILITY_EFFECT_COUNTER`, `ABILITY_EFFECT_AVOIDANCE_DISABLE`, `ABILITY_EFFECT_COUNTER_DISABLE`, `ABILITY_EFFECT_COVER`, `ABILITY_EFFECT_DRAW_AGGRO`, `ABILITY_EFFECT_PURSUIT`は効果固有の数値パラメータを使用しない. 加工済みマスターデータでは`effect_data.no_parameter`を設定する.


### ダメージ増加

`ABILITY_EFFECT_DAMAGE_INCREASE`は通常攻撃時だけ適用する. 発動した場合, `AbilityMasterData.effect_data.correction.correction_value`を倍率として通常攻撃ダメージへ乗算する.
通常攻撃の最大ダメージ上限99,999は本効果適用後のダメージへ適用する.
追撃・反撃・スキルダメージには本効果を適用しない.

### 固定ダメージ増加

`ABILITY_EFFECT_FIXED_DAMAGE_INCREASE`は, 発動対象のスキルが固定ダメージとして扱われる場合だけ適用する. 固定ダメージへ`AbilityMasterData.effect_data.correction.correction_value`を固定値として加算する.
現行の「[スキル仕様](skill.md)」には固定ダメージスキルを識別するデータ構造および固定ダメージ値の保持方法が定義されていないため, その定義が追加されるまでは適用対象スキルの判定方法を未確定とする.

### 回復

`ABILITY_EFFECT_HEAL`の具体的な適用対象・回復式・適用位置は未確定とする.

### かばう

`ABILITY_EFFECT_COVER`は攻撃対象リスト取得後に1回判定する. `AbilityMasterData.activation_rate`による発動条件を満たした場合, 取得済み攻撃対象リスト内の各キャラクターには当該攻撃のダメージを反映せず, `ABILITY_EFFECT_COVER`を発動したキャラクターへ代わりにダメージを反映する.

* ダメージ計算に使用する攻撃対象側の値は, かばう前に攻撃対象リストへ含まれていた各キャラクターの値を使用する.
* 攻撃対象リストの要素数と同じ回数だけ個別にダメージ計算し, その各ダメージをかばうキャラクターへ反映する.
* `ABILITY_EFFECT_COVER`を保持する候補キャラクターが複数いる場合は, フォーメーション内部番号の小さい順に候補リストを作成し, 「[疑似乱数](../../design/game/pseudorandom.md)」の「抽選」で1キャラクターだけを選ぶ. 発動確率判定は選ばれた1キャラクターについて行う.

### ひきつけ

`ABILITY_EFFECT_DRAW_AGGRO`は攻撃対象リスト取得前に判定する. `AbilityMasterData.activation_rate`による発動条件を満たした場合, 当該攻撃の攻撃範囲を決定する起点を`ABILITY_EFFECT_DRAW_AGGRO`を発動したキャラクターへ変更してから攻撃対象リストを取得する.
複数キャラクターが同時に`ABILITY_EFFECT_DRAW_AGGRO`の発動候補となった場合に, 最終的な起点をどのキャラクターにするかの競合規則は現時点では未定義とする.

### 追撃

ダメージ計算式は通常攻撃と同じ.


### 反撃

ダメージ計算式は通常攻撃と同じ.

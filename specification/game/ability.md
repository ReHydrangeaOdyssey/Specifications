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
* 防御無視.
* ピンチ対象優先.
* 防御力DOWN対象優先.
* ひきつけ無視.
* 回避＆反撃.
* HP1耐久.
* 戦闘不能味方人数連動の攻撃/防御補正.
* キャッスルブレイクダメージ増加.
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
* HP全快かつ通常攻撃時に発動する.
* 指定HP割合以下の敵が存在する通常攻撃時に発動する.
* 通常攻撃の最終攻撃対象が1体の場合に発動する.
* 攻撃スキル発動時に発動する.
* 自分以外の味方の通常攻撃成立時に発動する.
* 攻撃対象リストに一定HP以下の味方が含まれる場合に発動する.
* 敵通常攻撃の対象リスト取得直前に発動する.
* ダメージによってHP0以下になる直前に発動する.
* 状態異常付与判定を受ける直前に発動する.
* 「[キャッスルブレイク](guild_battle.md#キャッスルブレイク)」時に発動する.

`ABILITY_CONDITION_EVERY_N_TURNS`の`condition_value`は発動間隔となるターン数を表し, `turn_timing`に設定したタイミングで現在ターン数が指定間隔の倍数の場合に条件成立とする.
`ABILITY_CONDITION_HP_AT_OR_BELOW_THRESHOLD`, `ABILITY_CONDITION_ALLY_HP_AT_OR_BELOW_THRESHOLD_ATTACKED`, `ABILITY_CONDITION_TARGET_HP_AT_OR_BELOW_THRESHOLD_NORMAL_ATTACK`の`condition_value`は最大HPに対する割合を整数のパーセント値で保持する. 例えば`25`は最大HPの25%を表す.

各アビリティは1ターンに1回しか発動しない. 発動済み判定はEffect単位ではなくAbilityID単位で行う.
1ターン1アビリティ発動までという意味ではない.
1ターン内で複数回同一AbilityIDの発動条件を満たしても最初の1度しか発動しない.

## AbilityEffectID × AbilityConditionID × AbilityTarget

以下を許可組み合わせの正本とする. 表にない`AbilityEffectID × AbilityConditionID × AbilityTarget`はマスターデータ不正とする. `ALLY_SINGLE` / `ALLY_ALL`の両方を許可する行はマスターデータでどちらか一方を明示する.

| 効果説明 | AbilityEffectID | AbilityConditionID | AbilityTarget | 追加規則 |
|---|---|---|---|---|
| 戦闘の間常に自分の攻撃力をUP | `ABILITY_EFFECT_BUFF` | `ABILITY_CONDITION_BATTLE_START` | `ABILITY_TARGET_SELF` | `stat_correction.attack`を使用 |
| 戦闘の間常に自分の防御力をUP | `ABILITY_EFFECT_BUFF` | `ABILITY_CONDITION_BATTLE_START` | `ABILITY_TARGET_SELF` | `stat_correction.defense`を使用 |
| 戦闘の間常に自分の攻撃力と防御力をUP | `ABILITY_EFFECT_BUFF` | `ABILITY_CONDITION_BATTLE_START` | `ABILITY_TARGET_SELF` | `stat_correction.attack/defense`を使用 |
| ピンチ時に攻撃力をUP | `ABILITY_EFFECT_BUFF` | `ABILITY_CONDITION_HP_AT_OR_BELOW_THRESHOLD` | `ABILITY_TARGET_SELF` | `condition_value`をHP割合閾値として使用 |
| HP全快時に通常攻撃ダメージUP | `ABILITY_EFFECT_DAMAGE_INCREASE` | `ABILITY_CONDITION_HP_FULL_NORMAL_ATTACK` | `ABILITY_TARGET_NONE` | 通常攻撃ダメージへ`correction_value`を倍率適用 |
| 戦闘不能の仲間が多いほど攻撃力UP | `ABILITY_EFFECT_INCAPACITATED_ALLY_COUNT_STAT_CORRECTION` | `ABILITY_CONDITION_BATTLE_START` | `ABILITY_TARGET_SELF` | 現在の戦闘不能味方人数に対応するentry.attackを使用 |
| 戦闘不能の仲間が多いほど防御力UP | `ABILITY_EFFECT_INCAPACITATED_ALLY_COUNT_STAT_CORRECTION` | `ABILITY_CONDITION_BATTLE_START` | `ABILITY_TARGET_SELF` | 現在の戦闘不能味方人数に対応するentry.defenseを使用 |
| 戦闘不能時に味方1体の攻撃力UP | `ABILITY_EFFECT_BUFF` | `ABILITY_CONDITION_INCAPACITATED` | `ABILITY_TARGET_ALLY_SINGLE` | `stat_correction.attack`を使用 |
| 戦闘不能時に味方全体の攻撃力UP | `ABILITY_EFFECT_BUFF` | `ABILITY_CONDITION_INCAPACITATED` | `ABILITY_TARGET_ALLY_ALL` | `stat_correction.attack`を使用 |
| 戦闘不能時に味方1体の防御力UP | `ABILITY_EFFECT_BUFF` | `ABILITY_CONDITION_INCAPACITATED` | `ABILITY_TARGET_ALLY_SINGLE` | `stat_correction.defense`を使用 |
| 戦闘不能時に味方全体の防御力UP | `ABILITY_EFFECT_BUFF` | `ABILITY_CONDITION_INCAPACITATED` | `ABILITY_TARGET_ALLY_ALL` | `stat_correction.defense`を使用 |
| 戦闘不能時に敵1体の攻撃力DOWN | `ABILITY_EFFECT_DEBUFF` | `ABILITY_CONDITION_INCAPACITATED` | `ABILITY_TARGET_ENEMY_SINGLE` | `stat_correction.attack`を使用 |
| 戦闘不能時に敵全体の攻撃力DOWN | `ABILITY_EFFECT_DEBUFF` | `ABILITY_CONDITION_INCAPACITATED` | `ABILITY_TARGET_ENEMY_ALL` | `stat_correction.attack`を使用 |
| 戦闘不能時に敵1体の防御力DOWN | `ABILITY_EFFECT_DEBUFF` | `ABILITY_CONDITION_INCAPACITATED` | `ABILITY_TARGET_ENEMY_SINGLE` | `stat_correction.defense`を使用 |
| 戦闘不能時に敵全体の防御力DOWN | `ABILITY_EFFECT_DEBUFF` | `ABILITY_CONDITION_INCAPACITATED` | `ABILITY_TARGET_ENEMY_ALL` | `stat_correction.defense`を使用 |
| 敵の防御力を無視して攻撃 | `ABILITY_EFFECT_DEFENSE_IGNORE` | `ABILITY_CONDITION_NORMAL_ATTACK` | `ABILITY_TARGET_NONE` | 通常攻撃の対象防御力を0としてダメージ計算 |
| 敵単体への攻撃ダメージが2倍になる | `ABILITY_EFFECT_DAMAGE_INCREASE` | `ABILITY_CONDITION_SINGLE_TARGET_NORMAL_ATTACK` | `ABILITY_TARGET_NONE` | `correction_value=2.0` |
| 味方の攻撃に追撃 | `ABILITY_EFFECT_PURSUIT` | `ABILITY_CONDITION_ALLY_ATTACK` | `ABILITY_TARGET_NONE` | 味方通常攻撃の対象を追撃対象として引き継ぐ |
| ピンチ状態の敵を狙い攻撃 | `ABILITY_EFFECT_TARGET_HP_LOW_PRIORITY` | `ABILITY_CONDITION_TARGET_HP_AT_OR_BELOW_THRESHOLD_NORMAL_ATTACK` | `ABILITY_TARGET_ENEMY_SINGLE` | HP閾値は`condition_value`を使用 |
| 防御力DOWNの敵を狙い攻撃 | `ABILITY_EFFECT_TARGET_DEFENSE_DOWN_PRIORITY` | `ABILITY_CONDITION_NORMAL_ATTACK` | `ABILITY_TARGET_ENEMY_SINGLE` | 防御デバフ状態を優先 |
| 敵の挑発を無視して他に攻撃 | `ABILITY_EFFECT_DRAW_AGGRO_IGNORE` | `ABILITY_CONDITION_NORMAL_ATTACK` | `ABILITY_TARGET_NONE` | `ABILITY_EFFECT_DRAW_AGGRO`による起点変更を無視 |
| 攻撃回避を無効化し攻撃 | `ABILITY_EFFECT_AVOIDANCE_DISABLE` | `ABILITY_CONDITION_NORMAL_ATTACK` | `ABILITY_TARGET_NONE` | 通常攻撃時に適用 |
| カウンターを無効化し攻撃 | `ABILITY_EFFECT_COUNTER_DISABLE` | `ABILITY_CONDITION_NORMAL_ATTACK` | `ABILITY_TARGET_NONE` | 通常攻撃時に適用 |
| 固定ダメージスキルの攻撃力UP | `ABILITY_EFFECT_FIXED_DAMAGE_INCREASE` | `ABILITY_CONDITION_SKILL_ATTACK` | `ABILITY_TARGET_NONE` | FIXED型攻撃スキルだけへ固定値加算 |
| 敵の攻撃を回避 | `ABILITY_EFFECT_AVOIDANCE` | `ABILITY_CONDITION_ATTACKED` | `ABILITY_TARGET_SELF` | `status`未設定 |
| 敵の攻撃をカウンター | `ABILITY_EFFECT_COUNTER` | `ABILITY_CONDITION_ATTACKED` | `ABILITY_TARGET_SELF` | 反撃処理を使用 |
| 敵の攻撃を回避＆カウンター | `ABILITY_EFFECT_AVOIDANCE_COUNTER` | `ABILITY_CONDITION_ATTACKED` | `ABILITY_TARGET_SELF` | 通常攻撃のHP減算前に発動判定し, 成立時は攻撃を回避して反撃する |
| 戦闘不能時にカウンター | `ABILITY_EFFECT_COUNTER` | `ABILITY_CONDITION_INCAPACITATED` | `ABILITY_TARGET_SELF` | 戦闘不能確定時に反撃 |
| ピンチの味方をかばう | `ABILITY_EFFECT_COVER` | `ABILITY_CONDITION_ALLY_HP_AT_OR_BELOW_THRESHOLD_ATTACKED` | `ABILITY_TARGET_ALLY_SINGLE` | `condition_value`を対象味方のHP割合閾値として使用 |
| ダメージを1人で引き受ける | `ABILITY_EFFECT_DRAW_AGGRO` | `ABILITY_CONDITION_ENEMY_NORMAL_ATTACK_TARGETING` | `ABILITY_TARGET_SELF` | 対象リスト取得前のひきつけ処理を使用 |
| 戦闘不能時にHP1で耐える | `ABILITY_EFFECT_SURVIVE_AT_ONE_HP` | `ABILITY_CONDITION_LETHAL_DAMAGE` | `ABILITY_TARGET_SELF` | 発動時は当該ダメージ反映後HPを1とする |
| 攻撃しつつ敵を睡眠状態にする | `ABILITY_EFFECT_STATUS_ABNORMALITY_ATTACK` | `ABILITY_CONDITION_NORMAL_ATTACK` | `ABILITY_TARGET_NONE` | `status=STATUS_ABNORMALITY_COMA` |
| 攻撃しつつ敵を毒状態にする | `ABILITY_EFFECT_STATUS_ABNORMALITY_ATTACK` | `ABILITY_CONDITION_NORMAL_ATTACK` | `ABILITY_TARGET_NONE` | `status=STATUS_ABNORMALITY_POISON` |
| 攻撃しつつ敵を範囲不可状態にする | `ABILITY_EFFECT_STATUS_ABNORMALITY_ATTACK` | `ABILITY_CONDITION_NORMAL_ATTACK` | `ABILITY_TARGET_NONE` | `status=STATUS_ABNORMALITY_RANGE_ATTACK_DISABLED` |
| 攻撃しつつ敵を暗闇状態にする | `ABILITY_EFFECT_STATUS_ABNORMALITY_ATTACK` | `ABILITY_CONDITION_NORMAL_ATTACK` | `ABILITY_TARGET_NONE` | `status=STATUS_ABNORMALITY_BLINDNESS` |
| 沈黙状態になるのを回避 | `ABILITY_EFFECT_AVOIDANCE` | `ABILITY_CONDITION_STATUS_ABNORMALITY_APPLICATION` | `ABILITY_TARGET_SELF` | `status=STATUS_ABNORMALITY_SILENCE` |
| 範囲不可状態になるのを回避 | `ABILITY_EFFECT_AVOIDANCE` | `ABILITY_CONDITION_STATUS_ABNORMALITY_APPLICATION` | `ABILITY_TARGET_SELF` | `status=STATUS_ABNORMALITY_RANGE_ATTACK_DISABLED` |
| 暗闇状態になるのを回避 | `ABILITY_EFFECT_AVOIDANCE` | `ABILITY_CONDITION_STATUS_ABNORMALITY_APPLICATION` | `ABILITY_TARGET_SELF` | `status=STATUS_ABNORMALITY_BLINDNESS` |
| 戦闘不能時に味方のHPを回復 | `ABILITY_EFFECT_HEAL` | `ABILITY_CONDITION_INCAPACITATED` | `ABILITY_TARGET_ALLY_SINGLE`または`ABILITY_TARGET_ALLY_ALL` | 対象方式はMasterDataで明示 |
| 一定時間ごとに自分のHPを回復する | `ABILITY_EFFECT_HEAL` | `ABILITY_CONDITION_EVERY_N_TURNS` | `ABILITY_TARGET_SELF` | `condition_value`と`turn_timing`を使用 |
| 【騎士戦】CB時に自分の攻撃力をUP | `ABILITY_EFFECT_BUFF` | `ABILITY_CONDITION_CASTLE_BREAK` | `ABILITY_TARGET_SELF` | `stat_correction.attack`を使用 |
| 【騎士戦】CB時ダメージ2倍 | `ABILITY_EFFECT_CASTLE_BREAK_DAMAGE_INCREASE` | `ABILITY_CONDITION_CASTLE_BREAK` | `ABILITY_TARGET_NONE` | `correction_value=2.0` |

`ABILITY_EFFECT_INCAPACITATED_ALLY_COUNT_STAT_CORRECTION`は固定の線形式を仮定せず, MasterDataの0～4人それぞれの補正値を直接参照する. 「多いほどUP」を満たすため, 使用する能力値の補正は人数増加に対して単調非減少とする.

`ABILITY_EFFECT_BUFF`, `ABILITY_EFFECT_DEBUFF`, `ABILITY_EFFECT_HEAL`で`AbilityTarget`が対象を直接指定する場合は以下とする.

* `SELF`: 発動キャラクター自身.
* `ALLY_ALL` / `ENEMY_ALL`: 該当陣営のHP1以上の全キャラクター.
* `ALLY_SINGLE` / `ENEMY_SINGLE`: 該当陣営のHP1以上のキャラクターを`FormationSlotID`昇順で候補化し, 複数候補では戦闘の疑似乱数で1体を抽選する.
* 候補が0体の場合は効果対象なしとして終了する. `ABILITY_EFFECT_HEAL`は復活効果ではないためHP0を対象にしない.

`ABILITY_TARGET_NONE`を使用する効果は通常攻撃, スキル, 追撃, 反撃等の既存フローが決定した対象を使用する.

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

`ABILITY_CONDITION_CASTLE_BREAK`は通常戦闘のターン内発動状態とは独立して扱う. キャッスルブレイク1回につき, 選択された各キャラクターの効果種別ごとに最大1度だけ発動判定する. `ABILITY_EFFECT_BUFF`（攻撃力補正）と`ABILITY_EFFECT_CASTLE_BREAK_DAMAGE_INCREASE`（ダメージ補正）は別の効果種別であり, 両方の発動条件が成立した場合はそれぞれ個別に発動する. 一方の発動成立は他方の判定を抑止しない. 判定回数は次のキャッスルブレイクへ引き継がない. 通常戦闘の`AbilityBattleState.activation_count`と`activated_this_turn`をキャッスルブレイク専用判定の共有カウンタとして使用しない.


## 効果

効果種別は`AbilityEffectID`に従う. 効果固有値は「[マスターデータ](../../design/game/master_data.md)」の`AbilityMasterData.effect_data`共有体から取得する. `AbilityEffectID`と共有体フィールドの対応は「[マスターデータ](../../design/game/master_data.md)」を正とする. `ABILITY_EFFECT_AVOIDANCE`は`status_abnormality.status`が未設定の場合に攻撃回避, 設定されている場合に指定状態異常の回避を表す. `ABILITY_EFFECT_STATUS_ABNORMALITY_ATTACK`では`status_abnormality.status`を必須とし, 付与する状態異常を表す.

`ABILITY_EFFECT_COUNTER`, `ABILITY_EFFECT_AVOIDANCE_DISABLE`, `ABILITY_EFFECT_COUNTER_DISABLE`, `ABILITY_EFFECT_COVER`, `ABILITY_EFFECT_DRAW_AGGRO`, `ABILITY_EFFECT_PURSUIT`, `ABILITY_EFFECT_DEFENSE_IGNORE`, `ABILITY_EFFECT_TARGET_HP_LOW_PRIORITY`, `ABILITY_EFFECT_TARGET_DEFENSE_DOWN_PRIORITY`, `ABILITY_EFFECT_DRAW_AGGRO_IGNORE`, `ABILITY_EFFECT_AVOIDANCE_COUNTER`, `ABILITY_EFFECT_SURVIVE_AT_ONE_HP`は効果固有の数値パラメータを使用しない. 加工済みマスターデータでは`effect_data.no_parameter`を設定する.


### 追加戦闘効果

* `ABILITY_EFFECT_DEFENSE_IGNORE`: 通常攻撃のダメージ計算で攻撃対象防御力を0として扱う.
* `ABILITY_EFFECT_TARGET_HP_LOW_PRIORITY`: `condition_value`以下のHP割合の敵を通常攻撃の起点候補として優先する.
* `ABILITY_EFFECT_TARGET_DEFENSE_DOWN_PRIORITY`: 防御デバフ状態の敵を通常攻撃の起点候補として優先する.
* `ABILITY_EFFECT_DRAW_AGGRO_IGNORE`: 当該キャラクターの通常攻撃では敵側`ABILITY_EFFECT_DRAW_AGGRO`による起点変更を適用しない.
* `ABILITY_EFFECT_AVOIDANCE_COUNTER`: 通常攻撃が成立する場合, 通常攻撃ダメージをHPへ反映する前に発動率判定する. 発動した場合は当該通常攻撃を回避し, 反撃処理として攻撃者へのダメージを処理する.
* `ABILITY_EFFECT_SURVIVE_AT_ONE_HP`: ダメージ反映によってHP0以下になる直前に発動判定し, 成立した場合は当該ダメージ反映後HPを1とする.
* `ABILITY_EFFECT_INCAPACITATED_ALLY_COUNT_STAT_CORRECTION`: 現在の戦闘不能味方人数に一致するMasterData entryの攻撃/防御補正を, 攻撃力/防御力算出時に動的に適用する. `BuffDebuffEffectState`へ固定値として取り込まない.
* `ABILITY_EFFECT_CASTLE_BREAK_DAMAGE_INCREASE`: 騎士団戦のキャッスルブレイク時ダメージへ`correction_value`を倍率として適用する. キャッスルブレイクスコア式の`1.0 + アビリティダメージ補正値`には`アビリティダメージ補正値 = correction_value - 1.0`として渡す. 未発動なら補正値0.0とする.
* `ABILITY_CONDITION_CASTLE_BREAK`の`ABILITY_EFFECT_BUFF`: 発動成立したキャラクター自身の`stat_correction.attack`をキャッスルブレイクの攻撃力計算だけへ反映し, 戦闘中の`BuffDebuffEffectState`に追加しない.

### ダメージ増加

`ABILITY_EFFECT_DAMAGE_INCREASE`は通常攻撃時だけ適用する. 発動した場合, `AbilityMasterData.effect_data.correction.correction_value`を倍率として通常攻撃ダメージへ乗算する.
通常攻撃の最大ダメージ上限99,999は本効果適用後のダメージへ適用する.
追撃・反撃・スキルダメージには本効果を適用しない.

### 固定ダメージ増加

`ABILITY_EFFECT_FIXED_DAMAGE_INCREASE`は, 発動対象の攻撃スキルの`SkillMasterData.damage_value_type`が`SKILL_DAMAGE_VALUE_TYPE_FIXED`の場合だけ適用する. 固定ダメージ値として使用する`SkillMasterData.correction_value`へ`AbilityMasterData.effect_data.correction.correction_value`を固定値として加算する.
割合ダメージスキルには本効果を適用しない.

### 回復

`ABILITY_EFFECT_HEAL`の回復量は以下とし, 算出した回復量を対象キャラクターの最大HPで上限クランプする.

```
算出回復量 = 最大HP * (1 + AbilityMasterData.effect_data.correction.correction_value)
回復量 = min(算出回復量, 最大HP)
```

適用対象は`AbilityMasterData.target`を使用する. `ABILITY_CONDITION_EVERY_N_TURNS`の場合は`AbilityActivationConditionData.turn_timing`が示すターン内位置で条件を評価して回復を反映する. `ABILITY_CONDITION_INCAPACITATED`の場合は当該キャラクターの戦闘不能確定時に回復を反映する.

回復後HPは以下とし, 最大HPを超えない.

```
回復後HP = min(現在HP + 回復量, 最大HP)
```

### かばう

`ABILITY_EFFECT_COVER`は攻撃対象リスト取得後に1回判定する. 発動したターンは, 相手の攻撃対象リストに含まれるすべての味方への攻撃を引き受ける. `AbilityMasterData.activation_rate`による発動条件を満たした場合, 取得済み攻撃対象リスト内の各キャラクターには当該攻撃のダメージを反映せず, `ABILITY_EFFECT_COVER`を発動したキャラクターへ代わりにダメージを反映する. 同一ターンの再発動判定は行わない.

* ダメージ計算に使用する攻撃対象側の値は, かばう前に攻撃対象リストへ含まれていた各キャラクターの値を使用する.
* 攻撃対象リストの要素数と同じ回数だけ個別にダメージ計算し, その各ダメージをかばうキャラクターへ反映する.
* `ABILITY_EFFECT_COVER`を保持する候補キャラクターが複数いる場合は, フォーメーション内部番号の小さい順に候補リストを作成し, 「[疑似乱数](../../design/game/pseudorandom.md)」の「抽選」で1キャラクターだけを選ぶ. 発動確率判定は選ばれた1キャラクターについて行う.

### ひきつけ

`ABILITY_EFFECT_DRAW_AGGRO`は攻撃対象リスト取得前に判定する. `AbilityMasterData.activation_rate`による発動条件を満たした場合, 当該攻撃の攻撃範囲を決定する起点を`ABILITY_EFFECT_DRAW_AGGRO`を発動したキャラクターへ変更してから攻撃対象リストを取得する.
複数キャラクターが同時に`ABILITY_EFFECT_DRAW_AGGRO`の発動候補となった場合は, フォーメーション内部番号の小さい順に候補リストを作成し, 「[疑似乱数](../../design/game/pseudorandom.md)」の「抽選」で1キャラクターだけを選ぶ. 発動確率判定は選ばれた1キャラクターについてだけ行い, 不成立の場合に別候補の再抽選・再判定は行わない.

### 追撃

追撃の発動候補は行動キャラクターを除いた, `ABILITY_EFFECT_PURSUIT`を保持する味方キャラクターとする. 候補が複数存在する場合はフォーメーション内部番号の小さい順に並べ, 「[疑似乱数](../../design/game/pseudorandom.md#抽選)」により1キャラクターを抽選する. 発動率は選択したキャラクターの`AbilityMasterData.activation_rate`を使用し, 追撃対象は先行する味方の通常攻撃対象を引き継ぐ.

ダメージ計算式は通常攻撃と同じ.


### 反撃

ダメージ計算式は通常攻撃と同じ.

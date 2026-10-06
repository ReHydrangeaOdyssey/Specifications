# タクティクス

## 概要


* 編成したキャラクターに応じた「[タクティクス](tactics.md)」を「[騎士団戦](guild_battle.md)」中に使用できる.
  - キャラクターごとに固有の「[タクティクス](tactics.md)」を0~2所有している.
* 各「[タクティクス](tactics.md)」は1回の「[騎士団戦](guild_battle.md)」につき使用できる回数に制限がある.
  - 同一「[タクティクス](tactics.md)」の所持数をその「[タクティクス](tactics.md)」の段階とし, 使用回数および効果が上昇する.
    - 段階と同じ回数だけ使用可能とする.
      - 使用回数は最大5回とする.
    - 段階と同じ回数だけ効果が上昇する.
      - 効果の上昇は最大5段階とする.
      - 1段階あたりの効果増加値はタクティクスのマスターデータに`TacticsEffectID`・`TacticsTarget`ごとに保持する.
      - 段階レベル`n`の最終効果値は`基本効果値 + (n - 1) * 増加値`で算出する.
      - BP固定回復は整数値同士, 通常補正・割合は浮動小数点値同士, 戦闘時特殊効果は`TacticsBattleSpecialParameters`の各数値パラメータごとに同じ式を適用する.

以下のいずれかに分類される.

* バフ.
* デバフ.
* スコアアップ.
* 回復.
* 特殊.

## 消費TP

タクティクスによって変わる.

## 効果

タクティクスに応じて以下の効果を得ることができる. 効果種別はマスターデータの`TacticsEffectID`で表現する.
いくつかの効果を複合した効果を得る場合もある.

* 攻撃補正.
* 防御補正.
* 速度補正.
* スコア補正.
* 城防御補正.
* スコアリミット補正.
* 最大TP補正.
* BP回復.
* HP回復.
* 強襲CB率補正.
* 「[戦闘](battle.md)」時特殊効果.
* 相手の出撃時に選ばれる確率補正.



## 回復効果

### BP回復

`TACTICS_EFFECT_BP_RECOVERY`は固定値回復とする. 回復量は`u32`で保持し, 小数値は使用しない. 加工済みマスターでは`TacticsEffectData.effect_data.uint_value`を使用する. 現在BPへ回復量を加算し, 最大BPを超える場合は最大BPへクランプする.

### HP回復

`TACTICS_EFFECT_HP_RECOVERY`は`TacticsHpRecoveryType`で以下2種類を識別する.

* `TACTICS_HP_RECOVERY_INCAPACITATED_FULL`: HP0のキャラクターだけを対象とし, 最大HPの100%まで回復する. HP1以上のキャラクターは対象外.
* `TACTICS_HP_RECOVERY_POSITIVE_HP_RATE`: HP1以上のキャラクターだけを対象とし, タクティクスごとの回復割合を最大HPへ乗算して回復する. HP0のキャラクターは対象外.

どちらの回復方式も最大値を超えて回復しない.
`TACTICS_HP_RECOVERY_POSITIVE_HP_RATE`の段階レベル`n`における最終回復割合は`correction_value + (n - 1) * increase_value`として扱う. `TacticsHpRecoveryData.recovery_rate`を基本`correction_value`, `TacticsStageEffectData.increase_value`を1段階あたりの`increase_value`として使用する.

### 即時回復効果の終了方式

`TACTICS_EFFECT_BP_RECOVERY`および`TACTICS_EFFECT_HP_RECOVERY`を含む即時回復タクティクスは`TACTICS_END_TYPE_ON_ACTIVATION`だけを使用する. `TACTICS_END_TYPE_DURATION`および`TACTICS_END_TYPE_COUNT`は設定しない.

## 戦闘時特殊効果

`TACTICS_EFFECT_BATTLE_SPECIAL`は`TacticsBattleSpecialData`で具体的な特殊効果を保持する.

### 特殊効果系列

`TacticsBattleSpecialType`は「[型定義](../design/types.md)」のEnumを使用する. アサルトオーダー, エースオーダー, シャドウオーダーを独立したTypeとして追加し, フォートレス系列はフォートレスオーダーを表す. 以下で効果が指定されたTypeは表の意味を正本とする. 表に記載していない既存Typeの具体効果は本変更では追加定義しない.

| TacticsBattleSpecialType | 名称 | 効果 |
|---|---|---|
| `TACTICS_BATTLE_SPECIAL_ASSAULT` | アサルト | 戦闘時, 味方パーティの攻撃力を上昇させる. |
| `TACTICS_BATTLE_SPECIAL_ASSAULT_ORDER` | アサルトオーダー | 味方騎士団全体の攻撃力を上昇させる. |
| `TACTICS_BATTLE_SPECIAL_ERASE` | イレイス | 敵から受ける最初の通常攻撃ダメージを0にする. |
| `TACTICS_BATTLE_SPECIAL_ACE` | エース | 戦闘時, 味方パーティの攻撃力・防御力を上昇させる. |
| `TACTICS_BATTLE_SPECIAL_ACE_ORDER` | エースオーダー | 味方騎士団全体の攻撃力・防御力を上昇させる. |
| `TACTICS_BATTLE_SPECIAL_EXTERLIZE` | エクスターライズ | 攻撃回数が多いほどバトル獲得スコアを上昇させる. |
| `TACTICS_BATTLE_SPECIAL_EX_DRIVE` | エクスドライブ | キリ番キャッスルブレイク時の獲得スコアを上昇させる. |
| `TACTICS_BATTLE_SPECIAL_ELYSION` | エリュシオン | 強襲を無効化し, 戦闘時の攻撃力を上昇させ, 回避を発動させる. |
| `TACTICS_BATTLE_SPECIAL_ORACLE` | オラクル | 戦闘時, 味方パーティのスキル発動率を上昇させる. |
| `TACTICS_BATTLE_SPECIAL_ORATORIO` | オラトリオ | 強襲を無効化し, 戦闘時の攻撃力・スキル発動率を上昇させる. |
| `TACTICS_BATTLE_SPECIAL_CURSE` | カーズ | 対戦騎士団全体のスキル発動率を低下させる. |
| `TACTICS_BATTLE_SPECIAL_CASTLE_WEAKNESS` | キャッスルウィークネス | 対戦騎士団の城Lvを低下させる. |
| `TACTICS_BATTLE_SPECIAL_CASTLE_VEIL` | キャッスルヴェール | 味方騎士団の城Lvを上昇させる. |
| `TACTICS_BATTLE_SPECIAL_CLAUSTRUM` | クラウストルム | ヘイトを上昇させ, 迎撃時に攻撃力・防御力を上昇させる. |
| `TACTICS_BATTLE_SPECIAL_GRAVITY_ASSAULT` | グラビティアサルト | 戦闘時, 味方パーティの攻撃力を上昇させ, 速度を低下させる. |
| `TACTICS_BATTLE_SPECIAL_CLEVER_NOTE` | クレバーノート | バトルで敵を全滅させた場合に獲得スコアを上昇させ, TPを回復する. |
| `TACTICS_BATTLE_SPECIAL_JUGGERNAUT` | ジャガーノート/煌 | バトルで敵を全滅させた場合にBPを回復する. |
| `TACTICS_BATTLE_SPECIAL_SHADOW` | シャドウ | バトル時の強襲CB率を上昇させる. |
| `TACTICS_BATTLE_SPECIAL_SHADOW_ORDER` | シャドウオーダー | 味方騎士団全体の強襲CB率を上昇させる. |
| `TACTICS_BATTLE_SPECIAL_STREAM` | ストリーム | 戦闘時, 味方パーティの攻撃力・速度を上昇させる. |
| `TACTICS_BATTLE_SPECIAL_TARANTELLA` | タランテラ | 戦闘時, 味方パーティのスキル発動率・速度を上昇させる. |
| `TACTICS_BATTLE_SPECIAL_DIVINE_ACTIVE` | ディバインアクティブ | 戦闘時, 味方パーティのスキル発動率・最大TPを上昇させる. |
| `TACTICS_BATTLE_SPECIAL_DIVINE_ETOILE` | ディバインエトワール | 戦闘時, 味方パーティの攻撃力・防御力・最大TPを上昇させる. |
| `TACTICS_BATTLE_SPECIAL_DIVINE_THRUST` | ディバインスラスト | 戦闘時, 味方パーティの攻撃力・最大TPを上昇させる. |
| `TACTICS_BATTLE_SPECIAL_DIVINE_RAPID` | ディバインラピッド | 戦闘時, 味方パーティの速度・最大TPを上昇させる. |
| `TACTICS_BATTLE_SPECIAL_BERSERK` | バーサク | 強襲を無効化し, 戦闘時の攻撃力・防御力を上昇させる. |
| `TACTICS_BATTLE_SPECIAL_PANZER` | パンツァー | 強襲を無効化し, 戦闘時の防御力・速度を上昇させる. |
| `TACTICS_BATTLE_SPECIAL_FORCE_OF_PLAY` | フォースオブプレイ | 使用者自身を除く味方騎士団員のTPを小アップとして回復する. 回復量はマスターデータで保持する. |
| `TACTICS_BATTLE_SPECIAL_FORTRESS` | フォートレスオーダー | 味方騎士団全体の防御力を上昇させる. |
| `TACTICS_BATTLE_SPECIAL_BLITZ` | ブリッツ | 強襲CB発生率および強襲CB時の獲得スコアを上昇させる. |
| `TACTICS_BATTLE_SPECIAL_POINT_RISE` | ポイントライズ | 獲得する騎士団戦スコアを小アップさせる. 上昇量はマスターデータで保持する. |
| `TACTICS_BATTLE_SPECIAL_MENACE` | メナス | 対戦騎士団全体の防御力を低下させる. |
| `TACTICS_BATTLE_SPECIAL_RAMPAGE` | ランページ | バトルで獲得する騎士団戦スコアを小アップさせる. 上昇量はマスターデータで保持する. |
| `TACTICS_BATTLE_SPECIAL_RECONTRACT` | リコントラクト | バトルで敵を全滅させた場合にBP・TPを回復する. |
| `TACTICS_BATTLE_SPECIAL_WISE_NOTE` | ワイズノート | バトルで敵を全滅させた場合に獲得スコアを上昇させ, BPを回復する. |

### パラメータ

特殊効果は`TacticsBattleSpecialParameters`としてTypeごとに必要な数値を保持する. 使用しない値は0とする.

* 攻撃力補正.
* 防御力補正.
* 速度補正.
* スキル発動率補正.
* 最大TP補正.
* バトル獲得スコア補正.
* 騎士団戦獲得スコア補正.
* キャッスルブレイク獲得スコア補正.
* 強襲CB率補正.
* 強襲CB獲得スコア補正.
* ヘイト補正.
* 城Lv補正.
* BP固定回復量.
* TP固定回復量.
* 攻撃回数連動スコア補正.

強襲無効, 最初の通常攻撃ダメージ0, 回避発動等の真偽型挙動は`special_type`自体の意味として判定し, 数値パラメータを使用しない.

### 適用箇所

`TacticsBattleSpecialApplyTarget`で以下を識別する.

* 味方騎士団.
* 相手騎士団.
* 戦闘時味方パーティ.
* 戦闘時相手パーティ.
* キャッスルブレイク時.

### 発動条件

`TacticsBattleSpecialTrigger`で以下を識別する.

* なし.
* 戦闘時.
* 敵全滅時.
* キャッスルブレイク時.
* 強襲キャッスルブレイク時.
* 迎撃（被弾）時.

## 効果対象

タクティクスはキャラクター単体を対象とせず, 以下のパーティ単位または騎士団単位を対象とする. 効果対象は`TacticsTarget`で表現する.

* 自分パーティ.
* 相手パーティ.
  - `TACTICS_TARGET_OPPONENT_PARTY`は「出撃」後に戦闘へ入った時点の対戦相手パーティを表す.
  - 継続効果では出撃するたびにその時点の対戦相手パーティへ再Bindして適用する.
  - タクティクス使用時に特定の相手PlayerIDを固定する意味ではない.
* 味方騎士団.
* 敵騎士団.

## 効果時間

タクティクスによって変わる.

終了方式は`TacticsEndType`で識別する.

* `TACTICS_END_TYPE_DURATION`: 特定の時間. 発動時にGameServer時刻から終了時刻を算出して保持し, 現在時刻が終了時刻以上になった時点で無効化して継続状態から削除する. 残り秒数を定期的に減算する方式は使用しない.
* `TACTICS_END_TYPE_COUNT`: 時間制限なしの回数制限. 残り回数の消費イベントは`TacticsCountConsumeTrigger`で識別する.
* `TACTICS_END_TYPE_ON_ACTIVATION`: 発動時の1回に限る.




## 同一タクティクスの重複使用

* 同じタクティクスを複数回使用しても効果時間は延長しない.
* 同一系列の効果値は使用のたびに加算する.
* 回数制限がある効果は, 重複使用しても回数制限自体は増加しない.
* 回数制限がある効果は, マスターデータの`TacticsCountConsumeTrigger`で指定された以下のイベント発生時に残り回数を1回消費する.
  - `TACTICS_COUNT_CONSUME_TRIGGER_CASTLE_BREAK`: キャッスルブレイク時.
  - `TACTICS_COUNT_CONSUME_TRIGGER_ANNIHILATION`: 殲滅時.
  - `TACTICS_COUNT_CONSUME_TRIGGER_ANNIHILATION_ALL_ENEMIES`: 殲滅時に相手を全滅させた場合に消費する.
  - `TACTICS_COUNT_CONSUME_TRIGGER_SORTIE`: 出撃時.
* タクティクスの効果種別は`TacticsEffectID`, 効果対象は`TacticsTarget`で表現する.


## 騎士団戦中の継続効果状態

継続中のタクティクス効果はGameServerが「[型定義](../design/types.md)」の`TacticsActiveEffectState`として保持する. COUNT型では`count_consume_trigger`を保持し, 指定イベント発生時に残り回数を消費する. DURATION/COUNT/ON_ACTIVATIONの識別には`end_type`を保持する. DURATION型は`expires_at`へ絶対終了時刻を保持し, 残り秒数の減算管理は行わない.


## COUNT型効果の適用順

`TACTICS_END_TYPE_COUNT`は消費イベント発生時に当該回の効果を適用した後, `remaining_count`を1減算する. 減算後に0となった場合はその時点で効果を終了する. したがって効果回数が3回の場合は3回すべて効果を適用する.

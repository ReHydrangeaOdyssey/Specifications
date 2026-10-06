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
      - BP固定回復は整数値同士, 通常補正・割合は浮動小数点値同士, 戦闘時特殊効果は攻撃・防御・速度の各パラメータごとに同じ式を適用する.

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

## 戦闘時特殊効果

`TACTICS_EFFECT_BATTLE_SPECIAL`は`TacticsBattleSpecialData`で具体的な特殊効果を保持する.

### 特殊効果系列

`TacticsBattleSpecialType`として, アクセラレーター, アサルト, イレイス, エース, エクスターライズ, エクスドライブ, エッジノート, エリュシオン, エンダーブレイク, オラクル, オラトリオ, カーズ, カウンター, キャッスルウィークネス, キャッスルヴェール, クラウストルム, グラビティアサルト, クレバーノート, ジャガーノート, シャドウ, ステルス, ストリーム, スラッシャー, スロウレート, タランテラ, ディバインアクティブ, ディバインエトワール, ディバインスラスト, ディバインラピッド, バーサク, ハイド, パンツァー, ヒール, ファランクス, フォースオブウィッシュ, フォースオブプレイ, フォートレス, ブリッツ, プロヴォーク, ポイントライズ, メナス, ランページ, リヴァイブ, リコントラクト, リザレクション, レクトノート, ワイズノートの47系列を定義する. Enum値は「[型定義](../design/types.md)」を参照する.

### パラメータ

特殊効果は`TacticsBattleSpecialParameters`として以下3値を同時に保持できる.

* 攻撃.
* 防御.
* 速度.

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
  - タクティクス使用時に特定の相手PlayerIDを固定する意味ではない.
* 味方騎士団.
* 敵騎士団.

## 効果時間

タクティクスによって変わる.

終了方式は`TacticsEndType`で識別する.

* `TACTICS_END_TYPE_DURATION`: 特定の時間.
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

継続中のタクティクス効果はGameServerが「[型定義](../design/types.md)」の`TacticsActiveEffectState`として保持する.

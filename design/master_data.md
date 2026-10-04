# マスターデータ

いずれもJSON形式

本リポジトリにはマスターデータの実データJSONを配置しない。様々な都合により実データは本仕様書・設計書の配布物には含めず、本書ではマスターデータの構造のみを定義する。実データが存在しないことを未定義仕様とは扱わない。

このマスターデータを直接DBには入れることはできず, ゲームサーバーが加工してDBに渡す
画像やUVデータはクライアントが保持し, サーバーでは保管しない
各項目の型は「[型定義](types.md)」を参照

## キャラクター

* ID
* 肩書
* 名前
* レアリティ
* 属性
* HP
* 攻撃
* 防御
* 速度ランク
* BP
  - 最小0
  - 最大99
* 所持スキル一覧
  - 最低1つ
* 所持アビリティ一覧
* 所持タクティクス一覧
  - 0~2

## スキル

* ID
* 名前
* 効果説明文
* 効果ID
  - 「[型定義](types.md)」の`SkillEffectID`で定義するスキル効果種別
* 発動率
  - `0.2`の基本スキル発動率へ加算する値
* 補正値
  - `SkillEffectID`で示す効果に対する効果値
* 対象範囲
  - 「[型定義](types.md)」の`SkillTargetRange`を使用する
* 単体対象優先条件ID
  - `SkillTargetConditionID`を使用する
  - `0`は優先条件なし
* ランダム攻撃回数
  - `SkillTargetRange=SKILL_TARGET_RANGE_RANDOM`の場合に使用する
* 状態異常ID
  - `SkillEffectID=SKILL_EFFECT_STATUS_ABNORMALITY`の場合に`StatusAbnormalityID`を使用する
* 状態異常付与率
  - `SkillEffectID=SKILL_EFFECT_STATUS_ABNORMALITY`の場合に使用する
* バフ・デバフ対象能力
  - `SkillEffectID`がバフまたはデバフの場合に`SkillStatTarget`を使用する
* HP0回復可否
  - 回復スキルがHP0のキャラクターを回復対象にできるかを保持する
* 回復量
  - 回復スキル固有の回復量を保持する

## アビリティ

* ID
* 名前
* 効果説明文
* 効果ID
  - 「[型定義](types.md)」の`AbilityEffectID`で定義するアビリティ効果種別
* 発動条件ID
  - 「[型定義](types.md)」の`ConditionID`を使用する
* 発動条件値
  - `every_n_turns`のターン数、`hp_at_or_below_threshold`の閾値等、条件に具体値が必要な場合に使用する
* セット可能属性
  - `CharacterAttribute[]`で保持する
  - キャラクターの属性が一覧に含まれる場合のみセット可能
* 発動率
* 最大発動回数
  - 1戦闘中に発動可能な最大回数
* 補正値

## タクティクス

* ID
* 名前
* 効果説明文
* 分類
  - ユーザーサイドのアイコンIDでもある
* 消費TP
* 各段階の効果上昇量
  - 段階ごと、かつ`TacticsEffectID`と`TacticsTarget`ごとに保持する
* 終了方式
  - `TacticsEndType`
* 効果時間
* 効果回数
* 各種効果
  - `TacticsEffectID`
  - `TacticsTarget`
  - 効果値

## フォーメーション

* ID
* 名前
* 効果説明文
* 使用マス
* 各位置条件ID
* 攻撃/防御/速度/スキル等の補正値

## アイテム

* ID
* 名前
* 効果説明文
* 種類
* 効果


## 騎士団

* ID
* 名前
* 団長ID
* 所属メンバー
* 城レベル
* 武器庫レベル
* 食糧庫レベル
* 鍛冶屋レベル
* 兵法所レベル
* 酒場レベル
* 昼開始時刻
  - `GuildBattleStartTime`の11:30 / 12:15 / 13:00のいずれか1つ
* 夜開始時刻
  - `GuildBattleStartTime`の21:00 / 22:00 / 23:00のいずれか1つ


## 効果値の合算規則

* スキル、アビリティ、タクティクス、フォーメーションの効果値はマスターデータに保持する.
* 同一系列の効果値はすべて加算する.
* スキルは同じ`SkillEffectID`系列、アビリティは同じ`AbilityEffectID`系列、タクティクスは同じ`TacticsEffectID`系列として扱う.
* `SkillEffectID`、`AbilityEffectID`、`TacticsEffectID`は相互に別の列挙型であり、異なる種別間で列挙値を共有しない.

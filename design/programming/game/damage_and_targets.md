# ダメージ・攻撃対象のプログラミング設計

## 責務と処理順

`battle`配下のDamage算出と対象列生成を明確に分離する。通常攻撃・追撃・反撃は通常Damage flow、攻撃SkillはSkill Damage flowを使用し、Skillを通常攻撃の回避・反撃・COVER・ひきつけ・追撃経路に流し込まない。

1. Mode（Arena / GuildBattle）、攻撃者・対象者の検証済みStatus、Formation・Tactics・Ability・Buff/Debuffの補正を入力する。
2. 仕様式どおり各補正を集計して攻撃力・防御力の`f32`を求める。GuildBattleにだけ施設補正と該当Tactics補正を加え、Arenaへは混入させない。`BuffDebuffEffectState`はSkill / Ability由来に限定する。
3. 通常Damageは**`攻撃力 - 防御力 / 3`→最小250とのmax→Damage乱数（1.0000～1.0300、`next_bounded(301)`）乗算→最大99999とのmin**の順に実行する。中間結果も`f32`を維持する。HPへ反映する地点でだけ仕様の整数化を行う。
4. 対象範囲はキャラクター属性・位置・Status・Abilityの条件で決定する。対象リストの走査は**左から右、手前から奥**とし、`specification/game/character.md`の属性別範囲を使用する。打属性2×2は攻撃者の列を起点とし、中央値が左右同点なら左＋中央列を選択する。候補順のための乱数は消費しない。
5. 対象選定・スキル発動・回避・追撃・反撃の乱数は、それぞれ戦闘フローが要求した箇所でだけ消費する。対象・HITごとのDamage乱数の使い回しは行わない。
6. 既定の戦闘不能移行・COVER中のHP0・追撃対象継続・反撃は1ターン最大1回・暗闇による攻撃失敗時の分岐を守る。

## 異常入力と責務境界

- 非有限`f32`、Mode不正、存在しない対象、期待しないSkill Effect / Target Range組合せを入力境界で拒否する。範囲外の値を任意に丸めて正規値とみなさない。
- Damage結果はゲーム上のHP変動として返し、WebGL、音声やNetwork Response構築は呼び出し側に任せる。`panic`、I/O、隠れたRandom取得は行わない。

## テスト

GuildBattle / Arena別の補正差、最低250・最大99999、301段階の乱数境界、`f32`中間丸め、HP切り捨て位置、複数HITと乱数最終状態、配置方向と対象順、打属性同点、Blindness・COVER・Pursuit・Counterの各分岐を単体テストする。

正本：`../../../specification/game/battle.md`、`../../../specification/game/character.md`、`../../../specification/game/skill.md`、`../../../specification/game/ability.md`、`../../game/battle.md`。

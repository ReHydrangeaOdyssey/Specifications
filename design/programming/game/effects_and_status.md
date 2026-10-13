# Skill・Ability・状態異常のプログラミング設計

## モジュール境界

- `skill`: Main Skillの参照・発動判定・Target決定・Effect算出。各Characterの`SkillBattleState.activation_count`を扱う。
- `ability`: 許可された`AbilityEffectID × AbilityConditionID × AbilityTarget`の検証、条件評価、発動回数・1ターン1回制限、効果評価。各`AbilityBattleState`を扱う。
- `status_abnormality`: 付与、経過ターン・毒周期、解除の条件・抽選。Status情報の更新以外の戦闘ターン進行を決めない。
- 上位`battle`は`design/game/battle.md`に規定された評価点で各Moduleを呼び、順序を制御する。各Moduleが勝手に他のActionを再実行しない。

## Skill契約

1. メインスキルだけを発動候補とし、沈黙・最大発動回数等を**乱数抽選前**に検証する。
2. Skill発動率はArenaでは`0.2 + Skill補正 + Formation補正`、GuildBattleではこれにTactics補正を加算し、`[0, 1]`にClampする。抽選方法は共通PRNG仕様を使用する。
3. Target Side、Target Range、優先条件、効果型をMasterDataの確定型で判定し、候補順位と抽選点を区別する。固定・割合ダメージや単体/範囲・X字/十字の詳細式はSkill仕様から読み込む。
4. Skill発動により変更したEffect、HP、発動回数は**一つのAction結果**として上位へ返す。途中失敗時にランダム消費だけを正本へ残さない。

## Ability契約

1. Battle開始時に`activation_count=0`、`activated_this_turn=false`へ初期化する。ターン開始時（強制経過ターンを含む）は全Abilityの`activated_this_turn`をリセットする。
2. 条件の発生点は`design/game/battle.md`のBattle Start / Turn Start / Before / After / Turn End、通常攻撃、被攻撃、戦闘不能等の既定フローに従う。`EVERY_N_TURNS`は`current_turn>=1`かつ間隔が有効な場合だけ判定する。
3. AbilityIDごとの1ターン1回と、`max_activation_count`による戦闘累計上限を分離して検証する。上限到達時は候補抽選・発動率の乱数を消費しない。同時成立の候補整列は仕様が定める順位と同順位のRandom規則へ委譲する。
4. 効果はBUFF / DEBUFF、TARGET、DAMAGE、AVOIDANCE、COUNTER、PURSUIT、COVER、HEAL等の責務ごとに分け、Battle Flow内の適用点を守る。CB専用Abilityの判定Stateは通常戦闘用と共有しない。
5. **HP閾値Abilityについて、仕様上確定していない新たな「HP減少直後に必ず発動」等の契機を追加しない。** 評価は既に定義されたイベント位置でのみ実施し、追加契機が必要なら仕様確定まで保留する。

## 状態異常契約

- 同一状態異常再付与では最低継続ターンの経過値をリセットするが、毒の`poison_cycle_turns`は保持する。
- ターン終了時の処理は**Formation内部番号昇順→PlayerID昇順→固定陣営順**、各Characterでは**毒→暗闇→沈黙→範囲攻撃不可→昏睡**。不要な解除抽選では乱数を消費しない。
- 毒は3ターンごとに現在HPの5%を切り上げて減算し、毒によるHP0では戦闘不能時Abilityを実行しない。毒以外の最低継続ターンと50%解除判定は各Status仕様に従う。
- 双方の生存者が全員昏睡した場合、上位Battle Runtimeが行動なしの強制経過ターンを実行し、同じ状態異常順序・ターン終了処理を適用する。

## テスト

Skillの沈黙・回数上限・Mode別発動率、Target優先条件と乱数状態、Abilityの同一ターン2度目不発・上限時非消費、戦闘不能の反撃禁止、昏睡強制経過、毒周期独立、複数Characterの解除順、状態異常の重複付与と解除境界を単体テストする。Error時に状態・乱数を正本へ確定しないことも検査する。

正本：`../../../specification/game/skill.md`、`../../../specification/game/ability.md`、`../../../specification/game/status_abnormality.md`、`../../game/battle.md`。

# 編成・従者・パーティランクのプログラミング設計

## 責務

`formation`、`follower`、`party_rank`は、編成の妥当性検証と**編成時の数値計算**を担当し、戦闘RuntimeやDB参照を持たない。Formation位置の条件付き補正とFollower補正を区別する。

## 入力Validation

- Formationは3×3の内部番号`1..=9`を使用し、重複位置を拒否する。戦闘編成は1～5 Characterを扱い、騎士団戦の編成10スロット中の有効Characterのみをパーティランク集計対象にする。
- Followerは最大2枠で、スロット0は本体以下のレアリティ、スロット1は本体より低いレアリティに限定する。本体自身、同一本体の両Follower枠での重複を拒否する。別の本体に同一Followerを使うことは制限しない。
- Formation条件に必要な位置・属性・参照レコードの欠落は推測補完せず、検証失敗とする。

## 計算処理

1. 編成に含む本体CharacterとFollowerの基礎Statusを、入力済みデータから取得する。
2. FollowerのHP・攻撃・防御補正は**`本体 + 従者A×0.1 + 従者B×0.1`**の`f32`順序どおりに求め、内部値を小数のまま保持する。表示用に限り切り捨てる。
3. `PartyCharacterStatus`を別の型として生成し、PartyRankにはFollower適用後の最大HP・攻撃・防御・速度ランクだけを渡す。戦闘時バフ・Tactics・FormationをPartyRank集計へ混入させない。
4. HP・攻撃・防御の集計は仕様の切り捨て位置を適用し、段階境界表から各Rankを取得する。速度は速度レベル平均の切り捨て後にRankへ変換し、最終PartyRankは**4つのRank値の平均の切り上げ**で求める。Rankは`SS9=0`、`F-=32`の向きに従う。
5. 戦闘用Formation位置補正は使用時の条件を検証し、一致位置の攻撃・防御・速度・Skill補正だけを取得する。PartyRank用のStatusへ書き戻さない。
6. GuildBattle被弾時の優先配置は編成ID順で競合候補を整列し、**競合がある箇所のみ**仕様のRandomを使用する。抽選後の空位置補充も確定した内部番号・抽選外順に従う。

## 境界と単体テスト

- 結果を呼び出し側へ返し、DB更新・表示フォーマット・乱数Seed取得を行わない。Validation失敗を`panic`にしない。
- Formation重複／範囲外、Followerのレアリティ境界、Follower重複、空きスロット、各Rank表の上下限・ちょうど境界、平均切り捨て・最終切り上げ、`f32`差異、条件不一致の補正0、優先配置競合と乱数消費を単体テストにする。

正本：`../../../specification/game/formation.md`、`../../../specification/game/follower.md`、`../../../specification/game/party_rank.md`、`../../../specification/game/battle.md`。

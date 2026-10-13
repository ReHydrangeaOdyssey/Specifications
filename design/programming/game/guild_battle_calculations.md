# 騎士団戦の共通計算設計

## 適用範囲

`game-core`には騎士団戦の**決定的数値計算と条件判定**だけを置く。GameServerの単一Ownerが保持する騎士団戦Runtime、Request受付順、時刻取得、Replay / WAL / DB確定・認可はApplication層の責務。ClientとGameServerは同じ共通計算関数を使用して表示用に再現できるが、成功の正本はGameServerの確定結果である。

## 処理の分割

| 計算領域 | 計算入力 | 計算結果 | 正本 |
|---|---|---|---|
| 出撃・殲滅戦闘 | 対象GuildBattleの計算用Snapshot、出撃者・対象者、PRNG | 被弾・戦闘結果・HP/BP/TPの変化候補 | `specification/game/guild_battle.md`、`design/game/battle.md` |
| 強襲・Castle Break | 施設状態、Chain、Tacticsの効果値、対象・Random | 成否・攻撃結果・CB Scoreの候補 | `specification/game/guild_battle.md`の各CB節、`design/game/guild_battle.md` |
| Score | 1回の出撃結果、Chain・効果値等 | 出撃単位の小数を含むScoreとGuild合計用の加算値 | `specification/game/guild_battle.md`の殲滅/CBスコア節 |
| Tactics | 有効効果Snapshot、対象・発生イベント、専用Random | 許可判定、即時/継続効果、残回数の変更候補 | `tactics_runtime.md`、`specification/game/tactics.md` |
| 回復・復活・Item | 現在BP/HP、上限、Item種別等の検証済み状態 | 回復量・待機時間・残数の変更候補 | `specification/game/item.md`、`specification/game/guild_battle.md` |

## 決定性と適用順

1. 実際の受付・所有者認可とRequestSequenceの照合はGameServerで先に実行し、確定した計算用SnapshotとRandomを`game-core`へ渡す。
2. 専用戦闘PRNGとGuildBattle本体PRNGを混同しない。Tactics用Randomは本体PRNGから仕様どおり一度Seedを採番した後、専用Randomで抽選する。
3. Scoreは**単一出撃内の小数精度を維持**し、騎士団合計に加算するタイミングでだけ仕様に従い切り捨てる。CBの能力値補正・Score計算は既定フローに従い、同じ効果を二度加算しない。
4. `TacticsActiveEffectState`は適用対象、絶対期限、回数、発火イベントを明示した入力とする。`expires_at`の現在時刻との比較は呼び出し元で確定した時刻を渡して評価し、共通計算層でSystem Clockを読まない。
5. 共通関数は**状態変更候補**を返すだけでRequestSequenceを更新しない。通常EventのWAL耐久化、出撃のDB COMMITまたはRecovery Journal確定、後追いItem減算等はGameServer側の既存設計に従って反映する。サーバー間Item同期は追加しない。
6. 独立したサーバー機能であるGuild生成、Matching、DB Transaction、Replay改ざん検証はこのModuleに含めない。

## 単体テスト

確率端点、Chainとイベント種別、Tacticsの効果系列、CBスコア、施設補正、BP/TP上限、Item個数不足、出撃単位Scoreの小数・Guild合計の切り捨て、複数の専用Randomの独立性、失敗時PRNG未Commitを対象とする。GameServer永続化失敗はAdapter側の単体テストで検証する。

正本：`../../../specification/game/guild_battle.md`、`../../../specification/game/item.md`、`../../../specification/game/tactics.md`、`../../game/guild_battle.md`、`../server/guild_battle_runtime.md`。

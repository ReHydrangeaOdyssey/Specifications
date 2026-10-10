# 設計トレーサビリティ

## 概要

`design/programming/`の設計判断を現行仕様へ追跡できるよう、主要な実装境界と正本資料を対応付けます。ここにない新しいゲーム挙動をプログラミング設計の根拠にはしません。

## 対応表

| プログラミング設計 | 確定している内容 | 主な根拠 |
|---|---|---|
| `architecture.md` | Component責務、正本、Data / Control Path | `design/server/api.md`, `design/system/network.md`, 各Server設計 |
| `directory_structure.md` | Rust Workspace上の責務分割 | `design/system/rust_dependencies.md`, 各Component責務 |
| `implementation_rules.md` | 型変換、PRNG、Replay、Operation ID等の横断規則 | `design/shared/types.md`, `design/system/log.md`, `design/server/data_base.md` |
| `shared/shared_crates.md` | `game-core`, `protocol`, `common-types`, `server-common`, `auth-common` | `design/system/rust_dependencies.md` |
| `shared/types.md` | Wire / logical / DB型の境界 | `design/shared/types.md`, `design/shared/common_data_struct.md` |
| `shared/error_model.md` | Public Errorと内部Errorの境界 | `design/server/api_payload.md`, `design/server/public_api_responsibility.md` |
| `game/game_core.md` | Pure game logicの責務 | `design/game/battle.md`, `design/game/pseudorandom.md`, `specification/game/skill.md`, `specification/game/ability.md`, `specification/game/tactics.md` |
| `game/battle_runtime.md` | Character / Skill / Ability / Status runtime | `design/game/battle.md`, `design/shared/common_data_struct.md` |
| `game/pseudorandom.md` | PRNG実装・Seed・消費順 | `design/game/pseudorandom.md`, `design/test/test_policy.md` |
| `game/tactics_runtime.md` | Tactics専用Random、Active Effect | `design/game/guild_battle.md`, `specification/game/tactics.md` |
| `game/master_data_pipeline.md` | Parse / Normalize / Validate / Generate / Cross Check | `design/game/master_data_pipeline.md` |
| `client/client.md` | Client state、オフラインゲームプレイ制御、タイトル画面からの画像割り当て、Arena再現、GuildBattle再同期 | `design/client/client.md`, `design/client/scene_transition.md`, `design/game/master_data.md`, `design/server/guild_battle.md` |
| `server/api_boundary.md` | Public / Private / GameServer Routing | `design/server/api.md`, `design/server/public_api_responsibility.md` |
| `server/public_api.md` | Stateless Edge、認証検証、Cookie、Owner routing | `design/server/public_api.md`, `design/server/public_api_responsibility.md`, `design/server/session.md` |
| `server/private_api.md` | Account/Guild Domain、DB transaction、Lifecycle | `design/server/private_api.md`, `design/server/data_base.md` |
| `server/auth_session.md` | JWT、Refresh rotation、Discord auth | `design/server/session.md` |
| `server/arena.md` | Arena初期状態・Seed・Client再現 | `design/server/arina.md`, `design/game/arina.md` |
| `server/game_server.md` | Instance、Thread、Capacity、draining、Recovery | `design/server/game_server.md`, `design/system/log.md` |
| `server/guild_battle_runtime.md` | 現行受付Queueと出撃Response先行例外, CB/殲滅, Ability効果別判定, ScoreUpdate購読の残り時間・終了, Replay, 30:00 Queue処理 | `specification/game/guild_battle.md`, `specification/game/ability.md`, `design/server/guild_battle.md`, `design/server/public_api.md`, `design/server/api_payload.md`, `design/game/guild_battle.md` |
| `server/guild_battle_coordinator.md` | Matching、Assignment、Reconcile、Scale | `design/server/guild_battle_coordinator.md` |
| `server/persistence.md` | Schema責務、Transaction、Operation ID | `design/server/data_base.md`, `design/server/guild_battle_lifecycle.md` |
| `server/logging_recovery.md` | Log / Replay / Recovery Queueと保存 | `design/system/log.md`, `design/server/guild_battle.md` |
| `test/test_design.md` | Unit / Integration / Reproducibility / Replay / Failure / CB効果別判定・通知とキュー境界・除外Guild解除順序 | `design/test/test_policy.md`, `design/server/guild_battle_lifecycle.md` |
| `undecided.md` | 現仕様で固定できない事項 | 各資料の未定義・推奨記載 |

## 変更時の扱い

仕様書変更時は、該当する行のプログラミング設計とテストを同時に確認します。

特に次の変更は再現性へ直接影響するため、Versionとの整合を確認します。

- PRNG実装
- 乱数消費位置・候補順
- Battle計算順
- Skill / Ability / Tactics MasterData
- Runtime stateの意味
- Replay初期SnapshotまたはEvent意味

## 未確定事項の固定禁止

`undecided.md`へ記載した事項については、実装都合で選択が必要になっても「ゲーム仕様として確定した」と扱いません。後から仕様が確定した際に差し替え可能なBoundaryとして実装します。


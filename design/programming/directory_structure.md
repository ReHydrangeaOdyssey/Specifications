# 実装ディレクトリ構造

## 概要

現仕様で明示されているComponentと内部crateをWorkspaceの上位境界にし、各Application内では「transport / application / domain or runtime / infrastructure」の責務が混在しないよう論理分割します。

以下はRustの型名やファイル名を固定するものではなく、実装責務を配置するためのディレクトリ境界です。

```text
workspace/
├── crates/
│   ├── common-types/
│   ├── protocol/
│   ├── game-core/
│   │   └── src/
│   │       ├── battle/
│   │       ├── skill/
│   │       ├── ability/
│   │       ├── tactics/
│   │       ├── status_abnormality/
│   │       ├── formation/
│   │       ├── follower/
│   │       ├── party_rank/
│   │       └── pseudorandom/
│   ├── server-common/
│   └── auth-common/
│
├── apps/
│   ├── client/
│   ├── public-api-server/
│   │   └── src/
│   │       ├── transport/
│   │       ├── security/
│   │       ├── rate_limit/
│   │       ├── routing/
│   │       ├── session_cookie/
│   │       └── upstream/
│   ├── private-api-server/
│   │   └── src/
│   │       ├── transport/
│   │       ├── auth/
│   │       ├── account/
│   │       ├── guild/
│   │       ├── arena/
│   │       ├── guild_battle/
│   │       └── persistence/
│   ├── game-server/
│   │   └── src/
│   │       ├── transport/
│   │       ├── arena/
│   │       ├── guild_battle/
│   │       ├── replay/
│   │       ├── recovery/
│   │       ├── telemetry/
│   │       └── upstream/
│   ├── guild-battle-coordinator/
│   │   └── src/
│   │       ├── matching/
│   │       ├── assignment/
│   │       ├── discovery/
│   │       ├── reconcile/
│   │       ├── scale_out/
│   │       └── upstream/
│   └── discord-bot/
│
├── tools/
│   └── master-data-pipeline/
│       └── src/
│           ├── parse/
│           ├── normalize/
│           ├── validate/
│           ├── generate/
│           └── cross_check/
│
├── proto/
│   ├── public_api.proto
│   └── guild_battle_replay.proto
│
└── tests/
    ├── integration/
    ├── reproducibility/
    ├── replay/
    └── failure/
```

## 配置ルール

- `apps/client/`はRust/WASMのWeb Clientとします。Client内でBrowser API連携（`wasm-bindgen` / `web-sys` / `js-sys` / `wasm-bindgen-futures`）, WebGL 2描画, OPFSアセット管理, HCAデコード/Web Audio出力を論理的に分離します。下位の具体的なRustファイル名・ディレクトリ名は固定しません。
- Clientは共有`game-core`および`protocol`を使用し, 描画・音声・OPFSなどのBrowser APIを`game-core`へ持ち込みません。
- `game-core`にはHTTP、Database、Kubernetes、ファイルI/Oを置きません。
- Public APIの`routing`はDomain ruleを保持しません。
- Private APIのDatabase transactionは`persistence`境界で開始し、Account/Guild/GuildBattleのApplication処理がtransaction unitを決定します。
- GameServerの`guild_battle`からReplay/Eventを生成しても、Serialize・ファイルI/O・DB送信は`replay` Worker側へ渡します。
- Coordinatorの`matching`と`assignment`を分離し、GameServer容量選択と対戦ペア生成を混在させません。
- Protocol Buffers schemaは既存`public_api.proto`と`guild_battle_replay.proto`を正本とし、別のwire schemaを設計内で増やしません。

## 制約

- 責務が異なる処理は, Application間で似たコードが存在しても無条件に共通化しない。

## 参照資料

- `design/system/rust_dependencies.md`
- `design/server/public_api_responsibility.md`
- `design/server/private_api.md`
- `design/server/game_server.md`
- `design/server/guild_battle_coordinator.md`
- `design/system/log.md`
- 添付`rust_wasm_png_hca_library_selection(1).md`（2026-10-09）, 第1～7節.

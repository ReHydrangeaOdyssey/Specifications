# 実装ディレクトリ構造

## 結論

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

- `game-core`にはHTTP、Database、Kubernetes、ファイルI/Oを置きません。
- Public APIの`routing`はDomain ruleを保持しません。
- Private APIのDatabase transactionは`persistence`境界で開始し、Account/Guild/GuildBattleのApplication処理がtransaction unitを決定します。
- GameServerの`guild_battle`からReplay/Eventを生成しても、Serialize・ファイルI/O・DB送信は`replay` Worker側へ渡します。
- Coordinatorの`matching`と`assignment`を分離し、GameServer容量選択と対戦ペア生成を混在させません。
- Protocol Buffers schemaは既存`public_api.proto`と`guild_battle_replay.proto`を正本とし、別のwire schemaを設計内で増やしません。

## メリット・デメリット

### メリット

- 仕様上の正本Componentとコード配置が一致します。
- GameServerのHot PathへI/O責務が混入しにくくなります。
- 再現性テストを`game-core`単体で実行できます。

### デメリット

- 小規模開発としてはディレクトリ数が増えます。
- Application間で似たコードが発生した場合でも、責務が異なる処理を安易に共通化できません。

## 情報源

- `design/system/rust_dependencies.md`
- `design/server/public_api_responsibility.md`
- `design/server/private_api.md`
- `design/server/game_server.md`
- `design/server/guild_battle_coordinator.md`
- `design/system/log.md`

# Private API Server大枠設計

## 結論

Private API ServerはAccount / Guild等のDomain処理、認証状態、Databaseアクセス、GuildBattle永続ライフサイクルを担当する。

Application ComponentのうちPostgreSQLへ直接接続するのはPrivate API Serverだけとする。

## 論理構成

```text
Private API Server
├── Authentication / Session
├── Account
├── Guild
├── Arena Persistence
├── GuildBattle Persistence
├── GuildBattleLifecycleService
└── Database Access
```

この分類は詳細クラスを確定するものではなく、既存設計の責務を分けるための論理境界である。

## クラス図

```mermaid
classDiagram
    class PrivateApiServer {
        <<component>>
        AccessToken署名秘密鍵を保持
    }

    class AuthenticationSession {
        <<logical module>>
    }
    class AccountDomain {
        <<logical module>>
    }
    class GuildDomain {
        <<logical module>>
    }
    class GuildBattleLifecycleService {
        <<service>>
        +MarkGuildBattlePreloadFailed()
        +StartGuildBattle()
        +BeginGuildBattleResolving()
        +CompleteGuildBattle()
        +RetryPreloadFailedGuildBattle()
        +RematchPreloadFailedGuildBattles()
    }
    class DatabaseAccess {
        <<logical module>>
        Transaction
        Row Lock
        Idempotency
    }
    class PostgreSQL {
        <<database>>
    }

    PrivateApiServer --> AuthenticationSession
    PrivateApiServer --> AccountDomain
    PrivateApiServer --> GuildDomain
    PrivateApiServer --> GuildBattleLifecycleService
    AuthenticationSession --> DatabaseAccess
    AccountDomain --> DatabaseAccess
    GuildDomain --> DatabaseAccess
    GuildBattleLifecycleService --> DatabaseAccess
    DatabaseAccess --> PostgreSQL
```

`AuthenticationSession`等の名称は論理責務の表示名であり、Rust型名を確定するものではない。`GuildBattleLifecycleService`は既存資料で明示された名称である。

## GuildBattle永続状態

```mermaid
stateDiagram-v2
    [*] --> scheduled
    scheduled --> preload_failed: MarkGuildBattlePreloadFailed
    preload_failed --> scheduled: RetryPreloadFailedGuildBattle
    preload_failed --> scheduled: RematchPreloadFailedGuildBattles
    scheduled --> in_progress: StartGuildBattle
    in_progress --> resolving: BeginGuildBattleResolving
    resolving --> completed: CompleteGuildBattle
    completed --> [*]
```

任意の`status`を指定する汎用更新APIは設けない。

## 冪等Database更新

```mermaid
sequenceDiagram
    participant G as GameServer / Coordinator
    participant P as Private API Server
    participant D as PostgreSQL

    G->>P: Request + X-Operation-ID
    P->>D: Transaction開始 / Operation ID確認
    alt 未処理
        P->>D: Domain更新 + Operation記録
        D-->>P: Commit
        P-->>G: 初回成功Response
    else 処理済み
        D-->>P: 保存済み成功結果
        P-->>G: 初回成功時Response
    end
```

同一論理操作の初回送信、1回再試行、Recovery再送では同じ128bit UUIDの`X-Operation-ID`を使用する。

## 情報源

- `design/server/private_api.md`
- `design/server/data_base.md`
- `design/server/guild_battle_lifecycle.md`
- `design/system/network.md`

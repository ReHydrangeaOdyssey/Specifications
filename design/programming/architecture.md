# 全体アーキテクチャ

## 結論

実装の大枠は、`Client`、`Public API Server`、`Private API Server`、`GameServer`、`GuildBattleCoordinator`、`PostgreSQL`、`MasterData Pipeline`、共有内部crateへ分離する。

ゲームルールの正本、永続状態の正本、外部公開境界を分離し、各Componentが別ComponentのDomain責務を代行しない構造とする。

## Component責務

| Component | 主責務 | 保持しない責務 |
|---|---|---|
| Client | UI、イベントキュー、ローカル編成、Arena再現 | 戦闘結果の正本 |
| Public API Server | Internet境界、認証済みContext生成、Boundary Validation、Rate Limit、Routing | Account/Guild/Arena/GuildBattleのDomain判定 |
| Private API Server | Account/Guild、認証状態、DB仲介、永続ライフサイクル | Arena抽選、戦闘計算、GuildBattleマッチング |
| GameServer | Arena計算、GuildBattle状態、戦闘計算、Replay連携 | GuildBattle生成・マッチング・未割当Battleの自己割当 |
| GuildBattleCoordinator | GuildBattle生成、マッチング、GameServer選択、割当、Preload開始 | 通常ゲーム要求、戦闘状態、RequestSequence、ReplayQueue |
| PostgreSQL | 永続データ | Application Domain Logic |
| MasterData Pipeline | Parse、Normalize、Validate、生成、整合確認 | 未確定値の補完 |

## Component関係図

```mermaid
flowchart TB
    Internet((Internet))
    Client[Client]
    Ingress[Ingress]
    PublicAPI[Public API Server]
    PrivateAPI[Private API Server]
    GameServerA[GameServer A]
    GameServerB[GameServer B]
    Coordinator[GuildBattleCoordinator]
    DB[(PostgreSQL)]
    Bot[Discord Bot]

    Client --> Internet --> Ingress --> PublicAPI
    PublicAPI -->|mTLS| PrivateAPI
    PublicAPI -->|mTLS / 所有Instanceへ直接| GameServerA
    PublicAPI -->|mTLS / 所有Instanceへ直接| GameServerB

    Coordinator -->|mTLS| PrivateAPI
    Coordinator -->|mTLS| GameServerA
    Coordinator -->|mTLS| GameServerB

    GameServerA -->|mTLS| PrivateAPI
    GameServerB -->|mTLS| PrivateAPI
    PrivateAPI --> DB

    GameServerA -. 条件付き通知 .-> Bot
    GameServerB -. 条件付き通知 .-> Bot
    Coordinator -. 条件付き通知 .-> Bot
    PrivateAPI -. 条件付き通知 .-> Bot
```

## Public API Routing

```mermaid
flowchart LR
    Request[Client Request] --> Public[Public API Server]

    Public -->|CreateAccount / Login / Refresh / Logout| Private[Private API Server]
    Public -->|Guild操作| Private
    Public -->|UpdateArenaParty / StartArenaBattle| Game[GameServer]
    Public -->|GuildBattle操作| Resolve[GuildBattleID -> GameServerInstanceID]
    Resolve --> Game
```

## Arenaの正本と再現

```mermaid
sequenceDiagram
    participant C as Client
    participant P as Public API Server
    participant G as GameServer
    participant PA as Private API Server

    C->>P: StartArenaBattle(ClientVersion, LocalParty, ...)
    P->>G: 認証済みContextとRequestを中継
    G->>G: Version再確認
    G->>PA: 必要な永続データ取得/保存
    G->>G: Seed生成・戦闘計算
    G-->>P: 相手初期状態 + Seed
    P-->>C: 相手初期状態 + Seed
    C->>C: 同一Versionのロジックで戦闘再現
```

Serverの計算結果を正本とし、成功レスポンスでは勝敗や最終HP等の戦闘結果そのものを返さない。

## GuildBattleのControl PathとData Path

```mermaid
flowchart LR
    subgraph ControlPath[Control Path]
        Coordinator[GuildBattleCoordinator]
        Private[Private API Server]
        Game[所有GameServer]
        Coordinator --> Private
        Coordinator --> Game
    end

    subgraph DataPath[通常ゲーム要求]
        Client[Client] --> Public[Public API Server]
        Public --> Game2[所有GameServer]
        Game2 --> Private2[Private API Server]
    end
```

Coordinatorは割当・Preload開始後の通常ゲーム要求経路には入らない。

## GuildBattle所有モデル

```mermaid
flowchart TD
    Battle[GuildBattleID] --> Assignment[(GUILD_BATTLE.game_server_instance_id)]
    Assignment --> Instance[1 GameServer Instance]
    Instance --> Runtime[メモリ上GuildBattle State]
```

同一GuildBattleを複数GameServer間で共有メモリ同期する方式にはしない。

## 情報源

- `design/system/network.md`
- `design/server/public_api_responsibility.md`
- `design/server/private_api.md`
- `design/server/game_server.md`
- `design/server/guild_battle_coordinator.md`
- `design/client/client.md`
- `design/game/arina.md`

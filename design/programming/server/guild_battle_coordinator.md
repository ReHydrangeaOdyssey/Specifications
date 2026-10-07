# GuildBattleCoordinator大枠設計

## 結論

GuildBattleCoordinatorはGuildBattleのControl Path専用Componentとし、生成、マッチング、GameServer選択、割当、Preload開始指示、再起動時Reconcileを担当する。

通常のClientゲーム要求、戦闘状態、RequestSequence、ReplayQueue、戦闘計算結果は保持しない。

## 論理構成

```text
GuildBattleCoordinator
├── Matching
├── Assignment
├── GameServer Discovery
├── Capacity
├── Preload Control
├── Reconciliation
└── Scale-out Request
```

## クラス図

```mermaid
classDiagram
    class GuildBattleCoordinator {
        <<component>>
        LastAssignedAt
    }
    class Matching {
        <<logical module>>
    }
    class GameServerDiscovery {
        <<logical module>>
        EndpointSlice watch
    }
    class CapacitySelection {
        <<logical module>>
    }
    class Assignment {
        <<logical module>>
    }
    class PreloadControl {
        <<logical module>>
    }
    class Reconciliation {
        <<logical module>>
    }
    class ScaleOutRequest {
        <<logical module>>
    }

    GuildBattleCoordinator --> Matching
    GuildBattleCoordinator --> GameServerDiscovery
    GuildBattleCoordinator --> CapacitySelection
    GuildBattleCoordinator --> Assignment
    GuildBattleCoordinator --> PreloadControl
    GuildBattleCoordinator --> Reconciliation
    GuildBattleCoordinator --> ScaleOutRequest
```

各Module名は責務表示用であり、具体的なRust型名は固定しない。

## 割当フロー

```mermaid
flowchart TD
    Scheduled[scheduled / 未割当GuildBattle] --> Discover[ready GameServer検出]
    Discover --> Capacity[GetGameServerCapacity]
    Capacity --> Candidate{AcceptNewGuildBattle && AvailableGuildBattleCount > 0}
    Candidate -->|あり| Select[候補選択]
    Select --> Assign[AssignScheduledGuildBattles]
    Assign --> Preload[StartGuildBattlePreload]
    Candidate -->|容量不足| Scale[専用Kubernetes ControllerへScale-out要求]
    Scale --> Recheck[ready反映後に再確認]
    Recheck --> Capacity
```

候補選択では資料に定義された比較項目を使用する。推奨初期順序は`Ready判定 → 負荷判定 → Capacity使用率 → 最終割当時刻 → InstanceID`である。

## 再起動時Reconcile

```mermaid
flowchart TD
    Start[Coordinator起動 / 定期Reconcile] --> Load[GetGuildBattleCoordinationState]
    Load --> Unassigned{scheduledかつ未割当?}
    Unassigned -->|Yes| Assign[通常割当へ]
    Unassigned -->|No| Assigned{scheduledかつ割当済み?}
    Assigned -->|Yes| Endpoint{割当先Endpoint存在?}
    Endpoint -->|存在| Resend[StartGuildBattlePreload再送可]
    Endpoint -->|規定時間不在| Release[ReleaseScheduledGuildBattleAssignments]
    Release --> Assign
```

`in_progress`以降はEndpoint不在を理由に割当解除・再割当しない。進行中GuildBattleを別GameServerへ自動復旧する方式は資料で定義されていないため、本設計でも定義しない。

## 情報源

- `design/server/guild_battle_coordinator.md`
- `design/server/game_server.md`
- `design/operation/operation.md`
- `design/test/test_policy.md`

## シーケンス

### 編成登録時

```mermaid
sequenceDiagram
    actor User
    participant Client
    participant PublicAPIServer
    participant GameServer
    participant PrivateAPIServer
    participant DB

    User->>Client: 編成変更完了
    Client->>Client: 編成制約を検証
    Client->>PublicAPIServer: UpdateArenaParty
    PublicAPIServer->>GameServer: UpdateArenaParty
    GameServer->>GameServer: 送信された編成を同じ編成制約で再検証
    GameServer->>PrivateAPIServer: SaveArenaParty
    PrivateAPIServer->>DB: 編成情報登録
    DB-->>PrivateAPIServer: 登録完了
    PrivateAPIServer-->>GameServer: SaveArenaParty
    GameServer-->>PublicAPIServer: UpdateArenaParty
    PublicAPIServer-->>Client: UpdateArenaParty
    Client-->>User: 変更完了通知
```

### 対戦時

```mermaid
sequenceDiagram
    actor User
    participant Client
    participant PublicAPIServer
    participant GameServer
    participant PrivateAPIServer
    participant DB

    User->>Client: 対戦開始

    alt ランダム対戦
        Client->>PublicAPIServer: StartArenaBattle(AccessToken, PlayerID, ClientVersion, mode=random, LocalFormationID, LocalCharacters)
        PublicAPIServer->>GameServer: StartArenaBattle(PlayerID, ClientVersion, mode=random, LocalFormationID, LocalCharacters, AuthenticatedContext)
        GameServer->>GameServer: AuthenticatedContext・PlayerID等を検証
        GameServer->>GameServer: ClientVersion == GameServer Versionを検証
        GameServer->>GameServer: 共通内部API GenerateTimeBasedSeed で時刻ベースSeedを生成
        GameServer->>GameServer: PlayerID昇順の候補一覧へ生成したSeedを使用して対戦相手を抽選
        alt 候補プレイヤーが0人
            GameServer-->>PublicAPIServer: StartArenaBattle(ArenaBattleErrorResponse)
            PublicAPIServer-->>Client: StartArenaBattle(ArenaBattleErrorResponse)
        else 対戦相手決定
            GameServer->>PrivateAPIServer: GetArenaBattleData(PlayerID)
            PrivateAPIServer->>DB: 自分側編成データ取得
            DB-->>PrivateAPIServer: 自分側データ返却
            PrivateAPIServer-->>GameServer: GetArenaBattleData
            GameServer->>GameServer: LocalFormationID・LocalCharactersとServer保存自分側編成を比較
            alt 要求元PlayerのArenaParty未登録
                GameServer-->>PublicAPIServer: StartArenaBattle(ARENA_BATTLE_ERROR_REQUESTER_ARENA_PARTY_NOT_REGISTERED)
                PublicAPIServer-->>Client: StartArenaBattle(ArenaBattleErrorResponse)
            else 要求元PlayerのArenaParty登録済み
                GameServer->>PrivateAPIServer: GetArenaBattleData(OpponentPlayerID)
                PrivateAPIServer->>DB: 相手側編成データ取得
                DB-->>PrivateAPIServer: 相手側データ返却
                PrivateAPIServer-->>GameServer: GetArenaBattleData
                GameServer->>GameServer: 同じSeedから戦闘専用PRNGを新規生成
                GameServer->>GameServer: 自分側・相手側双方のFormationID・Charactersを初期状態として戦闘実行
                GameServer-->>PublicAPIServer: StartArenaBattle(OwnPartyMatched, OwnFormationID, OwnCharacters, EnemyFormationID, EnemyCharacters, Seed)
                PublicAPIServer-->>Client: StartArenaBattle(OwnPartyMatched, OwnFormationID, OwnCharacters, EnemyFormationID, EnemyCharacters, Seed)
                Client->>Client: OwnPartyMatched=falseならServer保存自分側編成でローカル編成を上書き
                Client->>Client: 同じSeedから戦闘専用PRNGを新規生成
                Client->>Client: EnemyFormationID・EnemyCharactersを使用してGameServerと同一の戦闘ロジックで戦闘を再現
                Client->>User: 戦闘内容表示
            end
        end
    else フレンド対戦
        Client->>PublicAPIServer: StartArenaBattle(AccessToken, PlayerID, ClientVersion, mode=friend, OpponentID, LocalFormationID, LocalCharacters)
        PublicAPIServer->>GameServer: StartArenaBattle(PlayerID, ClientVersion, mode=friend, OpponentID, LocalFormationID, LocalCharacters, AuthenticatedContext)
        GameServer->>GameServer: AuthenticatedContext・PlayerID等を検証
        GameServer->>GameServer: ClientVersion == GameServer Versionを検証
        GameServer->>GameServer: 共通内部API GenerateTimeBasedSeed で時刻ベースSeedを生成
        GameServer->>PrivateAPIServer: GetArenaBattleData(PlayerID)
        PrivateAPIServer->>DB: 自分側編成データ取得
        DB-->>PrivateAPIServer: 自分側データ返却
        PrivateAPIServer-->>GameServer: GetArenaBattleData
        GameServer->>GameServer: LocalFormationID・LocalCharactersとServer保存自分側編成を比較
        alt 要求元PlayerのArenaParty未登録
            GameServer-->>PublicAPIServer: StartArenaBattle(ARENA_BATTLE_ERROR_REQUESTER_ARENA_PARTY_NOT_REGISTERED)
            PublicAPIServer-->>Client: StartArenaBattle(ArenaBattleErrorResponse)
        else 要求元PlayerのArenaParty登録済み
            GameServer->>PrivateAPIServer: GetArenaBattleData(OpponentID)
            PrivateAPIServer->>DB: 相手側Player・ArenaPartyデータ取得
            DB-->>PrivateAPIServer: PlayerExists・ArenaPartyRegistered・編成データ返却
            PrivateAPIServer-->>GameServer: GetArenaBattleData
            alt OpponentIDが存在しない
                GameServer-->>PublicAPIServer: StartArenaBattle(ARENA_BATTLE_ERROR_PLAYER_NOT_FOUND)
                PublicAPIServer-->>Client: StartArenaBattle(ArenaBattleErrorResponse)
            else OpponentIDは存在するがArenaParty未登録
                GameServer-->>PublicAPIServer: StartArenaBattle(ARENA_BATTLE_ERROR_ARENA_PARTY_NOT_REGISTERED)
                PublicAPIServer-->>Client: StartArenaBattle(ArenaBattleErrorResponse)
            else 対戦可能
                GameServer->>GameServer: 同じSeedから戦闘専用PRNGを新規生成
                GameServer->>GameServer: 自分側・相手側双方のFormationID・Charactersを初期状態として戦闘実行
                GameServer-->>PublicAPIServer: StartArenaBattle(OwnPartyMatched, OwnFormationID, OwnCharacters, EnemyFormationID, EnemyCharacters, Seed)
                PublicAPIServer-->>Client: StartArenaBattle(OwnPartyMatched, OwnFormationID, OwnCharacters, EnemyFormationID, EnemyCharacters, Seed)
                Client->>Client: OwnPartyMatched=falseならServer保存自分側編成でローカル編成を上書き
                Client->>Client: 同じSeedから戦闘専用PRNGを新規生成
                Client->>Client: EnemyFormationID・EnemyCharactersを使用してGameServerと同一の戦闘ロジックで戦闘を再現
                Client->>User: 戦闘内容表示
            end
        end
    end
```


## ランダム対戦候補同期

GameServerはPrivateAPIの`GetAllPlayerIDs`を使用してDatabase上でArenaParty登録済みのPlayerIDだけをPlayerID昇順で取得し, その順序を維持してランダムアリーナ候補のPlayerIDキャッシュを同期する. ArenaParty未登録Playerは候補へ含めない. 抽選時は自身のPlayerIDを候補から除外し, 残りの候補もPlayerID昇順のまま「抽選」へ渡す.

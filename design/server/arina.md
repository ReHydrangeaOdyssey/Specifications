## シーケンス

### 編成登録時

```mermaid
sequenceDiagram
    actor User
    participant Client
    participant PublicAPIServer as Public API Server
    participant GameServer
    participant PrivateAPIServer as Private API Server
    participant Database

    User->>Client: 編成変更完了
    Client->>Client: 編成制約を検証
    Client->>PublicAPIServer: UpdateArenaParty
    PublicAPIServer->>GameServer: UpdateArenaParty
    GameServer->>GameServer: 送信された編成を同じ編成制約で再検証
    GameServer->>PrivateAPIServer: SaveArenaParty
    PrivateAPIServer->>Database: 編成情報登録
    Database-->>PrivateAPIServer: 登録完了
    PrivateAPIServer-->>GameServer: SaveArenaPartyResponse
    GameServer-->>PublicAPIServer: UpdateArenaPartyResponse
    PublicAPIServer-->>Client: UpdateArenaPartyResponse
    Client-->>User: 変更完了通知
```

### 対戦時

```mermaid
sequenceDiagram
    actor User
    participant Client
    participant PublicAPIServer as Public API Server
    participant GameServer
    participant PrivateAPIServer as Private API Server
    participant Database

    User->>Client: 対戦開始

    alt Mode=ARENA_MODE_RANDOM
        Client->>PublicAPIServer: StartArenaBattle(AccessToken, PlayerID, ClientVersion, Mode=ARENA_MODE_RANDOM, LocalFormationID, LocalCharacters)
        PublicAPIServer->>GameServer: StartArenaBattle(PlayerID, ClientVersion, Mode=ARENA_MODE_RANDOM, LocalFormationID, LocalCharacters, AuthenticatedContext)
        GameServer->>GameServer: AuthenticatedContext・PlayerID等を検証
        GameServer->>GameServer: ClientVersion == GameServer Versionを検証
        GameServer->>GameServer: 共通内部API GenerateTimeBasedSeed で時刻ベースSeedを生成
        GameServer->>PrivateAPIServer: GetAllPlayerIDs（対戦要求ごと）
        PrivateAPIServer->>Database: ArenaParty登録済みPlayerID取得
        Database-->>PrivateAPIServer: PlayerID昇順
        PrivateAPIServer-->>GameServer: 候補PlayerID一覧
        GameServer->>GameServer: 自身のPlayerIDを除外しSeedで対戦相手抽選
        alt 候補プレイヤーが0人
            GameServer-->>PublicAPIServer: ArenaBattleErrorResponse
            PublicAPIServer-->>Client: ArenaBattleErrorResponse
        else 対戦相手決定
            GameServer->>PrivateAPIServer: GetArenaBattleData(PlayerID)
            PrivateAPIServer->>Database: 自分側編成データ取得
            Database-->>PrivateAPIServer: 自分側データ返却
            PrivateAPIServer-->>GameServer: GetArenaBattleData
            GameServer->>GameServer: LocalFormationID・LocalCharactersとServer保存自分側編成を比較
            alt 要求元PlayerのArenaParty未登録
                GameServer-->>PublicAPIServer: ArenaBattleErrorResponse(ARENA_BATTLE_ERROR_REQUESTER_ARENA_PARTY_NOT_REGISTERED)
                PublicAPIServer-->>Client: ArenaBattleErrorResponse(ARENA_BATTLE_ERROR_REQUESTER_ARENA_PARTY_NOT_REGISTERED)
            else 要求元PlayerのArenaParty登録済み
                GameServer->>PrivateAPIServer: GetArenaBattleData(OpponentPlayerID)
                PrivateAPIServer->>Database: 相手側編成データ取得
                Database-->>PrivateAPIServer: 相手側データ返却
                PrivateAPIServer-->>GameServer: GetArenaBattleData
                GameServer->>GameServer: 同じSeedから戦闘専用PRNGを新規生成
                GameServer->>GameServer: 自分側・相手側双方のFormationID・Charactersを初期状態として戦闘実行
                GameServer-->>PublicAPIServer: ArenaBattleResponse(OwnPartyMatched, OwnFormationID, OwnCharacters, EnemyFormationID, EnemyCharacters, Seed, EnemyPlayerID)
                PublicAPIServer-->>Client: ArenaBattleResponse(OwnPartyMatched, OwnFormationID, OwnCharacters, EnemyFormationID, EnemyCharacters, Seed, EnemyPlayerID)
                Client->>Client: OwnPartyMatched=falseならServer保存自分側編成でローカル編成を上書き
                Client->>Client: 同じSeedから戦闘専用PRNGを新規生成
                Client->>Client: EnemyFormationID・EnemyCharactersを使用してGameServerと同一の戦闘ロジックで戦闘を再現
                Client->>User: 戦闘内容表示
            end
        end
    else Mode=ARENA_MODE_FRIEND
        Client->>PublicAPIServer: StartArenaBattle(AccessToken, PlayerID, ClientVersion, Mode=ARENA_MODE_FRIEND, OpponentID, LocalFormationID, LocalCharacters)
        PublicAPIServer->>GameServer: StartArenaBattle(PlayerID, ClientVersion, Mode=ARENA_MODE_FRIEND, OpponentID, LocalFormationID, LocalCharacters, AuthenticatedContext)
        GameServer->>GameServer: AuthenticatedContext・PlayerID等を検証
        GameServer->>GameServer: ClientVersion == GameServer Versionを検証
        GameServer->>GameServer: 共通内部API GenerateTimeBasedSeed で時刻ベースSeedを生成
        GameServer->>PrivateAPIServer: GetArenaBattleData(PlayerID)
        PrivateAPIServer->>Database: 自分側編成データ取得
        Database-->>PrivateAPIServer: 自分側データ返却
        PrivateAPIServer-->>GameServer: GetArenaBattleData
        GameServer->>GameServer: LocalFormationID・LocalCharactersとServer保存自分側編成を比較
        alt 要求元PlayerのArenaParty未登録
            GameServer-->>PublicAPIServer: ArenaBattleErrorResponse(ARENA_BATTLE_ERROR_REQUESTER_ARENA_PARTY_NOT_REGISTERED)
            PublicAPIServer-->>Client: ArenaBattleErrorResponse(ARENA_BATTLE_ERROR_REQUESTER_ARENA_PARTY_NOT_REGISTERED)
        else 要求元PlayerのArenaParty登録済み
            GameServer->>PrivateAPIServer: GetArenaBattleData(OpponentID)
            PrivateAPIServer->>Database: 相手側Player・ArenaPartyデータ取得
            Database-->>PrivateAPIServer: PlayerExists・ArenaPartyRegistered・編成データ返却
            PrivateAPIServer-->>GameServer: GetArenaBattleData
            alt OpponentIDが存在しない
                GameServer-->>PublicAPIServer: ArenaBattleErrorResponse(ARENA_BATTLE_ERROR_PLAYER_NOT_FOUND)
                PublicAPIServer-->>Client: ArenaBattleErrorResponse(ARENA_BATTLE_ERROR_PLAYER_NOT_FOUND)
            else OpponentIDは存在するがArenaParty未登録
                GameServer-->>PublicAPIServer: ArenaBattleErrorResponse(ARENA_BATTLE_ERROR_ARENA_PARTY_NOT_REGISTERED)
                PublicAPIServer-->>Client: ArenaBattleErrorResponse(ARENA_BATTLE_ERROR_ARENA_PARTY_NOT_REGISTERED)
            else 対戦可能
                GameServer->>GameServer: 同じSeedから戦闘専用PRNGを新規生成
                GameServer->>GameServer: 自分側・相手側双方のFormationID・Charactersを初期状態として戦闘実行
                GameServer-->>PublicAPIServer: ArenaBattleResponse(OwnPartyMatched, OwnFormationID, OwnCharacters, EnemyFormationID, EnemyCharacters, Seed, EnemyPlayerID)
                PublicAPIServer-->>Client: ArenaBattleResponse(OwnPartyMatched, OwnFormationID, OwnCharacters, EnemyFormationID, EnemyCharacters, Seed, EnemyPlayerID)
                Client->>Client: OwnPartyMatched=falseならServer保存自分側編成でローカル編成を上書き
                Client->>Client: 同じSeedから戦闘専用PRNGを新規生成
                Client->>Client: EnemyFormationID・EnemyCharactersを使用してGameServerと同一の戦闘ロジックで戦闘を再現
                Client->>User: 戦闘内容表示
            end
        end
    end
```


## ランダム対戦候補の取得

Random Arenaの対戦相手抽選では、要求ごとにPrivate API `GetAllPlayerIDs`を呼び、Database上にArenaPartyが登録されている通常PlayerのIDをPlayerID昇順で取得する。GameServerは候補一覧を保持・同期するキャッシュを設けない。要求元PlayerIDとシステムダミーPlayerID `0`を除いて、既存のSeedを用いた抽選を実行する。
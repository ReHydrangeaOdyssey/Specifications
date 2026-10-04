



## 戦闘結果の扱い

ClientとGameServerは同一バージョンの戦闘ロジックを保持する. GameServerは戦闘を実行するが、`StartArenaBattle`の成功レスポンスでは戦闘結果そのものを返さず、Clientで同じ戦闘を再現するための相手キャラクター初期状態とSeedを返す.

Clientは自身の初期状態、GameServerから受け取った相手初期状態、Seedを用いて同一の戦闘ロジックを実行する. 同一入力から算出される結果は一致することを前提とし、結果の正本はGameServerの計算結果とする.

## 遷移

```mermaid
stateDiagram-v2
    [*] --> アリーナ
    アリーナ --> ランダム対戦
    アリーナ --> フレンド対戦
    アリーナ --> 編成
    編成 --> アリーナ

    ランダム対戦 --> 戦闘
    フレンド対戦 --> 戦闘
    戦闘 --> 結果
    結果 --> アリーナ
```

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
    Client->>PublicAPIServer: UpdateArenaParty
    PublicAPIServer->>GameServer: UpdateArenaParty
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
        Client->>PublicAPIServer: StartArenaBattle(SessionID, PlayerID, mode=random)
        PublicAPIServer->>GameServer: StartArenaBattle(SessionID, PlayerID, mode=random)
        GameServer->>GameServer: SessionID・PlayerID等を検証
        GameServer->>GameServer: アリーナ戦闘用Seedを生成
        GameServer->>GameServer: 生成したSeedを使用して対戦相手を抽選
        alt 候補プレイヤーが0人
            GameServer-->>PublicAPIServer: StartArenaBattle(ArenaBattleErrorResponse)
            PublicAPIServer-->>Client: StartArenaBattle(ArenaBattleErrorResponse)
        else 対戦相手決定
            GameServer->>PrivateAPIServer: GetArenaBattleData(OpponentPlayerID)
            PrivateAPIServer->>DB: 必要データ取得
            DB-->>PrivateAPIServer: データ返却
            PrivateAPIServer-->>GameServer: GetArenaBattleData
            GameServer-->>PublicAPIServer: StartArenaBattle(EnemyCharacters, Seed)
            PublicAPIServer-->>Client: StartArenaBattle(EnemyCharacters, Seed)
            Client->>Client: GameServerと同一の戦闘ロジックで戦闘を再現
            Client->>User: 戦闘内容表示
        end
    else フレンド対戦
        Client->>PublicAPIServer: StartArenaBattle(SessionID, PlayerID, mode=friend, OpponentID)
        PublicAPIServer->>GameServer: StartArenaBattle(SessionID, PlayerID, mode=friend, OpponentID)
        GameServer->>GameServer: SessionID・PlayerID等を検証
        GameServer->>GameServer: アリーナ戦闘用Seedを生成
        GameServer->>PrivateAPIServer: GetArenaBattleData(OpponentID)
        PrivateAPIServer->>DB: 必要データ取得
        DB-->>PrivateAPIServer: データ返却
        PrivateAPIServer-->>GameServer: GetArenaBattleData
        GameServer-->>PublicAPIServer: StartArenaBattle(EnemyCharacters, Seed)
        PublicAPIServer-->>Client: StartArenaBattle(EnemyCharacters, Seed)
        Client->>Client: GameServerと同一の戦闘ロジックで戦闘を再現
        Client->>User: 戦闘内容表示
    end
```


## ランダム対戦候補同期

GameServerはPrivateAPIの`GetAllPlayerIDs`を使用してDatabase上の全PlayerIDを取得し、ランダムアリーナ候補のPlayerIDキャッシュを同期する。抽選時は自身のPlayerIDを候補から除外する。

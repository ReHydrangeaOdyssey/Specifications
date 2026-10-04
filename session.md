# セッション仕様


* 複数端末からのアクセスは不可
* OPFS上に保存される
* セッションIDの期限は72時間
  - 以下アクション時に期限がリセットされる
    - ログイン時
    - 騎士団戦参加時


### セッションID新規取得

GameServerはBotから起動される. BotはGameServer起動時に`[a-zA-Z0-9_]{64}`のTokenを生成し, 起動引数としてGameServerへ渡す.
botの検証は特定のロールを持っているか, 前回要求時から5分以上経過しているか
アクセストークンの期限は5分
アクセストークンおよびセッションIDの型は「[型定義](types.md)」を参照


```mermaid
sequenceDiagram
    actor User
    participant Discord
    participant Bot
    participant Client
    participant PublicAPIServer
    participant GameServer
    participant PrivateAPIServer
    participant DB

    User->>Discord: セッションID要求
    Discord->>Bot: ユーザーID送信
    Bot->>Bot: 検証

    alt 検証成功
        Bot->>PublicAPIServer: IssueAccessToken(Token)
        PublicAPIServer->>GameServer: IssueAccessToken(Token)
        GameServer->>GameServer: 起動時Tokenとの一致検証
        GameServer->>GameServer: アクセストークン生成
        GameServer-->>PublicAPIServer: IssueAccessToken
        PublicAPIServer-->>Bot: IssueAccessToken
        Bot-->>Discord: アクセストークン返答
        Discord-->>User: アクセストークン返答(DM)

        User->>Client: アクセストークン入力
        Client->>Client: PlayerIDチェック
        opt PlayerID が 0
            Client->>User: ユーザー名要求
            User->>Client: ユーザー名入力
            Client->>Client: ユーザー名チェック
            Client->>PublicAPIServer: CreatePlayer(UserName, AccessToken)
            PublicAPIServer->>GameServer: CreatePlayer(UserName, AccessToken)
            GameServer->>GameServer: AccessToken検証
            GameServer->>GameServer: ユーザー名チェック
            GameServer->>GameServer: PlayerID生成
            GameServer->>PrivateAPIServer: SavePlayerID
            PrivateAPIServer->DB: 保存(PlayerID, ユーザー名)
            GameServer-->>PublicAPIServer: CreatePlayer
            PublicAPIServer-->>Client: CreatePlayer
            Client->>Client: PlayerID保存
        end

        Client->>PublicAPIServer: Login(PlayerID, AccessToken) 
        PublicAPIServer->>GameServer: Login(PlayerID, AccessToken) 
        GameServer->>GameServer: アクセストークン無効化
        GameServer->>GameServer: セッションID生成
        GameServer->>PrivateAPIServer: SaveSessionID
        PrivateAPIServer->DB: 送信(PlayerID, セッションID, 期限)
        GameServer-->>PublicAPIServer: Login
        PublicAPIServer-->>Client: Login    
        Client->>Client: セッションID保存
    else 検証失敗
        Bot-->>Discord: 検証失敗返答
        Discord-->>User: 検証失敗返答
    end
```

#### 複数端末ログイン時

```mermaid
sequenceDiagram
    actor User
    participant ClientA as 既存Client
    participant ClientB as 新Client
    participant PublicAPI
    participant GameServer
    participant PrivateAPIServer
    participant Database

    User->>ClientB: ログイン操作
    ClientB->>PublicAPI: Login(PlayerID, AccessToken)
    PublicAPI->>GameServer: Login(PlayerID, AccessToken)

    GameServer->>PrivateAPIServer: GetActiveSession
    PrivateAPIServer->>Database: PlayerIDの有効Session検索
    Database-->>PrivateAPIServer: ExistingSession
    PrivateAPIServer-->>GameServer: GetActiveSession

    alt 有効なSessionが存在する
        GameServer->>PrivateAPIServer: InvalidateSession
        PrivateAPIServer->>Database: ExistingSessionを無効化
        Database-->>PrivateAPIServer: 無効化完了
        PrivateAPIServer-->>GameServer: InvalidateSession

        GameServer->>GameServer: 新しいSessionID生成
        GameServer->>PrivateAPIServer: SaveSessionID
        PrivateAPIServer->>Database: 新Session登録(PlayerID, SessionID, 期限)
        Database-->>PrivateAPIServer: 登録完了
        PrivateAPIServer-->>GameServer: SaveSessionID

        GameServer-->>PublicAPI: Login
        PublicAPI-->>ClientB: Login

        ClientA->>PublicAPI: ValidateSession(ExistingSession)
        PublicAPI->>GameServer: ValidateSession(ExistingSession)
        GameServer->>PrivateAPIServer: ValidateSession
        PrivateAPIServer->>Database: Session確認
        Database-->>PrivateAPIServer: 無効
        PrivateAPIServer-->>GameServer: ValidateSession
        GameServer-->>PublicAPI: ValidateSession
        PublicAPI-->>ClientA: ValidateSession
    else 有効なSessionが存在しない
        GameServer->>GameServer: 新しいSessionID生成
        GameServer->>PrivateAPIServer: SaveSessionID
        PrivateAPIServer->>Database: 新Session登録(PlayerID, SessionID, 期限)
        Database-->>PrivateAPIServer: 登録完了
        PrivateAPIServer-->>GameServer: SaveSessionID

        GameServer-->>PublicAPI: Login
        PublicAPI-->>ClientB: Login
    end
```

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
        Note over Client: PlayerID=0は未取得を表す予約値
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
            Client->>Client: PlayerID保存・新規プレイヤーフラグ保持
        end

        Client->>PublicAPIServer: Login(PlayerID, AccessToken) 
        PublicAPIServer->>GameServer: Login(PlayerID, AccessToken) 
        GameServer->>GameServer: AccessToken検証
        GameServer->>GameServer: Login成功時にAccessToken無効化
        GameServer->>GameServer: 暗号学的乱数でセッションID生成
        GameServer->>PrivateAPIServer: SaveSessionID
        PrivateAPIServer->DB: UPSERT(PlayerID, セッションID, 期限)
        GameServer-->>PublicAPIServer: Login
        PublicAPIServer-->>Client: Login    
        Client->>Client: セッションID保存

        opt 新規作成したPlayerIDの場合
            Client->>User: 初期騎士団名・昼開始時刻・夜開始時刻を要求
            User->>Client: 初期騎士団設定入力
            Client->>PublicAPIServer: CreateGuild(SessionID, PlayerID, GuildName, DaytimeStartTime, NighttimeStartTime)
            PublicAPIServer->>GameServer: CreateGuild
            GameServer->>PrivateAPIServer: SaveGuild(GuildID=PlayerID, GuildName, LeaderPlayerID=PlayerID, DaytimeStartTime, NighttimeStartTime)
            PrivateAPIServer->>DB: 初期騎士団・初期所属を保存
            DB-->>PrivateAPIServer: 保存完了
            PrivateAPIServer-->>GameServer: SaveGuild
            GameServer-->>PublicAPIServer: CreateGuild
            PublicAPIServer-->>Client: CreateGuild
        end
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
        PrivateAPIServer->>Database: ExistingSessionレコードを削除
        Database-->>PrivateAPIServer: 削除完了
        PrivateAPIServer-->>GameServer: InvalidateSession

        GameServer->>GameServer: 新しいSessionID生成
        GameServer->>PrivateAPIServer: SaveSessionID
        PrivateAPIServer->>Database: Session UPSERT(PlayerID, SessionID, 期限)
        Database-->>PrivateAPIServer: 登録完了
        PrivateAPIServer-->>GameServer: SaveSessionID

        GameServer-->>PublicAPI: Login
        PublicAPI-->>ClientB: Login

        ClientA->>PublicAPI: ValidateSession(ExistingSession, PlayerID)
        PublicAPI->>GameServer: ValidateSession(ExistingSession, PlayerID)
        GameServer->>PrivateAPIServer: ValidateSession(SessionID, PlayerID)
        PrivateAPIServer->>Database: Session確認
        Database-->>PrivateAPIServer: 無効
        PrivateAPIServer-->>GameServer: ValidateSession
        GameServer-->>PublicAPI: ValidateSession
        PublicAPI-->>ClientA: ValidateSession
    else 有効なSessionが存在しない
        GameServer->>GameServer: 新しいSessionID生成
        GameServer->>PrivateAPIServer: SaveSessionID
        PrivateAPIServer->>Database: Session UPSERT(PlayerID, SessionID, 期限)
        Database-->>PrivateAPIServer: 登録完了
        PrivateAPIServer-->>GameServer: SaveSessionID

        GameServer-->>PublicAPI: Login
        PublicAPI-->>ClientB: Login
    end
```


## SessionID生成規則

* SessionIDは暗号学的乱数で生成する.
* Databaseの`PLAYER_SESSION.session_id` UNIQUE制約に衝突した場合、Private APIは`SaveSessionIDErrorResponse`で`SAVE_SESSION_ID_ERROR_SESSION_ID_CONFLICT`を返す. GameServerはSessionIDを再生成して`SaveSessionID`を再実行する.
* `SaveSessionID`はPlayerIDを競合キーとしたUPSERTとする.

## PublicAPIでのSession検証

SessionIDを要求するPublicAPIは、要求本体を処理する前に以下をすべて検証する.

* Sessionレコードが存在すること.
* Sessionが有効期限内であること.
* SessionIDが要求PlayerIDに所有されていること.

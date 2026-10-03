# セッション仕様


* 複数端末からのアクセスは不可
* OPFS上に保存される
* セッションIDの期限は72時間
  - 以下アクション時に期限がリセットされる
    - ログイン時
    - 騎士団戦参加時


### セッションID新規取得

botの検証は特定のロールを持っているか, 前回要求時から5分以上経過しているか
アクセストークンの期限は5分
アクセストークンはu64
セッションIDはu64


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
        Bot->>PublicAPIServer: アクセストークン要求
        PublicAPIServer->>GameServer: アクセストークン要求
        GameServer->>GameServer: 送信元検証
        GameServer->>GameServer: アクセストークン生成
        GameServer-->>PublicAPIServer: アクセストークン返答
        PublicAPIServer-->>Bot: アクセストークン返答
        Bot-->>Discord: アクセストークン返答
        Discord-->>User: アクセストークン返答(DM)

        User->>Client: アクセストークン入力
        Client->>Client: PlayerIDチェック
        opt PlayerID が 0
            Client->>User: ユーザー名要求
            User->>Client: ユーザー名入力
            Client->>Client: ユーザー名チェック
            Client->>PublicAPIServer: 新規PlayerID要求(ユーザー名)
            PublicAPIServer->>GameServer: 新規PlayerID要求(ユーザー名)
            GameServer->>GameServer: ユーザー名チェック
            GameServer->>GameServer: PlayerID生成
            GameServer->PrivateAPIServer: 送信(PlayerID)
            PrivateAPIServer->DB: 保存(PlayerID)
            GameServer-->>PublicAPIServer: PlayerID返答
            PublicAPIServer-->>Client: PlayerID返答
            Client->>Client: PlayerID保存
        end

        Client->>PublicAPIServer: ログイン要求(PlayerID, AccessToken) 
        PublicAPIServer->>GameServer: ログイン要求(PlayerID, AccessToken) 
        GameServer->>GameServer: アクセストークン無効化
        GameServer->>GameServer: セッションID生成
        GameServer->PrivateAPIServer: 送信(PlayerID, セッションID)
        PrivateAPIServer->DB: セッションID保存
        GameServer-->>PublicAPIServer: セッションID返答
        PublicAPIServer-->>Client: セッションID返答    
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
    participant Database

    User->>ClientB: ログイン操作
    ClientB->>PublicAPI: ログイン要求(PlayerID, AccessToken)
    PublicAPI->>GameServer: ログイン要求(PlayerID, AccessToken)

    GameServer->>Database: PlayerIDの有効Session検索
    Database-->>GameServer: ExistingSession

    alt 有効なSessionが存在する
        GameServer->>Database: ExistingSessionを無効化
        Database-->>GameServer: 無効化完了

        GameServer->>GameServer: 新しいSessionID生成
        GameServer->>Database: 新Session登録(PlayerID, SessionID)
        Database-->>GameServer: 登録完了

        GameServer-->>PublicAPI: ログイン成功(SessionID)
        PublicAPI-->>ClientB: ログイン成功(SessionID)

        ClientA->>PublicAPI: ExistingSessionを使用したAPI要求
        PublicAPI->>GameServer: API要求(ExistingSession)
        GameServer->>Database: Session確認
        Database-->>GameServer: 無効
        GameServer-->>PublicAPI: Session無効
        PublicAPI-->>ClientA: 再ログイン要求
    else 有効なSessionが存在しない
        GameServer->>GameServer: 新しいSessionID生成
        GameServer->>Database: 新Session登録(PlayerID, SessionID)
        Database-->>GameServer: 登録完了

        GameServer-->>PublicAPI: ログイン成功(SessionID)
        PublicAPI-->>ClientB: ログイン成功(SessionID)
    end
```
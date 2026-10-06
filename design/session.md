# セッション仕様

* Accountの本人認証は`LoginID`と`Password`を使用する.
* Discord Bot連携はOptionとし, Accountの本人認証方式そのものには使用しない.
* Discord Bot連携では運営通知とDiscordロールによる追加認可を行う. 2つの機能は個別に有効・無効を設定可能とする.
* `DiscordAuthorizationRequired=true`の場合, Account新規作成およびLoginにはDiscord Botが発行した`DiscordAuthorizationToken`を必須とする. 現在の運用では`DiscordAuthorizationRequired=true`とする.
* `DiscordAuthorizationRequired=false`の場合, Discord Botを導入せずにAccount新規作成およびLoginを行える.
* Discordロールによる追加認可はAccountとDiscordUserIDの本人性Bindingには使用せず, 設定されたDiscord Guild内で必要Roleを保持していることの確認として扱う.
* `DiscordNotificationEnabled=true`の場合, GameServerおよびPrivate API Serverから運営向け通知をDiscord Botへ送信する. `false`の場合はBot通知を行わず, ErrorLog等の既存処理だけを行う.
* `ACCOUNT`と`PLAYER`は分離し, 認証主体を`ACCOUNT`, ゲーム上の主体を`PLAYER`とする.
* 1つのAccountに同時に保持できる有効なRefresh Sessionは1つだけとする.
* 新規Login成功時は既存Refresh Sessionを無効化してから新しいSessionを作成する.
* AccessTokenは短寿命の署名付きTokenとし, 通常PublicAPIの認証に使用する.
* RefreshTokenはAccessToken更新専用の長寿命Tokenとし, 通常のゲームAPIには使用しない.
* AccessTokenおよびRefreshTokenはClientのOPFS上に保存する.
* Refresh Sessionの期限は72時間とする.
  - 以下アクション時に期限をリセットする.
    - ログイン時.
    - 騎士団戦参加時.
* AccessTokenの期限は5分とする.
* 新規LoginまたはLogoutでRefresh Sessionを無効化した場合でも, 既に発行済みのAccessTokenは自身の`exp`到達まで最大5分間有効とする. AccessTokenごとの失効確認のためにPublicAPIからDatabaseへ問い合わせる方式とはしない.

## Discord Bot設定

| 設定 | 内容 | 現在の運用値 |
|---|---|---|
| `DiscordAuthorizationRequired` | Account新規作成およびLoginでDiscordロール追加認可を必須とするか | `true` |
| `DiscordNotificationEnabled` | 運営向け通知をDiscord Botへ送信するか | `true` |
| `DiscordGuildID` | 追加認可でRole確認対象とするDiscord Guild | 運用設定で指定する |
| `DiscordRequiredRoleID` | 追加認可で保持を必須とするDiscord Role | 運用設定で指定する |

* `DiscordAuthorizationRequired=false`の場合, `DiscordGuildID`および`DiscordRequiredRoleID`を追加認可には使用しない.
* `DiscordAuthorizationRequired=true`の場合, Discord Botを使用せずに新規Account作成または新規Loginを成功させる経路を設けない.
* `DiscordNotificationEnabled=false`の場合, 通知先Botが存在しないことをエラーとしてゲーム処理へ反映しない.

## Discord Bot追加認可

* Discord Botは設定されたDiscord Guild内で要求元DiscordUserIDが設定されたRoleを保持していることを確認する.
* Bot側のToken発行要求は, 同一DiscordUserIDについて前回要求時から5分以上経過している場合だけ許可する.
* Role確認成功後, Botは`DiscordAuthorizationToken`を生成し, Botが保持するEd25519秘密鍵で署名する.
* `DiscordAuthorizationToken`の有効期限は発行時刻から5分とする.
* `DiscordAuthorizationToken`はJWT Compact Serializationを使用し, AccessTokenとは別の署名鍵を使用する. Discord追加認可Token署名用秘密鍵はBotだけが保持し, Public API Serverは検証用公開鍵だけを保持する.
* `DiscordAuthorizationToken`には以下Claimを含める.
  - `iss`: Discord追加認可Token発行元を識別する固定値.
  - `aud`: `game-discord-authorization`.
  - `sub`: `DiscordUserID`を10進文字列化した値.
  - `iat`: 発行時刻.
  - `exp`: 有効期限.
* Public API Serverは`DiscordAuthorizationRequired=true`の場合, `CreateAccount`および`Login`の処理前に`DiscordAuthorizationToken`について以下をすべて検証する.
  - JWT構文が正しい.
  - `alg=EdDSA`である.
  - Discord追加認可Token検証用公開鍵で署名を正常に検証できる.
  - `iss`がDiscord追加認可Token用設定値と一致する.
  - `aud=game-discord-authorization`である.
  - 現在時刻が`exp`未満である.
* `DiscordAuthorizationToken`はAccountまたはPlayerIDへBindingしない. Role保持者であることだけを追加認可条件として扱う.
* `RefreshAccessToken`ではDiscordロールの再確認を行わない. Discord追加認可は新規Account作成および新規Login時だけ行う.
* Discord Bot連携用のGuild ID, Role ID, Bot Token, Bot通知用mTLS秘密鍵およびDiscord追加認可Token署名用秘密鍵をソースコードまたは公開リポジトリへ保存しない.

## LoginID

* LoginIDは3文字以上64文字以下とする.
* 使用可能文字はASCII英数字, `.`, `_`, `-`だけとする.
* LoginIDは大文字小文字を区別する.
* LoginIDはDatabase上で一意とする.

## Password

* Passwordは平文でDatabaseへ保存しない.
* PasswordはPrivate API ServerでArgon2idを使用してPasswordHashへ変換して保存する.
* Argon2idの最低パラメータは以下とする.
  - memory: 19456 KiB.
  - iterations: 2.
  - parallelism: 1.
* 実運用では上記を下回らない範囲で対象Server上の計測結果に応じて引き上げることを許可する.
* Passwordの最小長は15文字, 最大長は128文字とする.
* Passwordへ文字種の組み合わせ規則を設けない.
* PasswordをApplication Log, Access Log, Traceへ出力しない.

## AccessToken

* AccessTokenはJWT Compact Serializationを使用する.
* AccessTokenの署名アルゴリズムはEd25519を使用し, JOSE上の`alg`は`EdDSA`に固定する.
* Private API Serverだけが署名用秘密鍵を保持する.
* Public API Serverは検証用公開鍵を保持し, AccessToken検証時にPrivate API ServerまたはDatabaseへ問い合わせない.
* AccessTokenには以下Claimを含める.
  - `iss`: Token発行元を識別する固定値.
  - `aud`: `game-api`.
  - `sub`: `AccountID`を10進文字列化した値.
  - `player_id`: `PlayerID`.
  - `sid`: `SessionID`.
  - `iat`: 発行時刻.
  - `exp`: 有効期限.
* Public API ServerはAccessTokenについて以下をすべて検証する.
  - JWT構文が正しい.
  - `alg=EdDSA`である.
  - 署名が検証用公開鍵で正常に検証できる.
  - `iss`が設定値と一致する.
  - `aud=game-api`である.
  - 現在時刻が`exp`未満である.
  - `player_id`が要求`PlayerID`と一致する.
* 検証成功後, Public API Serverは`AccountID`, `PlayerID`, `SessionID`から`AuthenticatedContext`を生成し, mTLS接続上でGameServerへ要求と共に中継する.
* Clientから受信した`AuthenticatedContext`を使用しない.

## RefreshToken

* RefreshTokenは32byteの暗号学的乱数で生成する.
* DatabaseへRefreshTokenの平文を保存しない.
* Databaseへは`SHA-256(RefreshToken)`を`refresh_token_hash`として保存する.
* RefreshToken更新成功時は新しいRefreshTokenを生成し, Database上の`refresh_token_hash`を置換する. 更新前RefreshTokenは再利用できない.
* 同一RefreshTokenによる更新要求が同時に到達した場合でも成功する要求は1つだけとし, 検証と`refresh_token_hash`置換を同一トランザクション内で排他的に行う.
* RefreshTokenの期限は対応するRefresh Sessionの期限と同一とする.

## アカウント新規作成

```mermaid
sequenceDiagram
    actor User
    participant Discord
    participant Bot
    participant Client
    participant PublicAPIServer
    participant PrivateAPIServer
    participant DB

    opt DiscordAuthorizationRequired=true
        User->>Discord: Discord追加認可Token要求
        Discord->>Bot: DiscordUserID
        Bot->>Bot: Guild・Role・前回要求時刻を検証
        Bot->>Bot: DiscordAuthorizationToken生成・Ed25519署名
        Bot-->>Discord: DiscordAuthorizationToken返答
        Discord-->>User: DiscordAuthorizationToken返答(DM)
    end

    User->>Client: LoginID・Password・ユーザー名入力
    Client->>PublicAPIServer: CreateAccount(LoginID, Password, UserName, DiscordAuthorizationToken)
    PublicAPIServer->>PublicAPIServer: 必要な場合DiscordAuthorizationToken検証
    PublicAPIServer->>PrivateAPIServer: CreateAccount(LoginID, Password, UserName)
    PrivateAPIServer->>PrivateAPIServer: LoginID・Password・UserName検証
    PrivateAPIServer->>PrivateAPIServer: Argon2idでPasswordHash生成
    PrivateAPIServer->>PrivateAPIServer: AccountID・PlayerID生成
    PrivateAPIServer->>DB: ACCOUNT・PLAYERを同一トランザクションで保存
    DB-->>PrivateAPIServer: 保存完了
    PrivateAPIServer-->>PublicAPIServer: CreateAccount(PlayerID)
    PublicAPIServer-->>Client: CreateAccount(PlayerID)
    Client->>Client: PlayerID保存・新規プレイヤーフラグ保持
```

* `LoginID`はDatabase上で一意とする.
* `UserName`は既存のPlayerユーザー名制約に従う.
* Account作成とPlayer作成は同一トランザクションで行う.
* AccountIDおよびPlayerIDは予約済み無効値を生成しない.

## ログイン

```mermaid
sequenceDiagram
    actor User
    participant Discord
    participant Bot
    participant Client
    participant PublicAPIServer
    participant PrivateAPIServer
    participant DB

    opt DiscordAuthorizationRequired=true
        User->>Discord: Discord追加認可Token要求
        Discord->>Bot: DiscordUserID
        Bot->>Bot: Guild・Role・前回要求時刻を検証
        Bot->>Bot: DiscordAuthorizationToken生成・Ed25519署名
        Bot-->>Discord: DiscordAuthorizationToken返答
        Discord-->>User: DiscordAuthorizationToken返答(DM)
    end

    User->>Client: ログイン操作
    Client->>PublicAPIServer: Login(LoginID, Password, ClientVersion, DiscordAuthorizationToken)
    PublicAPIServer->>PublicAPIServer: ClientVersion == RequiredVersionを確認

    alt Version一致
        PublicAPIServer->>PublicAPIServer: 必要な場合DiscordAuthorizationToken検証
        PublicAPIServer->>PrivateAPIServer: AuthenticateAccount(LoginID, Password)
        PrivateAPIServer->>DB: LoginIDに対応するACCOUNT・PLAYER取得
        DB-->>PrivateAPIServer: Account・Player
        PrivateAPIServer->>PrivateAPIServer: Argon2idでPassword検証

        alt 認証成功
            PrivateAPIServer->>DB: 既存ACCOUNT_SESSION削除
            PrivateAPIServer->>PrivateAPIServer: SessionID・RefreshToken生成
            PrivateAPIServer->>DB: ACCOUNT_SESSION保存(SessionID, RefreshTokenHash, 期限72時間後)
            PrivateAPIServer->>PrivateAPIServer: AccessToken生成・Ed25519署名
            PrivateAPIServer-->>PublicAPIServer: AuthenticateAccount(PlayerID, AccessToken, RefreshToken)
            PublicAPIServer-->>Client: Login(PlayerID, AccessToken, RefreshToken)
            Client->>Client: AccessToken・RefreshToken保存
        else 認証失敗
            PrivateAPIServer-->>PublicAPIServer: 認証失敗
            PublicAPIServer-->>Client: API_ERROR_INVALID_CREDENTIALS
        end
    else Version不一致
        PublicAPIServer-->>Client: LoginVersionErrorResponse
    end
```

* Public API Serverは現在要求する`Version`を保持し, Login時に`LoginRequest.ClientVersion`との一致を検証する.
* `DiscordAuthorizationRequired=true`の場合, Discord追加認可Tokenの未指定は`API_ERROR_DISCORD_AUTHORIZATION_REQUIRED`, 不正または期限切れは`API_ERROR_INVALID_DISCORD_AUTHORIZATION_TOKEN`として返す.
* LoginID不存在とPassword不一致はClientへ同一の`API_ERROR_INVALID_CREDENTIALS`として返す.
* Login成功時に既存`ACCOUNT_SESSION`を削除してから新しいSessionを保存する.
* Login成功後, 旧RefreshTokenは使用できない.
* 旧AccessTokenは自身の`exp`到達まで最大5分間有効である.

## AccessToken更新

```mermaid
sequenceDiagram
    actor Client
    participant PublicAPIServer
    participant PrivateAPIServer
    participant DB

    Client->>PublicAPIServer: RefreshAccessToken(RefreshToken)
    PublicAPIServer->>PrivateAPIServer: RefreshAccessToken(RefreshToken)
    PrivateAPIServer->>PrivateAPIServer: SHA-256(RefreshToken)
    PrivateAPIServer->>DB: refresh_token_hash検索・期限確認
    DB-->>PrivateAPIServer: ACCOUNT_SESSION・PLAYER

    alt 有効
        PrivateAPIServer->>PrivateAPIServer: 新RefreshToken生成
        PrivateAPIServer->>DB: refresh_token_hashを新しいHashへ更新
        PrivateAPIServer->>PrivateAPIServer: 新AccessToken生成・Ed25519署名
        PrivateAPIServer-->>PublicAPIServer: AccessToken・RefreshToken
        PublicAPIServer-->>Client: AccessToken・RefreshToken
    else 無効
        PrivateAPIServer-->>PublicAPIServer: 無効
        PublicAPIServer-->>Client: API_ERROR_INVALID_REFRESH_TOKEN
    end
```

* RefreshToken更新ではRefresh Sessionの72時間期限を延長しない.
* 期限延長はLogin成功時および騎士団戦参加成功時だけ行う.

## Logout

```mermaid
sequenceDiagram
    actor Client
    participant PublicAPIServer
    participant PrivateAPIServer
    participant DB

    Client->>PublicAPIServer: Logout(RefreshToken)
    PublicAPIServer->>PrivateAPIServer: Logout(RefreshToken)
    PrivateAPIServer->>PrivateAPIServer: SHA-256(RefreshToken)
    PrivateAPIServer->>DB: 該当ACCOUNT_SESSION削除
    DB-->>PrivateAPIServer: 削除完了
    PrivateAPIServer-->>PublicAPIServer: Logout
    PublicAPIServer-->>Client: Logout
    Client->>Client: AccessToken・RefreshToken削除
```

* Logout後も既に発行済みのAccessTokenは自身の`exp`到達まで最大5分間有効とする.

## 騎士団戦参加時のSession期限更新

* Public API ServerはAccessToken検証後に`AuthenticatedContext`をGameServerへ渡す.
* GameServerは騎士団戦参加条件を満たした場合, `AuthenticatedContext.SessionID`を使用してPrivate APIの`ExtendAccountSession`を要求する.
* `ACCOUNT_SESSION`が存在しない, または既に期限切れの場合は騎士団戦へ参加させない.
* 更新成功時はRefresh Sessionの期限を更新時刻から72時間後へ変更する.

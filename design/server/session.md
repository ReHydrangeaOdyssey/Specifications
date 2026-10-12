# セッション仕様

* Accountの本人認証は`LoginID`と`Password`を使用する.
* Discord Bot連携はOptionとし, Accountの本人認証方式そのものには使用しない.
* Discord Bot連携では運営通知とDiscordロールによる追加認可を行う. 2つの機能は個別に有効・無効を設定可能とする.
* 運営者は追加認可方式を`AdditionalAuthorizationProvider`で選択する。現在の運用では`DISCORD`とする。
* `AdditionalAuthorizationProvider=NONE`の場合、追加認可Tokenを必要とせず、既存のLoginID/Password認証は維持する。
* `AdditionalAuthorizationProvider=DISCORD`で作成したAccountは`DiscordAuthorizationToken.sub`のDiscordUserIDをAccountへBindingし、Login時は同一DiscordUserIDのTokenだけを許可する。
* `DiscordNotificationEnabled=true`の場合, GameServer, GuildBattleCoordinatorおよびPrivate API Serverから運営向け通知をDiscord Botへ送信する. `false`の場合はBot通知を行わず, ErrorLog等の既存処理だけを行う.
* `ACCOUNT`と`PLAYER`は分離し, 認証主体を`ACCOUNT`, ゲーム上の主体を`PLAYER`とする.
* 1つのAccountに同時に保持できる有効なRefresh Sessionは1つだけとする.
* 新規Login成功時は既存Refresh Sessionを無効化してから新しいSessionを作成する.
* AccessTokenは短寿命の署名付きTokenとし, 通常PublicAPIの認証に使用する.
* RefreshTokenはAccessToken更新専用の長寿命Tokenとし, 通常のゲームAPIには使用しない.
* AccessTokenはClientのプロセスメモリ上だけに保持し, OPFS, LocalStorage, IndexedDB等の永続Client Storageへ保存しない.
* RefreshTokenはClient JavaScriptから参照可能なStorageへ保存せず, Public API Serverが`__Host-RefreshToken` Cookieとして設定する.
  - `Secure`を必須とする.
  - `HttpOnly`を必須とする.
  - `SameSite=Strict`とする.
  - `Path=/`とする.
  - `Domain`属性を指定しない.
  - Cookieの`Expires`または`Max-Age`は対応するRefresh Sessionの期限を超えない.
* Refresh Sessionの期限はLogin成功時刻から24時間後とし, Login後に延長しない.
* AccessTokenの期限は5分とする.
* 新規Login, Logout, Discord Role喪失またはRefreshToken再利用検知でRefresh Sessionを無効化した場合でも, 既に発行済みのAccessTokenは自身の`exp`到達まで最大5分間有効とする. AccessTokenごとの失効確認のためにPublicAPIからDatabaseへ問い合わせる方式とはしない.

Cross-Site配布時の認証は`design/system/network.md`の「静的Clientと認証Originが異なる場合の認証手順」に従う. 既存のRefresh Session回転・期限・Cookie属性は変更しない. 認証APIのClient側呼出元を表す後続のシーケンス図は認証Origin上の画面による第一者要求を論理的に示すものであり, 別Siteの静的配布ClientがStrict Cookieを付けて直接呼ぶことを意味しない.

## 追加認可方式の選択

Accountの`LoginID`・`Password`による本人認証と、運営者が構成時に選ぶ**追加認可**は分離する。追加認可の運用設定`AdditionalAuthorizationProvider`は以下のいずれか1値とし、サーバー側設定だけで選択する。Clientが申告した方式に切り替えてはならない。

| 値 | 追加認可の扱い |
|---|---|
| `DISCORD` | 従来のDiscord Role追加認可Tokenの署名、Claim、期限、Binding、再利用防止を実施する。現在の運用既定値。 |
| `POCKETBASE` | PocketBase側で認証済みであることをServerが検証する追加認可Adapterを使用する。Clientから受け取るユーザーID自体を検証済み主体とはみなさない。 |
| `OTHER` | 他の認証サービス用の拡張予約値。検証Adapter未実装では有効化を拒否する。 |
| `NONE` | 追加認可を要求しない。`LoginID`・`Password`認証、AccessToken、RefreshSession、Rate Limitは維持する。公開環境では非推奨。 |

- `DISCORD`は従来の`DiscordAuthorizationRequired=true`、`NONE`は`false`に相当する。`DiscordAuthorizationRequired`との二重設定は許可せず、移行後は`AdditionalAuthorizationProvider`を正本とする。`DiscordNotificationEnabled`はこの設定から独立して有効化できる。
- `DISCORD`では既存の`discord_authorization_token`を受け付ける。`POCKETBASE`などの非Discord方式ではPublic Requestの`additional_authorization_token`からAdapterが検証する。`NONE`では追加Tokenを必須としない。**選択中の方式の検証済み結果がない場合はAccount作成・Loginを拒否する**（`NONE`を除く）。
- Adapterが正本のサービスに対して署名・有効期限・発行者・Audience・必要な権限を検証して確定した`provider`と不変の`subject`だけをPrivate APIへ渡す。検証の具体的方式は対象サービスのAdapter契約による。`POCKETBASE`について具体的な資格情報の取得・検証を提供する実装がない場合、構成の起動時に失敗させ、無検証で通過させない。
- `ACCOUNT`に`additional_authorization_provider`と`additional_authorization_subject`を持ち、追加認可有効時は登録時の組をLogin時に照合する。既存Discord Accountの`discord_user_id`は移行時に`DISCORD`のsubjectへ対応付ける。`NONE`は追加認可のBindingを要求しない。異なる方式への既存Account移行を自動で行わない。
- `NONE`も認証不要な匿名アクセスを意味しない。認証なしの匿名ログインを許可する仕様は追加しない。

## Discord Bot設定

| 設定 | 内容 | 現在の運用値 |
|---|---|---|
| `AdditionalAuthorizationProvider` | Account新規作成およびLoginで追加認可に使う方式。`DISCORD`/`POCKETBASE`/`OTHER`/`NONE` | `DISCORD` |
| `DiscordNotificationEnabled` | 運営向け通知をDiscord Botへ送信するか | `true` |
| `DiscordGuildID` | 追加認可でRole確認対象とするDiscord Guild | 運用設定で指定する |
| `DiscordRequiredRoleID` | 追加認可で保持を必須とするDiscord Role | 運用設定で指定する |

* `AdditionalAuthorizationProvider`が`DISCORD`以外の場合、`DiscordGuildID`および`DiscordRequiredRoleID`を追加認可には使用しない。
* `AdditionalAuthorizationProvider=DISCORD`の場合、Discord Botを使用せずに新規Account作成または新規Loginを成功させる経路を設けない。
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
  - `jti`: Tokenごとに暗号学的乱数で生成する128bitの`DiscordAuthorizationTokenID`をcanonical UUID文字列で表した値.
  - `iat`: 発行時刻.
  - `exp`: 有効期限.
* Public API Serverは`AdditionalAuthorizationProvider=DISCORD`の場合, `CreateAccount`および`Login`の処理前に`DiscordAuthorizationToken`について以下をすべて検証する.
  - JWT構文が正しい.
  - `alg=EdDSA`である.
  - Discord追加認可Token検証用公開鍵で署名を正常に検証できる.
  - `iss`がDiscord追加認可Token用設定値と一致する.
  - `aud=game-discord-authorization`である.
  - 現在時刻が`exp`未満である.
  - `jti`が予約済み無効値ではない.
* Public API Serverは検証成功後に`sub`のDiscordUserIDと`jti`をPrivate API Serverへ中継する.
* Private API ServerはAccount新規作成またはLogin成功時に`jti`を使用済みとしてDatabaseへ保存する. 既に使用済みの`jti`では処理を成功させない.
* `AdditionalAuthorizationProvider=DISCORD`でAccountを新規作成する場合, `sub`のDiscordUserIDを`ACCOUNT.discord_user_id`へ保存する.
* `AdditionalAuthorizationProvider=DISCORD`でLoginする場合, `sub`のDiscordUserIDと`ACCOUNT.discord_user_id`が一致することを必須とする. 不一致時はAccount認証を成功させない.
* Discord Botが対象DiscordUserIDについて必要Roleを保持しなくなったことを検出した場合, mTLSでPrivate API Serverの`RevokeDiscordSessions`を要求し, 当該DiscordUserIDへBindingされたAccountの`ACCOUNT_SESSION`を削除する.
* `RefreshAccessToken`ではDiscord APIへのRole問い合わせを行わない. Role喪失はBotからのSession失効と24時間のRefresh Session期限で反映し, 通常ゲームAPIのHot PathへDiscord API通信を追加しない.
* Discord Bot連携用のGuild ID, Role ID, Bot Token, Bot通知用mTLS秘密鍵およびDiscord追加認可Token署名用秘密鍵をソースコードまたは公開リポジトリへ保存しない.

## LoginID

* LoginIDは3文字以上64文字以下とする.
* 使用可能文字はASCII英数字, `.`, `_`, `-`だけとする.
* LoginIDは大文字小文字を区別する.
* LoginIDはDatabase上で一意とする.

## Password

* Passwordは平文でDatabaseへ保存しない.
* PasswordはPrivate API ServerでArgon2idを使用してPasswordHashへ変換して保存する.
* Passwordごとに16byte以上の暗号学的乱数Saltを生成する. PasswordHashはArgon2idのパラメータ, Salt, Hashを含む形式で保存する.
* Argon2idの最低パラメータは以下とする.
  - memory: 19456 KiB.
  - iterations: 2.
  - parallelism: 1.
* 実運用では上記を下回らない範囲で対象Server上の計測結果に応じて引き上げることを許可する.
* Passwordの最小長は15文字, 最大長は128文字とする.
* Passwordへ文字種の組み合わせ規則を設けない.
* PasswordをApplication Log, Access Log, Traceへ出力しない.
* Private API ServerはArgon2id処理を認証専用の同時実行制限対象とし, ゲームデータ処理用の処理枠をArgon2id処理で占有しない.
* Argon2idの最大同時実行数は運用設定とし, 推奨初期値を2とする. 対象Server上のCPU・Memory計測値に応じて変更できるが, 無制限にはしない.

## AccessToken

* AccessTokenはJWT Compact Serializationを使用する.
* AccessTokenの署名アルゴリズムはEd25519を使用し, JOSE上の`alg`は`EdDSA`に固定する.
* Private API Serverだけが署名用秘密鍵を保持する.
* Public API Serverは検証用公開鍵を保持し, AccessToken検証時にPrivate API ServerまたはDatabaseへ問い合わせない.
* AccessTokenにはwire上の有限の最大長を設定し, 上限超過時はJWT構文解析および署名検証前に拒否する. 最大長は定義済みClaimと設定値から生成される正規Tokenを格納可能な値として設定し, 無制限にはしない.
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
* Public API ServerがRefreshTokenをCookieへ格納する場合は32byte値をBase64url without paddingでencodeし, Cookieから取得した値はdecodeしてからPrivate API Serverへ渡す. 不正なencodingはPrivate API Serverへ中継せず無効なRefreshTokenとして扱う.
* DatabaseへRefreshTokenの平文を保存しない.
* Databaseへは`SHA-256(RefreshToken)`を`refresh_token_hash`として保存する.
* RefreshToken更新成功時は新しいRefreshTokenを生成し, 更新前の`refresh_token_hash`を`previous_refresh_token_hash`へ移動してから新しいHashを`refresh_token_hash`へ保存する.
* 同一RefreshTokenによる更新要求が同時に到達した場合でも成功する要求は1つだけとし, 検証とHash置換を同一トランザクション内で排他的に行う.
* 受信RefreshTokenのHashが`previous_refresh_token_hash`と一致した場合はRefreshToken再利用として扱い, 対象`ACCOUNT_SESSION`を削除する. 新しいAccessTokenまたはRefreshTokenを発行しない.
* RefreshTokenの期限は対応するRefresh Sessionの期限と同一とし, Login成功時刻から24時間後を超えて更新しない.

## アカウント新規作成

```mermaid
sequenceDiagram
    actor User
    participant AuthProvider as 設定済み追加認可Provider
    participant Client
    participant PublicAPIServer as Public API Server
    participant PrivateAPIServer as Private API Server
    participant Database

    opt AdditionalAuthorizationProvider=DISCORD
        User->>AuthProvider: Discord用追加認可Tokenを要求
        AuthProvider-->>User: Discord用の検証可能なToken
    end

    User->>Client: LoginID・Password・ユーザー名入力
    Client->>PublicAPIServer: CreateAccount(LoginID, Password, UserName, 選択Provider用Tokenまたは省略)
    PublicAPIServer->>PublicAPIServer: Server設定に応じたAdapterで検証 (NONE時は追加認可なし)
    PublicAPIServer->>PrivateAPIServer: CreateAccount(LoginID, Password, UserName, Providerと検証済みSubject/Token識別子)
    PrivateAPIServer->>PrivateAPIServer: LoginID・Password・UserName検証
    PrivateAPIServer->>PrivateAPIServer: Argon2idでPasswordHash生成
    PrivateAPIServer->>PrivateAPIServer: AccountID・PlayerID生成
    PrivateAPIServer->>Database: ACCOUNT・PLAYER・Token使用済み記録を同一トランザクションで保存
    Database-->>PrivateAPIServer: 保存完了
    PrivateAPIServer-->>PublicAPIServer: CreateAccountPrivateResponse(PlayerID)
    PublicAPIServer-->>Client: CreateAccountResponse(PlayerID)
    Client->>Client: PlayerIDを保持。初期Guild作成要否はDBを正本として取得
```

* `LoginID`はDatabase上で一意とする.
* `UserName`は既存のPlayerユーザー名制約に従う.
* `AdditionalAuthorizationProvider=DISCORD`の場合はAccountへDiscordUserIDをBindingし, `DiscordAuthorizationTokenID`を使用済みとして保存する.
* Account作成, Player作成およびDiscord追加認可Token使用済み記録は同一トランザクションで行う.
* AccountIDおよびPlayerIDは予約済み無効値を生成しない.
* LoginID重複による作成失敗はClientへ既存LoginIDの存在を明示せず`API_ERROR_ACCOUNT_CREATION_FAILED`として返す.

### クロスサイト構成の画面境界

本番のClientと異なる認証Originにおける`CreateAccount`・`Login`・`RefreshAccessToken`・`Logout`は認証Originのトップレベルページで実施する。以下の従来図中でClientが認証Requestを送る部分は、認証Originの第一者画面の処理を表す。静的Clientへ直接AccessTokenを返す経路は使用せず、ログイン後は`IssueAuthorizationCode`→`https://rehydrangeaodyssey.github.io/auth/callback/`→`ExchangeAuthorizationCode`の経路で渡す。

## ログイン

```mermaid
sequenceDiagram
    actor User
    participant AuthProvider as 設定済み追加認可Provider
    participant Client
    participant PublicAPIServer as Public API Server
    participant PrivateAPIServer as Private API Server
    participant Database

    opt AdditionalAuthorizationProvider=DISCORD
        User->>AuthProvider: Discord用追加認可Tokenを要求
        AuthProvider-->>User: Discord用の検証可能なToken
    end

    User->>Client: ログイン操作
    Client->>PublicAPIServer: Login(LoginID, Password, ClientVersion, DiscordAuthorizationToken)
    PublicAPIServer->>PublicAPIServer: ClientVersion == RequiredVersionを確認

    alt Version一致
        PublicAPIServer->>PublicAPIServer: 選択した追加認可方式のTokenを検証
        PublicAPIServer->>PrivateAPIServer: AuthenticateAccount(LoginID, Password, DiscordUserID, DiscordAuthorizationTokenID)
        PrivateAPIServer->>Database: LoginIDに対応するACCOUNT・PLAYER取得
        Database-->>PrivateAPIServer: Account・Player
        PrivateAPIServer->>PrivateAPIServer: 必要な場合DiscordUserID Binding検証
        PrivateAPIServer->>PrivateAPIServer: Argon2idでPassword検証

        alt 認証成功
            PrivateAPIServer->>Database: 既存ACCOUNT_SESSION削除
            PrivateAPIServer->>PrivateAPIServer: SessionID・RefreshToken生成
            PrivateAPIServer->>Database: ACCOUNT_SESSION保存(SessionID, RefreshTokenHash, 期限24時間後)・Token使用済み記録
            PrivateAPIServer->>PrivateAPIServer: AccessToken生成・Ed25519署名
            PrivateAPIServer-->>PublicAPIServer: AuthenticateAccountResponse(PlayerID, AccessToken, RefreshToken)
            PublicAPIServer->>PublicAPIServer: RefreshTokenをHttpOnly Cookieへ設定
            PublicAPIServer-->>Client: LoginResponse(PlayerID, AccessToken)
            Client->>Client: AccessTokenをメモリへ保持
            opt 初期GuildがDatabaseに存在しない場合
                Client->>Client: 初期騎士団作成画面でGuildName・昼夜開始時刻を確定
                Client->>PublicAPIServer: CreateGuild(AccessToken, PlayerID, GuildName, DaytimeStartTime, NighttimeStartTime)
                PublicAPIServer->>PrivateAPIServer: CreateGuildPrivate(GuildName, DaytimeStartTime, NighttimeStartTime, AuthenticatedContext)
                alt Guild作成失敗・重複作成要求
                    PublicAPIServer-->>Client: RequiredOperationErrorResponse(API_ERROR_REQUIRED_OPERATION_FAILED, 必要な処理が実行できませんでした)
                else 初期騎士団作成成功
                    PublicAPIServer-->>Client: CreateGuildResponse
                    Client->>Client: Guild作成済み状態に更新
                end
            end
        else 認証失敗
            PrivateAPIServer-->>PublicAPIServer: 認証失敗
            PublicAPIServer-->>Client: ApiErrorResponse(API_ERROR_INVALID_CREDENTIALS)
        end
    else Version不一致
        PublicAPIServer-->>Client: LoginVersionErrorResponse
    end
```

* Public API Serverは現在要求する`Version`を保持し, Login時に`LoginRequest.ClientVersion`との一致を検証する.
* `AdditionalAuthorizationProvider=DISCORD`の場合、Discord追加認可Tokenの未指定は`API_ERROR_DISCORD_AUTHORIZATION_REQUIRED`, 不正, 期限切れまたは使用済みは`API_ERROR_INVALID_DISCORD_AUTHORIZATION_TOKEN`として返す.
* LoginID不存在, Password不一致およびDiscordUserID Binding不一致はClientへ同一の`API_ERROR_INVALID_CREDENTIALS`として返す.
* Login成功時に既存`ACCOUNT_SESSION`を削除してから新しいSessionを保存する.
* Login成功後, 旧RefreshTokenは使用できない.
* 旧AccessTokenは自身の`exp`到達まで最大5分間有効である.

初期騎士団の作成要否は、Databaseの`GUILD.id = PlayerID`の有無を正本として判定する。作成完了まで、Clientは初期Guild作成フローに必要な認証済みAPI以外を実行しない。Private APIは該当Playerによる他のゲーム操作を拒否する。作成済みGuildへの重複CreateGuildは拒否し、同一要求の再作成は行わない。

## AccessToken更新

```mermaid
sequenceDiagram
    actor Client
    participant PublicAPIServer as Public API Server
    participant PrivateAPIServer as Private API Server
    participant Database

    Client->>PublicAPIServer: RefreshAccessToken(__Host-RefreshToken Cookie)
    PublicAPIServer->>PublicAPIServer: Origin検証
    PublicAPIServer->>PrivateAPIServer: RefreshAccessToken(RefreshToken)
    PrivateAPIServer->>PrivateAPIServer: SHA-256(RefreshToken)
    PrivateAPIServer->>Database: current/previous Hash・期限確認
    Database-->>PrivateAPIServer: ACCOUNT_SESSION・PLAYER

    alt 現在有効なRefreshToken
        PrivateAPIServer->>PrivateAPIServer: 新RefreshToken生成
        PrivateAPIServer->>Database: previous Hash保存・current Hashを新しいHashへ更新
        PrivateAPIServer->>PrivateAPIServer: 新AccessToken生成・Ed25519署名
        PrivateAPIServer-->>PublicAPIServer: RefreshAccessTokenPrivateResponse(AccessToken, RefreshToken)
        PublicAPIServer->>PublicAPIServer: Rotation後RefreshTokenをHttpOnly Cookieへ設定
        PublicAPIServer-->>Client: RefreshAccessTokenResponse(AccessToken)
    else previous Hashと一致
        PrivateAPIServer->>Database: ACCOUNT_SESSION削除
        PrivateAPIServer-->>PublicAPIServer: RefreshToken再利用
        PublicAPIServer->>PublicAPIServer: RefreshToken Cookie削除
        PublicAPIServer-->>Client: ApiErrorResponse(API_ERROR_INVALID_REFRESH_TOKEN)
    else 無効
        PrivateAPIServer-->>PublicAPIServer: 無効
        PublicAPIServer->>PublicAPIServer: RefreshToken Cookie削除
        PublicAPIServer-->>Client: ApiErrorResponse(API_ERROR_INVALID_REFRESH_TOKEN)
    end
```

* RefreshToken更新ではRefresh Sessionの24時間期限を延長しない.
* `RefreshAccessToken`は設定済み認証Originと`Origin` Headerが一致する第一者Cookie付き要求だけを処理する. 別Siteの静的Clientへは認可コード+PKCE交換でAccessTokenを渡す.

## Logout

```mermaid
sequenceDiagram
    actor Client
    participant PublicAPIServer as Public API Server
    participant PrivateAPIServer as Private API Server
    participant Database

    Client->>PublicAPIServer: Logout(__Host-RefreshToken Cookie)
    PublicAPIServer->>PublicAPIServer: Origin検証
    PublicAPIServer->>PrivateAPIServer: Logout(RefreshToken)
    PrivateAPIServer->>PrivateAPIServer: SHA-256(RefreshToken)
    PrivateAPIServer->>Database: 該当ACCOUNT_SESSION削除
    Database-->>PrivateAPIServer: 削除完了
    PrivateAPIServer-->>PublicAPIServer: LogoutPrivateResponse
    PublicAPIServer->>PublicAPIServer: RefreshToken Cookie削除
    PublicAPIServer-->>Client: LogoutResponse
    Client->>Client: AccessToken削除
```

* `Logout`は設定済み認証Originと`Origin` Headerが一致する第一者Cookie付き要求だけを処理する.
* Logout後も既に発行済みのAccessTokenは自身の`exp`到達まで最大5分間有効とする.

## 騎士団戦参加時のSession確認

* Public API ServerはAccessToken検証後に`AuthenticatedContext`をGameServerへ渡す.
* GameServerは騎士団戦参加条件を満たした場合, `AuthenticatedContext.SessionID`を使用してPrivate APIの`ValidateAccountSession`を要求する.
* `ACCOUNT_SESSION`が存在しない, またはLogin成功時刻から24時間の期限を過ぎている場合は騎士団戦へ参加させない.
* 本処理ではRefresh Sessionの期限を延長しない.

CreateGuildへの応答が失われた場合、Clientは`GetInitialGuildStatus`でDB上の作成完了を照会し、作成済みなら通常フローへ、未作成なら初期Guild作成画面へ戻る。CreateGuild要求そのものは再試行しない。

## 追加認可方式のClient通知

Public APIの`GetAdditionalAuthorizationConfig`は認証不要・読取専用で、現在の選択値、追加認可の要否、およびAdapterの利用可否だけを提供する。ログイン・新規登録の第一者認証画面はこの応答に従って必要な認可入力を案内する。Provider選択はServer設定だけで確定し、ClientからのProvider自己申告による切替は認めない。

`ACCOUNT`の`additional_authorization_provider`に旧ProviderのBindingがあり、現在のServer設定が別Providerである場合は、自動的にAccountのBindingを更新しない。**そのAccountのログインは拒否**し、異なるProviderのSubjectを同一Accountとして扱わない。管理者による移行契約が別途追加されるまでは既存Bindingを保持する。

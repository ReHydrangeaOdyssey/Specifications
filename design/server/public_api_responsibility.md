# Public API責務境界

## 概要

Public API ServerはInternetと内部Componentの間に置くstatelessなEdge APIとする. Public API Serverは業務状態の正本を保持せず, Database上の状態またはGameServer上のゲーム状態を使用した業務判定を行わない.

Account/Guild系の業務処理はPrivate API Server, Arena/騎士団戦の業務処理はGameServerを正本とする.

## Public API Serverが担当する責務

* HTTP/2 over TLS 1.3の外部通信境界.
* Protocol Buffers Requestのdeserializeとwire上の形式検証.
* Request BodyおよびToken長の上限適用.
* Application Level Rate LimitとIngress側Network Level Rate Limitとの連携.
* AccessTokenのローカル検証と`PlayerID` Binding.
* `DiscordAuthorizationRequired=true`の場合のDiscordAuthorizationToken署名・期限等のローカル検証.
* `RefreshAccessToken`および`Logout`のOrigin検証.
* RefreshTokenの`__Host-RefreshToken` HttpOnly Cookie入出力.
* Login時のClientVersionとPublic API要求Versionの互換性判定.
* `AuthenticatedContext`生成. Clientが送信した`AuthenticatedContext`は使用しない.
* Public APIから内部APIへのRequest変換と中継.
* `GuildBattleID -> GameServerInstanceID`解決およびEndpoint解決による所有GameServerへのルーティング.
* 内部Componentが返したDomain Result/ErrorをPublic APIの既定Responseへ変換して返すこと.
* Public API仕様で明示されている同一Upstream Requestの再送制御. 再送によって業務判定をPublic APIへ移さない.

## Public API Serverが担当しない責務

以下はPublic API Serverで判定しない.

* Guildの団長・副団長権限判定.
* Guild所属人数, 加入上限20人判定.
* Guild加入・脱退・招待時の団長移動制約.
* `GUILD.membership_locked`を使用した所属変更可否判定.
* Guildの所属変更, 役職変更, 初期Guild復帰・所属スワップ.
* 初期GuildのID, 施設Level, 団長・副団長等のDomain初期値決定.
* Arena編成制約判定, 対戦相手抽選, Seed生成, 戦闘計算.
* GuildBattle参加可否, RequestSequence, 出撃, Tactics, Item, Heal, Revive等のゲームルール判定.
* Database transaction, Database row lock, 永続状態の整合性保証.
* ゲーム状態または認証状態の正本保持.

Public APIで行う文字列長, enum範囲, Token形式等のBoundary Validationと, Private API/GameServerが行うDomain Validationは別責務とする. Domain上の最終判定は必ず状態の正本を所有するComponentで行う.

## 内部通信の信頼境界

Public API ServerからPrivate API ServerおよびGameServerへの内部通信は, Private Network内に存在することだけを信頼根拠としない. mTLSにより呼出元と接続先のService Identityを相互検証し, 接続先ComponentはService Identityごとに呼び出し可能な内部APIを制限する. 証明書検証またはService Identity検証に失敗したRequestは業務処理を開始する前に拒否する.

Public API ServerでAccessTokenを検証済みであっても, Private API ServerおよびGameServerはPublic API Serverが事前に行ったDomain判定を信頼根拠としない. Account/Guildの認可・整合性はPrivate API ServerがDatabase上の現在状態を用いて再評価し, Arena/GuildBattleの操作可否・ゲーム制約はGameServerが自身の現在状態を用いて再評価する.

ClientがRequest Payloadへ指定したPlayerID等をそのままCaller Identityとして使用しない. Public API Serverは検証済みAccessTokenからCallerの`PlayerID`を確定し, Client入力とは分離した認証済みContextとして内部Componentへ渡す. 内部ComponentはCaller Identityと操作対象IDを区別して認可判定する.

## ルーティング

| Public API区分 | Public APIの中継先 | Domain責務の正本 |
|---|---|---|
| `CreateAccount`, `Login`, `RefreshAccessToken`, `Logout` | Private API Server | Private API Server / Database |
| `CreateGuild`, `UpdateGuildLeadership`, `ApplyGuildJoin`, `ApproveGuildJoinApplication`, `SendGuildInvitation`, `AcceptGuildInvitation`, `LeaveGuild` | Private API Server | Private API Server / Database |
| `UpdateArenaParty`, `StartArenaBattle` | GameServer | GameServer. 永続化はPrivate API Server経由 |
| `UpdateGuildBattleParty`, `JoinGuildBattle`, `GetGuildBattleStatus`, `GuildBattleSortie`, `UseTactics`, `UseItem`, Heal/Revive系 | GuildBattle所有GameServer | GameServer. 永続化はPrivate API Server経由 |

## Public API内部構成

Public API Serverは単一Deploymentのまま次の論理Moduleへ分割する.

```text
PublicApiServer
├── transport
│   ├── tls_http2
│   └── protobuf_codec
├── security
│   ├── access_token_verifier
│   ├── discord_authorization_verifier
│   ├── origin_validator
│   └── request_limits
├── rate_limit
├── routing
│   ├── private_api_router
│   ├── game_server_router
│   └── guild_battle_owner_resolver
├── session_cookie
└── upstream
    ├── private_api_client
    └── game_server_client
```

`routing`および`upstream`はDomain ruleを持たない. Public API methodごとの処理は上記Moduleを組み合わせる薄いAdapterとする.

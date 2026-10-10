# API仕様

APIはPublic APIとPrivate APIに分離する. 個別メソッドの仕様は以下のファイルを正とする.

* Public APIは「[Public API仕様](public_api.md)」を参照する.
* Private APIは「[Private API仕様](private_api.md)」を参照する.
* 騎士団戦の生成・割当制御は「[騎士団戦コーディネーター](guild_battle_coordinator.md)」を参照する.
* Database上の騎士団戦状態遷移は「[騎士団戦永続ライフサイクル](guild_battle_lifecycle.md)」を正とする.
* 要求およびレスポンスのデータ構造は「[API Payload](api_payload.md)」を参照する. Public APIおよびPrivate APIを含む本システムのAPI通信PayloadはProtocol Buffersで表現する. Public APIのProtocol Buffers wire schemaは「[public_api.proto](../system/public_api.proto)」を参照する. Private APIのfield number・wire schemaは未定義とする.

## Public API

Public APIはClientからの要求を受け付ける外部向けEdge APIである. 責務境界は「[Public API責務境界](public_api_responsibility.md)」を正とする. `AccessToken`を使用する要求では署名・有効期限・Audience・PlayerIDとのBindingをローカル検証し, 検証のためにDatabaseへ問い合わせない. `DiscordAuthorizationRequired=true`の場合はAccount新規作成およびLogin時にDiscord Botが発行した`DiscordAuthorizationToken`を追加検証する. RefreshTokenはHttpOnly Cookieで受け取りClient JavaScriptへ返さない. Account/Guild系要求はPrivate APIへ, Arena/GuildBattle系要求はGameServerへ中継する. Public APIにはレート制限およびRequest Size Limitを適用する.
Public API Serverは認証状態, Guild状態およびゲーム状態を正本として保持しないstateless構成とし, Database状態またはGameServer状態を使用するDomain ruleを判定しない. Kubernetes上で水平スケール可能とする.
騎士団戦要求は`GuildBattleID -> GameServerInstanceID`を解決して所有GameServerへ中継する.
Public API ServerからPrivate API ServerおよびGameServerへの通信はmTLSで相互認証し, Private Network内であることだけを信頼根拠としない. Public API Serverは検証済みAccessTokenからCaller Identityを確定して内部Contextへ渡し, Client入力のPlayerIDをCaller Identityとして採用しない. Private API ServerおよびGameServerはPublic API Serverによる事前のDomain判定を信頼せず, 自身が所有する現在状態を用いて認可およびDomain invariantを最終判定する.

## Private API

Private APIはPublic API Server, GameServer, GuildBattleCoordinatorおよび運営Componentから利用する内部APIである. Account/GuildのDomain rule, 騎士団戦の永続ライフサイクルとDatabase transactionを所有し, Public API Serverから受けたGuild操作の最終判定をDatabase上の現在状態で行う. 運営Componentは運用専用APIだけを呼び出す. `DiscordAuthorizationRequired=true`の場合はDiscord BotからRole喪失時の`RevokeDiscordSessions`だけを受け付ける. Account認証, AccessToken発行, Databaseへの保存・取得を仲介し, Clientから直接呼び出さない. Private Network内へ配置し, Public API Server, GameServer, GuildBattleCoordinatorおよびDiscord Botとの通信はmTLSを必須とする. Token署名用秘密鍵はPrivate API Serverだけが保持する. Arenaの抽選はGameServer, 騎士団戦のマッチング生成はGuildBattleCoordinatorが担当する.

## 違い

| 項目 | Public API | Private API |
|---|---|---|
| 主な呼び出し元 | Client | Public API Server, GameServer, GuildBattleCoordinator, 運営Component(運用APIのみ), Discord Bot(`RevokeDiscordSessions`のみ) |
| 主な役割 | Edge境界. Token検証, Boundary Validation, Rate Limit, RefreshToken Cookie管理, GameServer/Private APIへのRouting | Account認証, Guild Domain処理, GuildBattle永続Lifecycle, AccessToken発行, Refresh Session管理, Database transaction・保存・取得 |
| 配置 | InternetからIngress経由で到達可能なAPI境界 | Private Network内. Public API Server/GameServer/GuildBattleCoordinator/運営Component, および`RevokeDiscordSessions`を呼び出すDiscord Botとの通信はmTLS必須 |
| 認証検証 | AccessTokenをローカル検証する. 設定によりCreateAccount/Login時にDiscordAuthorizationTokenもローカル検証する | LoginID/PasswordおよびRefreshTokenをDatabaseと照合する |
| 状態 | stateless. 認証状態・ゲーム状態を正本として保持しない | Account/Session永続状態をDatabase経由で管理する |
| レート制限 | 適用する | Public API向けレート制限は適用しない |
| 詳細仕様 | `public_api.md` | `private_api.md` |

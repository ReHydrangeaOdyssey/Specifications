# API通信契約

## RPC通信方式

- Public APIはHTTP/2 over TLS 1.3、内部APIは相互証明書認証（mTLS）付きHTTP/2を使用し、Protocol BuffersをBodyとして送受信する。gRPC/gRPC-WebのService層は採用しない。
- 通常RPCは`POST /v1/public/{MethodName}`、Private RPCは`POST /v1/private/{MethodName}`、CoordinatorからGameServerのControl RPCは`POST /v1/control/{MethodName}`、運営専用Coordinator RPCは`POST /v1/operations/coordinator/{MethodName}`とする。MethodNameは定義済みAllowlistに完全一致する場合のみ実行する。
- Bodyの形式は`Content-Type: application/x-protobuf`とし、通常の成功応答はHTTP 200で定義済みResponseメッセージを返す。失敗時はHTTP 400（不正Body）、401（Token不正）、403（権限違反）、404（未定義Path）、405（Method違反）、409（状態競合）、413（サイズ超過）、415（形式不正）、429（制限超過）、503（依存Server未応答）を用いる。Domain上の業務エラーは既存定義のエラー用Protocol Buffers Responseで区別する。
- 失敗を含む認証・ゲーム状態APIに`Cache-Control: no-store`を付加し、共有Cacheを禁止する。ブラウザFetchはHTTP/2/TLS 1.3を直接指定できないため、Ingress側で必須化し、接続結果を結合試験で検証する。
- Public APIの通常認証は`Authorization: Bearer <AccessToken>`とする。DB状態の最終判定はPrivate API、戦闘・Arena状態の最終判定は所有GameServerが実施し、Public APIは中継・境界検証・Rate Limitを担当する。

HTTPステータスコードは標準の3桁整数であり任意の細分類値を追加できない。Requestの構文不正は400、認証失敗は401、権限違反は403、対象不在は404、更新競合は409、制限超過は429等とする。業務固有エラー（施設最大Lv、ゴールド不足など）は該当HTTPコードのBodyに`ApiErrorResponse.error_code`を設定して区別する。失敗Bodyは`Content-Type: application/x-protobuf`とする。

## Method名

Public API: `CreateAccount`, `Login`, `RefreshAccessToken`, `Logout`, `CreateGuild`, `UpdateGuildLeadership`, `ApplyGuildJoin`, `ApproveGuildJoinApplication`, `SendGuildInvitation`, `AcceptGuildInvitation`, `LeaveGuild`, `UpdateArenaParty`, `StartArenaBattle`, `UpdateGuildBattleParty`, `JoinGuildBattle`, `GetGuildBattleStatus`, `SubscribeGuildBattleUpdates`, `GuildBattleSortie`, `UseTactics`, `UseItem`, `UseTavernRecovery`, `StartHeal`, `CancelHeal`, `CompleteHeal`, `StartRevive`, `CancelRevive`, `CompleteRevive`, `IssueAuthorizationCode`, `ExchangeAuthorizationCode`, `GetGuildFacilityUpgradeCost`, `UpgradeGuildFacility`, `SearchGuilds`, `SearchPlayers`, `ListGuildJoinApplications`, `ListGuildInvitations`, `GetGuildDetail`, `UpdateGuildBattleStartTimes`, `GetMyGuildBattle`, `GetGuildBattleResult`, `GetArenaParty`, `GetGuildBattleParty`, `ListMyGuildBattleReplays`, `GetMyGuildBattleReplay`, `GetInitialGuildStatus`。

Private API: `CreateAccount`, `AuthenticateAccount`, `RefreshAccessToken`, `Logout`, `ValidateAccountSession`, `RevokeDiscordSessions`, `CreateGuildPrivate`, `UpdateGuildLeadershipPrivate`, `SetGuildMembershipLock`, `ApplyGuildJoinPrivate`, `ApproveGuildJoinApplicationPrivate`, `SendGuildInvitationPrivate`, `AcceptGuildInvitationPrivate`, `LeaveGuildPrivate`, `SaveArenaParty`, `GetArenaBattleData`, `GetAllPlayerIDs`, `GetGuildsForBattleMatching`, `SaveGuildBattleExcludedGuilds`, `GetGuildBattleExcludedGuilds`, `ClearGuildBattleExcludedGuilds`, `SaveScheduledGuildBattles`, `GetScheduledGuilds`, `GetGuildBattleCoordinationState`, `AssignScheduledGuildBattles`, `ReleaseScheduledGuildBattleAssignments`, `GetGuildBattleAssignment`, `SaveGuildBattleParty`, `GetGuildBattleFormation`, `GetGuildMembers`, `GetGuildData`, `GetPlayerItems`, `UpdatePlayerItem`, `MarkGuildBattlePreloadFailed`, `StartGuildBattle`, `BeginGuildBattleResolving`, `RematchPreloadFailedGuildBattles`, `RetryPreloadFailedGuildBattle`, `CancelPreloadFailedGuildBattle`, `DeleteUnassignedGuildBattles`, `SaveGuildBattleJoinLog`, `SaveGuildBattleSortieLog`, `SaveGuildBattleTacticsLog`, `SaveGuildBattleItemLog`, `SaveGuildBattleHealLog`, `SaveGuildBattleReviveLog`, `SaveErrorLog`, `CompleteGuildBattle`, `IssueAuthorizationCodePrivate`, `RedeemAuthorizationCodePrivate`, `GetGuildFacilityUpgradeCostPrivate`, `UpgradeGuildFacilityPrivate`, `SearchGuildsPrivate`, `SearchPlayersPrivate`, `ListGuildJoinApplicationsPrivate`, `ListGuildInvitationsPrivate`, `GetGuildDetailPrivate`, `UpdateGuildBattleStartTimesPrivate`, `GetMyGuildBattlePrivate`, `GetGuildBattleResultPrivate`, `GetMyArenaPartyPrivate`, `GetMyGuildBattlePartyPrivate`, `ListMyGuildBattleReplaysPrivate`, `GetMyGuildBattleReplayPrivate`, `GetInitialGuildStatusPrivate`。

Control APIは`GetGameServerCapacity`と`StartGuildBattlePreload`のみをCoordinatorのService Identityに許可する。運営APIは既存の操作名を使用し、運営用Service Identityだけに許可する。RPCのPath形式は固定するが、個別の運営操作のPayloadは元の運営設計が正本とする。

## Wire schemaと入力検証

- Publicの正本は`design/system/public_api.proto`、PrivateおよびControlの正本は`design/system/private_api.proto`とする。固定長配列の個数、予約ID、enum許容値、文字列の長さ、数値の上下限は`design/server/api_payload.md`と`design/shared/types.md`を用いてDeserialize後に検証する。
- 新規Messageで「未設定」と0等の既定値を区別する場合は`optional`/`oneof`を使用する。無効な論理値や不正固定長をDomainへ渡さずHTTP 400とする。未知フィールドは前方互換性のため読み飛ばす。
- ClientはService Identityや内部`AuthenticatedContext`を指定できない。認証済みCaller IdentityはPublic APIがTokenから確定し、内部mTLS呼出しへ付与する。

## Origin、CORS、Cookie

- 静的Clientは`https://rehydrangeaodyssey.github.io`に固定する。Public API Originは静的Clientの配布設定`public_api_origin`にHTTPS Originとして定義する。GameServerにはClientから直接接続しない。
- Cross-Origin RPCと認可コード交換の`Access-Control-Allow-Origin`には静的Clientの厳密なOriginだけを返す。`Access-Control-Allow-Methods: POST, OPTIONS`、`Access-Control-Allow-Headers: Authorization, Content-Type`、`Vary: Origin`を使用する。Cross-OriginではCookieを送信しない（`credentials: omit`）。任意のOriginを許可しない。
- Session Cookieが必要なCreateAccount/Login/RefreshAccessToken/Logout/IssueAuthorizationCodeはPublic API Originの第一者トップレベル認証画面から行う。`Secure; HttpOnly; SameSite=Strict; Path=/`、Domain属性なしの`__Host-RefreshToken`を維持し、CookieをCross-Siteで送信しない。Cookie付き状態変更RequestはOrigin完全一致を確認する。
- 認証Originは`GET /auth/authorize`で認証ページを提供し、`Content-Security-Policy`（`frame-ancestors 'none'`）と`Referrer-Policy: no-referrer`を設定する。状態変更Requestでは`Origin`の完全一致とCSRF防御を必須とする。具体的には、同Originページで生成する32byteの`__Host-CsrfToken`（`Secure`, `SameSite=Strict`, `Path=/`, Domainなし）をCookieと`X-CSRF-Token` Headerの両方で送り、定数時間比較で照合する。認証OriginだけでCookieを設定・利用する。
- 認証ページのリダイレクトURIとPKCE S256を検証し、未登録URIへリダイレクトしない。認可コードは60秒以内に失効し一度しか使用できない。Callback URIは`https://rehydrangeaodyssey.github.io/auth/callback/`に固定する。

## 認証コードの手順

1. ClientはWeb Cryptoの暗号学的乱数で`state`とPKCE `code_verifier`を生成し、当該タブの`sessionStorage`だけに認証一時情報を保持する（5分以内）。`code_challenge=BASE64URL(SHA256(ASCII(code_verifier)))`を生成し、認証Originの`/auth/authorize`へトップレベル遷移する。AccessTokenは永続Storageへ保存しない。
2. 認証Originは同OriginのCreateAccount/Login/RefreshAccessTokenでSessionを確認する。認証完了後の`IssueAuthorizationCode`はCookieを受け、Private APIの`IssueAuthorizationCodePrivate`がRefreshTokenハッシュからDB上のSessionを特定する。
3. Private APIはRefresh Session、登録済み戻り先URI、PKCE S256を確認して32byteの乱数コードを作る。DBにはコードのSHA-256、SessionID、PlayerID、RedirectURI、S256、期限・使用時刻を保存する。発行元ページは`?code=...&state=...`を付けて固定Callbackへリダイレクトする。AccessToken等の秘密情報をURLへ載せない。
4. ClientはCallback URLからコード等を取り除き、保存済stateと一致する場合のみCookieなしで`ExchangeAuthorizationCode`を要求する。Public APIがPrivateの`RedeemAuthorizationCodePrivate`を呼ぶ。Private APIはコード未使用、60秒期限、Session有効、URI・S256一致を単一の排他DBトランザクションで検証し、使用済みにしてAccessTokenを発行する。重複交換は拒否する。
5. ClientはAccessTokenをプロセスメモリにのみ保持し、state/verifierを`sessionStorage`から削除する。交換失敗・タイムアウト時は以前のコードを繰り返し送信せず、最初から認証をやり直す。認証不能でもローカル機能は維持する。

ClientがAccessToken失効を確認した場合、ログアウトして通信未接続状態へ切り替える。失効を契機に状態変更Requestを自動再送しない。ローカル機能は維持する。

## 状態取得・ストリーム・リトライ

- `SubscribeGuildBattleUpdates`は`POST /v1/public/SubscribeGuildBattleUpdates`から長寿命HTTP/2 Response Bodyを返し、既存のvarint長prefixで`GuildBattleScoreUpdate`を連結する。Proxyのバッファリングを無効とする。
- 購読が切断されたときは`GetGuildBattleStatus`で現在値へ再同期してから再購読する。Retryは初回1秒、失敗ごとに2倍、上限30秒とし、同じClientタブでは同じBattleへの同時購読を1つに限る。戦闘終了と判定した場合は再購読を止める。
- AccessToken切れが確定した場合はClientをログアウト・Server未接続状態にし、自動再認証を開始しない。利用者が改めてログインする場合に認証Originへ遷移する。Timeoutや通信断は業務処理の不成立を意味しない。状態変更Requestを無条件に新しいSequenceで再送しない。成立確認には既存のStatus APIを使用し、従来のOperation ID・Sequenceの冪等条件を維持する。

## RPCの型対応

以下に全Allowlist Methodを型と対応させる。複数成功Responseまたは長寿命Streamは既存の業務契約を正とする。

| 区分 | Method | Request Message | Response Message |
|---|---|---|---|
| Public | `CreateAccount` | `CreateAccountRequest` | `CreateAccountResponse` |
| Public | `Login` | `LoginRequest` | `LoginResponse` |
| Public | `RefreshAccessToken` | `RefreshAccessTokenRequest` | `RefreshAccessTokenResponse` |
| Public | `Logout` | `LogoutRequest` | `LogoutResponse` |
| Public | `CreateGuild` | `CreateGuildRequest` | `CreateGuildResponse` |
| Public | `UpdateGuildLeadership` | `UpdateGuildLeadershipRequest` | `UpdateGuildLeadershipResponse` |
| Public | `ApplyGuildJoin` | `ApplyGuildJoinRequest` | `ApplyGuildJoinResponse` |
| Public | `ApproveGuildJoinApplication` | `ApproveGuildJoinApplicationRequest` | `ApproveGuildJoinApplicationResponse` |
| Public | `SendGuildInvitation` | `SendGuildInvitationRequest` | `SendGuildInvitationResponse` |
| Public | `AcceptGuildInvitation` | `AcceptGuildInvitationRequest` | `AcceptGuildInvitationResponse` |
| Public | `LeaveGuild` | `LeaveGuildRequest` | `LeaveGuildResponse` |
| Public | `UpdateArenaParty` | `UpdateArenaPartyRequest` | `UpdateArenaPartyResponse` |
| Public | `StartArenaBattle` | `ArenaBattleRequest` | `ArenaBattleResponse / ArenaBattleErrorResponse` |
| Public | `UpdateGuildBattleParty` | `UpdateGuildBattlePartyRequest` | `UpdateGuildBattlePartyResponse` |
| Public | `JoinGuildBattle` | `JoinGuildBattleRequest` | `GuildBattleJoinResponse` |
| Public | `GetGuildBattleStatus` | `GetGuildBattleStatusRequest` | `GetGuildBattleStatusResponse` |
| Public | `SubscribeGuildBattleUpdates` | `SubscribeGuildBattleUpdatesRequest` | `GuildBattleScoreUpdate (stream)` |
| Public | `GuildBattleSortie` | `GuildBattleSortieRequest` | `GuildBattleCastleBreakResponse / GuildBattleAnnihilationResponse` |
| Public | `UseTactics` | `UseTacticsRequest` | `UseTacticsResponse` |
| Public | `UseItem` | `UseItemRequest` | `UseItemResponse` |
| Public | `UseTavernRecovery` | `UseTavernRecoveryRequest` | `UseTavernRecoveryResponse` |
| Public | `StartHeal` | `StartHealRequest` | `StartHealResponse` |
| Public | `CancelHeal` | `CancelHealRequest` | `CancelHealResponse` |
| Public | `CompleteHeal` | `CompleteHealRequest` | `CompleteHealResponse` |
| Public | `StartRevive` | `StartReviveRequest` | `StartReviveResponse` |
| Public | `CancelRevive` | `CancelReviveRequest` | `CancelReviveResponse` |
| Public | `CompleteRevive` | `CompleteReviveRequest` | `CompleteReviveResponse` |
| Public | `IssueAuthorizationCode` | `IssueAuthorizationCodeRequest` | `IssueAuthorizationCodeResponse` |
| Public | `ExchangeAuthorizationCode` | `ExchangeAuthorizationCodeRequest` | `ExchangeAuthorizationCodeResponse` |
| Public | `GetGuildFacilityUpgradeCost` | `GetGuildFacilityUpgradeCostRequest` | `GetGuildFacilityUpgradeCostResponse` |
| Public | `UpgradeGuildFacility` | `UpgradeGuildFacilityRequest` | `UpgradeGuildFacilityResponse` |
| Public | `SearchGuilds` | `SearchGuildsRequest` | `SearchGuildsResponse` |
| Public | `SearchPlayers` | `SearchPlayersRequest` | `SearchPlayersResponse` |
| Public | `ListGuildJoinApplications` | `ListGuildJoinApplicationsRequest` | `ListGuildJoinApplicationsResponse` |
| Public | `ListGuildInvitations` | `ListGuildInvitationsRequest` | `ListGuildInvitationsResponse` |
| Public | `GetGuildDetail` | `GetGuildDetailRequest` | `GetGuildDetailResponse` |
| Public | `UpdateGuildBattleStartTimes` | `UpdateGuildBattleStartTimesRequest` | `UpdateGuildBattleStartTimesResponse` |
| Public | `GetMyGuildBattle` | `GetMyGuildBattleRequest` | `GetMyGuildBattleResponse` |
| Public | `GetGuildBattleResult` | `GetGuildBattleResultRequest` | `GetGuildBattleResultResponse` |
| Public | `GetArenaParty` | `GetArenaPartyRequest` | `GetArenaPartyResponse` |
| Public | `GetGuildBattleParty` | `GetGuildBattlePartyRequest` | `GetGuildBattlePartyResponse` |
| Public | `ListMyGuildBattleReplays` | `ListMyGuildBattleReplaysRequest` | `ListMyGuildBattleReplaysResponse` |
| Public | `GetMyGuildBattleReplay` | `GetMyGuildBattleReplayRequest` | `GetMyGuildBattleReplayResponse` |
| Private | `CreateAccount` | `CreateAccountPrivateRequest` | `CreateAccountPrivateResponse` |
| Private | `AuthenticateAccount` | `AuthenticateAccountRequest` | `AuthenticateAccountResponse` |
| Private | `RefreshAccessToken` | `RefreshAccessTokenPrivateRequest` | `RefreshAccessTokenPrivateResponse` |
| Private | `Logout` | `LogoutPrivateRequest` | `LogoutPrivateResponse` |
| Private | `ValidateAccountSession` | `ValidateAccountSessionRequest` | `ValidateAccountSessionResponse` |
| Private | `RevokeDiscordSessions` | `RevokeDiscordSessionsRequest` | `RevokeDiscordSessionsResponse` |
| Private | `CreateGuildPrivate` | `CreateGuildPrivateRequest` | `CreateGuildPrivateResponse` |
| Private | `UpdateGuildLeadershipPrivate` | `UpdateGuildLeadershipPrivateRequest` | `UpdateGuildLeadershipPrivateResponse` |
| Private | `SetGuildMembershipLock` | `SetGuildMembershipLockRequest` | `SetGuildMembershipLockResponse` |
| Private | `ApplyGuildJoinPrivate` | `ApplyGuildJoinPrivateRequest` | `ApplyGuildJoinPrivateResponse` |
| Private | `ApproveGuildJoinApplicationPrivate` | `ApproveGuildJoinApplicationPrivateRequest` | `ApproveGuildJoinApplicationPrivateResponse` |
| Private | `SendGuildInvitationPrivate` | `SendGuildInvitationPrivateRequest` | `SendGuildInvitationPrivateResponse` |
| Private | `AcceptGuildInvitationPrivate` | `AcceptGuildInvitationPrivateRequest` | `AcceptGuildInvitationPrivateResponse` |
| Private | `LeaveGuildPrivate` | `LeaveGuildPrivateRequest` | `LeaveGuildPrivateResponse` |
| Private | `SaveArenaParty` | `SaveArenaPartyRequest` | `SaveArenaPartyResponse` |
| Private | `GetArenaBattleData` | `GetArenaBattleDataRequest` | `GetArenaBattleDataResponse` |
| Private | `GetAllPlayerIDs` | `GetAllPlayerIDsRequest` | `GetAllPlayerIDsResponse` |
| Private | `GetGuildsForBattleMatching` | `GetGuildsForBattleMatchingRequest` | `GetGuildsForBattleMatchingResponse` |
| Private | `SaveGuildBattleExcludedGuilds` | `SaveGuildBattleExcludedGuildsRequest` | `SaveGuildBattleExcludedGuildsResponse` |
| Private | `GetGuildBattleExcludedGuilds` | `GetGuildBattleExcludedGuildsRequest` | `GetGuildBattleExcludedGuildsResponse` |
| Private | `ClearGuildBattleExcludedGuilds` | `ClearGuildBattleExcludedGuildsRequest` | `ClearGuildBattleExcludedGuildsResponse` |
| Private | `SaveScheduledGuildBattles` | `SaveScheduledGuildBattlesRequest` | `SaveScheduledGuildBattlesResponse` |
| Private | `GetScheduledGuilds` | `GetScheduledGuildsRequest` | `GetScheduledGuildsResponse` |
| Private | `GetGuildBattleCoordinationState` | `GetGuildBattleCoordinationStateRequest` | `GetGuildBattleCoordinationStateResponse` |
| Private | `AssignScheduledGuildBattles` | `AssignScheduledGuildBattlesRequest` | `AssignScheduledGuildBattlesResponse` |
| Private | `ReleaseScheduledGuildBattleAssignments` | `ReleaseScheduledGuildBattleAssignmentsRequest` | `ReleaseScheduledGuildBattleAssignmentsResponse` |
| Private | `GetGuildBattleAssignment` | `GetGuildBattleAssignmentRequest` | `GetGuildBattleAssignmentResponse` |
| Private | `SaveGuildBattleParty` | `SaveGuildBattlePartyRequest` | `SaveGuildBattlePartyResponse` |
| Private | `GetGuildBattleFormation` | `GetGuildBattleFormationRequest` | `GetGuildBattleFormationResponse` |
| Private | `GetGuildMembers` | `GetGuildMembersRequest` | `GetGuildMembersResponse` |
| Private | `GetGuildData` | `GetGuildDataRequest` | `GetGuildDataResponse` |
| Private | `GetPlayerItems` | `GetPlayerItemsRequest` | `GetPlayerItemsResponse` |
| Private | `UpdatePlayerItem` | `UpdatePlayerItemRequest` | `UpdatePlayerItemResponse` |
| Private | `MarkGuildBattlePreloadFailed` | `MarkGuildBattlePreloadFailedRequest` | `MarkGuildBattlePreloadFailedResponse` |
| Private | `StartGuildBattle` | `StartGuildBattleRequest` | `StartGuildBattleResponse` |
| Private | `BeginGuildBattleResolving` | `BeginGuildBattleResolvingRequest` | `BeginGuildBattleResolvingResponse` |
| Private | `RematchPreloadFailedGuildBattles` | `RematchPreloadFailedGuildBattlesRequest` | `RematchPreloadFailedGuildBattlesResponse` |
| Private | `RetryPreloadFailedGuildBattle` | `RetryPreloadFailedGuildBattleRequest` | `RetryPreloadFailedGuildBattleResponse` |
| Private | `CancelPreloadFailedGuildBattle` | `CancelPreloadFailedGuildBattleRequest` | `CancelPreloadFailedGuildBattleResponse` |
| Private | `DeleteUnassignedGuildBattles` | `DeleteUnassignedGuildBattlesRequest` | `DeleteUnassignedGuildBattlesResponse` |
| Private | `SaveGuildBattleJoinLog` | `SaveGuildBattleJoinLogRequest` | `SaveGuildBattleJoinLogResponse` |
| Private | `SaveGuildBattleSortieLog` | `SaveGuildBattleSortieLogRequest` | `SaveGuildBattleSortieLogResponse` |
| Private | `SaveGuildBattleTacticsLog` | `SaveGuildBattleTacticsLogRequest` | `SaveGuildBattleTacticsLogResponse` |
| Private | `SaveGuildBattleItemLog` | `SaveGuildBattleItemLogRequest` | `SaveGuildBattleItemLogResponse` |
| Private | `SaveGuildBattleHealLog` | `SaveGuildBattleHealLogRequest` | `SaveGuildBattleHealLogResponse` |
| Private | `SaveGuildBattleReviveLog` | `SaveGuildBattleReviveLogRequest` | `SaveGuildBattleReviveLogResponse` |
| Private | `SaveErrorLog` | `SaveErrorLogRequest` | `SaveErrorLogResponse` |
| Private | `CompleteGuildBattle` | `CompleteGuildBattleRequest` | `CompleteGuildBattleResponse` |
| Private | `IssueAuthorizationCodePrivate` | `IssueAuthorizationCodePrivateRequest` | `IssueAuthorizationCodePrivateResponse` |
| Private | `RedeemAuthorizationCodePrivate` | `RedeemAuthorizationCodePrivateRequest` | `RedeemAuthorizationCodePrivateResponse` |
| Private | `GetGuildFacilityUpgradeCostPrivate` | `GetGuildFacilityUpgradeCostPrivateRequest` | `GetGuildFacilityUpgradeCostPrivateResponse` |
| Private | `UpgradeGuildFacilityPrivate` | `UpgradeGuildFacilityPrivateRequest` | `UpgradeGuildFacilityPrivateResponse` |
| Private | `SearchGuildsPrivate` | `SearchGuildsPrivateRequest` | `SearchGuildsPrivateResponse` |
| Private | `SearchPlayersPrivate` | `SearchPlayersPrivateRequest` | `SearchPlayersPrivateResponse` |
| Private | `ListGuildJoinApplicationsPrivate` | `ListGuildJoinApplicationsPrivateRequest` | `ListGuildJoinApplicationsPrivateResponse` |
| Private | `ListGuildInvitationsPrivate` | `ListGuildInvitationsPrivateRequest` | `ListGuildInvitationsPrivateResponse` |
| Private | `GetGuildDetailPrivate` | `GetGuildDetailPrivateRequest` | `GetGuildDetailPrivateResponse` |
| Private | `UpdateGuildBattleStartTimesPrivate` | `UpdateGuildBattleStartTimesPrivateRequest` | `UpdateGuildBattleStartTimesPrivateResponse` |
| Private | `GetMyGuildBattlePrivate` | `GetMyGuildBattlePrivateRequest` | `GetMyGuildBattlePrivateResponse` |
| Private | `GetGuildBattleResultPrivate` | `GetGuildBattleResultPrivateRequest` | `GetGuildBattleResultPrivateResponse` |
| Private | `GetMyArenaPartyPrivate` | `GetMyArenaPartyPrivateRequest` | `GetMyArenaPartyPrivateResponse` |
| Private | `GetMyGuildBattlePartyPrivate` | `GetMyGuildBattlePartyPrivateRequest` | `GetMyGuildBattlePartyPrivateResponse` |
| Private | `ListMyGuildBattleReplaysPrivate` | `ListMyGuildBattleReplaysPrivateRequest` | `ListMyGuildBattleReplaysPrivateResponse` |
| Private | `GetMyGuildBattleReplayPrivate` | `GetMyGuildBattleReplayPrivateRequest` | `GetMyGuildBattleReplayPrivateResponse` |
| Public | `GetInitialGuildStatus` | `GetInitialGuildStatusRequest` | `GetInitialGuildStatusResponse` |
| Private | `GetInitialGuildStatusPrivate` | `GetInitialGuildStatusPrivateRequest` | `GetInitialGuildStatusPrivateResponse` |

# Public API仕様

API全体の分類は「[API仕様](api.md)」を参照する.

- Clientから要求を受ける.
- 認証系APIはPrivate API Serverへ中継する.
- ゲーム系APIはGameServerへ中継する.
- Public API Serverは認証状態およびゲーム状態を正本として保持しないstateless構成とする.
- テスト環境では Private Network の外側に配置される.
- 要求/レスポンスの意味・制約は[API Payload](api_payload.md), Protocol Buffersのwire schemaとfield numberは「[public_api.proto](../system/public_api.proto)」を参照する. `public_api.proto`はPayload schemaを定義し, gRPC Service・HTTP method・HTTP pathは追加定義しない.
- `DiscordAuthorizationRequired=true`の場合, `CreateAccount`および`Login`は処理前にDiscordAuthorizationTokenを「[セッション仕様](session.md)」に従って検証する.
- `AccessToken`を要求するPublicAPIは, 処理前にAccessTokenを検証する.
  - 署名, `alg`, `iss`, `aud`, `exp`, `player_id`を「[セッション仕様](session.md)」に従って検証する.
  - AccessToken検証のためにPrivate API ServerまたはDatabaseへ問い合わせない.
  - AccessTokenの`player_id`と要求`PlayerID`が一致しない場合は`ApiErrorResponse(API_ERROR_INVALID_ACCESS_TOKEN)`を返し, 要求本体を処理しない.
  - 検証成功時は`AuthenticatedContext`を生成し, GameServerへ要求と共に中継する.
- 個別に失敗レスポンスが定義されていないPublicAPIの失敗時は`ApiErrorResponse`を使用する.
- PublicAPIは下記「レート制限」に従って要求数を制限する. 超過時は`ApiErrorResponse(API_ERROR_RATE_LIMIT_EXCEEDED)`を返し, 要求本体を処理しない.
- 表に記載していないPublicAPIには個別のApplication Level Rate Limitを設定しない. Ingress等で行うNetwork LevelのDoS対策は本表とは別とする.
- Public APIのRequest Bodyには有限の最大サイズを設定し, IngressおよびPublic API Serverの双方で上限を適用する. 上限超過要求はPayloadの完全なdeserializeおよび認証処理より前に拒否する.
- Request Body最大サイズは各Public API Payloadについて仕様上取り得る最大serialization sizeを満たす値として設定し, 無制限にはしない.
- `AccessToken`および`DiscordAuthorizationToken`にはwire上の有限の最大長を設定し, JWT構文解析および署名検証より前に上限超過を拒否する. 最大長は定義済みClaimと設定値から生成される正規Tokenを格納可能な値として設定し, 無制限にはしない.
- `CreateAccount`および`Login`はLoginID単位のApplication Level Rate Limitに加えてSource IP単位のNetwork Level Rate Limitを必須とする. Source IP単位の閾値は`CreateAccount`と`Login`の合計で推奨初期値20 requests/min/IP, burst 5とする. 閾値は運用設定で変更可能とするが, 無制限にはしない.
- Source IPは信頼済みIngressが付与した値だけを使用し, Clientから直接送信されたForwarded/X-Forwarded-For相当HeaderをそのままRate Limit keyとして使用しない.
- `GuildBattleID`を含む要求は`GuildBattleID -> GameServerInstanceID`を解決し, 当該騎士団戦を所有するGameServerへ中継する. 解決結果はPublic API Serverのメモリへキャッシュしてよいが正本とはしない.
  - 本番Kubernetes環境ではGameServer用EndpointSliceをwatchし, `GameServerInstanceID`に一致するPod UIDのEndpointへ直接中継する.
  - 割当済み`GameServerInstanceID`に対応するEndpointが存在しない場合は`ApiErrorResponse(API_ERROR_GAME_SERVER_UNAVAILABLE)`を返す.
- Application Level Rate LimitのカウンタはPublic API Pod単位で独立管理せず, 複数Pod間で同一カウント単位の結果を共有する. 共有方式はKubernetes Ingress/Gatewayまたは共有Rate Limit Storeを使用し, Public API Serverの認証状態・ゲーム状態をstatelessとする方針を崩さない.

## レート制限

`RPM`は1分あたり, `RPH`は1時間あたり, `PRD`は1日あたりの最大要求数を表す. 各窓は同時に適用し, いずれか1つでも超過した要求を拒否する.

| 区分 | 対象PublicAPI | RPM | RPH | PRD | カウント単位 |
|---|---|---:|---:|---:|---|
| アカウント作成 | `CreateAccount` | 1 | 5 | 10 | LoginID |
| ログイン | `Login` | 1 | 5 | 25 | LoginID |
| 新規作成時のみ | `CreateGuild` | 1 | 5 | 10 | PlayerID |
| アリーナ | `UpdateArenaParty`, `StartArenaBattle` | 2 | 50 | 100 | PlayerID |

## システム

### アカウント新規作成

#### メソッド名

`CreateAccount`

#### 処理内容

- LoginID, Password, UserName, DiscordAuthorizationTokenを受け取る.
- `DiscordAuthorizationRequired=true`の場合はDiscordAuthorizationTokenを検証する. 未指定の場合は`API_ERROR_DISCORD_AUTHORIZATION_REQUIRED`, 不正または期限切れの場合は`API_ERROR_INVALID_DISCORD_AUTHORIZATION_TOKEN`を返す.
- `DiscordAuthorizationRequired=false`の場合はDiscordAuthorizationTokenを要求しない.
- LoginIDおよびPasswordは「[セッション仕様](session.md)」に従って検証する.
- UserNameをチェックする.
  - 有効なUTF-8である.
  - 10文字以下である.
  - 空文字ではない.
  - ユーザー名の重複は許可する.
- `DiscordAuthorizationRequired=true`の場合は検証済みTokenからDiscordUserIDとDiscordAuthorizationTokenIDを取得する.
- Private API Serverの`CreateAccount`へLoginID, Password, UserNameと, 必要な場合DiscordUserID, DiscordAuthorizationTokenIDを要求する.
- Private API ServerはAccountIDおよびPlayerIDを生成し, `ACCOUNT`と`PLAYER`を同一トランザクションで保存する. Discord追加認可を使用する場合はAccountへのDiscordUserID BindingおよびToken使用済み記録も同一トランザクションで保存する.
- `PLAYER.max_bp`は200で初期化する.

#### 要求データ

[API Payload](api_payload.md)の「CreateAccountRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「CreateAccountResponse」を参照する.

#### 失敗時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照する. Discord追加認可必須時のToken未指定は`API_ERROR_DISCORD_AUTHORIZATION_REQUIRED`, Token不正は`API_ERROR_INVALID_DISCORD_AUTHORIZATION_TOKEN`, LoginID不正は`API_ERROR_INVALID_LOGIN_ID`, Password不正は`API_ERROR_INVALID_PASSWORD`, UserName不正は`API_ERROR_INVALID_USER_NAME`. LoginID重複を含むDatabase上のAccount作成失敗は`API_ERROR_ACCOUNT_CREATION_FAILED`として返し, 既存LoginIDの存在をClientへ区別して返さない. Private API ServerのArgon2id同時実行上限到達時は`API_ERROR_RATE_LIMIT_EXCEEDED`を返す.

### ログイン要求

#### メソッド名

`Login`

#### 処理内容

- `LoginRequest.ClientVersion`とPublic API Serverが要求する`Version`を比較する.
  - 一致しない場合は認証処理を行わず, `LoginVersionErrorResponse`で`API_ERROR_CLIENT_VERSION_MISMATCH`と要求Versionを返す.
  - Clientは本エラーを受け取った場合, ゲームデータおよびClientの更新をユーザーへ促す.
- `DiscordAuthorizationRequired=true`の場合はDiscordAuthorizationTokenを検証する. 未指定の場合は`API_ERROR_DISCORD_AUTHORIZATION_REQUIRED`, 不正または期限切れの場合は`API_ERROR_INVALID_DISCORD_AUTHORIZATION_TOKEN`を返す.
- `DiscordAuthorizationRequired=false`の場合はDiscordAuthorizationTokenを要求しない.
- `DiscordAuthorizationRequired=true`の場合は検証済みTokenからDiscordUserIDとDiscordAuthorizationTokenIDを取得する.
- Private API Serverの`AuthenticateAccount`へLoginID, Passwordと, 必要な場合DiscordUserID, DiscordAuthorizationTokenIDを送信する.
- Private API ServerはDiscord追加認可が有効な場合にAccountへBindingされたDiscordUserIDとの一致およびToken未使用を確認する.
- Private API ServerはPassword検証成功時に既存Refresh Sessionを無効化し, 新しいSessionID, AccessToken, RefreshTokenを生成する.
- Public API ServerはRefreshTokenをResponse Bodyへ含めず, 「[セッション仕様](session.md)」に従う`__Host-RefreshToken` HttpOnly Cookieとして設定する.
- LoginID不存在, Password不一致およびDiscordUserID Binding不一致は区別せず`API_ERROR_INVALID_CREDENTIALS`として返す.

#### 要求データ

[API Payload](api_payload.md)の「LoginRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「LoginResponse」を参照する.

#### 失敗時レスポンス

Discord追加認可必須時のToken未指定は`ApiErrorResponse(API_ERROR_DISCORD_AUTHORIZATION_REQUIRED)`, Token不正または使用済みは`ApiErrorResponse(API_ERROR_INVALID_DISCORD_AUTHORIZATION_TOKEN)`を返す. Account認証失敗は`ApiErrorResponse(API_ERROR_INVALID_CREDENTIALS)`を返す. Private API ServerのArgon2id同時実行上限到達時は`ApiErrorResponse(API_ERROR_RATE_LIMIT_EXCEEDED)`を返す. Version不一致は`LoginVersionErrorResponse`を返す.

### AccessToken更新

#### メソッド名

`RefreshAccessToken`

#### 処理内容

- `__Host-RefreshToken` CookieからRefreshTokenを取得する. Request BodyからRefreshTokenを受け付けない.
- 設定済みClient Originと`Origin` Headerが一致することを確認し, 不一致の場合は処理しない.
- Private API Serverの`RefreshAccessToken`へRefreshTokenを送信する.
- Private API ServerでRefreshTokenのcurrent/previous Hash, Session存在, 有効期限を検証する.
- current Hash一致時はRefreshTokenをRotationし, 新しいAccessTokenとRefreshTokenを返す.
- previous Hash一致時はRefreshToken再利用としてRefresh Sessionを無効化する.
- RefreshTokenが無効, 期限切れまたは再利用検知となった場合は`__Host-RefreshToken` Cookieを削除する.
- Public API ServerはRotation後RefreshTokenをResponse Bodyへ含めず, `__Host-RefreshToken` Cookieを更新する.
- Refresh Sessionの24時間期限は本処理では延長しない.

#### 要求データ

[API Payload](api_payload.md)の「RefreshAccessTokenRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「RefreshAccessTokenResponse」を参照する.

#### 失敗時レスポンス

[API Payload](api_payload.md)の`ApiErrorResponse(API_ERROR_INVALID_REFRESH_TOKEN)`を返す.

### ログアウト

#### メソッド名

`Logout`

#### 処理内容

- `__Host-RefreshToken` CookieからRefreshTokenを取得する. Request BodyからRefreshTokenを受け付けない.
- 設定済みClient Originと`Origin` Headerが一致することを確認し, 不一致の場合は処理しない.
- Private API Serverの`Logout`へRefreshTokenを送信する.
- Private API ServerはRefreshTokenに対応する`ACCOUNT_SESSION`を削除する.
- Public API Serverは`__Host-RefreshToken` Cookieを削除する.
- 既に発行済みのAccessTokenは自身の`exp`到達まで最大5分間有効とする.

#### 要求データ

[API Payload](api_payload.md)の「LogoutRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「LogoutResponse」を参照する.

### 騎士団新規作成

#### メソッド名

`CreateGuild`

#### 処理内容

- AccessTokenを検証し, Requestの`PlayerID`が検証済みTokenのPlayerIDと一致することを確認して`AuthenticatedContext`を生成する.
- GuildNameがUTF-8, 最大10文字, 空文字不可のBoundary Validationを満たすことを確認する. GuildNameの重複可否やGuild初期値はPublic API Serverで判定しない.
- `GuildName`, `DaytimeStartTime`, `NighttimeStartTime`と`AuthenticatedContext`をPrivate API Serverの`CreateGuildPrivate`へ中継する.
- GuildID, 施設Level, 団長・副団長, 所属, `membership_locked`および開始時刻のDomain Validation・初期化はPrivate API ServerがDatabase上の現在状態を用いて行う.
- `CreateGuildPrivate`の同一Upstream Requestが処理失敗した場合は同一要求を1回だけ再実行する. 再実行も失敗した場合は`RequiredOperationErrorResponse`で`API_ERROR_REQUIRED_OPERATION_FAILED`と固定文言`必要な処理が実行できませんでした`だけをClientへ返す.

#### 要求データ

[API Payload](api_payload.md)の「CreateGuildRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「CreateGuildResponse」を参照する.

#### 失敗時レスポンス

GuildNameがBoundary Validationを満たさない場合は`ApiErrorResponse(API_ERROR_INVALID_GUILD_NAME)`を返す. `CreateGuildPrivate`の1回再実行後も処理できない場合は`RequiredOperationErrorResponse`を返す. Private API Serverが返したDomain Errorは対応するPublic API Errorへ変換する.

### 騎士団役職変更

#### メソッド名

`UpdateGuildLeadership`

#### 処理内容

- AccessTokenを検証し, Requestの`PlayerID`が検証済みTokenのPlayerIDと一致することを確認して`AuthenticatedContext`を生成する.
- `GuildID`, `LeaderPlayerID`, `SubleaderPlayerID`と`AuthenticatedContext`をPrivate API Serverの`UpdateGuildLeadershipPrivate`へ中継する.
- 団長権限, 対象Guild所属, 副団長未設定値`0`, 団長・副団長同一PlayerID禁止を含むDomain Validationと更新はPrivate API Serverが同一Databaseトランザクションで行う.
- Private API Serverが団長権限なしを返した場合は`ApiErrorResponse(API_ERROR_GUILD_LEADERSHIP_CHANGE_NOT_ALLOWED)`, 変更対象不正を返した場合は`ApiErrorResponse(API_ERROR_INVALID_GUILD_LEADERSHIP_TARGET)`へ変換する.

#### 要求データ

[API Payload](api_payload.md)の「UpdateGuildLeadershipRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「UpdateGuildLeadershipResponse」を参照する.

### 騎士団加入申請

#### メソッド名

`ApplyGuildJoin`

#### 処理内容

- AccessTokenを検証し, Requestの`PlayerID`が検証済みTokenのPlayerIDと一致することを確認して`AuthenticatedContext`を生成する.
- `GuildID`と`AuthenticatedContext`をPrivate API Serverの`ApplyGuildJoinPrivate`へ中継する.
- 現在所属Guildの役職・所属人数と団長移動制約のDomain Validation, 未承認加入申請保存はPrivate API ServerがDatabase上の現在状態を用いて行う.
- 本Public API Serverでは所属GuildIDを変更せず, Domain条件を判定しない.

#### 要求・レスポンス

[API Payload](api_payload.md)の「ApplyGuildJoinRequest」「ApplyGuildJoinResponse」を参照する.

#### 失敗時レスポンス

団長以外のメンバーが存在するGuildの団長が申請した場合は`API_ERROR_GUILD_LEADER_MOVE_NOT_ALLOWED`を返す.

### 騎士団加入申請承認

#### メソッド名

`ApproveGuildJoinApplication`

#### 処理内容

- AccessTokenを検証し, Requestの`PlayerID`が検証済みTokenのPlayerIDと一致することを確認して`AuthenticatedContext`を生成する.
- `GuildID`, `ApplicantPlayerID`と`AuthenticatedContext`をPrivate API Serverの`ApproveGuildJoinApplicationPrivate`へ中継する.
- 承認権限, 加入申請存在, `membership_locked`, 所属人数上限, 団長移動制約および所属変更はPrivate API Serverが同一Databaseトランザクションで判定・実行する.

#### 要求・レスポンス

[API Payload](api_payload.md)の「ApproveGuildJoinApplicationRequest」「ApproveGuildJoinApplicationResponse」を参照する.

#### 失敗時レスポンス

所属人数が20人の場合は`API_ERROR_GUILD_FULL`, 承認権限がない場合は`API_ERROR_GUILD_JOIN_APPROVAL_NOT_ALLOWED`, 加入申請が存在しない場合は`API_ERROR_GUILD_JOIN_APPLICATION_NOT_FOUND`, 所属変更禁止期間の場合は`API_ERROR_GUILD_MEMBERSHIP_CHANGE_NOT_ALLOWED`, 申請Playerが団長移動制約に違反する場合は`API_ERROR_GUILD_LEADER_MOVE_NOT_ALLOWED`を返す.

### 騎士団招待送信

#### メソッド名

`SendGuildInvitation`

#### 処理内容

- AccessTokenを検証し, Requestの`PlayerID`が検証済みTokenのPlayerIDと一致することを確認して`AuthenticatedContext`を生成する.
- `GuildID`, `InviteePlayerID`と`AuthenticatedContext`をPrivate API Serverの`SendGuildInvitationPrivate`へ中継する.
- 招待権限および招待対象Playerの団長移動制約のDomain Validation, 招待保存はPrivate API ServerがDatabase上の現在状態を用いて行う.
- 本Public API Serverでは招待対象Playerの所属GuildIDを変更せず, Domain条件を判定しない.

#### 要求・レスポンス

[API Payload](api_payload.md)の「SendGuildInvitationRequest」「SendGuildInvitationResponse」を参照する.

#### 失敗時レスポンス

団長・副団長以外が要求した場合は`API_ERROR_GUILD_INVITATION_NOT_ALLOWED`, 招待対象Playerが団長移動制約に違反する場合は`API_ERROR_GUILD_LEADER_MOVE_NOT_ALLOWED`を返す.

### 騎士団招待承諾

#### メソッド名

`AcceptGuildInvitation`

#### 処理内容

- AccessTokenを検証し, Requestの`PlayerID`が検証済みTokenのPlayerIDと一致することを確認して`AuthenticatedContext`を生成する.
- `GuildID`と`AuthenticatedContext`をPrivate API Serverの`AcceptGuildInvitationPrivate`へ中継する.
- 未承諾招待存在, `membership_locked`, 所属人数上限, 団長移動制約および所属変更はPrivate API Serverが同一Databaseトランザクションで判定・実行する.

#### 要求・レスポンス

[API Payload](api_payload.md)の「AcceptGuildInvitationRequest」「AcceptGuildInvitationResponse」を参照する.

#### 失敗時レスポンス

所属人数が20人の場合は`API_ERROR_GUILD_FULL`, 招待が存在しない場合は`API_ERROR_GUILD_INVITATION_NOT_FOUND`, 所属変更禁止期間の場合は`API_ERROR_GUILD_MEMBERSHIP_CHANGE_NOT_ALLOWED`, 要求Playerが団長移動制約に違反する場合は`API_ERROR_GUILD_LEADER_MOVE_NOT_ALLOWED`を返す.

### 騎士団脱退

#### メソッド名

`LeaveGuild`

#### 処理内容

- AccessTokenを検証し, Requestの`PlayerID`が検証済みTokenのPlayerIDと一致することを確認して`AuthenticatedContext`を生成する.
- `AuthenticatedContext`をPrivate API Serverの`LeaveGuildPrivate`へ中継する.
- 脱退元Guildと復帰先初期Guildの`membership_locked`, 団長移動制約, 初期Guild復帰, 必要な所属スワップおよび役職更新はPrivate API Serverが同一Databaseトランザクションで判定・実行する. 新しいGuildは作成しない.

#### 要求データ

[API Payload](api_payload.md)の「LeaveGuildRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「LeaveGuildResponse」を参照する.

#### 失敗時レスポンス

所属変更禁止期間の場合は`ApiErrorResponse(API_ERROR_GUILD_MEMBERSHIP_CHANGE_NOT_ALLOWED)`, 団長以外のメンバーが存在するGuildの団長が脱退しようとした場合は`ApiErrorResponse(API_ERROR_GUILD_LEADER_MOVE_NOT_ALLOWED)`を返す.

## 編成共通Validation

アリーナ編成および騎士団戦編成では以下を共通Validationする.

- `FormationID`はDatabase固定参照データ`FORMATION`に存在するIDを指定する.
- 有効な本体`CharacterID`はCharacter MasterDataに存在するIDだけを許可し, 本体キャラクター同士で同一CharacterIDを重複指定できない.
- `FollowerCharacterID[2]`の予約済み無効値以外の各IDはCharacter MasterDataに存在することを必須とする.
- 各本体キャラクターについて, 予約済み無効値以外の`FollowerCharacterID`が当該本体`CharacterID`と一致する編成を拒否する. この規則はArena編成とGuildBattle編成の双方に適用する.
- `AbilityID[2]`の予約済み無効値以外の各IDは, 当該本体キャラクターの`CharacterMasterData.ability_ids`に含まれることを必須とする.
- 同一本体キャラクターのAbilityスロットでは同一AbilityIDを重複指定できず, さらに同一`AbilityEffectID`を持つAbilityを複数指定できない.
- `MainSkillID`は, 当該本体キャラクターの`CharacterMasterData.skill_ids`または現在その本体キャラクターへ編成している従者の`CharacterMasterData.skill_ids`のいずれかに含まれることを必須とする.
- 従者の空きスロットを表す予約済み無効値はMainSkill候補へ含めない.
- 従者スロットのレアリティ制約および同一本体キャラクター内での従者重複禁止は「[従者仕様](../../specification/game/follower.md)」に従う. 別の本体キャラクター間で同一従者CharacterIDを使用することは許可する.

## アリーナ関連

### パーティ変更

#### メソッド名

`UpdateArenaParty`

#### 処理内容

- ClientはPublic APIを呼び出す前にアリーナ編成制約を検証する.
- GameServerは受信した編成データを用いて同じ編成制約を再検証する.
- `Characters`は1～5件とし, 各`Position`はフォーメーション内部番号1～9だけを許可する. 同一`Position`への複数本体キャラクター配置は編成不正とする.
- 検証成功後, GameServerからPrivate API Serverへ編成情報登録を要求する.
- Private API ServerがDatabaseへ編成情報を登録する.

#### 要求データ

[API Payload](api_payload.md)の「UpdateArenaPartyRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「UpdateArenaPartyResponse」を参照する.

#### 編成不正時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照する. `API_ERROR_INVALID_PARTY`.

### アリーナ開始

#### メソッド名

`StartArenaBattle`

#### 処理内容

- AccessToken, PlayerID等の要求検証を完了する.
- `ArenaBattleRequest.ClientVersion`と処理対象GameServer自身の`Version`を比較する. 不一致の場合は戦闘処理を開始せず`ClientVersionMismatchResponse`を返す.
- Clientが送信した`LocalFormationID`・`LocalCharacters`とDatabaseから取得した要求元ArenaPartyを比較する. 一致結果を`OwnPartyMatched`として返し, 不一致の場合はDatabase上の`OwnFormationID`・`OwnCharacters`をClient側の正しい編成として返す.
- GameServer共通内部API`GenerateTimeBasedSeed`を使用して時刻ベースSeedを生成する.
- `Mode=random`の場合は候補PlayerIDをPlayerID昇順に並べ, 生成したSeedを用いて対戦相手を抽選する.
- GameServerはPrivate API Server経由でDatabaseから要求元PlayerIDと対戦相手PlayerIDの両方について`GetArenaBattleData`を実行し, 双方のFormationID・編成情報を取得する.
- 要求元PlayerIDのArenaPartyが未登録の場合は対戦処理を開始せず`ARENA_BATTLE_ERROR_REQUESTER_ARENA_PARTY_NOT_REGISTERED`を返す.
- `Mode=friend`で指定した`OpponentID`がDatabaseに存在しない場合は`ARENA_BATTLE_ERROR_PLAYER_NOT_FOUND`を返す.
- `Mode=friend`で指定した`OpponentID`は存在するがArenaParty未登録の場合は`ARENA_BATTLE_ERROR_ARENA_PARTY_NOT_REGISTERED`を返す.
- 対戦相手抽選後, 戦闘開始前に同じSeedから戦闘専用の新しいPRNGを生成する. 対戦相手抽選で進んだPRNG状態は引き継がない.
- GameServerが自分側と相手側双方のFormationID・キャラクター初期状態を用いて戦闘を実行し, その計算結果を正本とする.
- 成功レスポンスでは戦闘結果そのものは返さず, Clientが同一戦闘を再現するための自分側編成一致結果・Server保存自分側編成・`EnemyFormationID`・相手キャラクター初期状態・Seedを返す. Clientは`OwnPartyMatched=false`の場合, Server保存自分側編成でローカル編成を上書きしてその編成を戦闘再現に使用する.
- Clientも戦闘開始前に同じSeedから戦闘専用の新しいPRNGを生成する.

#### 要求データ

[API Payload](api_payload.md)の「ArenaBattleRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「ArenaBattleResponse」を参照する.

#### エラー時レスポンス

[API Payload](api_payload.md)の「ArenaBattleErrorResponse」を参照する. 要求元PlayerIDのArenaPartyが未登録の場合は`ARENA_BATTLE_ERROR_REQUESTER_ARENA_PARTY_NOT_REGISTERED`, ランダム対戦で候補が存在しない場合は`ARENA_BATTLE_ERROR_NO_OPPONENT_AVAILABLE`, フレンド対戦でOpponentIDが存在しない場合は`ARENA_BATTLE_ERROR_PLAYER_NOT_FOUND`, OpponentIDは存在するがArenaParty未登録の場合は`ARENA_BATTLE_ERROR_ARENA_PARTY_NOT_REGISTERED`を返す. `ClientVersion`がGameServer Versionと不一致の場合は`ClientVersionMismatchResponse`を返す.


## 騎士団戦関連

騎士団戦参加後, GameServerは`GuildBattleID`ごとに`PlayerID -> RequestSequence`のマップを保持する.

- 参加前の初期値は`0`とする.
- 初回の`JoinGuildBattle`成功時に限り, 騎士団戦本体PRNGを1回消費して`next_bounded(1,000,000,000) + 1`を求め, プレイヤー固有の初期RequestSequenceとして割り当てる. 他プレイヤーとの重複は許可する. すでにJoin済みのPlayerが再実行した場合はPRNGを消費せず, 現在保持しているRequestSequenceを返す.
- 参加後の騎士団戦PublicAPI要求は, 再接続用の`GetGuildBattleStatus`を除き`GuildBattleID`, `PlayerID`, `RequestSequence`を含む.
- `GetGuildBattleStatus`はAccessToken・PlayerID・GuildBattleIDで本人性と参加状態を検証し, 現在のRequestSequenceを含む状態一式を返す. この要求ではRequestSequenceを加算しない.
- 要求RequestSequenceがGameServer保持値と一致する場合のみ処理する.
- 一致しない場合は`ApiErrorResponse(API_ERROR_INVALID_GUILD_BATTLE_SEQUENCE)`を返す.
- `GetGuildBattleStatus`を除く要求が成功するたびにGameServer保持RequestSequenceを`1`加算し, 成功レスポンスの`NextRequestSequence`としてClientへ返す.
- 失敗した要求ではRequestSequenceを加算しない.


### 騎士団戦パーティ変更

#### メソッド名

`UpdateGuildBattleParty`

#### 処理内容

- ClientはPublic APIを呼び出す前に騎士団戦編成制約を検証する.
- GameServerは受信した編成データを用いて同じ編成制約を再検証する.
- `GuildBattlePartyCharacter[10]`のうち有効な本体キャラクターを1～10件とし, 各`PriorityPosition`はフォーメーション内部番号1～9だけを許可する. 複数本体キャラクターの同一`PriorityPosition`指定は「[フォーメーション仕様](../../specification/game/formation.md)」に従い許可する.
- 検証成功後, GameServerからPrivate API Serverへパーティ情報登録を要求する.
- Private API ServerがDatabaseへパーティ情報を登録する.

#### 要求データ

[API Payload](api_payload.md)の「UpdateGuildBattlePartyRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「UpdateGuildBattlePartyResponse」を参照する.

#### 変更不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照する. 時間条件により変更不可の場合は`API_ERROR_GUILD_BATTLE_PARTY_UPDATE_NOT_ALLOWED`, 編成制約違反の場合は`API_ERROR_INVALID_PARTY`を返す.

### 騎士団戦参加通知

#### メソッド名

`JoinGuildBattle`

#### 処理内容

- Public API ServerがGameServerへ参加通知を送る.
- GameServerは`JoinGuildBattleRequest.ClientVersion`と自身の`Version`を比較し, 不一致の場合は参加処理を開始せず`ClientVersionMismatchResponse`を返す.
- GameServerが参加チェックを行う.
  - 要求`GuildBattleID`が騎士団戦中であることを確認する.
  - 要求`GuildID`が, その`GuildBattleID`で対戦中の騎士団のいずれかであることを確認する.
  - `PlayerID`の現在所属GuildIDが要求`GuildID`と一致することを確認する.
- 参加可能時は`AuthenticatedContext.SessionID`に対応するRefresh SessionがPrivate API Server上で有効であることを確認する. Sessionが存在しない, またはLogin成功時刻から24時間の期限を過ぎている場合は参加を拒否する. 本処理ではSession期限を延長しない.
- Client送信の`LocalFormationID`・`LocalCharacters`とGameServerがPreload済みの当該Player編成を比較する. 一致結果を`PartyMatched`として返す. 不一致の場合は`ServerFormationID`・`ServerCharacters`を返し, ClientはServer編成でローカル編成を上書きして参加後の表示・操作に使用する.
- PlayerIDが未Joinの場合だけ騎士団戦本体PRNGを消費して初期RequestSequenceを割り当てる. すでにJoin済みの場合はPRNGを消費せず現在保持しているRequestSequenceを返す.

#### 要求データ

[API Payload](api_payload.md)の「JoinGuildBattleRequest」を参照する.

#### 参加可能時レスポンス

[API Payload](api_payload.md)の「GuildBattleJoinResponse」を参照する.

#### 参加不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照する. 参加条件違反は`API_ERROR_GUILD_BATTLE_JOIN_NOT_ALLOWED`. Version不一致は`ClientVersionMismatchResponse`を返す.

### 騎士団戦状態取得

#### メソッド名

`GetGuildBattleStatus`

#### 処理内容

- AccessToken, PlayerID, GuildBattleIDから参加中プレイヤーを検証する.
- 再接続時にClient状態を復元するため, 現在HP, BP, TP, 治療・復活状態, 出撃待機, タクティクス状態, アイテム残数, スコア, チェイン, CBC状態, 現在RequestSequenceを取得する.
- 本APIではRequestSequenceを加算しない.

#### 要求データ

[API Payload](api_payload.md)の「GetGuildBattleStatusRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「GetGuildBattleStatusResponse」を参照する.

### 出撃要求

#### メソッド名

`GuildBattleSortie`

#### 処理内容

- 出撃可否をチェックする.
- 騎士団戦全体の`Sequence`を加算する.
- 出撃内容を抽選する.
- キャッスルブレイク処理または戦闘処理を行う.
- チェイン処理を行う.

#### 要求データ

[API Payload](api_payload.md)の「GuildBattleSortieRequest」を参照する.

#### キャッスルブレイク時レスポンス

[API Payload](api_payload.md)の「GuildBattleCastleBreakResponse」を参照する.

#### 殲滅時レスポンス

[API Payload](api_payload.md)の「GuildBattleAnnihilationResponse」を参照する.

#### 出撃不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照する. `API_ERROR_GUILD_BATTLE_SORTIE_NOT_ALLOWED`.

### タクティクス使用要求

#### メソッド名

`UseTactics`

#### 処理内容

GameServer側のチェック.

- 要求TacticsIDが当該プレイヤーの騎士団戦編成キャラクターから使用可能になっているタクティクスであること.
- `TacticsUseCondition`を満たしていること. `TACTICS_USE_CONDITION_ALL_ANNIHILATED`は使用プレイヤーのパーティが全滅している場合だけ成立する.
- TP.
- 使用回数.

使用条件を満たさない場合は使用不可として拒否し, TP・使用回数・RequestSequenceを変更しない. ランダム要素を持つタクティクスではGameServerが騎士団戦の現在の疑似乱数生成器から1値を取得して`Seed`とし, そのSeedから生成したタクティクス固有疑似乱数生成器でランダム結果を決定する.

#### 要求データ

[API Payload](api_payload.md)の「UseTacticsRequest」を参照する.

#### 使用可能時レスポンス

[API Payload](api_payload.md)の「UseTacticsResponse」を参照する. ランダム要素を使用した場合は再現用`Seed`, 使用しない場合は`Seed=0`を返す.

#### 使用不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照する. `API_ERROR_TACTICS_NOT_AVAILABLE`.

### アイテム使用要求

#### メソッド名

`UseItem`

#### 処理内容

#### 要求データ

[API Payload](api_payload.md)の「UseItemRequest」を参照する.

#### GameServer側のチェック

- 所持数.

#### 使用可能時レスポンス

[API Payload](api_payload.md)の「UseItemResponse」を参照する.

#### 使用不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照する. `API_ERROR_ITEM_NOT_AVAILABLE`.

### 治療開始要求

#### メソッド名

`StartHeal`

#### 処理内容

#### 要求データ

[API Payload](api_payload.md)の「StartHealRequest」を参照する.

#### GameServer側のチェック

- 回復状態でないとする.

#### 開始可能時の処理

- 治療開始前が全滅状態であるかを回復状態に保持する.
- 回復待機時間を算出する.
- 回復中状態へ変更する.

#### 開始可能時レスポンス

[API Payload](api_payload.md)の「StartHealResponse」を参照する.

#### 開始不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照する. `API_ERROR_HEAL_NOT_AVAILABLE`.

### 治療キャンセル要求

#### メソッド名

`CancelHeal`

#### 処理内容

#### 要求データ

[API Payload](api_payload.md)の「CancelHealRequest」を参照する.

#### GameServer側のチェック

- 回復中状態である.

#### キャンセル可能時の処理

- 回復待機時間をリセットする.
- 回復中状態を解除する.
- 治療開始前が全滅状態の場合は全滅状態へ戻す.
- 治療開始前が全滅状態でない場合は通常状態へ戻す.
- HP / BPは回復しない.

#### レスポンス

[API Payload](api_payload.md)の「CancelHealResponse」を参照する.

- 失敗: [API Payload](api_payload.md)の「ApiErrorResponse」を参照する. `API_ERROR_HEAL_CANCEL_NOT_ALLOWED`.

### 治療完了要求

#### メソッド名

`CompleteHeal`

#### 処理内容

#### 要求データ

[API Payload](api_payload.md)の「CompleteHealRequest」を参照する.

#### GameServer側のチェック

- 回復完了状態である.

#### 完了可能時の処理

- BP/HP回復処理を行う.
- 回復状態を解除する.

#### 完了可能時レスポンス

[API Payload](api_payload.md)の「CompleteHealResponse」を参照する.

#### 完了不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照する. `API_ERROR_HEAL_COMPLETE_NOT_ALLOWED`.

### 復活開始要求

#### メソッド名

`StartRevive`

#### 処理内容

#### 要求データ

[API Payload](api_payload.md)の「StartReviveRequest」を参照する.

#### GameServer側の処理

- 復活可能かチェックする.
- 「[パーティランク](../../specification/game/party_rank.md)」に従ってパーティランクを算出し, 復活待機時間を決定する.
- 復活可能な場合は復活中状態へ変更する.

#### 復活可能時レスポンス

[API Payload](api_payload.md)の「StartReviveResponse」を参照する.

パーティランクに応じた復活待機時間経過後, GameServerは復活完了状態へ変更する. この時点ではBP消費・HP回復は行わない.

#### 復活不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照する. `API_ERROR_REVIVE_NOT_AVAILABLE`.

### 復活キャンセル要求

#### メソッド名

`CancelRevive`

#### 処理内容

#### 要求データ

[API Payload](api_payload.md)の「CancelReviveRequest」を参照する.

#### GameServer側のチェック

- 復活中状態である.

#### キャンセル可能時の処理

- 復活待機時間を破棄する.
- 全滅状態へ戻す.

#### レスポンス

[API Payload](api_payload.md)の「CancelReviveResponse」を参照する.

- 失敗: [API Payload](api_payload.md)の「ApiErrorResponse」を参照する. `API_ERROR_REVIVE_CANCEL_NOT_ALLOWED`.

### 復活完了要求

#### メソッド名

`CompleteRevive`

#### 処理内容

#### 要求データ

[API Payload](api_payload.md)の「CompleteReviveRequest」を参照する.

#### GameServer側のチェック

- 復活完了状態である.

#### 完了可能時の処理

- BP/HP処理を行う.
- 全滅状態を解除する.

#### 完了可能時レスポンス

[API Payload](api_payload.md)の「CompleteReviveResponse」を参照する.

#### 完了不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照する. `API_ERROR_REVIVE_COMPLETE_NOT_ALLOWED`.

# Private API仕様

Methodごとの通信Pathは`POST /v1/private/{MethodName}`とし、wire schemaは`design/system/private_api.proto`、Transportは`design/system/api_transport.md`を正とする。

API全体の分類は「[API仕様](api.md)」を参照する.

- Private Network 内に配置される.
- 認証・Account・Guild・騎士団戦ルーティング関連要求はPublic API Serverから受ける.
- Database保存・取得要求はGameServerおよびGuildBattleCoordinatorから受ける.
- `AdditionalAuthorizationProvider=DISCORD`の場合, Discord BotからはRole喪失時の`RevokeDiscordSessions`だけを受け付ける.
- Public API Server, GameServer, GuildBattleCoordinatorおよびDiscord BotとPrivate API Server間の通信はmTLSを必須とし, 双方が信頼済みCAによる証明書を検証する. Clientからの直接接続を受け付けない.
- mTLS証明書のService Identityを検証し, Public API Serverからは認証・Account・Guild・騎士団戦ルーティング関連API, GameServerからはゲームデータ関連API, GuildBattleCoordinatorからは騎士団戦生成・割当・再抽選に必要なAPI, Discord Botからは`RevokeDiscordSessions`だけを受け付ける. 運営用APIはmTLSで識別した運営Componentからだけ受け付ける.
- Databaseへ直接接続できるApplication ComponentはPrivate API Serverだけとする.
- AccessToken署名用秘密鍵はPrivate API Serverだけが保持する.
- Databaseとのデータ保存・取得を仲介する. Arenaの抽選はGameServer, 騎士団戦のマッチング生成はGuildBattleCoordinatorが行う.
- Database上の`GUILD_BATTLE.status`遷移はPrivate API Server内の`GuildBattleLifecycleService`が所有する. 状態遷移規則は「[騎士団戦永続ライフサイクル](guild_battle_lifecycle.md)」を正とし, 任意statusを指定する汎用更新APIは公開しない.
- 要求/レスポンスのデータ構造は[API Payload](api_payload.md)を参照する. Private APIの要求・レスポンスPayloadはProtocol Buffersで表現する. 各メソッドのfield number・wire schemaは`design/system/private_api.proto`, HTTP Method/Pathは`design/system/api_transport.md`を正とする.
- Public API Serverから受信するAccessToken認証済みのAccount/Guild系内部要求では`AuthenticatedContext`を内部Request Contextとして必須とする. Caller Identityは`AuthenticatedContext.PlayerID`を正とし, Client由来のPlayerIDをCaller Identityとして使用しない. 内部PayloadにCaller PlayerIDと同義のフィールドが存在する場合はPublic API Serverが`AuthenticatedContext`から設定し, Private API Serverは不一致を拒否する.
- 騎士団戦中のDatabase送信では初回送信開始から5秒以内にCOMMITを確認できない場合、DB/NW障害と判定する。同一要求のRetryは合計5秒以内で最大1回とし、Recovery移行後は当該Battle終了までDBへ再接続しない。 Replay Workerによるリプレイログ送信も同じ規則を使用する. 再試行も失敗した場合, GameServerはDB障害発生状態へ移行し, それ以降の騎士団戦中DB送信を行わず, 本来送信するデータを`/var/lib/game-server/recovery/guild_battle_<GuildBattleID>_<InstanceID>/event_<EventIndex>_<OperationID>.json`に不変レコードとして保存する。Workerが一時ファイル、SHA-256検査、ファイルfsync、原子的rename、親ディレクトリfsyncまで確定して初めて当該Eventを成立扱いとする。 Replay EventのRecovery保存は専用Worker側で行い、騎士団戦処理スレッド自身はファイルI/Oを実行しない。ただし成立操作の成功応答は当該Workerの耐久化完了通知の後とする。 本番Kubernetes環境では同PathをGameServer専用Persistent Volumeへmountし, GameServer実行Userだけが読み書き可能とする. Recovery保存領域にはGameServer Instanceごとに運用設定で容量上限およびファイル数上限を必須設定し, 推奨初期値を2 GiBおよび1,000 filesとする. 無制限に増加させない. ファイルはGameServer再起動後も保持する. 騎士団戦終了後に残存RecoveryファイルをEvent番号・保存順で一括再送し、GameServer起動時には終了済みBattleの残存ファイルだけ再送し, 全件成功時だけ対応ファイルを削除し, 途中失敗時は削除せず残す.
- `GuildBattleLifecycleService`による状態変更および騎士団戦中にDatabase状態を変更する要求は共通HTTP Header `X-Operation-ID`を必須とする. 値は128bit UUIDとし, 同一論理操作の初回送信, 1回再試行, Recovery再送で同じ値を使用する. Private API ServerはDatabaseトランザクション内でOperation IDの重複を検査し, 処理済みの場合は更新を再適用せず初回成功時レスポンスを返す.
- `CompleteGuildBattle`は専用の失敗処理を使用し, 1回再試行しても失敗した場合はErrorLogを保存し, `DiscordNotificationEnabled=true`の場合はBot通知を行った後, 運営による手動復旧対象とする.

## 騎士団施設・検索・編成・Replay読み取り

- `UpgradeGuildFacilityPrivate`は認証済み`PlayerID`の`GUILD_MEMBER`所属・残高・施設Lv・費用表をDBトランザクション内で再確認し、必要額だけを`PLAYER.gold`から減額して対象施設Lvを1加算する。`offered_gold`が必要額未満、Player残高不足、施設最大Lvの場合は更新しない。1回のAPIで2Lv以上上がらない。重複する同一論理操作の更新を二重適用しない。要求額が必要額を超える分は徴収しない。
- `GetGuildFacilityUpgradeCostPrivate`は対象Guildの現在Lvと次Lv必要Gold、最大Lvかどうかを返す。`GetGuildDetailPrivate`はGuild情報・所属Player・役職・施設値をDBから取得する。
- `UpdateGuildBattleStartTimesPrivate`は要求者が現在団長であることと昼夜の許容値を確認し、翌JST 0:00適用の保留設定を更新する。マッチング済み対戦は変更しない。
- `SearchGuildsPrivate`および`SearchPlayersPrivate`は名前prefix照合で通常Guild/PlayerだけをID昇順・指定Limit以内で返す。`ListGuildJoinApplicationsPrivate`はAuthenticatedContextにより対象Guildの団長/副団長のみ受け付け、`ListGuildInvitationsPrivate`は招待された本人向けに未処理行だけを取得する。Public APIの認証済みCaller Identityを必須とする。
- `GetMyArenaPartyPrivate`, `GetMyGuildBattlePartyPrivate`は呼出元本人のDB保存編成を返す。未登録の場合は`registered=false`とする。`GetMyGuildBattlePrivate`は所属Guildへの対戦割当をDBから取得し、`GetGuildBattleResultPrivate`は確定済み対戦結果を取得する。
- `ListMyGuildBattleReplaysPrivate`は現段階でPlayer向けに公開しない。将来公開する場合、本人参加記録が確認できる現行Versionの対戦を開始時刻降順・ID降順で50件まで返す。`GetMyGuildBattleReplayPrivate`は同じアクセス条件を再検証し、当該対戦の`event_index`昇順に、1から連続することを検証してEnvelopeを返す。過去VersionのReplayをプレイヤーへ返さない。


開始時刻変更の適用時刻は要求を受け付けたJST日付の翌日00:00とする。`GetGuildsForBattleMatching`は対象のJST日付に有効な昼夜時刻を使用し、適用前に生成済みの`GUILD_BATTLE`には遡って変更を加えない。

## 認証コードの永続化

`IssueAuthorizationCodePrivate`では第一者認証OriginのCookieから渡されたRefreshTokenをPrivate APIが検証してSessionを識別する。`RedeemAuthorizationCodePrivate`ではコード未使用、60秒期限、Session有効、URI完全一致、PKCE S256一致を原子的に判定し、成立した場合だけコードを消費してAccessTokenを発行する。`design/system/private_api.proto`を正とする。

## 認証・アカウント関連

### アカウント新規作成

#### メソッド名

`CreateAccount`

#### 処理内容

- LoginIDの重複をDatabaseで確認する.
- LoginID重複時は作成せず, ClientへLoginID重複を区別して返さない.
- `AdditionalAuthorizationProvider=DISCORD`の場合は要求DiscordAuthorizationTokenIDが未使用であることを確認する.
- Passwordごとに16byte以上の暗号学的乱数Saltを生成し, PasswordをArgon2idでPasswordHashへ変換する.
- Argon2id処理は認証専用の同時実行制限対象とし, 設定済み最大同時実行数を超えて開始しない. 空きがない場合は待機キューを無制限に増加させず, `API_ERROR_RATE_LIMIT_EXCEEDED`として拒否する.
- AccountIDおよびPlayerIDを生成する.
  - `0`と`u64::MAX`は予約済み無効値のため生成対象外.
  - Databaseの一意制約に衝突した場合は再生成する.
- `ACCOUNT`と`PLAYER`を同一トランザクションで保存する. `AdditionalAuthorizationProvider=DISCORD`の場合はDiscordUserID BindingとDiscordAuthorizationTokenID使用済み記録も同一トランザクションで保存する.
- `PLAYER.max_bp`は200, `guild_battle_win_count`・`guild_battle_lose_count`・`guild_battle_participation_count`・`guild_battle_total_score`は0で初期化する.

#### 要求・レスポンス

[API Payload](api_payload.md)の「CreateAccountPrivateRequest」「CreateAccountPrivateResponse」を参照する.

### アカウント認証

#### メソッド名

`AuthenticateAccount`

#### 処理内容

- LoginIDに対応する`ACCOUNT`および`PLAYER`を取得する.
- `AdditionalAuthorizationProvider=DISCORD`の場合は要求DiscordUserIDが`ACCOUNT.discord_user_id`と一致し, 要求DiscordAuthorizationTokenIDが未使用であることを確認する.
- Argon2id処理は認証専用の同時実行制限対象とし, 設定済み最大同時実行数を超えて開始しない. 空きがない場合は待機キューを無制限に増加させず, `API_ERROR_RATE_LIMIT_EXCEEDED`として拒否する.
- Argon2idでPasswordを検証する.
- LoginID不存在, Password不一致およびDiscordUserID Binding不一致を呼び出し元へ区別して返さない.
- 認証成功時は既存`ACCOUNT_SESSION`を削除する.
- 128bitのSessionIDを暗号学的乱数で生成する.
- 32byteのRefreshTokenを暗号学的乱数で生成する.
- `SHA-256(RefreshToken)`を`refresh_token_hash`として保存し, `previous_refresh_token_hash=NULL`で初期化する.
- `ACCOUNT_SESSION.expires_at`を認証成功時刻から24時間後として保存する.
- `AdditionalAuthorizationProvider=DISCORD`の場合は認証成功と同一トランザクションでDiscordAuthorizationTokenIDを使用済みとして保存する.
- AccessTokenを生成してEd25519で署名する. AccessTokenの有効期限は発行時刻から5分とする.

#### 要求・レスポンス

[API Payload](api_payload.md)の「AuthenticateAccountRequest」「AuthenticateAccountResponse」を参照する.

### AccessToken更新

#### メソッド名

`RefreshAccessToken`

#### 処理内容

- 受信したRefreshTokenをSHA-256でHash化する.
- `ACCOUNT_SESSION.refresh_token_hash`または`previous_refresh_token_hash`と照合し, `expires_at`が有効期限内であることを確認する.
- `refresh_token_hash`と一致した場合は新しいRefreshTokenを生成し, 更新前`refresh_token_hash`を`previous_refresh_token_hash`へ移動してから`refresh_token_hash`を新しいHashへ置換する.
- `previous_refresh_token_hash`と一致した場合はRefreshToken再利用として対象`ACCOUNT_SESSION`を削除し, Tokenを発行しない.
- 新しいAccessTokenを生成してEd25519で署名する.
- `ACCOUNT_SESSION.expires_at`は変更しない.
- RefreshToken検証, Hash置換またはSession削除は同一トランザクションで行い, 対象`ACCOUNT_SESSION`を排他的に更新する. 同一RefreshTokenによる同時要求では1要求だけを成功させる.

#### 要求・レスポンス

[API Payload](api_payload.md)の「RefreshAccessTokenPrivateRequest」「RefreshAccessTokenPrivateResponse」を参照する.

### ログアウト

#### メソッド名

`Logout`

#### 処理内容

- 受信したRefreshTokenをSHA-256でHash化する.
- 一致する`ACCOUNT_SESSION`を削除する.
- 既に発行済みのAccessTokenは個別失効させない.

#### 要求・レスポンス

[API Payload](api_payload.md)の「LogoutPrivateRequest」「LogoutPrivateResponse」を参照する.

### Refresh Session確認

#### メソッド名

`ValidateAccountSession`

#### 処理内容

- 指定SessionIDに対応する`ACCOUNT_SESSION`が存在し, 現在時刻が`expires_at`未満であることを確認する.
- 有効な場合は`IsValid=true`を返す.
- 存在しない, または期限切れの場合は`IsValid=false`を返す.
- 本処理では`expires_at`を変更しない.

#### 要求・レスポンス

[API Payload](api_payload.md)の「ValidateAccountSessionRequest」「ValidateAccountSessionResponse」を参照する.

### Discord Role喪失時Session失効

#### メソッド名

`RevokeDiscordSessions`

#### 処理内容

- `AdditionalAuthorizationProvider=DISCORD`の場合にDiscord Botからだけ受け付ける.
- mTLS証明書のService IdentityがDiscord Botであることを確認する.
- 指定DiscordUserIDと一致する`ACCOUNT.discord_user_id`を持つAccountの`ACCOUNT_SESSION`をすべて削除する.
- 既に発行済みのAccessTokenは個別失効させず, 自身の`exp`到達まで最大5分間有効とする.

#### 要求・レスポンス

[API Payload](api_payload.md)の「RevokeDiscordSessionsRequest」「RevokeDiscordSessionsResponse」を参照する.

## プレイヤー・騎士団関連

### 初期騎士団作成

#### メソッド名

`CreateGuildPrivate`

#### 処理内容

- Public API ServerのService Identityと`AuthenticatedContext`を検証し, `AuthenticatedContext.PlayerID`を作成Playerとして使用する.
- GuildName, DaytimeStartTime, NighttimeStartTimeのDomain Validationを行う. GuildNameの重複は許可する.
- `GuildID = AuthenticatedContext.PlayerID`として初期Guildを作成する.
- `castle_level`, `armory_level`, `food_storage_level`, `smithy_level`, `strategy_office_level`, `tavern_level`をすべて1, `leader_player_id=AuthenticatedContext.PlayerID`, `subleader_player_id=0`, `membership_locked=false`で初期化する.
- `GUILD_MEMBER`へ作成Playerを所属させる. Guild作成, 施設初期値, 役職初期値, 開始時刻, 所属追加は同一Databaseトランザクションで行う.

#### 要求・レスポンス

[API Payload](api_payload.md)の「CreateGuildPrivateRequest」「CreateGuildPrivateResponse」を参照する.

初期Guild作成の前に`GUILD.id=AuthenticatedContext.PlayerID`の存在を確認し、存在する場合は重複作成として拒否する。作成前のPlayerからは認証および初期Guild作成フローに必要な要求だけを許可する。CreateGuildのDB COMMIT後にResponseが失われても再作成を行わない。

### 騎士団役職変更

#### メソッド名

`UpdateGuildLeadershipPrivate`

#### 処理内容

- `AuthenticatedContext.PlayerID`が更新対象`GUILD.leader_player_id`と一致することをDatabase上で確認する.
- 一致しない場合は更新せず, 団長権限なしとしてPublic API Serverへ返す.
- LeaderPlayerIDが対象Guildの`GUILD_MEMBER`に存在することを確認する.
- SubleaderPlayerIDが`0`の場合は副団長未設定として許可する. `0`以外の場合だけ対象Guildの`GUILD_MEMBER`に存在することを確認する.
- SubleaderPlayerIDが`0`以外でLeaderPlayerIDと同一値の場合は更新しない.
- 上記をすべて満たす場合のみ`GUILD.leader_player_id`と`GUILD.subleader_player_id`を更新する. 団長確認, 所属確認, 同一PlayerID禁止確認, 更新は同一トランザクションで行う.

#### 要求データ

[API Payload](api_payload.md)の「UpdateGuildLeadershipPrivateRequest」を参照する.

### 騎士団所属変更ロック更新

#### メソッド名

`SetGuildMembershipLock`

#### 処理内容

- 指定されたすべてのGuildIDについて`GUILD.membership_locked`を要求値へ更新する.
- 騎士団戦開戦前処理開始時は`true`, 騎士団戦終了または運営判断による中止時は`false`へ更新する.
- 所属変更禁止状態の正本はDatabaseの`GUILD.membership_locked`とする.

#### 要求・レスポンス

[API Payload](api_payload.md)の「SetGuildMembershipLockRequest」「SetGuildMembershipLockResponse」を参照する.

### 騎士団加入申請

#### メソッド名

`ApplyGuildJoinPrivate`

#### 処理内容

- `AuthenticatedContext.PlayerID`を申請Playerとして使用し, 現在所属Guildにおける役職と所属人数をDatabaseから取得する.
- 申請Playerが現在所属Guildの団長で, 団長以外のメンバーが1人以上存在する場合は`API_ERROR_GUILD_LEADER_MOVE_NOT_ALLOWED`として申請を保存しない. 副団長にはこの制約を適用しない.
- `GUILD_JOIN_APPLICATION`へ未承認加入申請を保存する.
- 本処理では`GUILD_MEMBER`を変更しない.

#### 要求データ

[API Payload](api_payload.md)の「ApplyGuildJoinPrivateRequest」を参照する.

### 騎士団加入申請承認

#### メソッド名

`ApproveGuildJoinApplicationPrivate`

#### 処理内容

- `AuthenticatedContext.PlayerID`が対象Guildの現在の`leader_player_id`または`subleader_player_id`と一致することをDatabase上で確認する.
- `GUILD_JOIN_APPLICATION`に対象申請が存在することを確認する.
- 同一Databaseトランザクション内でApplicantPlayerIDの現在所属Guildと加入先Guildを取得し, 両Guildの`membership_locked=false`を再確認する.
- ApplicantPlayerIDが現在所属Guildの団長で, 団長以外のメンバーが1人以上存在する場合は加入を成立させない. 副団長にはこの制約を適用しない.
- 対象Guildの`GUILD_MEMBER`件数を同一トランザクション内で確認し, 20人以上の場合は加入を成立させない.
- すべての条件を満たす場合だけApplicantPlayerIDの既存`GUILD_MEMBER`を加入先Guildへ更新する. ApplicantPlayerIDが加入元Guildの副団長だった場合は加入元Guildの`subleader_player_id`を`0`へ戻す. ApplicantPlayerIDが加入元Guildの団長で, 団長以外のメンバーが0人であるため移動可能な場合は加入元Guildの`leader_player_id`を`0`へ更新する. 役職更新・所属更新・対応する加入申請削除は同一トランザクションで行う.

#### 要求データ

[API Payload](api_payload.md)の「ApproveGuildJoinApplicationPrivateRequest」を参照する.

### 騎士団招待送信

#### メソッド名

`SendGuildInvitationPrivate`

#### 処理内容

- `AuthenticatedContext.PlayerID`が対象Guildの現在の団長または副団長であることをDatabase上で確認する.
- InviteePlayerIDが現在所属Guildの団長で, 団長以外のメンバーが1人以上存在する場合は`API_ERROR_GUILD_LEADER_MOVE_NOT_ALLOWED`として招待を保存しない. 副団長にはこの制約を適用しない.
- 権限を満たす場合だけ`GUILD_INVITATION`へ招待を保存する.
- 本処理では`GUILD_MEMBER`を変更しない.

#### 要求データ

[API Payload](api_payload.md)の「SendGuildInvitationPrivateRequest」を参照する.

### 騎士団招待承諾

#### メソッド名

`AcceptGuildInvitationPrivate`

#### 処理内容

- `AuthenticatedContext.PlayerID`宛ての`GUILD_INVITATION`が存在することを確認する.
- 同一Databaseトランザクション内で`AuthenticatedContext.PlayerID`の現在所属Guildと招待元Guildを取得し, 両Guildの`membership_locked=false`を再確認する.
- `AuthenticatedContext.PlayerID`が現在所属Guildの団長で, 団長以外のメンバーが1人以上存在する場合は加入を成立させない. 副団長にはこの制約を適用しない.
- 対象Guildの`GUILD_MEMBER`件数を同一トランザクション内で確認し, 20人以上の場合は加入を成立させない.
- すべての条件を満たす場合だけ`AuthenticatedContext.PlayerID`の既存`GUILD_MEMBER`を招待元Guildへ更新する. 当該Playerが加入元Guildの副団長だった場合は加入元Guildの`subleader_player_id`を`0`へ戻す. 当該Playerが加入元Guildの団長で, 団長以外のメンバーが0人であるため移動可能な場合は加入元Guildの`leader_player_id`を`0`へ更新する. 役職更新・所属更新・対応する招待削除は同一トランザクションで行う.

#### 要求データ

[API Payload](api_payload.md)の「AcceptGuildInvitationPrivateRequest」を参照する.

### 騎士団脱退・初期騎士団復帰

#### メソッド名

`LeaveGuildPrivate`

#### 処理内容

- `AuthenticatedContext.PlayerID`の現在所属GuildIDと`GuildID = AuthenticatedContext.PlayerID`の初期騎士団を取得する.
- 同一Databaseトランザクション内で脱退元Guildと復帰先初期Guildの`membership_locked=false`を再確認する. いずれかが`true`の場合は所属変更・所属スワップを行わない.
- `AuthenticatedContext.PlayerID`が脱退元Guildの団長で, 団長以外のメンバーが1人以上存在する場合は脱退を成立させない.
- 当該Playerが脱退元Guildの副団長だった場合は, 所属変更と同時に脱退元Guildの`subleader_player_id`を`0`へ戻す.
- 当該Playerが脱退元Guildの団長で, 団長以外のメンバーが0人であるため脱退可能な場合は, 所属変更と同時に脱退元Guildの`leader_player_id`を`0`へ更新する.
- 初期騎士団の現在団長が当該Player自身の場合は, 当該Playerだけを初期騎士団へ戻す.
- 初期騎士団の現在団長が別Playerの場合は, 当該Playerを初期騎士団へ戻し, その現在団長Playerを当該Playerが直前まで所属していたGuildIDへ移動し, 初期騎士団の団長を当該Playerへ変更する.
- 所属スワップと団長更新は同一トランザクションで行う.

#### 要求・レスポンス

[API Payload](api_payload.md)の「LeaveGuildPrivateRequest」「LeaveGuildPrivateResponse」を参照する.

## アリーナ関連

### 編成情報登録

#### メソッド名

`SaveArenaParty`

#### 処理内容

- Databaseへアリーナパーティ情報を保存する.

#### 要求データ

[API Payload](api_payload.md)の「SaveArenaPartyRequest」を参照する.

#### レスポンス

[API Payload](api_payload.md)の「SaveArenaPartyResponse」を参照する.

### アリーナ戦闘用データ取得

#### メソッド名

`GetArenaBattleData`

#### 処理内容

- `GetArenaBattleDataRequest.PlayerID`で指定したPlayerのアリーナ戦闘用データをDatabaseから取得する. 要求元Playerと対戦相手Playerの双方で使用する.
- PlayerID自体が存在しない場合は`PlayerExists=false`, `ArenaPartyRegistered=false`を返す.
- PlayerIDは存在するがArenaParty未登録の場合は`PlayerExists=true`, `ArenaPartyRegistered=false`を返す.
- ArenaParty登録済みの場合は両方をtrueとし, FormationIDとCharactersを返す.

#### 要求データ

[API Payload](api_payload.md)の「GetArenaBattleDataRequest」を参照する.

#### レスポンス

[API Payload](api_payload.md)の「GetArenaBattleDataResponse」を参照する.

### 全PlayerID取得

#### メソッド名

`GetAllPlayerIDs`

#### 処理内容

- Random Arenaの対戦要求の都度、Database上でArenaParty登録済みの通常PlayerIDをPlayerID昇順で取得する. GameServerには候補キャッシュを持たせない. ArenaParty未登録PlayerおよびシステムダミーPlayerID `0`は返さない.

#### レスポンス

[API Payload](api_payload.md)の「GetAllPlayerIDsResponse」を参照する.


## 騎士団戦関連

### 騎士団戦マッチング候補取得

#### メソッド名

`GetGuildsForBattleMatching`

#### 処理内容

- 指定`TargetDate`・`StartTime`を設定している通常騎士団について, GuildIDと現在の所属人数をDatabaseから取得する. システムダミーGuildID `0`は通常マッチング候補から除外して返さない.
- 抽選, 0人除外, 並び替え, Seed生成, ペア生成, GuildBattleID生成は行わない. これらのマッチングロジックはGuildBattleCoordinatorが行う.

#### 要求・レスポンス

[API Payload](api_payload.md)の「GetGuildsForBattleMatchingRequest」「GetGuildsForBattleMatchingResponse」を参照する.

### 0人除外騎士団保存

#### メソッド名

`SaveGuildBattleExcludedGuilds`

#### 処理内容

- 対象日・開始時刻で所属0人のためマッチングから除外したGuildID一覧をDatabaseへ保存する.
- 同一対象日・開始時刻の既存一覧は要求一覧で置換する.
- GuildID=0のシステムダミーGuildは保存対象にしない.

#### 要求・レスポンス

[API Payload](api_payload.md)の「SaveGuildBattleExcludedGuildsRequest」「SaveGuildBattleExcludedGuildsResponse」を参照する.

### 0人除外騎士団取得

#### メソッド名

`GetGuildBattleExcludedGuilds`

#### 処理内容

- 対象日・開始時刻に対応する`GUILD_BATTLE_EXCLUDED_GUILD`をGuildID昇順で返す.
- 割当済みGameServerは本一覧を保持し, 時間帯単位の所属ロック解除処理へ使用する.

#### 要求・レスポンス

[API Payload](api_payload.md)の「GetGuildBattleExcludedGuildsRequest」「GetGuildBattleExcludedGuildsResponse」を参照する.

### 0人除外騎士団削除

#### メソッド名

`ClearGuildBattleExcludedGuilds`

#### 処理内容

- 対象日・開始時刻の除外Guild一覧を削除する.
- 所属ロック解除完了後に実行する.

#### 要求・レスポンス

[API Payload](api_payload.md)の「ClearGuildBattleExcludedGuildsRequest」「ClearGuildBattleExcludedGuildsResponse」を参照する.

### 開戦予定騎士団戦保存

#### メソッド名

`SaveScheduledGuildBattles`

#### 処理内容

- GuildBattleCoordinatorが生成した`ScheduledGuildBattle[]`を`GUILD_BATTLE`へ`scheduled`として保存する.
- `start_at`は`TargetDate`と`StartTime`をJSTとして結合した時刻を保存する.
- `end_at`は`start_at + 30分`を保存する.
- `initial_seed`はこの時点では未生成のためNULLとする.
- 同一`TargetDate`・`StartTime`の開戦予定データが既に存在する場合は新規保存せず, 既存データを返す.
- 本APIでは抽選・ペア生成・GuildBattleID生成を行わない.

#### 要求・レスポンス

[API Payload](api_payload.md)の「SaveScheduledGuildBattlesRequest」「SaveScheduledGuildBattlesResponse」を参照する.

### 開戦予定騎士団戦取得

#### メソッド名

`GetScheduledGuilds`

#### 処理内容
- 指定JST日付と`GuildBattleStartTime`に一致する開戦予定の騎士団戦IDと, 対戦する2騎士団のIDを取得する.

#### 要求データ
[API Payload](api_payload.md)の「GetScheduledGuildsRequest」を参照する.

#### レスポンス
[API Payload](api_payload.md)の「GetScheduledGuildsResponse」を参照する.

### 騎士団戦Coordinator状態取得

#### メソッド名

`GetGuildBattleCoordinationState`

#### 呼び出し元

- mTLSで認証済みのGuildBattleCoordinatorだけが呼び出せる.

#### 処理内容

- `status=scheduled`の`GUILD_BATTLE`について, GuildBattleID, 対戦GuildID, `start_at`, `end_at`, `status`, `game_server_instance_id`を取得する.
- `start_at`, GuildBattleID昇順で返す.
- 固定開始時刻から生成した通常対戦だけでなく, `RetryPreloadFailedGuildBattle`で任意の`RestartAt`を指定して新IDで生成された対戦も対象とする.
- 状態変更は行わない.
- GuildBattleCoordinatorの起動時および定期Reconcileに使用する.

#### 要求・レスポンス

[API Payload](api_payload.md)の「GetGuildBattleCoordinationStateRequest」「GetGuildBattleCoordinationStateResponse」を参照する.

### 開戦予定騎士団戦割当

#### メソッド名

`AssignScheduledGuildBattles`

#### 呼び出し元

- 通常処理ではmTLSで認証済みのGuildBattleCoordinatorだけが呼び出せる.

#### 処理内容

- 要求`GuildBattleID[]`について`status=scheduled`かつ`game_server_instance_id IS NULL`であることを確認する.
- 条件を満たす各騎士団戦の`game_server_instance_id`をGuildBattleCoordinatorが選択した要求`GameServerInstanceID`へ更新する.
- 取得と更新は同一トランザクションで行い, 同一`GuildBattleID`を複数GameServerへ割り当てない.
- PostgreSQLの行Lockを使用し, 運営による手動復旧処理等と競合した場合も同一`GuildBattleID`を重複割当しない.
- すでに割当済み, または`scheduled`以外の対象は更新せず応答`Battles`へ含めない.

#### 要求・レスポンス

[API Payload](api_payload.md)の「AssignScheduledGuildBattlesRequest」「AssignScheduledGuildBattlesResponse」を参照する.

### 開戦予定騎士団戦割当解除

#### メソッド名

`ReleaseScheduledGuildBattleAssignments`

#### 呼び出し元

- mTLSで認証済みのGuildBattleCoordinatorだけが呼び出せる.

#### 処理内容

- 要求`GuildBattleID[]`のうち`status=scheduled`かつ`game_server_instance_id`が要求`GameServerInstanceID`と一致する騎士団戦だけを対象とする.
- 対象`GUILD_BATTLE.game_server_instance_id`をNULLへ更新して未割当へ戻す.
- `in_progress`, `resolving`, `completed`, `preload_failed`の騎士団戦は変更しない.
- GuildID, `membership_locked`, `initial_seed`および騎士団戦結果は変更しない.
- 更新は同一トランザクションで行う.

#### 要求・レスポンス

[API Payload](api_payload.md)の「ReleaseScheduledGuildBattleAssignmentsRequest」「ReleaseScheduledGuildBattleAssignmentsResponse」を参照する.

### 騎士団戦所有GameServer取得

#### メソッド名

`GetGuildBattleAssignment`

#### 処理内容

- 指定GuildBattleIDの`game_server_instance_id`をDatabaseから取得する.
- 未割当の場合は`Exists=false`を返す.
- Public API Server, GameServerおよびGuildBattleCoordinatorからの要求を受け付ける.

#### 要求・レスポンス

[API Payload](api_payload.md)の「GetGuildBattleAssignmentRequest」「GetGuildBattleAssignmentResponse」を参照する.

### 騎士団戦編成情報登録

#### メソッド名

`SaveGuildBattleParty`

#### 処理内容

- Databaseへ騎士団戦パーティ情報を保存する.

#### 要求データ
[API Payload](api_payload.md)の「SaveGuildBattlePartyRequest」を参照する.

### 編成情報取得

#### メソッド名

`GetGuildBattleFormation`

#### 処理内容

- 騎士団戦開戦前に, 対象騎士団へ所属している各メンバーの最大BPと編成情報を取得する.

#### 要求データ

[API Payload](api_payload.md)の「GetGuildBattleFormationRequest」を参照する.

#### レスポンス

[API Payload](api_payload.md)の「GetGuildBattleFormationResponse」を参照する.

### 騎士団所属メンバー取得

#### メソッド名

`GetGuildMembers`

#### 処理内容

- GuildIDに所属する全PlayerIDをPlayerID昇順で取得する.

#### 要求・レスポンス

[API Payload](api_payload.md)の「GetGuildMembersRequest」「GetGuildMembersResponse」を参照する.

### 騎士団レベル情報取得

#### メソッド名

`GetGuildData`

#### 処理内容

- 指定GuildIDの城レベルを含む騎士団レベル情報を取得する.

#### 要求・レスポンス

[API Payload](api_payload.md)の「GetGuildDataRequest」「GetGuildDataResponse」を参照する.

### プレイヤー所持アイテム取得

#### メソッド名

`GetPlayerItems`

#### 処理内容

- 指定PlayerIDの`PLAYER_ITEM`を取得する.

#### 要求・レスポンス

[API Payload](api_payload.md)の「GetPlayerItemsRequest」「GetPlayerItemsResponse」を参照する.

### プレイヤー所持アイテム更新

#### メソッド名

`UpdatePlayerItem`

#### 処理内容

- 指定PlayerID・ItemIDの所持数をDatabaseへ保存する。ただし当該Playerが`in_progress`または`resolving`の騎士団戦に含まれる場合は、Battle Item Event以外の変更を409で拒否する。

#### 要求データ

[API Payload](api_payload.md)の「UpdatePlayerItemRequest」を参照する.

### 騎士団戦のItem保存制約

対戦に必要なItem初期数量はPreloadの`GetPlayerItems`から取得し、`StartGuildBattle`で開戦時DB在庫とCreate Snapshotの一致を検証する。`JoinGuildBattle`はItem予約のためのPrivate APIを呼ばない。

`UpdatePlayerItem`等、Battle Item Event以外のItem在庫更新は、対象Playerが開戦中または結果確定待ちの騎士団戦に含まれる場合は409で拒否する。このチェックはPrivate APIのDB Transactionで行い、GameServer間の在庫同期とはしない。DBへの在庫書込みはPrivate API経由に限定する。

### Preload失敗遷移

#### メソッド名

`MarkGuildBattlePreloadFailed`

#### 呼び出し元

- mTLSで認証済みのGameServerだけが呼び出せる.

#### 処理内容

- `GuildBattleLifecycleService`で`scheduled -> preload_failed`だけを実行する.
- 対象`GuildBattleID`が`status=scheduled`であることを確認する.
- `GUILD_BATTLE.game_server_instance_id`が要求`GameServerInstanceID`と一致することを同一トランザクション内で確認する.
- `initial_seed`が未保存であることを確認する.
- 所有権不一致または許可されていない状態の場合は更新しない.

#### 要求データ

[API Payload](api_payload.md)の「MarkGuildBattlePreloadFailedRequest」を参照する.

### 騎士団戦開始

#### メソッド名

`StartGuildBattle`

#### 呼び出し元

- mTLSで認証済みのGameServerだけが呼び出せる.

#### 処理内容

- `GuildBattleLifecycleService`で`scheduled -> in_progress`を実行する.
- 現在statusと所有GameServerを確認した上で, InitialSeed保存, GuildBattle Create Replay保存, `status=in_progress`更新を同一Databaseトランザクションで実行する.
- 要求GuildIDがDatabase上の対戦Guildと一致することを確認する.
- 開戦処理の途中状態をDatabaseへ残さない.

#### 要求データ

[API Payload](api_payload.md)の「StartGuildBattleRequest」を参照する.

### 騎士団戦解決開始

#### メソッド名

`BeginGuildBattleResolving`

#### 呼び出し元

- mTLSで認証済みのGameServerだけが呼び出せる.

#### 処理内容

- `GuildBattleLifecycleService`で`in_progress -> resolving`だけを実行する.
- 対象`GuildBattleID`の所有GameServerが要求`GameServerInstanceID`と一致することを同一トランザクション内で確認する.
- 所有権不一致または許可されていない状態の場合は更新しない.

#### 要求データ

[API Payload](api_payload.md)の「BeginGuildBattleResolvingRequest」を参照する.

### Preload失敗対戦の再抽選結果保存

#### メソッド名

`RematchPreloadFailedGuildBattles`

#### 処理内容

- 本APIは`GuildBattleLifecycleService`の`preload_failed -> scheduled`遷移として扱う. 本API自身は抽選を行わず, 抽選ロジックと疑似乱数消費はGuildBattleCoordinator側で行う.
- 要求されたGuildBattleIDがすべて`GUILD_BATTLE_STATUS_PRELOAD_FAILED`であることを確認する.
- 要求のGuildBattleID集合と`Battles[]`のGuildBattleID集合が一致することを確認する.
- 同一トランザクションで各対象`GUILD_BATTLE.guild_a_id` / `guild_b_id`をGuildBattleCoordinator生成済みペアへ更新し, `status=scheduled`, `game_server_instance_id=NULL`へ戻す.
- 問題解決後に運営が再抽選を選択した場合だけGuildBattleCoordinatorから呼び出す.

#### 要求・レスポンス

[API Payload](api_payload.md)の「RematchPreloadFailedGuildBattlesRequest」「RematchPreloadFailedGuildBattlesResponse」を参照する.

### Preload失敗対戦の同一ペア再開

#### メソッド名

`RetryPreloadFailedGuildBattle`

#### 呼び出し元

- mTLSで認証済みの運営Componentだけが呼び出せる.

#### 処理内容

- 運営が問題解決後に同一ペアで再開すると判断した場合に使用する. `preload_failed`の旧`GuildBattleID`を再利用せず, 新しい`GuildBattleID`で`scheduled`レコードを挿入する.
- 対象旧`GuildBattleID`が`GUILD_BATTLE_STATUS_PRELOAD_FAILED`であることを同一トランザクションで確認する.
- 旧レコードの`guild_a_id` / `guild_b_id`および`matching_target_date` / `matching_start_time`を新レコードへ引き継ぐ.
- Private API Serverが専用Sequenceから新IDを原子的に採番し, `2^63 + 連番`を使用する. 元IDの再利用および元IDの主キー更新は行わない.
- 新レコードには`start_at=RestartAt`, `end_at=RestartAt + 30分`, `initial_seed=NULL`, `status=scheduled`, `game_server_instance_id=NULL`を設定する.
- 旧レコードを`status=replaced`とし, `replaced_by_guild_battle_id`へ新IDを保存する. 新レコード挿入と旧レコード更新を同一トランザクションで確定する.
- 同一マッチング枠のトランザクション単位排他と, 元ID・状態検証により多重再開を防ぐ.
- 保存後はレスポンスで返された新IDに対して通常の割当・開戦前Preloadを再実行する.

#### 要求・レスポンス

[API Payload](api_payload.md)の「RetryPreloadFailedGuildBattleRequest」「RetryPreloadFailedGuildBattleResponse」を参照する.

### Preload失敗対戦の運営中止

#### メソッド名

`CancelPreloadFailedGuildBattle`

#### 呼び出し元

- mTLSで認証済みの運営Componentだけが呼び出せる.

#### 処理内容

- 対象`GuildBattleID`の`status=preload_failed`を確認し, `GuildBattleLifecycleService`で`canceled`へ遷移させる.
- 同一トランザクションで当該対戦2Guildの`membership_locked=false`を保存する.
- 同じ`matching_target_date` / `matching_start_time`の全対戦（再開用の新IDを含む）が終端状態なら, 除外Guildの所属ロック解除と`GUILD_BATTLE_EXCLUDED_GUILD`削除も同じトランザクションで実行する.
- 同一枠排他を`CompleteGuildBattle`および`RetryPreloadFailedGuildBattle`と共有する. 中止済みIDによる再開・再中止は許可しない.

#### 要求・レスポンス

[API Payload](api_payload.md)の「CancelPreloadFailedGuildBattleRequest」「CancelPreloadFailedGuildBattleResponse」を参照する.

### 未割当騎士団戦の運営削除

#### メソッド名

`DeleteUnassignedGuildBattles`

#### 呼び出し元

- mTLSで認証済みの運営Componentだけが呼び出せる.

#### 処理内容

- 指定`GuildBattleID[]`のうち`status=scheduled`かつ`game_server_instance_id IS NULL`の対戦だけを削除する.
- 削除する各対戦の`guild_a_id` / `guild_b_id`について, 他に同一時間帯の未完了騎士団戦が存在しない場合は`GUILD.membership_locked=false`へ更新する.
- 削除後に同一対象日・開始時刻の未完了騎士団戦が0件となった場合は, `GUILD_BATTLE_EXCLUDED_GUILD`に保持している0人除外Guildも`membership_locked=false`へ更新し, 対応する除外一覧を削除する.
- 削除対象以外の騎士団戦レコードは変更しない.

#### 要求・レスポンス

[API Payload](api_payload.md)の「DeleteUnassignedGuildBattlesRequest」「DeleteUnassignedGuildBattlesResponse」を参照する.

### 騎士団戦ログ送信

騎士団戦中の成立した各種処理について, GameServerのReplay WorkerからPrivate API Serverへリプレイログ送信が行われる. 各論理Payloadは「[guild_battle_replay.proto](../system/guild_battle_replay.proto)」の`GuildBattleReplayEnvelope`へ変換してProtocol BuffersでSerializeし, `GUILD_BATTLE_REPLAY_LOG.payload`へバイナリ保存する.
通常の騎士団戦要求処理スレッドはPrivate API Serverへのリプレイログ保存完了を待機しない。ただし出撃は非同期Worker経由の`SaveGuildBattleSortieLog` COMMIT完了を成功Responseの条件とする。Workerへの依頼と完了確認は非同期で行う。 処理成立時はReplay EventをReplayQueueへ追加し, Replay Workerが成立順に送信する.
騎士団戦作成ログだけは`StartGuildBattle`のDatabaseトランザクション内で同期保存し, InitialSeed保存と`GUILD_BATTLE.status=in_progress`遷移を同時に確定する.
ReplayQueueおよびDatabase送信失敗時の扱いは「[ログ仕様](../system/log.md)」および「騎士団戦DB送信失敗時」に従う. `SaveGuildBattle*LogRequest.event_index`は1より大きい番号を要求し、Create Eventは番号1とする。各保存処理は`(guild_battle_id,event_index)`と`(guild_battle_id,operation_id)`の一意制約で同番号・同Operation ID・同Raw Envelopeのみ冪等とし、異なる組合せは拒否する。Private APIは`X-Operation-ID`、Replay Envelopeの決定的Byte列、直前の`GUILD_BATTLE_REPLAY_ANCHOR`から媒体非依存のEvent Hashを計算する。対象BattleのAnchor行をロックし、Replay行・DB Operation冪等行・Anchorの更新を1 Transactionで確定する。Createは`StartGuildBattle`内で前Hashゼロ・Event1とAnchorを同時作成する。番号が欠けるRequestは保留せず拒否し、順序はGameServerのDB Workerが制御する。Replay File/WAL/JournalのRecord Hashや署名鍵IDをDBのEvent Hashに混入しない。

#### 参加

#### メソッド名

`SaveGuildBattleJoinLog`

#### 処理内容

[API Payload](api_payload.md)の「GuildBattleJoinLogPayload」を参照する.

#### 出撃

#### メソッド名

`SaveGuildBattleSortieLog`

#### 処理内容

[API Payload](api_payload.md)の「GuildBattleSortieLogPayload」を参照する.

#### タクティクス使用

#### メソッド名

`SaveGuildBattleTacticsLog`

#### 処理内容

[API Payload](api_payload.md)の「GuildBattleTacticsLogPayload」を参照する.

#### アイテム使用

#### メソッド名

`SaveGuildBattleItemLog`

#### 処理内容

[API Payload](api_payload.md)の「GuildBattleItemLogPayload」を参照する.

#### 治療

#### メソッド名

`SaveGuildBattleHealLog`

#### 処理内容

[API Payload](api_payload.md)の「GuildBattleHealLogPayload」を参照する.

#### 復活

#### メソッド名

`SaveGuildBattleReviveLog`

#### 処理内容

[API Payload](api_payload.md)の「GuildBattleReviveLogPayload」を参照する.

### エラーログ送信

#### メソッド名

`SaveErrorLog`

#### 処理内容

- 騎士団戦開戦前の編成情報取得処理失敗時.
- 騎士団戦最終結果保存失敗時.
- エラーログは`ERROR_LOG`テーブルへ保存する.

#### 要求データ

[API Payload](api_payload.md)の「SaveErrorLogRequest」を参照する.

### 騎士団戦完了

#### メソッド名

`CompleteGuildBattle`

#### 呼び出し元

- mTLSで認証済みのGameServerだけが呼び出せる.

#### 処理内容

- `GuildBattleLifecycleService`で`resolving -> completed`だけを実行する.
- 対象`GuildBattleID`の所有GameServerが要求`GameServerInstanceID`と一致することを確認する.
- 最終結果2Guild分の保存, 参加Playerの参加回数・勝敗数・累計騎士団スコア更新, `status=completed`, 当該対戦2Guildの`membership_locked=false`を同一Databaseトランザクションで実行する. 同一`matching_target_date`・`matching_start_time`の全騎士団戦（後継対戦含む）が`completed`・`canceled`・`replaced`の終端状態となった場合に限り, 同一トランザクションで除外Guildも`membership_locked=false`へ更新し, `GUILD_BATTLE_EXCLUDED_GUILD`を削除する. 並行するComplete・Cancel・Retryはマッチング枠単位排他とGuildBattleID昇順の行Lockで終了判定と後継対戦追加を直列化する.
- `GuildResults`のGuildID集合がDatabase上の対戦2Guildと一致し, 2件の勝敗組み合わせが最終Scoreと整合することを確認する. Scoreが異なる場合は高い側`WIN`・低い側`LOSE`, 同値の場合は両側`DRAW`だけを許可する.
- `PlayerRecords`にはJoin済み通常Playerの全員とDummy PlayerID `0`を含め、`Participants`の通常PlayerID集合と一致させる。通常Playerの勝敗計上は`sortie_count>=1`の場合に限る。`PlayerRecords`と`Participants`で同一PlayerIDを重複指定できない. PlayerID `0`以外はDatabase上で対戦2Guildのいずれかに所属していることを確認し, 指定`Result`が所属Guildの`GuildResults.Result`と一致することを確認する.
- `Participants`のうち`sortie_count>=3`の通常Playerに限り参加回数を1加算し、騎士団戦終了時点の各Playerの未切り捨て`acquired_score`を小数点以下切り捨てして`u64`へ変換した値を累計騎士団スコアへ加算する。勝利・敗北による勝敗数加算は`PlayerRecords.sortie_count>=1`の通常Playerだけに適用する。 引き分けの場合は更新しない.
- いずれかの処理が失敗した場合はトランザクション全体をRollbackし, `completed`へ遷移しない.
- 初回失敗時は同一`X-Operation-ID`で1回だけ再試行する. 再試行も失敗した場合はError Logを保存し, `DiscordNotificationEnabled=true`の場合はBot通知後に運営による手動復旧対象とする.

#### 要求データ

[API Payload](api_payload.md)の「CompleteGuildBattleRequest」を参照する.

`GetInitialGuildStatusPrivate`は通常Player本人について`GUILD.id=PlayerID`の存在を読み取り、作成済みなら`initial_guild_created=true`と当該GuildID、未作成ならfalseと`guild_id=0`を返す。初期Guild未作成で許可する限定参照APIに含める。

## プロフィール・フレンドの永続化API

| Method | 処理 |
|---|---|
| `GetPlayerProfilePrivate` | 通常Playerの名前・騎士団戦参加回数・勝利数・累計スコアを`PLAYER`から取得し、二者の承認済みフレンド関係を照会する |
| `SendFriendRequestPrivate` | 有効な異なる通常PlayerIDを確認し、`FRIEND_REQUEST`へ未処理申請を保存する。既存フレンドとの二重申請を拒否する。同方向の未処理申請には`already_requested=true`を返し、逆方向からの申請は許可する |
| `ListFriendRequestsPrivate` | 宛先本人の未処理申請を送信元Player名とともに返す |
| `RespondFriendRequestPrivate` | 受信者本人が指定申請を排他Lockし、承認なら`FRIEND`追加と申請削除を原子的に実行、拒否なら申請のみ削除する。既に両者がフレンドであれば`already_friends=true`を返し、その残存申請を削除して変更操作を終了する |
| `ListFriendsPrivate` | 両向きに成立した`FRIEND`レコードを相手PlayerID・名前で取得する |
| `RemoveFriendPrivate` | 指定Playerが当事者である`FRIEND`の組を削除し、残存する対向申請があれば同一Transactionで削除する |

Public API経由で本人性を検証した`AuthenticatedContext`を要求する。更新は既存Private APIの`X-Operation-ID`冪等化とDB Transactionの規則を使う。wire形式は`design/system/private_api.proto`を正とする。

`GetGuildDetailPrivate`は`GUILD`の開始時刻予約を読み取るときに、適用開始を経過した予約を同じDBトランザクションで有効値へ反映し、予約値を消去してから応答を構成する。未適用の予約は`GetGuildDetailResponse`の`pending_daytime_start_time`・`pending_nighttime_start_time`・`pending_start_time_effective_at`として返す。未予約時はこれらのoptionalフィールドを設定しない。

### SaveGuildBattleTavernRecoveryLog

Private RPC `SaveGuildBattleTavernRecoveryLog`は`SaveGuildBattleTavernRecoveryLogRequest`（`payload`, `event_index`）を受け、`SaveGuildBattleTavernRecoveryLogResponse`を返す。`X-Operation-ID`を必須とし、`GuildBattleID`・`event_index`・PlayerIDの整合性および成立時刻を検証する。`GUILD_BATTLE_REPLAY_LOG`へのEnvelope保存とPlayerの酒場残回数/次回回復時刻更新を、既存Operation IDの重複判定と同一DB Transactionで確定する。同一Operationの再送は初回結果を返し、回数を再消費しない。Recoveryモードの新規`UseTavernRecovery`はGameServer入口で拒否し、消費Eventを作成しない。本Private RPCはRecovery移行前にDBで成立済みの操作について、同じOperation IDの冪等照合・再送を行う場合に限る。Recovery移行後に新規酒場消費を後追い成立させない。

### 追加認可Providerを用いるAccount作成・Login

Public APIはServer設定`AdditionalAuthorizationProvider`に従って追加認可Tokenを検証し、検証済み`provider`・`subject`をPrivate APIへ渡す。Private APIはサービス間mTLS Caller Identityを確認し、現在有効なServer設定と一致しない方式を拒否する。`DISCORD`については従来のToken使用済み検証とDiscordUserID Bindingを維持する。`POCKETBASE`は検証Adapterが明示的に提供される構成でのみ使用可能とし、追加認可の検証に失敗した場合は既存AccountのLoginID/Passwordが一致してもLoginさせない。`NONE`は追加認可を要求しないが本人認証は引き続き必須とする。

## 回復記録の真正性と再適用の制限

GameServerのRecovery記録は専用秘密鍵を使ってEventの正規化Payloadと連鎖HashをEd25519署名し、再起動時に署名・連続番号・Operation IDを検証する。不一致、署名不能、DB上の同番号異Payloadは自動再適用を拒否して隔離し、署名のないローカル情報をDBの確定結果に優先させない。DBへの再送は署名検証に合格したEventについて、既存の冪等Transactionでのみ行う。`UseTavernRecovery`はRecovery中に拒否するためローカル再適用対象には含めない。正本の詳細は`design/programming/server/logging_recovery.md`を参照する。


### Item使用ログと所持数の後追いTransaction

`SaveGuildBattleItemLog`はGameServerがWAL耐久化後に成立させたItem Eventの**非同期・冪等**なDB反映を行う。BattleのCreate Snapshotと先行するItem EventをEvent番号順に参照し、`quantity_before/after`の差1と当該Battle内の数量連続性を検証する。GameServerから送られた残数をDB正本へ直接代入しない。`PLAYER_ITEM`の該当行をLockし、1以上の残数確認→1減算とReplay Event追加を同一TransactionでCOMMITする。`X-Operation-ID`とEvent Hashの重複は同一内容だけ冪等成功とし、改ざん・不一致・負在庫は拒否する。既存のWAL/Journal保全・Replay確定規則を適用する。通常のItem使用ResponseはこのDB完了を待たない。酒場は従来どおりDB同一Transactionの完了を成功条件とする。

### `StartGuildBattle`におけるItem初期在庫

Preload結果のCreate Snapshotに含まれる通常PlayerのItem一覧がDB `PLAYER_ITEM`の開戦時数量・ItemIDと一致することを、Create Event保存と同一Transactionで確定する。食い違う場合は409で開始拒否し、GameServerはPreload失敗として既存手順に従う。`GetPlayerItems`の結果は開戦前の候補値であり、開戦後のBattle内Item状態は確定済みCreate Snapshotを使用する。

# Private API仕様

API全体の分類は「[API仕様](api.md)」を参照する.

- Private Network 内に配置される.
- 認証・Account・騎士団戦ルーティング関連要求はPublic API Serverから受ける.
- Database保存・取得要求はGameServerから受ける.
- Public API ServerおよびGameServerとPrivate API Server間の通信はmTLSを必須とし, 双方が信頼済みCAによる証明書を検証する. Clientからの直接接続を受け付けない.
- mTLS証明書のService Identityを検証し, Public API Serverからは認証・Account・騎士団戦ルーティング関連API, GameServerからはゲームデータ関連APIだけを受け付ける.
- Databaseへ直接接続できるApplication ComponentはPrivate API Serverだけとする.
- AccessToken署名用秘密鍵はPrivate API Serverだけが保持する.
- Databaseとのデータ保存・取得を仲介する. ゲームロジック上の抽選・マッチング生成はGameServerが行う.
- 要求/レスポンスのデータ構造は[API Payload](api_payload.md)を参照する.
- 騎士団戦中のDatabase送信失敗時は同一要求を1回だけ再試行する. 再試行も失敗した場合, GameServerはDB障害発生状態へ移行し, それ以降の騎士団戦中DB送信を行わず, 本来送信するデータをカレントディレクトリ直下のUTF-8 JSONファイルへ保存する. ファイルはGameServer再起動後も保持する. 騎士団戦終了時にローカル保存データを一括送信し, 成功時は対応ファイルを削除し, 失敗時は削除せず残す.
- `SaveGuildBattleResult`は専用の失敗処理を使用し, 1回再試行しても失敗した場合はErrorLogを保存し, `DiscordNotificationEnabled=true`の場合はBot通知を行った後, 運営による手動復旧対象とする.

## 認証・アカウント関連

### アカウント新規作成

#### メソッド名

`CreateAccount`

#### 処理内容

- LoginIDの重複をDatabaseで確認する.
- LoginID重複時は作成しない.
- PasswordをArgon2idでPasswordHashへ変換する.
- AccountIDおよびPlayerIDを生成する.
  - `0`と`u64::MAX`は予約済み無効値のため生成対象外.
  - Databaseの一意制約に衝突した場合は再生成する.
- `ACCOUNT`と`PLAYER`を同一トランザクションで保存する.
- `PLAYER.max_bp`は200, `guild_battle_win_count`と`guild_battle_lose_count`は0で初期化する.

#### 要求・レスポンス

[API Payload](api_payload.md)の「CreateAccountPrivateRequest」「CreateAccountPrivateResponse」を参照する.

### アカウント認証

#### メソッド名

`AuthenticateAccount`

#### 処理内容

- LoginIDに対応する`ACCOUNT`および`PLAYER`を取得する.
- Argon2idでPasswordを検証する.
- LoginID不存在とPassword不一致を呼び出し元へ区別して返さない.
- 認証成功時は既存`ACCOUNT_SESSION`を削除する.
- 128bitのSessionIDを暗号学的乱数で生成する.
- 32byteのRefreshTokenを暗号学的乱数で生成する.
- `SHA-256(RefreshToken)`を`refresh_token_hash`として保存する.
- `ACCOUNT_SESSION.expires_at`を認証成功時刻から72時間後として保存する.
- AccessTokenを生成してEd25519で署名する. AccessTokenの有効期限は発行時刻から5分とする.

#### 要求・レスポンス

[API Payload](api_payload.md)の「AuthenticateAccountRequest」「AuthenticateAccountResponse」を参照する.

### AccessToken更新

#### メソッド名

`RefreshAccessToken`

#### 処理内容

- 受信したRefreshTokenをSHA-256でHash化する.
- `ACCOUNT_SESSION.refresh_token_hash`が一致し, `expires_at`が有効期限内であることを確認する.
- 新しいRefreshTokenを生成し, `refresh_token_hash`を新しいHashへ置換する.
- 新しいAccessTokenを生成してEd25519で署名する.
- `ACCOUNT_SESSION.expires_at`は変更しない.
- RefreshToken検証とHash置換は同一トランザクションで行い, 対象`ACCOUNT_SESSION`を排他的に更新する. 同一RefreshTokenによる同時要求では1要求だけを成功させる.

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

### Refresh Session期限更新

#### メソッド名

`ExtendAccountSession`

#### 処理内容

- 指定SessionIDに対応する`ACCOUNT_SESSION`が存在し, 現在時刻が`expires_at`未満であることを確認する.
- 有効な場合は`expires_at`を現在時刻から72時間後へ更新し`IsValid=true`を返す.
- 存在しない, または期限切れの場合は更新せず`IsValid=false`を返す.

#### 要求・レスポンス

[API Payload](api_payload.md)の「ExtendAccountSessionRequest」「ExtendAccountSessionResponse」を参照する.

## プレイヤー・騎士団関連

### 騎士団保存

#### メソッド名

`SaveGuild`

#### 処理内容

- 新規騎士団をDatabaseへ保存する.
- 初期騎士団作成時は`subleader_player_id=0`, `membership_locked=false`で初期化する.

#### 要求データ

[API Payload](api_payload.md)の「SaveGuildRequest」を参照する.

### 騎士団役職保存

#### メソッド名

`SaveGuildLeadership`

#### 処理内容

- `SaveGuildLeadershipRequest.RequesterPlayerID`が更新対象`GUILD.leader_player_id`と一致することをDatabase上で確認する.
- 一致しない場合は更新せず, 団長権限なしとしてGameServerへ返す.
- LeaderPlayerIDとSubleaderPlayerIDがともに対象Guildの`GUILD_MEMBER`に存在することを確認する.
- LeaderPlayerIDとSubleaderPlayerIDが同一値の場合は更新しない.
- 上記をすべて満たす場合のみ`GUILD.leader_player_id`と`GUILD.subleader_player_id`を更新する. 団長確認, 所属確認, 同一PlayerID禁止確認, 更新は同一トランザクションで行う.

#### 要求データ

[API Payload](api_payload.md)の「SaveGuildLeadershipRequest」を参照する.

### 騎士団所属変更ロック更新

#### メソッド名

`SetGuildMembershipLock`

#### 処理内容

- 指定されたすべてのGuildIDについて`GUILD.membership_locked`を要求値へ更新する.
- 騎士団戦開戦前処理開始時は`true`, 騎士団戦終了または運営判断による中止時は`false`へ更新する.
- 所属変更禁止状態の正本はDatabaseの`GUILD.membership_locked`とする.

#### 要求・レスポンス

[API Payload](api_payload.md)の「SetGuildMembershipLockRequest」「SetGuildMembershipLockResponse」を参照する.

### 騎士団加入申請保存

#### メソッド名

`SaveGuildJoinApplication`

#### 処理内容

- 申請Playerの現在所属Guildにおける役職と所属人数をDatabaseから取得する.
- 申請Playerが現在所属Guildの団長で, 団長以外のメンバーが1人以上存在する場合は`API_ERROR_GUILD_LEADER_MOVE_NOT_ALLOWED`として申請を保存しない. 副団長にはこの制約を適用しない.
- `GUILD_JOIN_APPLICATION`へ未承認加入申請を保存する.
- 本処理では`GUILD_MEMBER`を変更しない.

#### 要求データ

[API Payload](api_payload.md)の「SaveGuildJoinApplicationRequest」を参照する.

### 騎士団加入申請承認

#### メソッド名

`ApproveGuildJoinApplicationPrivate`

#### 処理内容

- RequesterPlayerIDが対象Guildの現在の`leader_player_id`または`subleader_player_id`と一致することをDatabase上で確認する.
- `GUILD_JOIN_APPLICATION`に対象申請が存在することを確認する.
- 同一Databaseトランザクション内でApplicantPlayerIDの現在所属Guildと加入先Guildを取得し, 両Guildの`membership_locked=false`を再確認する.
- ApplicantPlayerIDが現在所属Guildの団長で, 団長以外のメンバーが1人以上存在する場合は加入を成立させない. 副団長にはこの制約を適用しない.
- 対象Guildの`GUILD_MEMBER`件数を同一トランザクション内で確認し, 20人以上の場合は加入を成立させない.
- すべての条件を満たす場合だけApplicantPlayerIDの既存`GUILD_MEMBER`を加入先Guildへ更新し, 対応する加入申請を削除する.

#### 要求データ

[API Payload](api_payload.md)の「ApproveGuildJoinApplicationPrivateRequest」を参照する.

### 騎士団招待保存

#### メソッド名

`SaveGuildInvitation`

#### 処理内容

- RequesterPlayerIDが対象Guildの現在の団長または副団長であることをDatabase上で確認する.
- InviteePlayerIDが現在所属Guildの団長で, 団長以外のメンバーが1人以上存在する場合は`API_ERROR_GUILD_LEADER_MOVE_NOT_ALLOWED`として招待を保存しない. 副団長にはこの制約を適用しない.
- 権限を満たす場合だけ`GUILD_INVITATION`へ招待を保存する.
- 本処理では`GUILD_MEMBER`を変更しない.

#### 要求データ

[API Payload](api_payload.md)の「SaveGuildInvitationRequest」を参照する.

### 騎士団招待承諾

#### メソッド名

`AcceptGuildInvitationPrivate`

#### 処理内容

- 指定PlayerID宛ての`GUILD_INVITATION`が存在することを確認する.
- 同一Databaseトランザクション内でPlayerIDの現在所属Guildと招待元Guildを取得し, 両Guildの`membership_locked=false`を再確認する.
- PlayerIDが現在所属Guildの団長で, 団長以外のメンバーが1人以上存在する場合は加入を成立させない. 副団長にはこの制約を適用しない.
- 対象Guildの`GUILD_MEMBER`件数を同一トランザクション内で確認し, 20人以上の場合は加入を成立させない.
- すべての条件を満たす場合だけPlayerIDの既存`GUILD_MEMBER`を招待元Guildへ更新し, 対応する招待を削除する.

#### 要求データ

[API Payload](api_payload.md)の「AcceptGuildInvitationPrivateRequest」を参照する.

### 騎士団脱退・初期騎士団復帰

#### メソッド名

`LeaveGuildPrivate`

#### 処理内容

- PlayerIDの現在所属GuildIDと`GuildID = PlayerID`の初期騎士団を取得する.
- 同一Databaseトランザクション内で脱退元Guildと復帰先初期Guildの`membership_locked=false`を再確認する. いずれかが`true`の場合は所属変更・所属スワップを行わない.
- 初期騎士団の現在団長がPlayerID自身の場合は, PlayerIDだけを初期騎士団へ戻す.
- 初期騎士団の現在団長が別Playerの場合は, PlayerIDを初期騎士団へ戻し, その現在団長PlayerをPlayerIDが直前まで所属していたGuildIDへ移動し, 初期騎士団の団長をPlayerIDへ変更する.
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

[API Payload](api_payload.md)の「UpdateArenaPartyResponse」を参照する.

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

- Database上でArenaParty登録済みのPlayerIDだけをPlayerID昇順で取得し, GameServerのアリーナ抽選候補キャッシュ同期に使用する. ArenaParty未登録Playerは返さない.

#### レスポンス

[API Payload](api_payload.md)の「GetAllPlayerIDsResponse」を参照する.


## 騎士団戦関連

### 騎士団戦マッチング候補取得

#### メソッド名

`GetGuildsForBattleMatching`

#### 処理内容

- 指定`TargetDate`・`StartTime`を設定している騎士団について, GuildIDと現在の所属人数をDatabaseから取得する.
- 抽選, 0人除外, 並び替え, Seed生成, ペア生成, GuildBattleID生成は行わない. これらのマッチングロジックはGameServerが行う.

#### 要求・レスポンス

[API Payload](api_payload.md)の「GetGuildsForBattleMatchingRequest」「GetGuildsForBattleMatchingResponse」を参照する.

### 開戦予定騎士団戦保存

#### メソッド名

`SaveScheduledGuildBattles`

#### 処理内容

- GameServerが生成した`ScheduledGuildBattle[]`を`GUILD_BATTLE`へ`scheduled`として保存する.
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

### 開戦予定騎士団戦Claim

#### メソッド名

`ClaimScheduledGuildBattles`

#### 処理内容

- 指定TargetDate・StartTimeに該当し, `status=scheduled`かつ`game_server_instance_id IS NULL`の騎士団戦から最大`MaxCount`件を取得する.
- 取得した各騎士団戦の`game_server_instance_id`を要求`GameServerInstanceID`へ更新する.
- 取得と更新は同一トランザクションで行い, PostgreSQLの`FOR UPDATE SKIP LOCKED`を使用して複数GameServerから同時要求された場合でも同一`GuildBattleID`を複数GameServerへ割り当てない.

#### 要求・レスポンス

[API Payload](api_payload.md)の「ClaimScheduledGuildBattlesRequest」「ClaimScheduledGuildBattlesResponse」を参照する.

### 騎士団戦所有GameServer取得

#### メソッド名

`GetGuildBattleAssignment`

#### 処理内容

- 指定GuildBattleIDの`game_server_instance_id`をDatabaseから取得する.
- 未割当の場合は`Exists=false`を返す.
- Public API Serverからの要求も受け付ける.

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

- 指定PlayerID・ItemIDの所持数をDatabaseへ保存する.

#### 要求データ

[API Payload](api_payload.md)の「UpdatePlayerItemRequest」を参照する.

### 騎士団戦状態更新

#### メソッド名

`UpdateGuildBattleStatus`

#### 処理内容

- `GUILD_BATTLE.status`を指定状態へ更新する.

#### 要求データ

[API Payload](api_payload.md)の「UpdateGuildBattleStatusRequest」を参照する.

### Preload失敗対戦の再抽籤結果保存

#### メソッド名

`RematchPreloadFailedGuildBattles`

#### 処理内容

- 本APIは抽籤を行わない. 抽籤ロジックと疑似乱数消費はGameServer側で行う.
- 要求されたGuildBattleIDがすべて`GUILD_BATTLE_STATUS_PRELOAD_FAILED`であることを確認する.
- 要求のGuildBattleID集合と`Battles[]`のGuildBattleID集合が一致することを確認する.
- 同一トランザクションで各対象`GUILD_BATTLE.guild_a_id` / `guild_b_id`をGameServer生成済みペアへ更新し, `status=scheduled`, `game_server_instance_id=NULL`へ戻す.
- 問題解決後に運営が再抽籤を選択した場合だけGameServerから呼び出す.

#### 要求・レスポンス

[API Payload](api_payload.md)の「RematchPreloadFailedGuildBattlesRequest」「RematchPreloadFailedGuildBattlesResponse」を参照する.

### 騎士団戦ログ送信

騎士団戦中の成立した各種処理について, GameServerからPrivate API Serverへログ送信が行われる. 各Payloadは`GuildBattleID`を含み, `GUILD_BATTLE_REPLAY_LOG`へ保存する.

#### 騎士団戦作成

#### メソッド名

`SaveGuildBattleCreateLog`

#### 処理内容

[API Payload](api_payload.md)の「GuildBattleCreateLogPayload」を参照する.

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

### 騎士団戦最終結果保存

#### メソッド名

`SaveGuildBattleResult`

#### 処理内容

[API Payload](api_payload.md)の「GuildBattleResultSaveRequest」を参照する.

### プレイヤー騎士団戦勝敗数更新

#### メソッド名

`UpdatePlayerGuildBattleRecord`

#### 処理内容

- GameServerが騎士団戦最終結果の処理を完了した後に更新する.
- 勝利の場合は対象Playerの`guild_battle_win_count`を1加算する.
- 敗北の場合は対象Playerの`guild_battle_lose_count`を1加算する.
- 引き分けの場合は更新しない.

#### 要求データ

[API Payload](api_payload.md)の「UpdatePlayerGuildBattleRecordRequest」を参照する.

# Private API仕様

API全体の分類は「[API仕様](api.md)」を参照する.

- Private Network 内に配置される.
- GameServer から要求を受ける.
- GameServerとPrivate API Server間の通信はmTLSを必須とし, 双方が信頼済みCAによる証明書を検証する. Client/Botからの直接接続を受け付けない.
- Database とのデータ保存・取得を仲介する. ゲームロジック上の抽選・マッチング生成はGameServerが行う.
- 要求/レスポンスのデータ構造は[API Payload](api_payload.md)を参照する.
- 騎士団戦中のDatabase送信失敗時は同一要求を1回だけ再試行する. 再試行も失敗した場合, GameServerはDB障害発生状態へ移行し, それ以降の騎士団戦中DB送信を行わず, 本来送信するデータをカレントディレクトリ直下のUTF-8 JSONファイルへ保存する. ファイルはGameServer再起動後も保持する. 騎士団戦終了時にローカル保存データを一括送信し, 成功時は対応ファイルを削除し, 失敗時は削除せず残す.
- `SaveGuildBattleResult`は専用の失敗処理を使用し, 1回再試行しても失敗した場合はErrorLog保存・Bot通知後, 運営による手動復旧対象とする.

## セッション・プレイヤー関連

### Discord User IDからPlayerID取得

#### メソッド名

`GetPlayerIDByDiscordUserID`

#### 処理内容

- 指定DiscordUserIDに一意に結び付くPlayerIDをDatabaseから取得する.
- 未登録の場合は`Exists=false`を返す.

#### 要求・レスポンス

[API Payload](api_payload.md)の「GetPlayerIDByDiscordUserIDRequest」「GetPlayerIDByDiscordUserIDResponse」を参照する.

### PlayerID重複確認

#### メソッド名

`CheckPlayerIDExists`

#### 処理内容

- 指定PlayerIDがDatabaseに既に存在するか確認する.

#### 要求・レスポンス

[API Payload](api_payload.md)の「CheckPlayerIDExistsRequest」「CheckPlayerIDExistsResponse」を参照する.

### 騎士団保存

#### メソッド名

`SaveGuild`

#### 処理内容

- 新規騎士団をDatabaseへ保存する.

#### 要求データ

[API Payload](api_payload.md)の「SaveGuildRequest」を参照する.

### 騎士団役職保存

#### メソッド名

`SaveGuildLeadership`

#### 処理内容

- `SaveGuildLeadershipRequest.RequesterPlayerID`が更新対象`GUILD.leader_player_id`と一致することをDatabase上で確認する.
- 一致しない場合は更新せず, 団長権限なしとしてGameServerへ返す.
- 一致する場合のみ`GUILD.leader_player_id`を指定LeaderPlayerIDへ更新し, `GUILD.subleader_player_id`を指定SubleaderPlayerIDへ更新する. 団長確認と更新は同一トランザクションで行う.

#### 要求データ

[API Payload](api_payload.md)の「SaveGuildLeadershipRequest」を参照する.

### プレイヤー所属騎士団更新

#### メソッド名

`SetPlayerGuild`

#### 処理内容

- `GUILD_MEMBER`のPlayerID所属先を指定GuildIDへ更新する.

#### 要求データ

[API Payload](api_payload.md)の「SetPlayerGuildRequest」を参照する.

### PlayerID保存

#### メソッド名

`SavePlayerID`

#### 処理内容

- DatabaseへPlayerID, DiscordUserID, UserNameを保存し, `PLAYER.max_bp`を初期値200で作成する.
- `PLAYER.discord_user_id`は一意制約で1つのDiscord User IDが複数PlayerIDへ結び付かないようにする.

#### 要求データ

[API Payload](api_payload.md)の「SavePlayerIDRequest」を参照する.

### セッションID保存

#### メソッド名

`SaveSessionID`

#### 処理内容

- `player_id`を競合キーとしてDatabaseへセッションIDをUPSERTする.
- SessionIDのUNIQUE制約衝突時は衝突をGameServerへ返す.

#### 要求データ

[API Payload](api_payload.md)の「SaveSessionIDRequest」を参照する.

#### 成功時レスポンス

- 保存完了とする.

#### エラー時レスポンス

[API Payload](api_payload.md)の「SaveSessionIDErrorResponse」を参照する. SessionIDのUNIQUE制約衝突時は`SAVE_SESSION_ID_ERROR_SESSION_ID_CONFLICT`を返す.

### 有効セッション取得

#### メソッド名

`GetActiveSession`

#### 処理内容
- PlayerIDに紐づく有効なセッションを取得する.

#### 要求データ
[API Payload](api_payload.md)の「GetActiveSessionRequest」を参照する.

#### レスポンス
[API Payload](api_payload.md)の「GetActiveSessionResponse」を参照する.

### セッション無効化

#### メソッド名

`InvalidateSession`

#### 処理内容
- 指定されたセッションに該当する`PLAYER_SESSION`レコードをDatabaseから削除する.

#### 要求データ
[API Payload](api_payload.md)の「InvalidateSessionRequest」を参照する.

#### レスポンス
[API Payload](api_payload.md)の「InvalidateSessionResponse」を参照する.

### セッション確認

#### メソッド名

`ValidateSession`

#### 処理内容
- 指定されたSessionIDの存在, 有効期限, 指定PlayerIDとの所有関係を確認する.

#### 要求データ
[API Payload](api_payload.md)の「ValidateSessionRequest」を参照する.

#### レスポンス
[API Payload](api_payload.md)の「ValidateSessionResponse」を参照する.

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

### 開戦前データ再取得

#### メソッド名

`RetryGuildBattlePreload`

#### 処理内容

- 開戦前データ処理終了後かつ当該騎士団戦の開戦前に限り使用可能とする.
- 指定GuildBattleIDについて, 要求に含まれる前回取得失敗PlayerIDの編成情報およびPLAYER_ITEM取得を再実行する.
- 再取得に成功したプレイヤーは当該騎士団戦のGameServer保持データへ復帰させる.
- 再取得に失敗したプレイヤーは当該騎士団戦のGameServer保持データから除外した状態を維持する.

#### 要求・レスポンス

[API Payload](api_payload.md)の「RetryGuildBattlePreloadRequest」「RetryGuildBattlePreloadResponse」を参照する.

### 騎士団戦ログ送信

騎士団戦中の成立した各種処理について, GameServerからPrivate API Serverへログ送信が行われる. 各Payloadは`GuildBattleID`を含み, `GUILD_BATTLE_REPLAY_LOG`へ保存する.

#### 騎士団戦作成

#### メソッド名

`SaveGuildBattleCreateLog`

#### 処理内容

[API Payload](api_payload.md)の「GuildBattleCreateLogPayload」を参照する.

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

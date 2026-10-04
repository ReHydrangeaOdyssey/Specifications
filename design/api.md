# API仕様

# PublicAPI

- Client / Bot から要求を受ける
- GameServer に要求を中継する
- GameServer からの結果を Client / Bot に返す
- テスト環境では Private Network の外側に配置される
- 要求 / レスポンスのデータ構造は[API Payload](api_payload.md)を参照する
- `SessionID`を要求するPublicAPIは、処理前にSessionの存在、有効期限、要求`PlayerID`との所有関係をすべて検証する
  - いずれかが不正な場合は`ApiErrorResponse(API_ERROR_INVALID_SESSION)`を返し、要求本体を処理しない
- 個別に失敗レスポンスが定義されていないPublicAPIの失敗時は`ApiErrorResponse`を使用する

## システム

### アクセストークン要求

#### メソッド名

`IssueAccessToken`

#### 処理内容

- AccessTokenRequest.TokenがGameServer起動時にBotから引数で渡されたTokenと一致することを検証する
- アクセストークンを生成する
  - 有効期限: 5分
  - 型は「[型定義](types.md)」の`AccessToken`を参照
  - 暗号学的乱数を用いて生成
  - ゲームサーバーのメモリ上のみ保管

#### 要求データ

[API Payload](api_payload.md)の「AccessTokenRequest」を参照

#### 成功時レスポンス

[API Payload](api_payload.md)の「AccessTokenResponse」を参照

#### 失敗時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照。Token不一致は`API_ERROR_INVALID_TOKEN`.

### 新規PlayerID要求

#### メソッド名

`CreatePlayer`

#### 処理内容

- AccessTokenを検証する
- CreatePlayerではAccessTokenを無効化しない
- AccessTokenはLogin成功時に無効化する
- ユーザー名をチェックする
  - 有効なUTF-8であること
  - 10文字以下であること
  - 空文字ではないこと
  - ユーザー名の重複は許可する
- PlayerIDを生成する
  - `0`と`u64::MAX`は予約済み無効値のため生成対象外
  - Private API Serverの`CheckPlayerIDExists`で重複を確認する
  - 重複している場合は再生成する
  - 重複していないことを確認してからClientへ返す
- 生成したPlayerIDをPrivate API Server経由でDatabaseへ保存する

#### 必要パラメータ

[API Payload](api_payload.md)の「CreatePlayerRequest」を参照

#### 成功時レスポンス

[API Payload](api_payload.md)の「CreatePlayerResponse」を参照

#### 失敗時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照。AccessToken不正は`API_ERROR_INVALID_ACCESS_TOKEN`、ユーザー名不正は`API_ERROR_INVALID_USER_NAME`.

### ログイン要求

#### メソッド名

`Login`

#### 処理内容

- AccessTokenを検証する
- Login成功時にアクセストークンを無効化する
- セッションIDを暗号学的乱数で生成する
- PlayerIDとセッションIDをPrivate API Server経由でDatabaseへUPSERTする
- SessionIDのUNIQUE制約に衝突した場合はSessionIDを再生成して保存を再試行する

#### 要求データ

[API Payload](api_payload.md)の「LoginRequest」を参照

#### 成功時レスポンス

[API Payload](api_payload.md)の「LoginResponse」を参照

#### 失敗時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照。AccessToken不正は`API_ERROR_INVALID_ACCESS_TOKEN`.

セッション仕様

- SessionIDの型は「[型定義](types.md)」の`SessionID`を参照
- SessionIDの期限: 72時間
- ログイン時に期限がリセットされる
- 騎士団戦参加時に期限がリセットされる
- 複数端末からのアクセスは不可
- ClientではOPFS上に保存される


### セッション確認

#### メソッド名

`ValidateSession`

#### 処理内容

- SessionIDの存在を確認する
- 有効期限内であることを確認する
- SessionIDが要求PlayerIDに所有されていることを確認する

#### 要求データ

[API Payload](api_payload.md)の「ValidateSessionPublicRequest」を参照

#### レスポンス

[API Payload](api_payload.md)の「ValidateSessionPublicResponse」を参照

### 騎士団新規作成

#### メソッド名

`CreateGuild`

#### 処理内容

- SessionIDを検証する
- プレイヤーの初期騎士団を新規作成する
- 作成する騎士団の`GuildID`には要求元`PlayerID`と同一値を使用する
- 城、武器庫、食糧庫、鍛冶屋、兵法所、酒場の各施設レベルをすべて1で初期化する
- 作成したプレイヤーを生成した騎士団へ所属させる
- 作成したプレイヤーを団長として保存する
- 初期騎士団は、プレイヤーが他の騎士団へ所属した後も削除しない

#### 要求データ

[API Payload](api_payload.md)の「CreateGuildRequest」を参照

#### 成功時レスポンス

[API Payload](api_payload.md)の「CreateGuildResponse」を参照

### 騎士団所属変更

#### メソッド名

`JoinGuild`

#### 処理内容

- SessionIDを検証する
- 指定GuildIDの所属人数が20未満であることを確認する
- プレイヤーの所属を指定GuildIDへ更新する

#### 要求データ

[API Payload](api_payload.md)の「JoinGuildRequest」を参照

#### 成功時レスポンス

[API Payload](api_payload.md)の「JoinGuildResponse」を参照

#### 失敗時レスポンス

満員の場合は`ApiErrorResponse(API_ERROR_GUILD_FULL)`を返す。

### 騎士団脱退

#### メソッド名

`LeaveGuild`

#### 処理内容

- SessionIDを検証する
- 現在所属している騎士団からプレイヤーを脱退させる
- 新しい騎士団は生成しない
- `GuildID = PlayerID`で既存の初期騎士団を特定する
- プレイヤーの所属を初期騎士団へ更新する
- 初期騎士団の施設レベル、団長情報その他の騎士団データは既存値をそのまま使用する

#### 要求データ

[API Payload](api_payload.md)の「LeaveGuildRequest」を参照

#### 成功時レスポンス

[API Payload](api_payload.md)の「LeaveGuildResponse」を参照

## アリーナ関連

### パーティ変更

#### メソッド名

`UpdateArenaParty`

#### 処理内容

- GameServerからPrivate API Serverへ編成情報登録を要求する
- Private API ServerがDatabaseへ編成情報を登録する

#### 要求データ

[API Payload](api_payload.md)の「UpdateArenaPartyRequest」を参照

#### 成功時レスポンス

[API Payload](api_payload.md)の「UpdateArenaPartyResponse」を参照

### アリーナ開始

#### メソッド名

`StartArenaBattle`

#### 処理内容

- SessionID、PlayerID等の要求検証を完了する
- GameServerがアリーナ戦闘用Seedを生成する
- `Mode=random`の場合は生成したSeedを用いて対戦相手を抽選する
- GameServerはPrivate API Server経由でDatabaseから必要データを取得する
- GameServerが戦闘を実行する

#### 要求データ

[API Payload](api_payload.md)の「ArenaBattleRequest」を参照

#### 成功時レスポンス

[API Payload](api_payload.md)の「ArenaBattleResponse」を参照

#### エラー時レスポンス

[API Payload](api_payload.md)の「ArenaBattleErrorResponse」を参照


## 騎士団戦関連

騎士団戦参加後、GameServerは`GuildBattleID`ごとに`PlayerID -> RequestSequence`のマップを保持する。

- 参加前の初期値は`0`とする.
- `JoinGuildBattle`成功時に、プレイヤー固有の初期RequestSequenceを範囲乱数`1..=1,000,000,000`で生成して割り当てる。他プレイヤーとの重複は許可する.
- 参加後の騎士団戦PublicAPI要求は`GuildBattleID`、`PlayerID`、`RequestSequence`を含む.
- 要求RequestSequenceがGameServer保持値と一致する場合のみ処理する.
- 一致しない場合は`ApiErrorResponse(API_ERROR_INVALID_GUILD_BATTLE_SEQUENCE)`を返す.
- 要求が成功するたびにGameServer保持RequestSequenceを`1`加算し、成功レスポンスの`NextRequestSequence`としてClientへ返す.
- 失敗した要求ではRequestSequenceを加算しない.


### 騎士団戦パーティ変更

#### メソッド名

`UpdateGuildBattleParty`

#### 処理内容

- GameServerからPrivate API Serverへパーティ情報登録を要求する
- Private API ServerがDatabaseへパーティ情報を登録する

#### 要求データ

[API Payload](api_payload.md)の「UpdateGuildBattlePartyRequest」を参照

#### 成功時レスポンス

[API Payload](api_payload.md)の「UpdateGuildBattlePartyResponse」を参照

#### 変更不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照。`API_ERROR_GUILD_BATTLE_PARTY_UPDATE_NOT_ALLOWED`.

### 騎士団戦参加通知

#### メソッド名

`JoinGuildBattle`

#### 処理内容

- Public API ServerがGameServerへ参加通知を送る
- GameServerが参加チェックを行う
- 参加可能時はSessionIDの期限を72時間後へ更新する
- PlayerIDへ初期RequestSequenceを割り当てる

#### 要求データ

[API Payload](api_payload.md)の「JoinGuildBattleRequest」を参照

#### 参加可能時レスポンス

[API Payload](api_payload.md)の「GuildBattleJoinResponse」を参照

#### 参加不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照。`API_ERROR_GUILD_BATTLE_JOIN_NOT_ALLOWED`.

### 騎士団戦状態取得

#### メソッド名

`GetGuildBattleStatus`

#### 処理内容
- 参加中プレイヤーの編成IDと現在HPを取得する

#### 要求データ

[API Payload](api_payload.md)の「GetGuildBattleStatusRequest」を参照

#### 成功時レスポンス

[API Payload](api_payload.md)の「GetGuildBattleStatusResponse」を参照

### 出撃要求

#### メソッド名

`GuildBattleSortie`

#### 処理内容

- 出撃可否チェック
- 騎士団戦全体`Sequence`加算
- 出撃内容抽選
- キャッスルブレイク処理、または戦闘処理
- チェイン処理

#### 要求データ

[API Payload](api_payload.md)の「GuildBattleSortieRequest」を参照

#### キャッスルブレイク時レスポンス

[API Payload](api_payload.md)の「GuildBattleCastleBreakResponse」を参照

#### 殲滅時レスポンス

[API Payload](api_payload.md)の「GuildBattleAnnihilationResponse」を参照

#### 出撃不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照。`API_ERROR_GUILD_BATTLE_SORTIE_NOT_ALLOWED`.

### タクティクス使用要求

#### メソッド名

`UseTactics`

#### 処理内容

GameServer側のチェック

- 操作ロック状態
- TP
- 使用回数

#### 要求データ

[API Payload](api_payload.md)の「UseTacticsRequest」を参照

#### 使用可能時レスポンス

[API Payload](api_payload.md)の「UseTacticsResponse」を参照

#### 使用不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照。`API_ERROR_TACTICS_NOT_AVAILABLE`.

### アイテム使用要求

#### メソッド名

`UseItem`

#### 処理内容

#### 要求データ

[API Payload](api_payload.md)の「UseItemRequest」を参照

#### GameServer側のチェック

- 所持数

#### 使用可能時レスポンス

[API Payload](api_payload.md)の「UseItemResponse」を参照

#### 使用不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照。`API_ERROR_ITEM_NOT_AVAILABLE`.

### 治療開始要求

#### メソッド名

`StartHeal`

#### 処理内容

#### 要求データ

[API Payload](api_payload.md)の「StartHealRequest」を参照

#### GameServer側のチェック

- 回復状態でないこと

#### 開始可能時の処理

- 回復待機時間を算出する
- 回復中状態へ変更する

#### 開始可能時レスポンス

[API Payload](api_payload.md)の「StartHealResponse」を参照

#### 開始不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照。`API_ERROR_HEAL_NOT_AVAILABLE`.

### 治療キャンセル要求

#### メソッド名

`CancelHeal`

#### 処理内容

#### 要求データ

[API Payload](api_payload.md)の「CancelHealRequest」を参照

#### GameServer側のチェック

- 回復中状態であること

#### キャンセル可能時の処理

- 回復待機時間をリセットする
- 回復中状態を解除する
- HP / BPは回復しない

#### レスポンス

[API Payload](api_payload.md)の「CancelHealResponse」を参照

- 失敗: [API Payload](api_payload.md)の「ApiErrorResponse」を参照。`API_ERROR_HEAL_CANCEL_NOT_ALLOWED`.

### 治療完了要求

#### メソッド名

`CompleteHeal`

#### 処理内容

#### 要求データ

[API Payload](api_payload.md)の「CompleteHealRequest」を参照

#### GameServer側のチェック

- 回復完了状態であること

#### 完了可能時の処理

- BP / HP回復処理を行う
- 回復状態を解除する

#### 完了可能時レスポンス

[API Payload](api_payload.md)の「CompleteHealResponse」を参照

#### 完了不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照。`API_ERROR_HEAL_COMPLETE_NOT_ALLOWED`.

### 復活開始要求

#### メソッド名

`StartRevive`

#### 処理内容

#### 要求データ

[API Payload](api_payload.md)の「StartReviveRequest」を参照

#### GameServer側の処理

- 復活可能かチェックする
- 復活可能な場合は復活中状態へ変更する

#### 復活可能時レスポンス

[API Payload](api_payload.md)の「StartReviveResponse」を参照

5秒経過後、GameServerは復活完了状態へ変更しますこの時点ではBP消費・HP回復は行われません

#### 復活不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照。`API_ERROR_REVIVE_NOT_AVAILABLE`.

### 復活キャンセル要求

#### メソッド名

`CancelRevive`

#### 処理内容

#### 要求データ

[API Payload](api_payload.md)の「CancelReviveRequest」を参照

#### GameServer側のチェック

- 復活中状態であること

#### キャンセル可能時の処理

- 復活待機時間を破棄する
- 全滅状態へ戻す

#### レスポンス

[API Payload](api_payload.md)の「CancelReviveResponse」を参照

- 失敗: [API Payload](api_payload.md)の「ApiErrorResponse」を参照。`API_ERROR_REVIVE_CANCEL_NOT_ALLOWED`.

### 復活完了要求

#### メソッド名

`CompleteRevive`

#### 処理内容

#### 要求データ

[API Payload](api_payload.md)の「CompleteReviveRequest」を参照

#### GameServer側のチェック

- 復活完了状態であること

#### 完了可能時の処理

- BP / HP処理を行う
- 全滅状態を解除する

#### 完了可能時レスポンス

[API Payload](api_payload.md)の「CompleteReviveResponse」を参照

#### 完了不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照。`API_ERROR_REVIVE_COMPLETE_NOT_ALLOWED`.

# PrivateAPI

- Private Network 内に配置される
- GameServer から要求を受ける
- Database とのデータ保存・取得を仲介する
- 要求 / レスポンスのデータ構造は[API Payload](api_payload.md)を参照する

## セッション・プレイヤー関連

### PlayerID重複確認

#### メソッド名

`CheckPlayerIDExists`

#### 処理内容

- 指定PlayerIDがDatabaseに既に存在するか確認する

#### 要求・レスポンス

[API Payload](api_payload.md)の「CheckPlayerIDExistsRequest」「CheckPlayerIDExistsResponse」を参照

### 騎士団保存

#### メソッド名

`SaveGuild`

#### 処理内容

- 新規騎士団をDatabaseへ保存する

#### 要求データ

[API Payload](api_payload.md)の「SaveGuildRequest」を参照

### プレイヤー所属騎士団更新

#### メソッド名

`SetPlayerGuild`

#### 処理内容

- `GUILD_MEMBER`のPlayerID所属先を指定GuildIDへ更新する

#### 要求データ

[API Payload](api_payload.md)の「SetPlayerGuildRequest」を参照

### PlayerID保存

#### メソッド名

`SavePlayerID`

#### 処理内容

- DatabaseへPlayerIDを保存する

#### 要求データ

[API Payload](api_payload.md)の「SavePlayerIDRequest」を参照

### セッションID保存

#### メソッド名

`SaveSessionID`

#### 処理内容

- `player_id`を競合キーとしてDatabaseへセッションIDをUPSERTする
- SessionIDのUNIQUE制約衝突時は衝突をGameServerへ返す

#### 要求データ

[API Payload](api_payload.md)の「SaveSessionIDRequest」を参照

### 有効セッション取得

#### メソッド名

`GetActiveSession`

#### 処理内容
- PlayerIDに紐づく有効なセッションを取得する

#### 要求データ
[API Payload](api_payload.md)の「GetActiveSessionRequest」を参照

#### レスポンス
[API Payload](api_payload.md)の「GetActiveSessionResponse」を参照

### セッション無効化

#### メソッド名

`InvalidateSession`

#### 処理内容
- 指定されたセッションに該当する`PLAYER_SESSION`レコードをDatabaseから削除する

#### 要求データ
[API Payload](api_payload.md)の「InvalidateSessionRequest」を参照

#### レスポンス
[API Payload](api_payload.md)の「InvalidateSessionResponse」を参照

### セッション確認

#### メソッド名

`ValidateSession`

#### 処理内容
- 指定されたSessionIDの存在、有効期限、指定PlayerIDとの所有関係を確認する

#### 要求データ
[API Payload](api_payload.md)の「ValidateSessionRequest」を参照

#### レスポンス
[API Payload](api_payload.md)の「ValidateSessionResponse」を参照

## アリーナ関連

### 編成情報登録

#### メソッド名

`SaveArenaParty`

#### 処理内容

- Databaseへアリーナパーティ情報を保存する

#### 要求データ

[API Payload](api_payload.md)の「SaveArenaPartyRequest」を参照

#### レスポンス

[API Payload](api_payload.md)の「UpdateArenaPartyResponse」を参照

### アリーナ戦闘用データ取得

#### メソッド名

`GetArenaBattleData`

#### 処理内容

- 指定された対戦相手PlayerIDのアリーナ戦闘用データをDatabaseから取得する

#### 要求データ

[API Payload](api_payload.md)の「GetArenaBattleDataRequest」を参照

#### レスポンス

[API Payload](api_payload.md)の「GetArenaBattleDataResponse」を参照

### 全PlayerID取得

#### メソッド名

`GetAllPlayerIDs`

#### 処理内容

- Databaseに存在する全PlayerIDを取得し、GameServerのアリーナ抽選候補キャッシュ同期に使用する

#### レスポンス

[API Payload](api_payload.md)の「GetAllPlayerIDsResponse」を参照


## 騎士団戦関連

### 開戦予定騎士団戦取得

#### メソッド名

`GetScheduledGuilds`

#### 処理内容
- 指定JST日付と`GuildBattleStartTime`に一致する開戦予定の騎士団戦IDと、対戦する2騎士団のIDを取得する

#### 要求データ
[API Payload](api_payload.md)の「GetScheduledGuildsRequest」を参照

#### レスポンス
[API Payload](api_payload.md)の「GetScheduledGuildsResponse」を参照

### 騎士団戦編成情報登録

#### メソッド名

`SaveGuildBattleParty`

#### 処理内容

- Databaseへ騎士団戦パーティ情報を保存する

#### 要求データ
[API Payload](api_payload.md)の「SaveGuildBattlePartyRequest」を参照

### 編成情報取得

#### メソッド名

`GetGuildBattleFormation`

#### 処理内容

- 騎士団戦開戦前に、対象騎士団へ所属している各メンバーの編成情報を取得する

#### 要求データ

[API Payload](api_payload.md)の「GetGuildBattleFormationRequest」を参照

#### レスポンス

[API Payload](api_payload.md)の「GetGuildBattleFormationResponse」を参照

### 騎士団所属メンバー取得

#### メソッド名

`GetGuildMembers`

#### 処理内容

- GuildIDに所属する全PlayerIDを取得する

#### 要求・レスポンス

[API Payload](api_payload.md)の「GetGuildMembersRequest」「GetGuildMembersResponse」を参照

### 騎士団レベル情報取得

#### メソッド名

`GetGuildData`

#### 処理内容

- 指定GuildIDの城レベルを含む騎士団レベル情報を取得する

#### 要求・レスポンス

[API Payload](api_payload.md)の「GetGuildDataRequest」「GetGuildDataResponse」を参照

### プレイヤー所持アイテム取得

#### メソッド名

`GetPlayerItems`

#### 処理内容

- 指定PlayerIDの`PLAYER_ITEM`を取得する

#### 要求・レスポンス

[API Payload](api_payload.md)の「GetPlayerItemsRequest」「GetPlayerItemsResponse」を参照

### プレイヤー所持アイテム更新

#### メソッド名

`UpdatePlayerItem`

#### 処理内容

- 指定PlayerID・ItemIDの所持数をDatabaseへ保存する

#### 要求データ

[API Payload](api_payload.md)の「UpdatePlayerItemRequest」を参照

### 騎士団戦状態更新

#### メソッド名

`UpdateGuildBattleStatus`

#### 処理内容

- `GUILD_BATTLE.status`を指定状態へ更新する

#### 要求データ

[API Payload](api_payload.md)の「UpdateGuildBattleStatusRequest」を参照

### 開戦前データ再取得

#### メソッド名

`RetryGuildBattlePreload`

#### 処理内容

- 開戦前データ処理終了後かつ当該騎士団戦の開戦前に限り使用可能
- 指定GuildBattleIDについて、要求に含まれる前回取得失敗PlayerIDの編成情報およびPLAYER_ITEM取得を再実行する
- 再取得に成功したプレイヤーは当該騎士団戦のGameServer状態へ復帰させる
- 再取得に失敗したプレイヤーは除外状態を維持する

#### 要求・レスポンス

[API Payload](api_payload.md)の「RetryGuildBattlePreloadRequest」「RetryGuildBattlePreloadResponse」を参照

### 騎士団戦ログ送信

騎士団戦中の成立した各種処理について、GameServerからPrivate API Serverへログ送信が行われる。各Payloadは`GuildBattleID`を含み、`GUILD_BATTLE_REPLAY_LOG`へ保存する。

#### 騎士団戦作成

#### メソッド名

`SaveGuildBattleCreateLog`

#### 処理内容

[API Payload](api_payload.md)の「GuildBattleCreateLogPayload」を参照

#### 出撃

#### メソッド名

`SaveGuildBattleSortieLog`

#### 処理内容

[API Payload](api_payload.md)の「GuildBattleSortieLogPayload」を参照

#### タクティクス使用

#### メソッド名

`SaveGuildBattleTacticsLog`

#### 処理内容

[API Payload](api_payload.md)の「GuildBattleTacticsLogPayload」を参照

#### アイテム使用

#### メソッド名

`SaveGuildBattleItemLog`

#### 処理内容

[API Payload](api_payload.md)の「GuildBattleItemLogPayload」を参照

#### 治療

#### メソッド名

`SaveGuildBattleHealLog`

#### 処理内容

[API Payload](api_payload.md)の「GuildBattleHealLogPayload」を参照

#### 復活

#### メソッド名

`SaveGuildBattleReviveLog`

#### 処理内容

[API Payload](api_payload.md)の「GuildBattleReviveLogPayload」を参照

### エラーログ送信

#### メソッド名

`SaveErrorLog`

#### 処理内容

- 騎士団戦開戦前の編成情報取得処理失敗時
- 騎士団戦最終結果保存失敗時
- エラーログは`ERROR_LOG`テーブルへ保存する

#### 要求データ

[API Payload](api_payload.md)の「SaveErrorLogRequest」を参照

### 騎士団戦最終結果保存

#### メソッド名

`SaveGuildBattleResult`

#### 処理内容

[API Payload](api_payload.md)の「GuildBattleResultSaveRequest」を参照

# API仕様

# PublicAPI

- Client / Bot から要求を受ける
- GameServer に要求を中継する
- GameServer からの結果を Client / Bot に返す
- テスト環境では Private Network の外側に配置される
- 要求 / レスポンスのデータ構造は[API Payload](api_payload.md)を参照する

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


### 新規PlayerID要求

#### メソッド名

`CreatePlayer`

#### 処理内容

- AccessTokenを検証する
- ユーザー名をチェックする
- PlayerIDを生成する
- 生成したPlayerIDをPrivate API Server経由でDatabaseへ保存する

#### 必要パラメータ

[API Payload](api_payload.md)の「CreatePlayerRequest」を参照

#### 成功時レスポンス

[API Payload](api_payload.md)の「CreatePlayerResponse」を参照

#### 失敗時レスポンス

### ログイン要求

#### メソッド名

`Login`

#### 処理内容

- アクセストークンを無効化する
- セッションIDを生成する
- PlayerIDとセッションIDをPrivate API Server経由でDatabaseへ保存する

#### 要求データ

[API Payload](api_payload.md)の「LoginRequest」を参照

#### 成功時レスポンス

[API Payload](api_payload.md)の「LoginResponse」を参照

セッション仕様

- SessionIDの型は「[型定義](types.md)」の`SessionID`を参照
- SessionIDの期限: 72時間
- ログイン時に期限がリセットされる
- 騎士団戦参加時に期限がリセットされる
- 複数端末からのアクセスは不可
- ClientではOPFS上に保存される

## アリーナ関連

### アリーナ戦闘シード取得

#### メソッド名

`GetArenaBattleSeed`

#### 処理内容

- GameServerがアリーナ戦闘用の初期シードを発行する

#### 要求データ

[API Payload](api_payload.md)の「GetArenaBattleSeedRequest」を参照

#### 成功時レスポンス

[API Payload](api_payload.md)の「GetArenaBattleSeedResponse」を参照

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

- GameServerが戦闘を実行する
- GameServerはPrivate API Server経由でDatabaseから必要データを取得する

#### 要求データ

[API Payload](api_payload.md)の「ArenaBattleRequest」を参照

#### 成功時レスポンス

[API Payload](api_payload.md)の「ArenaBattleResponse」を参照

## 騎士団戦関連

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

### 騎士団戦参加通知

#### メソッド名

`JoinGuildBattle`

#### 処理内容

- Public API ServerがGameServerへ参加通知を送る
- GameServerが参加チェックを行う
- 参加可能時はSessionIDの期限を72時間後へ更新する

#### 要求データ

[API Payload](api_payload.md)の「JoinGuildBattleRequest」を参照

#### 参加可能時レスポンス

[API Payload](api_payload.md)の「GuildBattleJoinResponse」を参照

#### 参加不可時レスポンス

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
- シーケンス加算
- 出撃内容抽選
- キャッスルブレイク処理、または戦闘処理
- チェイン処理

#### 要求データ

[API Payload](api_payload.md)の「GuildBattleSortieRequest」を参照

#### キャッスルブレイク時レスポンス

[API Payload](api_payload.md)の「GuildBattleCastleBreakResponse」を参照

#### 殲滅時レスポンス

[API Payload](api_payload.md)の「GuildBattleAnnihilationResponse」を参照

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

- 使用拒否

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

- 使用拒否

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

- 開始拒否

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

- 失敗: キャンセル拒否

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

- 完了拒否

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

- 復活開始拒否

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

- 失敗: キャンセル拒否

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

- 復活完了拒否

# PrivateAPI

- Private Network 内に配置される
- GameServer から要求を受ける
- Database とのデータ保存・取得を仲介する
- 要求 / レスポンスのデータ構造は[API Payload](api_payload.md)を参照する

## セッション・プレイヤー関連

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

- DatabaseへセッションIDを保存する

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
- 指定されたセッションを無効化する

#### 要求データ
[API Payload](api_payload.md)の「InvalidateSessionRequest」を参照

#### レスポンス
[API Payload](api_payload.md)の「InvalidateSessionResponse」を参照

### セッション確認

#### メソッド名

`ValidateSession`

#### 処理内容
- 指定されたセッションが有効か確認する

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

#### 要求

- 必要データ取得

レスポンス

- データ返却

## 騎士団戦関連

### 開戦予定騎士団取得

#### メソッド名

`GetScheduledGuilds`

#### 処理内容
- 指定時間に開戦予定の騎士団を取得する

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

### 騎士団戦ログ送信

騎士団戦中の成立した各種処理について、GameServerからPrivate API Serverへログ送信が行われます

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

### 騎士団戦最終結果保存

#### メソッド名

`SaveGuildBattleResult`

#### 処理内容

[API Payload](api_payload.md)の「GuildBattleResultSaveRequest」を参照

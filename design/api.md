# API仕様

# PublicAPI

- Client/Bot から要求を受ける.
- GameServer に要求を中継する.
- GameServer からの結果を Client/Bot に返す.
- テスト環境では Private Network の外側に配置される.
- 要求/レスポンスのデータ構造は[API Payload](api_payload.md)を参照する.
- `SessionID`を要求するPublicAPIは, 処理前にSessionの存在, 有効期限, 要求`PlayerID`との所有関係をすべて検証する.
  - いずれかが不正な場合は`ApiErrorResponse(API_ERROR_INVALID_SESSION)`を返し, 要求本体を処理しない.
- 個別に失敗レスポンスが定義されていないPublicAPIの失敗時は`ApiErrorResponse`を使用する.
- PublicAPIは下記「レート制限」に従って要求数を制限する. 超過時は`ApiErrorResponse(API_ERROR_RATE_LIMIT_EXCEEDED)`を返し, 要求本体を処理しない.

## レート制限

`RPM`は1分あたり, `RPH`は1時間あたり, `PRD`は1日あたりの最大要求数を表す. 各窓は同時に適用し, いずれか1つでも超過した要求を拒否する.

| 区分 | 対象PublicAPI | RPM | RPH | PRD | カウント単位 |
|---|---|---:|---:|---:|---|
| ログイン | `Login` | 1 | 5 | 25 | PlayerID |
| 新規作成時のみ | `CreatePlayer` | 1 | 5 | 10 | AccessToken |
| 新規作成時のみ | `CreateGuild` | 1 | 5 | 10 | PlayerID |
| アリーナ | `UpdateArenaParty`, `StartArenaBattle` | 2 | 50 | 100 | PlayerID |

## システム

### アクセストークン要求

#### メソッド名

`IssueAccessToken`

#### 処理内容

- `AccessTokenRequest. DiscordUserID`はBotがDiscord上で本人確認済みのユーザーIDとして受け取る.
- Private APIの`GetPlayerIDByDiscordUserID`で既存PlayerIDを検索する.
- アクセストークンを生成する.
  - 有効期限は5分とする.
  - 型は「[型定義](types.md)」の`AccessToken`を参照する.
  - 暗号学的乱数を用いて生成する.
  - `AccessTokenState`としてDiscordUserID, 既存PlayerID（存在しない場合は0）, 有効期限, 使用回数0をGameServerメモリ上だけに保持する.
  - AccessTokenは本人確認済みDiscordUserIDとPlayerIDのBindingとして扱い, 別PlayerIDのLoginには使用できない.
- GameServer起動引数へStartup Tokenを渡す方式は廃止する. Botから`IssueAccessToken`を許可する代替認証方式は未確定とし, 本仕様では定義しない.

#### 要求データ

[API Payload](api_payload.md)の「AccessTokenRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「AccessTokenResponse」を参照する.

#### 失敗時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照する. Bot認証方式は未確定のため, Bot認証失敗の具体的エラー条件は代替認証方式確定時に定義する.

### 新規PlayerID要求

#### メソッド名

`CreatePlayer`

#### 処理内容

- AccessTokenを検証する.
  - 有効期限内であることを確認する.
  - `AccessTokenState.bound_player_id=0`であり, まだ既存PlayerIDへBindingされていないことを確認する.
  - 検証前に`use_count >= 3`の場合は`API_ERROR_INVALID_ACCESS_TOKEN`として拒否し, 検証成功時に`use_count`を1増加する.
- CreatePlayerではAccessTokenを無効化しない.
- PlayerID生成後, AccessTokenに保持するDiscordUserIDを`PLAYER.discord_user_id`として保存し, `AccessTokenState.bound_player_id`へ生成したPlayerIDを設定する.
- AccessTokenはLogin成功時に無効化する.
- ユーザー名をチェックする.
  - 有効なUTF-8である.
  - 10文字以下である.
  - 空文字ではない.
  - ユーザー名の重複は許可する.
- PlayerIDを生成する.
  - `0`と`u64::MAX`は予約済み無効値のため生成対象外.
  - Private API Serverの`CheckPlayerIDExists`で重複を確認する.
  - 重複している場合は再生成する.
  - 重複していないことを確認してからClientへ返す.
- 生成したPlayerID, AccessTokenに結び付いたDiscordUserID, ユーザー名をPrivate API Server経由でDatabaseへ保存する.

#### 必要パラメータ

[API Payload](api_payload.md)の「CreatePlayerRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「CreatePlayerResponse」を参照する.

#### 失敗時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照する. AccessToken不正は`API_ERROR_INVALID_ACCESS_TOKEN`, ユーザー名不正は`API_ERROR_INVALID_USER_NAME`.

### ログイン要求

#### メソッド名

`Login`

#### 処理内容

- AccessTokenを検証する.
  - 有効期限内であることを確認する.
  - `AccessTokenState.bound_player_id`が要求`PlayerID`と一致することを確認し, AccessTokenとPlayerIDの本人性を検証する.
  - 検証前に`use_count >= 3`の場合は`API_ERROR_INVALID_ACCESS_TOKEN`として拒否し, 検証成功時に`use_count`を1増加する.
- Login成功時にアクセストークンを無効化する.
- セッションIDを暗号学的乱数で生成する.
- PlayerIDとセッションIDをPrivate API Server経由でDatabaseへUPSERTする.
- SessionIDのUNIQUE制約に衝突した場合はSessionIDを再生成して保存を再試行する.

#### 要求データ

[API Payload](api_payload.md)の「LoginRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「LoginResponse」を参照する.

#### 失敗時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照する. AccessToken不正は`API_ERROR_INVALID_ACCESS_TOKEN`.

セッション仕様.

- SessionIDの型は「[型定義](types.md)」の`SessionID`を参照する.
- SessionIDの期限: 72時間.
- ログイン時に期限がリセットされる.
- 騎士団戦参加時に期限がリセットされる.
- 複数端末からのアクセスは不可とする.
- ClientではOPFS上に保存される.


### セッション確認

#### メソッド名

`ValidateSession`

#### 処理内容

- SessionIDの存在を確認する.
- 有効期限内であることを確認する.
- SessionIDが要求PlayerIDに所有されていることを確認する.

#### 要求データ

[API Payload](api_payload.md)の「ValidateSessionPublicRequest」を参照する.

#### レスポンス

[API Payload](api_payload.md)の「ValidateSessionPublicResponse」を参照する.

### 騎士団新規作成

#### メソッド名

`CreateGuild`

#### 処理内容

- SessionIDを検証する.
- プレイヤーの初期騎士団を新規作成する.
- 作成する騎士団の`GuildID`には要求元`PlayerID`と同一値を使用する.
- 城, 武器庫, 食糧庫, 鍛冶屋, 兵法所, 酒場の各施設レベルをすべて1で初期化する.
- `DaytimeStartTime`と`NighttimeStartTime`を騎士団の開始時刻として保存する.
- 作成したプレイヤーを生成した騎士団へ所属させる.
- 作成したプレイヤーを団長として保存する.
- 初期騎士団は, プレイヤーが他の騎士団へ所属した後も削除しない.

#### 要求データ

[API Payload](api_payload.md)の「CreateGuildRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「CreateGuildResponse」を参照する.

### 騎士団所属変更

#### メソッド名

`JoinGuild`

#### 処理内容

- SessionIDを検証する.
- 指定GuildIDの所属人数が20未満であることを確認する.
- 現在所属する騎士団および指定GuildIDが騎士団戦開戦前処理開始後から終了までの所属変更禁止期間ではないことを確認する.
- プレイヤーの所属を指定GuildIDへ更新する.

#### 要求データ

[API Payload](api_payload.md)の「JoinGuildRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「JoinGuildResponse」を参照する.

#### 失敗時レスポンス

満員の場合は`ApiErrorResponse(API_ERROR_GUILD_FULL)`を返す. 所属変更禁止期間の場合は`ApiErrorResponse(API_ERROR_GUILD_MEMBERSHIP_CHANGE_NOT_ALLOWED)`を返す.

### 騎士団脱退

#### メソッド名

`LeaveGuild`

#### 処理内容

- SessionIDを検証する.
- 現在所属している騎士団が騎士団戦開戦前処理開始後から終了までの所属変更禁止期間ではないことを確認する.
- 現在所属している騎士団からプレイヤーを脱退させる.
- 新しい騎士団は生成しない.
- `GuildID = PlayerID`で既存の初期騎士団を特定する.
- プレイヤーの所属を初期騎士団へ更新する.
- 初期騎士団の施設レベル, 団長情報その他の騎士団データは既存値をそのまま使用する.

#### 要求データ

[API Payload](api_payload.md)の「LeaveGuildRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「LeaveGuildResponse」を参照する.

#### 失敗時レスポンス

所属変更禁止期間の場合は`ApiErrorResponse(API_ERROR_GUILD_MEMBERSHIP_CHANGE_NOT_ALLOWED)`を返す.

## アリーナ関連

### パーティ変更

#### メソッド名

`UpdateArenaParty`

#### 処理内容

- ClientはPublic APIを呼び出す前にアリーナ編成制約を検証する.
- GameServerは受信した編成データを用いて同じ編成制約を再検証する.
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

- SessionID, PlayerID等の要求検証を完了する.
- GameServerがアリーナ戦闘用Seedを生成する.
- `Mode=random`の場合は候補PlayerIDをPlayerID昇順に並べ, 生成したSeedを用いて対戦相手を抽選する.
- GameServerはPrivate API Server経由でDatabaseから必要データを取得する.
- 対戦相手抽選後, 戦闘開始前に同じSeedから戦闘専用の新しいPRNGを生成する. 対戦相手抽選で進んだPRNG状態は引き継がない.
- GameServerが相手`FormationID`を含む初期状態を用いて戦闘を実行し, その計算結果を正本とする.
- 成功レスポンスでは戦闘結果そのものは返さず, Clientが同一戦闘を再現するための`EnemyFormationID`・相手キャラクター初期状態・Seedを返す.
- Clientも戦闘開始前に同じSeedから戦闘専用の新しいPRNGを生成する.

#### 要求データ

[API Payload](api_payload.md)の「ArenaBattleRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「ArenaBattleResponse」を参照する.

#### エラー時レスポンス

[API Payload](api_payload.md)の「ArenaBattleErrorResponse」を参照する.


## 騎士団戦関連

騎士団戦参加後, GameServerは`GuildBattleID`ごとに`PlayerID -> RequestSequence`のマップを保持する.

- 参加前の初期値は`0`とする.
- `JoinGuildBattle`成功時に, プレイヤー固有の初期RequestSequenceを範囲乱数`1..=1,000,000,000`で生成して割り当てる. 他プレイヤーとの重複は許可する.
- 参加後の騎士団戦PublicAPI要求は`GuildBattleID`, `PlayerID`, `RequestSequence`を含む.
- 要求RequestSequenceがGameServer保持値と一致する場合のみ処理する.
- 一致しない場合は`ApiErrorResponse(API_ERROR_INVALID_GUILD_BATTLE_SEQUENCE)`を返す.
- 要求が成功するたびにGameServer保持RequestSequenceを`1`加算し, 成功レスポンスの`NextRequestSequence`としてClientへ返す.
- 失敗した要求ではRequestSequenceを加算しない.


### 騎士団戦パーティ変更

#### メソッド名

`UpdateGuildBattleParty`

#### 処理内容

- ClientはPublic APIを呼び出す前に騎士団戦編成制約を検証する.
- GameServerは受信した編成データを用いて同じ編成制約を再検証する.
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
- GameServerが参加チェックを行う.
  - 要求`GuildBattleID`が騎士団戦中であることを確認する.
  - 要求`GuildID`が, その`GuildBattleID`で対戦中の騎士団のいずれかであることを確認する.
  - `PlayerID`の現在所属GuildIDが要求`GuildID`と一致することを確認する.
- 参加可能時はSessionIDの期限を72時間後へ更新する.
- PlayerIDへ初期RequestSequenceを割り当てる.

#### 要求データ

[API Payload](api_payload.md)の「JoinGuildBattleRequest」を参照する.

#### 参加可能時レスポンス

[API Payload](api_payload.md)の「GuildBattleJoinResponse」を参照する.

#### 参加不可時レスポンス

[API Payload](api_payload.md)の「ApiErrorResponse」を参照する. `API_ERROR_GUILD_BATTLE_JOIN_NOT_ALLOWED`.

### 騎士団戦状態取得

#### メソッド名

`GetGuildBattleStatus`

#### 処理内容
- 参加中プレイヤーの編成IDと現在HPを取得する.

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

- TP.
- 使用回数.

#### 要求データ

[API Payload](api_payload.md)の「UseTacticsRequest」を参照する.

#### 使用可能時レスポンス

[API Payload](api_payload.md)の「UseTacticsResponse」を参照する.

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
- 復活可能な場合は復活中状態へ変更する.

#### 復活可能時レスポンス

[API Payload](api_payload.md)の「StartReviveResponse」を参照する.

5秒経過後, GameServerは復活完了状態へ変更する. この時点ではBP消費・HP回復は行わない.

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

# PrivateAPI

- Private Network 内に配置される.
- GameServer から要求を受ける.
- Database とのデータ保存・取得を仲介する.
- 要求/レスポンスのデータ構造は[API Payload](api_payload.md)を参照する.
- 騎士団戦中のDatabase送信失敗時は同一要求を1回だけ再試行する. 再試行も失敗した場合, GameServerはDB障害発生状態へ移行し, それ以降の騎士団戦中DB送信を行わず, 本来送信するデータをローカル保存する. 騎士団戦終了時にローカル保存データを一括送信する.
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

- DatabaseへPlayerID, DiscordUserID, UserNameを保存する.
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

- 指定された対戦相手PlayerIDのアリーナ戦闘用データをDatabaseから取得する.

#### 要求データ

[API Payload](api_payload.md)の「GetArenaBattleDataRequest」を参照する.

#### レスポンス

[API Payload](api_payload.md)の「GetArenaBattleDataResponse」を参照する.

### 全PlayerID取得

#### メソッド名

`GetAllPlayerIDs`

#### 処理内容

- Databaseに存在する全PlayerIDをPlayerID昇順で取得し, GameServerのアリーナ抽選候補キャッシュ同期に使用する.

#### レスポンス

[API Payload](api_payload.md)の「GetAllPlayerIDsResponse」を参照する.


## 騎士団戦関連

### 騎士団戦組み合わせ生成・保存

#### メソッド名

`CreateScheduledGuildBattles`

#### 処理内容

- 対象日・`GuildBattleStartTime`に一致する騎士団を抽出する.
- `GUILD_MEMBER`が0件の騎士団は対戦組み合わせ生成対象から除外する.
- 抽出一覧へ疑似乱数の「抽選」を適用して順序を決め, 先頭から2騎士団ずつペアを作る.
- 奇数の場合は最後の騎士団を事前作成済みダミープレイヤーの初期騎士団とペアにする.
- `GuildBattleID = YYYYMMDD * 10^11 + GuildBattleStartTimeEnumValue * 10^8 + PairIndex`でIDを生成する.
- 各ペアを`GUILD_BATTLE`へ`scheduled`として保存する.

#### 要求・レスポンス

[API Payload](api_payload.md)の「CreateScheduledGuildBattlesRequest」「CreateScheduledGuildBattlesResponse」を参照する.

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

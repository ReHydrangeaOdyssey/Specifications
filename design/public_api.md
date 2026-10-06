# Public API仕様

API全体の分類は「[API仕様](api.md)」を参照する.

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
- 生成したPlayerID, AccessTokenに結び付いたDiscordUserID, ユーザー名をPrivate API Server経由でDatabaseへ保存する. 新規Playerの`max_bp`は200で初期化する.

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
- `LoginRequest.ClientVersion`とGameServerが要求する`Version`を比較する.
  - 一致しない場合はSessionを発行せず, `LoginVersionErrorResponse`で`API_ERROR_CLIENT_VERSION_MISMATCH`と要求Versionを返す.
  - Clientは本エラーを受け取った場合, ゲームデータおよびClientの更新をユーザーへ促す.
- Login成功時にアクセストークンを無効化する.
- セッションIDを暗号学的乱数で生成する.
- PlayerIDとセッションIDをPrivate API Server経由でDatabaseへUPSERTする.
- SessionIDのUNIQUE制約に衝突した場合はSessionIDを再生成して保存を再試行する.

#### 要求データ

[API Payload](api_payload.md)の「LoginRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「LoginResponse」を参照する.

#### 失敗時レスポンス

AccessToken不正は[API Payload](api_payload.md)の`ApiErrorResponse(API_ERROR_INVALID_ACCESS_TOKEN)`を返す. Version不一致は`LoginVersionErrorResponse`を返す.

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
- GuildNameがUTF-8, 最大10文字, 空文字不可の制約を満たすことを確認する. GuildNameの重複は許可する.
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

#### 失敗時レスポンス

GuildNameが制約を満たさない場合は`ApiErrorResponse(API_ERROR_INVALID_GUILD_NAME)`を返す.

### 騎士団役職変更

#### メソッド名

`UpdateGuildLeadership`

#### 処理内容

- SessionIDを検証する.
- 団長・副団長へ指定可能なPlayerID条件は, 現時点では未定義とする.
- GameServerからPrivate API Serverへ要求`PlayerID`を`RequesterPlayerID`として含めた`SaveGuildLeadership`を要求する.
- Private API ServerはDatabase上の現在の`GUILD.leader_player_id`と`RequesterPlayerID`が一致する場合のみ役職を更新する.
- 一致しない場合は`ApiErrorResponse(API_ERROR_GUILD_LEADERSHIP_CHANGE_NOT_ALLOWED)`としてClientへ返す.

#### 要求データ

[API Payload](api_payload.md)の「UpdateGuildLeadershipRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「UpdateGuildLeadershipResponse」を参照する.

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
- GameServerは受信した編成データを用いて同じ編成制約を再検証する. 同一キャラクター内で同じAbilityEffectIDを持つアビリティが複数設定されている場合は編成不正とする.
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
- GameServer共通内部API`GenerateTimeBasedSeed`を使用して時刻ベースSeedを生成する.
- `Mode=random`の場合は候補PlayerIDをPlayerID昇順に並べ, 生成したSeedを用いて対戦相手を抽選する.
- GameServerはPrivate API Server経由でDatabaseから要求元PlayerIDと対戦相手PlayerIDの両方について`GetArenaBattleData`を実行し, 双方のFormationID・編成情報を取得する.
- `Mode=friend`で指定した`OpponentID`がDatabaseに存在しない場合は`ARENA_BATTLE_ERROR_PLAYER_NOT_FOUND`を返す.
- `Mode=friend`で指定した`OpponentID`は存在するがArenaParty未登録の場合は`ARENA_BATTLE_ERROR_ARENA_PARTY_NOT_REGISTERED`を返す.
- 対戦相手抽選後, 戦闘開始前に同じSeedから戦闘専用の新しいPRNGを生成する. 対戦相手抽選で進んだPRNG状態は引き継がない.
- GameServerが自分側と相手側双方のFormationID・キャラクター初期状態を用いて戦闘を実行し, その計算結果を正本とする.
- 成功レスポンスでは戦闘結果そのものは返さず, Clientが同一戦闘を再現するための`EnemyFormationID`・相手キャラクター初期状態・Seedを返す.
- Clientも戦闘開始前に同じSeedから戦闘専用の新しいPRNGを生成する.

#### 要求データ

[API Payload](api_payload.md)の「ArenaBattleRequest」を参照する.

#### 成功時レスポンス

[API Payload](api_payload.md)の「ArenaBattleResponse」を参照する.

#### エラー時レスポンス

[API Payload](api_payload.md)の「ArenaBattleErrorResponse」を参照する. ランダム対戦で候補が存在しない場合は`ARENA_BATTLE_ERROR_NO_OPPONENT_AVAILABLE`, フレンド対戦でOpponentIDが存在しない場合は`ARENA_BATTLE_ERROR_PLAYER_NOT_FOUND`, OpponentIDは存在するがArenaParty未登録の場合は`ARENA_BATTLE_ERROR_ARENA_PARTY_NOT_REGISTERED`を返す.


## 騎士団戦関連

騎士団戦参加後, GameServerは`GuildBattleID`ごとに`PlayerID -> RequestSequence`のマップを保持する.

- 参加前の初期値は`0`とする.
- `JoinGuildBattle`成功時に, プレイヤー固有の初期RequestSequenceを範囲乱数`1..=1,000,000,000`で生成して割り当てる. 他プレイヤーとの重複は許可する.
- 参加後の騎士団戦PublicAPI要求は, 再接続用の`GetGuildBattleStatus`を除き`GuildBattleID`, `PlayerID`, `RequestSequence`を含む.
- `GetGuildBattleStatus`はSessionID・PlayerID・GuildBattleIDで本人性と参加状態を検証し, 現在のRequestSequenceを含む状態一式を返す. この要求ではRequestSequenceを加算しない.
- 要求RequestSequenceがGameServer保持値と一致する場合のみ処理する.
- 一致しない場合は`ApiErrorResponse(API_ERROR_INVALID_GUILD_BATTLE_SEQUENCE)`を返す.
- `GetGuildBattleStatus`を除く要求が成功するたびにGameServer保持RequestSequenceを`1`加算し, 成功レスポンスの`NextRequestSequence`としてClientへ返す.
- 失敗した要求ではRequestSequenceを加算しない.


### 騎士団戦パーティ変更

#### メソッド名

`UpdateGuildBattleParty`

#### 処理内容

- ClientはPublic APIを呼び出す前に騎士団戦編成制約を検証する.
- GameServerは受信した編成データを用いて同じ編成制約を再検証する. 同一キャラクター内で同じAbilityEffectIDを持つアビリティが複数設定されている場合は編成不正とする.
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

- SessionID, PlayerID, GuildBattleIDから参加中プレイヤーを検証する.
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
- 「[パーティランク](../specification/party_rank.md)」に従ってパーティランクを算出し, 復活待機時間を決定する.
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

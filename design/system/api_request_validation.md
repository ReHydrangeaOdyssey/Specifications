# RPC入力フィールド検証契約

## 適用範囲

本表は`design/system/api_transport.md`のPublic/Private Allowlistに対応するRequest Messageの全フィールドを列挙する。Schemaのフィールド番号・型は対応する`.proto`を正本とする。
HTTP 400は構文/型/許容値の不正、401は認証不成立、403は権限違反、404は対象不在、409は現在状態と衝突する業務要求に使用する。`ApiErrorResponse.error_code`は該当する既存Enumで詳細化する。既定値`0`や`false`が正当な場合、省略と値を混同しない。

各表の「検証」は既存の`design/server/api_payload.md`・`design/shared/types.md`の個別制約より広い値域を許可する意味ではない。通常のProto3スカラーのPresenceを直接検知できない箇所は、既定値の業務上の妥当性で判定する。値0が正当でかつ入力時の明示が必要な開始時刻Enum、およびfalseが明示的な解除操作となる`locked`等は`optional`でPresenceを保持する。

## 利用中RPCの厳密な検証（汎用表より優先）

この節は現在の騎士団戦・ログイン/認証・編成で使用する要求のPresenceおよび業務状態検証を定める。`0`や`false`が合法な値を持つ既存フィールドは、proto3既定値だけで省略と同一視しない。`optional`が必要なときは既存tagを維持する。列挙値を変更する場合も`0`が業務上有効なEnumのPresenceを失わせない。

| RPC / Field | Presence・許容値 | 不正・衝突時 |
|---|---|---|
| `GetAdditionalAuthorizationConfig` / 空Request | Message Body必須、Credential不要 | HTTP 400 |
| `CreateAccount`・`Login` / `login_id`,`password` | `login_id`: ASCII英数字と `._-`、3～64文字・大文字小文字を区別。`password`: 非空。認可Tokenは選択中Providerの契約に従い、`NONE`なら追加Token不要 | 400（形式）、401（認証） |
| `CreateGuild` / `guild_name`,`daytime_start_time`,`nighttime_start_time` | `guild_name`: UTF-8で1～10文字（重複可）。昼夜はProtoBuf `optional`のPresence必須。定義済み列挙値0が有効なら明示0を許可 | 400（省略/列挙外） |
| `RespondFriendRequest` / `approve` | `optional bool`を必須。明示`false`は拒否として有効 | 400（省略） |
| `UseItem` / `player_id`,`guild_battle_id`,`request_sequence`,`item_id` | 既存ID範囲とOwner/Join/Sequence一致を要求。所持数0のときの使用は不成立。Item残数の変更はWAL受理確定後 | 400（型・範囲）、403（他人）、409（残数・順序・対戦状態） |
| `SaveGuildBattleItemLog` / `payload`,`event_index` | Payload必須、Event番号2以上、Operation ID必須。数量が差1で、Create Snapshotからの使用順と一致すること。DB在庫は1以上 | 400（構造）、409（同番号異Payload/在庫競合） |
| `SaveGuildBattleSortieLog` / `payload`,`event_index` | Payload必須、Event番号2以上、Operation ID必須。受付済みの出撃と一意に照合 | 400（欠落/番号）、409（重複不整合） |
| `SaveGuildBattleTavernRecoveryLog` / `payload`,`event_index` | Payload必須、Event番号2以上、Operation ID必須。`remaining_uses_after`は0..3でDB正本残数と照合 | 400（範囲/欠落）、409（状態競合） |
| `CompleteGuildBattle` / 対戦ID・結果・記録 | Player/対戦ID一致、全WAL/Journal反映・署名/連鎖・Replay検証完了を要求 | 400（不正）、409（未確定Event） |

その他の既存RPCについては下表および各API Payloadの制約を適用する。各Requestの`0`/`false`に新たな意味が確認されない限り、値だけを理由として新しいゲームルールを追加しない。

## フィールド一覧

通常のBearer認証を要するPublic RPCについては、各表の`access_token`行に加えて[API通信契約](api_transport.md)の「通常認証Public RPCのBearer Header/Body AccessToken整合」を適用する。移行期間中はHeader/Body両方を検証し、不一致・欠落はHTTP 401で拒否する。認証不要・認証Origin専用の既存フローにはこの二重照合を適用しない。

追加認可Tokenの必須性は`design/server/session.md`の`AdditionalAuthorizationProvider`を正本とする。`DISCORD`では従来Field 4、`POCKETBASE`ではField 5を用い、`NONE`では両者の省略を認める。検証Adapter未実装の方式は許可しない。

### Public `GetAdditionalAuthorizationConfig` — `GetAdditionalAuthorizationConfigRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| （フィールドなし） | - | 空MessageのRequest Bodyを必須とする | ログイン前に使用可能。認証Tokenは不要。 | 400（Body省略/破損） |


### Public `CreateAccount` — `CreateAccountRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `login_id` | `string`（1） | 必須、3～64文字（Proto3空文字は拒否） | ASCII英数字および`._-`のみ。大小文字を区別 | 400:文字/長さ不正、401:認証失敗 |
| `password` | `string`（2） | 空文字禁止、長さ/形式は既存認証仕様 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:形式不正、401:認証不成立 |
| `user_name` | `string`（3） | 必須。有効なUTF-8で1～10文字 | 重複可。空文字または10文字超は拒否する | 400:文字数/形式不正 |
| `discord_authorization_token` | `string`（4） | `DISCORD`のとき必須。それ以外では省略可 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `additional_authorization_token` | `string`（5） | `POCKETBASE`等の非Discord追加認可で必須、`NONE`では省略可 | 検証Adapterが検証したTokenのみ有効 | 401:認可不成立、400:形式不正 |

### Public `Login` — `LoginRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `login_id` | `string`（1） | 必須、3～64文字（Proto3空文字は拒否） | ASCII英数字および`._-`のみ。大小文字を区別 | 400:文字/長さ不正、401:認証失敗 |
| `password` | `string`（2） | 空文字禁止、長さ/形式は既存認証仕様 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:形式不正、401:認証不成立 |
| `client_version` | `string`（3） | 必須、空文字不可 | Server指定のRequiredVersionと一致 | 400:空値、既存のClientVersionMismatch Error:不一致 |
| `discord_authorization_token` | `string`（4） | `DISCORD`のとき必須。それ以外では省略可 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `additional_authorization_token` | `string`（5） | `POCKETBASE`等の非Discord追加認可で必須、`NONE`では省略可 | 検証Adapterが検証したTokenのみ有効 | 401:認可不成立、400:形式不正 |

### Public `RefreshAccessToken` — `RefreshAccessTokenRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| （フィールドなし） | - | 空Request Messageを必須とする | Body省略不可 | 400 |

### Public `Logout` — `LogoutRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| （フィールドなし） | - | 空Request Messageを必須とする | Body省略不可 | 400 |

### Public `CreateGuild` — `CreateGuildRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_name` | `string`（3） | 必須、空文字不可 | UTF-8で最大10文字、重複可 | 400/API_ERROR_INVALID_GUILD_NAME |
| `daytime_start_time` | `optional GuildBattleStartTime`（4） | Presence必須（`has_`で確認） | 型の値域 + 既存Payload制約 | 400:省略/無効値 |
| `nighttime_start_time` | `optional GuildBattleStartTime`（5） | Presence必須（`has_`で確認） | 型の値域 + 既存Payload制約 | 400:省略/無効値 |

### Public `UpdateGuildLeadership` — `UpdateGuildLeadershipRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `leader_player_id` | `uint64`（4） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `subleader_player_id` | `uint64`（5） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `ApplyGuildJoin` — `ApplyGuildJoinRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `ApproveGuildJoinApplication` — `ApproveGuildJoinApplicationRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `applicant_player_id` | `uint64`（4） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `SendGuildInvitation` — `SendGuildInvitationRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `invitee_player_id` | `uint64`（4） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `AcceptGuildInvitation` — `AcceptGuildInvitationRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `LeaveGuild` — `LeaveGuildRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `UpdateArenaParty` — `UpdateArenaPartyRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `formation_id` | `uint32`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `characters` | `repeated ArenaPartyCharacter`（4） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |

### Public `StartArenaBattle` — `ArenaBattleRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `client_version` | `string`（3） | 必須、空文字不可 | Server指定のRequiredVersionと一致 | 400:空値、既存のClientVersionMismatch Error:不一致 |
| `mode` | `optional ArenaMode`（4） | Presence必須（`has_`で確認） | 型の値域 + 既存Payload制約 | 400:省略/無効値 |
| `opponent_id` | `uint64`（5） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `local_formation_id` | `uint32`（6） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `local_characters` | `repeated ArenaPartyCharacter`（7） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |

### Public `UpdateGuildBattleParty` — `UpdateGuildBattlePartyRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `formation_id` | `uint32`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `characters` | `repeated GuildBattlePartyCharacter`（4） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |

### Public `JoinGuildBattle` — `JoinGuildBattleRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `client_version` | `string`（3） | 必須、空文字不可 | Server指定のRequiredVersionと一致 | 400:空値、既存のClientVersionMismatch Error:不一致 |
| `guild_id` | `uint64`（4） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（5） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `local_formation_id` | `uint32`（6） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `local_characters` | `repeated GuildBattlePartyCharacter`（7） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |

### Public `GetGuildBattleStatus` — `GetGuildBattleStatusRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `SubscribeGuildBattleUpdates` — `SubscribeGuildBattleUpdatesRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `GuildBattleSortie` — `GuildBattleSortieRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `request_sequence` | `uint64`（4） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `select_id` | `repeated uint32`（5） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |

### Public `UseTactics` — `UseTacticsRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `request_sequence` | `uint64`（4） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `tactics_id` | `uint32`（5） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `UseItem` — `UseItemRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `request_sequence` | `uint64`（4） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `item_id` | `uint32`（5） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `UseTavernRecovery` — `UseTavernRecoveryRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `request_sequence` | `uint64`（4） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `StartHeal` — `StartHealRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `request_sequence` | `uint64`（4） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `CancelHeal` — `CancelHealRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `request_sequence` | `uint64`（4） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `CompleteHeal` — `CompleteHealRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `request_sequence` | `uint64`（4） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `StartRevive` — `StartReviveRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `request_sequence` | `uint64`（4） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `CancelRevive` — `CancelReviveRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `request_sequence` | `uint64`（4） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `CompleteRevive` — `CompleteReviveRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `request_sequence` | `uint64`（4） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `IssueAuthorizationCode` — `IssueAuthorizationCodeRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `redirect_uri` | `string`（1） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
| `code_challenge_sha256` | `bytes`（2） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |

### Public `ExchangeAuthorizationCode` — `ExchangeAuthorizationCodeRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `authorization_code` | `bytes`（1） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
| `redirect_uri` | `string`（2） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
| `code_verifier` | `string`（3） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |

### Public `GetGuildFacilityUpgradeCost` — `GetGuildFacilityUpgradeCostRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `facility_id` | `GuildFacilityID`（4） | Messageは存在確認、Enumは定義済み値のみ | 対象enum値/ネストフィールドの制約 | 400:未定義enum/不正内容 |

### Public `UpgradeGuildFacility` — `UpgradeGuildFacilityRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `facility_id` | `GuildFacilityID`（4） | Messageは存在確認、Enumは定義済み値のみ | 対象enum値/ネストフィールドの制約 | 400:未定義enum/不正内容 |
| `offered_gold` | `uint32`（5） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `SearchGuilds` — `SearchGuildsRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `name_prefix` | `string`（3） | 空を許す | 空文字は全件検索用のPrefix、検索上限に従う | 400:型/長さ不正、401:認証失敗 |
| `limit` | `uint32`（4） | 0を許さない検索limitは省略も拒否 | 1～50（検索API）、それ以外は既存API値域 | 400:無効なID/範囲、409:状態競合 |
| `after_guild_id` | `uint64`（5） | 0は有効な既定カーソル | 0を先頭カーソルとして許可 | 400:無効なID/範囲、409:状態競合 |

### Public `SearchPlayers` — `SearchPlayersRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `name_prefix` | `string`（3） | 空を許す | 空文字は全件検索用のPrefix、検索上限に従う | 400:型/長さ不正、401:認証失敗 |
| `limit` | `uint32`（4） | 0を許さない検索limitは省略も拒否 | 1～50（検索API）、それ以外は既存API値域 | 400:無効なID/範囲、409:状態競合 |
| `after_player_id` | `uint64`（5） | 0は有効な既定カーソル | 0を先頭カーソルとして許可 | 400:無効なID/範囲、409:状態競合 |

### Public `ListGuildJoinApplications` — `ListGuildJoinApplicationsRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `ListGuildInvitations` — `ListGuildInvitationsRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `GetGuildDetail` — `GetGuildDetailRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `UpdateGuildBattleStartTimes` — `UpdateGuildBattleStartTimesRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `daytime_start_time` | `optional GuildBattleStartTime`（4） | Presence必須（`has_`で確認） | 型の値域 + 既存Payload制約 | 400:省略/無効値 |
| `nighttime_start_time` | `optional GuildBattleStartTime`（5） | Presence必須（`has_`で確認） | 型の値域 + 既存Payload制約 | 400:省略/無効値 |

### Public `GetMyGuildBattle` — `GetMyGuildBattleRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `GetGuildBattleResult` — `GetGuildBattleResultRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `GetArenaParty` — `GetArenaPartyRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `GetGuildBattleParty` — `GetGuildBattlePartyRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `ListMyGuildBattleReplays` — `ListMyGuildBattleReplaysRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `GetMyGuildBattleReplay` — `GetMyGuildBattleReplayRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `CreateAccount` — `CreateAccountPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `login_id` | `string`（1） | 必須、3～64文字（Proto3空文字は拒否） | ASCII英数字および`._-`のみ。大小文字を区別 | 400:文字/長さ不正、401:認証失敗 |
| `password` | `string`（2） | 空文字禁止、長さ/形式は既存認証仕様 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:形式不正、401:認証不成立 |
| `user_name` | `string`（3） | 必須。有効なUTF-8で1～10文字 | 重複可。空文字または10文字超は拒否する | 400:文字数/形式不正 |
| `discord_user_id` | `uint64`（4） | `DISCORD`の場合のみ検証済みID必須。それ以外は0 | Serverで確認済みのDiscordUserID。Account Bindingと照合 | 400/401:不正・不一致 |
| `discord_authorization_token_id` | `bytes`（5） | `DISCORD`の場合のみ検証済みToken ID必須。それ以外は空bytes | 使用済みToken IDをDBと照合し、再利用を拒否 | 400/401:不正・再利用 |
| `additional_authorization_provider` | `string`（6） | Serverが選択・検証済みのProviderを必須として中継する | `DISCORD` / `POCKETBASE` / `OTHER` / `NONE`。Client申告を採用しない。未実装Adapterの有効化は禁止 | 400/401:不正・未検証 |
| `additional_authorization_subject` | `string`（7） | `NONE`以外で検証済み不変Subject必須、`NONE`では空文字 | 登録対象AccountへProviderと組でBindingする | 400/401:不正・未検証 |

### Private `AuthenticateAccount` — `AuthenticateAccountRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `login_id` | `string`（1） | 必須、3～64文字（Proto3空文字は拒否） | ASCII英数字および`._-`のみ。大小文字を区別 | 400:文字/長さ不正、401:認証失敗 |
| `password` | `string`（2） | 空文字禁止、長さ/形式は既存認証仕様 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:形式不正、401:認証不成立 |
| `discord_user_id` | `uint64`（3） | `DISCORD`の場合のみ検証済みID必須。それ以外は0 | Serverで確認済みのDiscordUserID。Account Bindingと照合 | 400/401:不正・不一致 |
| `discord_authorization_token_id` | `bytes`（4） | `DISCORD`の場合のみ検証済みToken ID必須。それ以外は空bytes | 使用済みToken IDをDBと照合し、再利用を拒否 | 400/401:不正・再利用 |
| `additional_authorization_provider` | `string`（5） | Serverが選択・検証済みのProviderを必須として中継する | `DISCORD` / `POCKETBASE` / `OTHER` / `NONE`。登録時Bindingと照合 | 400/401:不正・不一致 |
| `additional_authorization_subject` | `string`（6） | `NONE`以外で検証済み不変Subject必須、`NONE`では空文字 | Accountに保存された同ProviderのSubjectと照合 | 400/401:不正・不一致 |

### Private `RefreshAccessToken` — `RefreshAccessTokenPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `refresh_token` | `bytes`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |

### Private `Logout` — `LogoutPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `refresh_token` | `bytes`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |

### Private `ValidateAccountSession` — `ValidateAccountSessionRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `session_id` | `bytes`（1） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |

### Private `RevokeDiscordSessions` — `RevokeDiscordSessionsRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `discord_user_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `CreateGuildPrivate` — `CreateGuildPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_name` | `string`（1） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
| `daytime_start_time` | `optional game.model.GuildBattleStartTime`（2） | Presence必須（`has_`で確認） | 型の値域 + 既存Payload制約 | 400:省略/無効値 |
| `nighttime_start_time` | `optional game.model.GuildBattleStartTime`（3） | Presence必須（`has_`で確認） | 型の値域 + 既存Payload制約 | 400:省略/無効値 |

### Private `UpdateGuildLeadershipPrivate` — `UpdateGuildLeadershipPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `leader_player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `subleader_player_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `SetGuildMembershipLock` — `SetGuildMembershipLockRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_id` | `repeated uint64`（1） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |
| `locked` | `optional bool`（2） | optionalのPresence必須。falseはロック解除 | true/false | 400:省略/無効値 |

### Private `ApplyGuildJoinPrivate` — `ApplyGuildJoinPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `ApproveGuildJoinApplicationPrivate` — `ApproveGuildJoinApplicationPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `applicant_player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `SendGuildInvitationPrivate` — `SendGuildInvitationPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `invitee_player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `AcceptGuildInvitationPrivate` — `AcceptGuildInvitationPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `LeaveGuildPrivate` — `LeaveGuildPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| （フィールドなし） | - | 空Request Messageを必須とする | Body省略不可 | 400 |

### Private `SaveArenaParty` — `SaveArenaPartyRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `formation_id` | `uint32`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `characters` | `repeated game.publicapi.ArenaPartyCharacter`（3） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |

### Private `GetArenaBattleData` — `GetArenaBattleDataRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `GetAllPlayerIDs` — `GetAllPlayerIDsRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| （フィールドなし） | - | 空Request Messageを必須とする | Body省略不可 | 400 |

### Private `GetGuildsForBattleMatching` — `GetGuildsForBattleMatchingRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `target_date` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `start_time` | `optional game.model.GuildBattleStartTime`（2） | Presence必須（`has_`で確認） | 型の値域 + 既存Payload制約 | 400:省略/無効値 |

### Private `SaveGuildBattleExcludedGuilds` — `SaveGuildBattleExcludedGuildsRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `target_date` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `start_time` | `optional game.model.GuildBattleStartTime`（2） | Presence必須（`has_`で確認） | 型の値域 + 既存Payload制約 | 400:省略/無効値 |
| `guild_id` | `repeated uint64`（3） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |

### Private `GetGuildBattleExcludedGuilds` — `GetGuildBattleExcludedGuildsRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `target_date` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `start_time` | `optional game.model.GuildBattleStartTime`（2） | Presence必須（`has_`で確認） | 型の値域 + 既存Payload制約 | 400:省略/無効値 |

### Private `ClearGuildBattleExcludedGuilds` — `ClearGuildBattleExcludedGuildsRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `target_date` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `start_time` | `optional game.model.GuildBattleStartTime`（2） | Presence必須（`has_`で確認） | 型の値域 + 既存Payload制約 | 400:省略/無効値 |

### Private `SaveScheduledGuildBattles` — `SaveScheduledGuildBattlesRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `target_date` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `start_time` | `optional game.model.GuildBattleStartTime`（2） | Presence必須（`has_`で確認） | 型の値域 + 既存Payload制約 | 400:省略/無効値 |
| `battles` | `repeated ScheduledGuildBattle`（3） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |

### Private `GetScheduledGuilds` — `GetScheduledGuildsRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `target_date` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `start_time` | `optional game.model.GuildBattleStartTime`（2） | Presence必須（`has_`で確認） | 型の値域 + 既存Payload制約 | 400:省略/無効値 |

### Private `GetGuildBattleCoordinationState` — `GetGuildBattleCoordinationStateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| （フィールドなし） | - | 空Request Messageを必須とする | Body省略不可 | 400 |

### Private `AssignScheduledGuildBattles` — `AssignScheduledGuildBattlesRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `game_server_instance_id` | `string`（1） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
| `guild_battle_id` | `repeated uint64`（2） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |

### Private `ReleaseScheduledGuildBattleAssignments` — `ReleaseScheduledGuildBattleAssignmentsRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `game_server_instance_id` | `string`（1） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
| `guild_battle_id` | `repeated uint64`（2） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |

### Private `GetGuildBattleAssignment` — `GetGuildBattleAssignmentRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_battle_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `SaveGuildBattleParty` — `SaveGuildBattlePartyRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `formation_id` | `uint32`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `characters` | `repeated game.publicapi.GuildBattlePartyCharacter`（3） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |

### Private `GetGuildBattleFormation` — `GetGuildBattleFormationRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `GetGuildMembers` — `GetGuildMembersRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `GetGuildData` — `GetGuildDataRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `GetPlayerItems` — `GetPlayerItemsRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `UpdatePlayerItem` — `UpdatePlayerItemRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `item_id` | `uint32`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `quantity` | `uint32`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `MarkGuildBattlePreloadFailed` — `MarkGuildBattlePreloadFailedRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_battle_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `game_server_instance_id` | `string`（2） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |

### Private `StartGuildBattle` — `StartGuildBattleRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `game_server_instance_id` | `string`（1） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
| `create_log` | `game.guildbattle.replay.GuildBattleCreateLogPayload`（2） | Messageは存在確認、Enumは定義済み値のみ | 対象enum値/ネストフィールドの制約 | 400:未定義enum/不正内容 |

### Private `BeginGuildBattleResolving` — `BeginGuildBattleResolvingRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_battle_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `game_server_instance_id` | `string`（2） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |

### Private `RematchPreloadFailedGuildBattles` — `RematchPreloadFailedGuildBattlesRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_battle_id` | `repeated uint64`（1） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |
| `battles` | `repeated ScheduledGuildBattle`（2） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |

### Private `RetryPreloadFailedGuildBattle` — `RetryPreloadFailedGuildBattleRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_battle_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `restart_at` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `CancelPreloadFailedGuildBattle` — `CancelPreloadFailedGuildBattleRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_battle_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `DeleteUnassignedGuildBattles` — `DeleteUnassignedGuildBattlesRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_battle_id` | `repeated uint64`（1） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |

### Private `SaveGuildBattleJoinLog` — `SaveGuildBattleJoinLogRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `payload` | `game.guildbattle.replay.GuildBattleJoinLogPayload`（1） | Messageは存在確認、Enumは定義済み値のみ | 対象enum値/ネストフィールドの制約 | 400:未定義enum/不正内容 |
| `event_index` | `uint64`（2） | 省略/0は拒否 | 2以上（Create=1）、GuildBattleID内で連続・一意 | 400:無効番号、409:不一致 |

### Private `SaveGuildBattleSortieLog` — `SaveGuildBattleSortieLogRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `payload` | `game.guildbattle.replay.GuildBattleSortieLogPayload`（1） | Messageは存在確認、Enumは定義済み値のみ | 対象enum値/ネストフィールドの制約 | 400:未定義enum/不正内容 |
| `event_index` | `uint64`（2） | 省略/0は拒否 | 2以上（Create=1）、GuildBattleID内で連続・一意 | 400:無効番号、409:不一致 |

### Private `SaveGuildBattleTacticsLog` — `SaveGuildBattleTacticsLogRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `payload` | `game.guildbattle.replay.GuildBattleTacticsLogPayload`（1） | Messageは存在確認、Enumは定義済み値のみ | 対象enum値/ネストフィールドの制約 | 400:未定義enum/不正内容 |
| `event_index` | `uint64`（2） | 省略/0は拒否 | 2以上（Create=1）、GuildBattleID内で連続・一意 | 400:無効番号、409:不一致 |

### Private `SaveGuildBattleItemLog` — `SaveGuildBattleItemLogRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `payload` | `game.guildbattle.replay.GuildBattleItemLogPayload`（1） | Messageは存在確認、Enumは定義済み値のみ | 対象enum値/ネストフィールドの制約 | 400:未定義enum/不正内容 |
| `event_index` | `uint64`（2） | 省略/0は拒否 | 2以上（Create=1）、GuildBattleID内で連続・一意 | 400:無効番号、409:不一致 |

### Private `SaveGuildBattleHealLog` — `SaveGuildBattleHealLogRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `payload` | `game.guildbattle.replay.GuildBattleHealLogPayload`（1） | Messageは存在確認、Enumは定義済み値のみ | 対象enum値/ネストフィールドの制約 | 400:未定義enum/不正内容 |
| `event_index` | `uint64`（2） | 省略/0は拒否 | 2以上（Create=1）、GuildBattleID内で連続・一意 | 400:無効番号、409:不一致 |

### Private `SaveGuildBattleReviveLog` — `SaveGuildBattleReviveLogRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `payload` | `game.guildbattle.replay.GuildBattleReviveLogPayload`（1） | Messageは存在確認、Enumは定義済み値のみ | 対象enum値/ネストフィールドの制約 | 400:未定義enum/不正内容 |
| `event_index` | `uint64`（2） | 省略/0は拒否 | 2以上（Create=1）、GuildBattleID内で連続・一意 | 400:無効番号、409:不一致 |

### Private `SaveErrorLog` — `SaveErrorLogRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `time` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `error_log` | `string`（3） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |

### Private `CompleteGuildBattle` — `CompleteGuildBattleRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_battle_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `game_server_instance_id` | `string`（2） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
| `guild_results` | `repeated GuildBattleFinalGuildResult`（3） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |
| `player_records` | `repeated GuildBattlePlayerRecordUpdate`（4） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |
| `participants` | `repeated GuildBattlePlayerParticipation`（5） | 空配列を許すかは業務契約に従う | 要素型 + 固定要素数/個数上限（既存仕様） | 400:要素・個数不正 |

### Private `IssueAuthorizationCodePrivate` — `IssueAuthorizationCodePrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `refresh_token` | `bytes`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `redirect_uri` | `string`（2） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
| `code_challenge_sha256` | `bytes`（3） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |

### Private `RedeemAuthorizationCodePrivate` — `RedeemAuthorizationCodePrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `authorization_code` | `bytes`（1） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
| `redirect_uri` | `string`（2） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
| `code_verifier_sha256` | `bytes`（3） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |

### Private `GetGuildFacilityUpgradeCostPrivate` — `GetGuildFacilityUpgradeCostPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `facility_id` | `game.publicapi.GuildFacilityID`（3） | Messageは存在確認、Enumは定義済み値のみ | 対象enum値/ネストフィールドの制約 | 400:未定義enum/不正内容 |

### Private `UpgradeGuildFacilityPrivate` — `UpgradeGuildFacilityPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `facility_id` | `game.publicapi.GuildFacilityID`（3） | Messageは存在確認、Enumは定義済み値のみ | 対象enum値/ネストフィールドの制約 | 400:未定義enum/不正内容 |
| `offered_gold` | `uint32`（4） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `SearchGuildsPrivate` — `SearchGuildsPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `name_prefix` | `string`（1） | 空を許す | 空文字は全件検索用のPrefix、検索上限に従う | 400:型/長さ不正、401:認証失敗 |
| `limit` | `uint32`（2） | 0を許さない検索limitは省略も拒否 | 1～50（検索API）、それ以外は既存API値域 | 400:無効なID/範囲、409:状態競合 |
| `after_guild_id` | `uint64`（3） | 0は有効な既定カーソル | 0を先頭カーソルとして許可 | 400:無効なID/範囲、409:状態競合 |

### Private `SearchPlayersPrivate` — `SearchPlayersPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `name_prefix` | `string`（1） | 空を許す | 空文字は全件検索用のPrefix、検索上限に従う | 400:型/長さ不正、401:認証失敗 |
| `limit` | `uint32`（2） | 0を許さない検索limitは省略も拒否 | 1～50（検索API）、それ以外は既存API値域 | 400:無効なID/範囲、409:状態競合 |
| `after_player_id` | `uint64`（3） | 0は有効な既定カーソル | 0を先頭カーソルとして許可 | 400:無効なID/範囲、409:状態競合 |

### Private `ListGuildJoinApplicationsPrivate` — `ListGuildJoinApplicationsPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `ListGuildInvitationsPrivate` — `ListGuildInvitationsPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `GetGuildDetailPrivate` — `GetGuildDetailPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `guild_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `UpdateGuildBattleStartTimesPrivate` — `UpdateGuildBattleStartTimesPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `daytime_start_time` | `optional game.model.GuildBattleStartTime`（3） | Presence必須（`has_`で確認） | 型の値域 + 既存Payload制約 | 400:省略/無効値 |
| `nighttime_start_time` | `optional game.model.GuildBattleStartTime`（4） | Presence必須（`has_`で確認） | 型の値域 + 既存Payload制約 | 400:省略/無効値 |

### Private `GetMyGuildBattlePrivate` — `GetMyGuildBattlePrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `GetGuildBattleResultPrivate` — `GetGuildBattleResultPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `GetMyArenaPartyPrivate` — `GetMyArenaPartyPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `GetMyGuildBattlePartyPrivate` — `GetMyGuildBattlePartyPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `ListMyGuildBattleReplaysPrivate` — `ListMyGuildBattleReplaysPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `current_version` | `string`（2） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |

### Private `GetMyGuildBattleReplayPrivate` — `GetMyGuildBattleReplayPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `guild_battle_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `current_version` | `string`（3） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |

### Public `GetInitialGuildStatus` — `GetInitialGuildStatusRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `GetInitialGuildStatusPrivate` — `GetInitialGuildStatusPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `GetPlayerProfile` — `GetPlayerProfileRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `target_player_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `SendFriendRequest` — `SendFriendRequestRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `target_player_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `ListNotifications` — `ListNotificationsRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `RespondFriendRequest` — `RespondFriendRequestRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `sender_player_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `approve` | `optional bool`（4） | optionalのPresence必須。falseは拒否操作 | true/false | 400:省略/無効値 |

### Public `ListFriends` — `ListFriendsRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Public `RemoveFriend` — `RemoveFriendRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `access_token` | `string`（1） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `friend_player_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `GetPlayerProfilePrivate` — `GetPlayerProfilePrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `requester_player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `target_player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `SendFriendRequestPrivate` — `SendFriendRequestPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `sender_player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `recipient_player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `ListFriendRequestsPrivate` — `ListFriendRequestsPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `recipient_player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `RespondFriendRequestPrivate` — `RespondFriendRequestPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `recipient_player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `sender_player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `approve` | `optional bool`（3） | optionalのPresence必須。falseは拒否操作 | true/false | 400:省略/無効値 |

### Private `ListFriendsPrivate` — `ListFriendsPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

### Private `RemoveFriendPrivate` — `RemoveFriendPrivateRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `player_id` | `uint64`（1） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `friend_player_id` | `uint64`（2） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |

## 共通検証手順

1. Content-TypeとBody上限を先に確認し、定義済みRequest MessageとしてDeserializeする。
2. `optional`フィールドはPresenceを確認する。必須のString/bytesは空値を拒否し、整数・Enumは業務上の予約値と指定可能集合を確認する。
3. ネストMessageを再帰的に検証し、繰返しフィールドの件数・参照ID・重複禁止・固定長を業務契約と照合する。
4. 認証済みCaller/対象GuildBattleの所有・権限・現在状態をServer正本で確認する。
5. エラーは既存のHTTPステータスと`ApiErrorResponse`を用い、失敗した状態変更は永続化しない。

出撃の保存失敗は成功として応答せず、既存のAPIエラーに従う。一般Player向けReplay一覧/取得は現段階では公開しない。

### Private `SaveGuildBattleTavernRecoveryLog` — `SaveGuildBattleTavernRecoveryLogRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `payload` | `GuildBattleTavernRecoveryLogPayload`（1） | 必須（message存在必須） | GuildBattleID・PlayerID・GuildID、残回数0～3、次回回復時刻と成立時刻の整合 | 400 / 409 |
| `event_index` | `uint64`（2） | 必須、0は禁止 | GuildBattleIDごとに連番。DBでOperation IDと合わせて重複検証 | 400 / 409 |

`X-Operation-ID`はUUID 128bitを必須とする。Replay Eventと`PLAYER_TAVERN_RECOVERY`更新は同一Transactionに含める。

## 運用中の認証RPCに適用する具体規則

- `GetAdditionalAuthorizationConfig`は空のRequest Message Bodyのみを許可し、AccessTokenを要求しない。Provider列挙はServer側設定値に従い、ClientのRequestから選択しない。
- `CreateAccount.login_id`および`Login.login_id`は非空で、`design/server/session.md`の3～64文字制約を満たすこと。`password`は空文字を許可せずSession仕様に従う。登録時`user_name`は有効なUTF-8で1～10文字とし、重複を許可する。
- `Login.client_version`は空文字を拒否してServerの要求Versionと比較し、不一致を専用Version Errorとして返す。
- 追加認可Tokenは現在選択されたProviderに応じて1系統だけを検証する。`NONE`ならTokenの存在自体を認可成立とは扱わない。未実装Adapterの構成はServerの起動時に拒否し、Clientの自己申告で変えない。
- `RespondFriendRequest.approve`など、**明示0/falseと省略が業務上異なるフィールドだけ**はProtoBufの`optional`のPresenceも確認する。その他のRPCの完全な値域について未提示のゲームルールを一括補完することはせず、実装に採用するAPIから個別の既存Payload制約を適用する。

### Item使用・保存の確定検証

- Public `UseItem`は認証済みPlayerIDと当該Battleの単一Owner・Join・RequestSequence・ItemID・Battle内数量1以上を必須とし、失敗では状態を変更しない。Client申告の残数は受け取らない。成功はWAL耐久保存後であり、DB減算の完了待ちはしない。
- Private `SaveGuildBattleItemLog`は`quantity_before >= 1`と`quantity_after=quantity_before-1`、Create Snapshotからの同一Player/Itemの先行Item Event連続性、Event番号・Operation ID・Event Hashの一致、DB在庫1以上を同一Transactionで検証する。同一Operationの再送は同じ結果のみ返し、別内容は409を返す。
- Private `UpdatePlayerItem`等、Battle Item Eventを介さない在庫書込みは対象Playerが`in_progress`または`resolving`の対戦に含まれる間は409を返す。予約APIは存在しない。

### 運用対象RPCの値域補足（汎用行に優先）

- Public `CreateAccount`/`Login`の`login_id`は既存Session仕様のASCII英数字・`.`・`_`・`-`、3～64文字を適用する。`Login.client_version`は非空、要求Version不一致は専用Version Errorを使用する。新しいパスワード文字種別・長さの上限は発明しない。
- Public `CreateGuild.guild_name`はUTF-8で空文字を拒否し最大10文字とする。昼夜の開始時刻は定義済みEnum値と`optional` Presenceの両方を確認する。`player_id=0`を通常Playerとして受理しない。
- Private `StartGuildBattle`は`game_server_instance_id`非空と`create_log`存在・正本Owner一致を必須とし、Item Snapshotを同じDB Transactionで現在在庫と照合する。Snapshot不一致は409、未存在Createログは400とする。
- Private `UpdatePlayerItem`はPlayerID・ItemIDの有効性に加え、PlayerID単位のTransaction排他・対戦状態確認を行い、対象Playerが進行中/結果確定待ちBattleのCreate Snapshotに含まれる場合は409とする。`quantity=0`は所持数を0へ更新する正当な値として扱い、これだけでは省略入力とは断定しない。

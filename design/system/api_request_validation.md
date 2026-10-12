# RPC入力フィールド検証契約

## 適用範囲

本表は`design/system/api_transport.md`のPublic/Private Allowlistに対応するRequest Messageの全フィールドを列挙する。Schemaのフィールド番号・型は対応する`.proto`を正本とする。
HTTP 400は構文/型/許容値の不正、401は認証不成立、403は権限違反、404は対象不在、409は現在状態と衝突する業務要求に使用する。`ApiErrorResponse.error_code`は該当する既存Enumで詳細化する。既定値`0`や`false`が正当な場合、省略と値を混同しない。

各表の「検証」は既存の`design/server/api_payload.md`・`design/shared/types.md`の個別制約より広い値域を許可する意味ではない。通常のProto3スカラーのPresenceを直接検知できない箇所は、既定値の業務上の妥当性で判定する。値0が正当でかつ入力時の明示が必要な開始時刻Enum、およびfalseが明示的な解除操作となる`locked`等は`optional`でPresenceを保持する。

## フィールド一覧

追加認可Tokenの必須性は`design/server/session.md`の`AdditionalAuthorizationProvider`を正本とする。`DISCORD`では従来Field 4、`POCKETBASE`ではField 5を用い、`NONE`では両者の省略を認める。検証Adapter未実装の方式は許可しない。

### Public `CreateAccount` — `CreateAccountRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `login_id` | `string`（1） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
| `password` | `string`（2） | 空文字禁止、長さ/形式は既存認証仕様 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:形式不正、401:認証不成立 |
| `user_name` | `string`（3） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
| `discord_authorization_token` | `string`（4） | `DISCORD`のとき必須。それ以外では省略可 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |
| `additional_authorization_token` | `string`（5） | `POCKETBASE`等の非Discord追加認可で必須、`NONE`では省略可 | 検証Adapterが検証したTokenのみ有効 | 401:認可不成立、400:形式不正 |

### Public `Login` — `LoginRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `login_id` | `string`（1） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
| `password` | `string`（2） | 空文字禁止、長さ/形式は既存認証仕様 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:形式不正、401:認証不成立 |
| `client_version` | `string`（3） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
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
| `guild_name` | `string`（3） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
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
| `client_version` | `string`（3） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
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
| `client_version` | `string`（3） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
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
| `login_id` | `string`（1） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
| `password` | `string`（2） | 空文字禁止、長さ/形式は既存認証仕様 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:形式不正、401:認証不成立 |
| `user_name` | `string`（3） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
| `discord_user_id` | `uint64`（4） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `discord_authorization_token_id` | `bytes`（5） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |

### Private `AuthenticateAccount` — `AuthenticateAccountRequest`

| Field | Wire型 | Presence/必須性 | 有効値/制限 | 不正時 |
|---|---|---|---|---|
| `login_id` | `string`（1） | 非空を要求する場合は空文字/空bytesを拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:型/長さ不正、401:認証失敗 |
| `password` | `string`（2） | 空文字禁止、長さ/形式は既存認証仕様 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 400:形式不正、401:認証不成立 |
| `discord_user_id` | `uint64`（3） | ID/Sequence/Amountの業務無効値を検証（0は用途に応じる） | 整数型範囲 + 予約値・既存Payload上下限 | 400:無効なID/範囲、409:状態競合 |
| `discord_authorization_token_id` | `bytes`（4） | 未設定の認証情報は拒否 | UTF-8/Token/Header/Sizeなど既存Payload制約 | 401:認証不正、400:形式不正 |

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

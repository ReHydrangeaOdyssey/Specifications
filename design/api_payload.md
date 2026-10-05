# APIPayload

## 共通

各項目の型は「[型定義](types.md)」を参照する.

`ArenaMode`は「[型定義](types.md)」を参照する.

### CharacterHP

| 項目 | 型 | 内容 |
|---|---|---|
| CharacterID | `CharacterID` | キャラクターID |
| CurrentHP | `HP` | 現在HP |

### BattleCharacterStatus

| 項目 | 型 | 内容 |
|---|---|---|
| CharacterID | `CharacterID` | キャラクターID |
| Position | `FormationSlotID` | 戦闘時の配置位置. フォーメーション内部番号を使用 |
| HP | `Float32` | 戦闘計算で使用する現在HP |
| Attack | `Float32` | 戦闘計算で使用する攻撃力 |
| Defense | `Float32` | 戦闘計算で使用する防御力 |
| SpeedRank | `SpeedRank` | 速度ランク |
| AbilityID | `AbilityID[2]` | アビリティID |
| MainSkillID | `SkillID` | 戦闘で使用するメインスキルID |

### TacticsEffectResult

| 項目 | 型 | 内容 |
|---|---|---|
| TacticsEffectID | `TacticsEffectID` | 適用したタクティクス効果種別 |
| Target | `TacticsTarget` | 効果対象 |
| EffectValue | `Float32` | 効果値 |

### FormationCharacterHP

| 項目 | 型 | 内容 |
|---|---|---|
| FormationSlotID | `FormationSlotID` | 編成ID |
| CurrentHP | `HP` | 現在HP |

固定長配列で未使用要素を表す場合は `FormationSlotID=255`, `CurrentHP=0` とする.

### ArenaPartyCharacter

| 項目 | 型 | 内容 |
|---|---|---|
| CharacterID | `CharacterID` | キャラクターID |
| Position | `FormationSlotID` | 配置位置. フォーメーション内部番号を使用 |
| FollowerCharacterID | `CharacterID[2]` | 従者のキャラクターID |
| AbilityID | `AbilityID[2]` | アビリティID |
| MainSkillID | `SkillID` | メインスキルID |

### GuildBattlePartyCharacter

| 項目 | 型 | 内容 |
|---|---|---|
| CharacterID | `CharacterID` | キャラクターID |
| PriorityPosition | `FormationSlotID` | 優先配置位置. フォーメーション内部番号を使用 |
| FollowerCharacterID | `CharacterID[2]` | 従者のキャラクターID |
| AbilityID | `AbilityID[2]` | アビリティID |
| MainSkillID | `SkillID` | メインスキルID |

`GuildBattlePartyCharacter[10]`の配列位置を編成スロットIDとして扱い, IDは`0`始まりとする.
未使用の`GuildBattlePartyCharacter`は, 全フィールドを各型の予約済み無効値にする. `CharacterID == u32::MAX`の場合, その`GuildBattlePartyCharacter`全体を無効要素として扱う.
`FollowerCharacterID[2]`および`AbilityID[2]`の空き要素は, それぞれ`CharacterID`および`AbilityID`の予約済み無効値`u32::MAX`で表現する.

`ArenaPartyCharacter`の`FollowerCharacterID[2]`および`AbilityID[2]`についても, 空き要素は同じ予約済み無効値を使用する.
`FollowerCharacterID[2]`はスロット0を「編成先キャラクターと同一レアリティ以下」, スロット1を「編成先キャラクターより低レアリティのみ」の従者枠として扱う.

### ApiErrorResponse

| 項目 | 型 | 内容 |
|---|---|---|
| ErrorCode | `ApiErrorCode` | PublicAPI共通エラーコード |

PublicAPIで失敗レスポンスが必要な場合は, 個別に別構造が定義されている場合を除き本構造を使用する.

## システム

### AccessTokenRequest

| 項目 | 型 | 内容 |
|---|---|---|
| DiscordUserID | `DiscordUserID` | Botが本人確認済みのDiscord User ID. AccessTokenの本人性Bindingに使用する |

### AccessTokenResponse

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 生成されたアクセストークン |

### CreatePlayerRequest

| 項目 | 型 | 内容 |
|---|---|---|
| UserName | `UserName` | ユーザー名 |
| AccessToken | `AccessToken` | 検証するアクセストークン |

### CreatePlayerResponse

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 新規生成されたPlayerID |

### LoginRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | ログイン対象PlayerID |
| AccessToken | `AccessToken` | ログインに使用するアクセストークン |

### LoginResponse

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | 生成されたセッションID |

### ValidateSessionPublicRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | 確認するSessionID |
| PlayerID | `PlayerID` | SessionIDの所有者として検証するPlayerID |

### ValidateSessionPublicResponse

| 項目 | 型 | 内容 |
|---|---|---|
| IsValid | `Bool` | 存在・期限・PlayerID所有関係のすべてが有効な場合true |

### CreateGuildRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | 騎士団を作成するプレイヤーID |
| GuildName | `Name` | 作成する騎士団名 |
| DaytimeStartTime | `GuildBattleStartTime` | 昼開始時刻.11:30 / 12:15 / 13:00のいずれか |
| NighttimeStartTime | `GuildBattleStartTime` | 夜開始時刻.21:00 / 22:00 / 23:00のいずれか |

### CreateGuildResponse

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID` | 作成された騎士団ID |

作成成功時, `PlayerID`は作成された`GuildID`へ所属する.

### JoinGuildRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | 所属を変更するプレイヤーID |
| GuildID | `GuildID` | 所属先騎士団ID |

### JoinGuildResponse

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID` | 所属後の騎士団ID |

### LeaveGuildRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | 脱退するプレイヤーID. 初期騎士団のGuildID特定にも使用する |

### LeaveGuildResponse

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID` | 脱退後に戻った初期騎士団ID. 値はPlayerIDと同一 |

## アリーナ

### UpdateArenaPartyRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| FormationID | `FormationID` | 使用するフォーメーションID |
| Characters | `ArenaPartyCharacter[]` | 編成キャラクター情報.1～5件 |

### UpdateArenaPartyResponse

- 登録完了とする.

### ArenaBattleRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| Mode | `ArenaMode` | 対戦モード |
| OpponentID | `PlayerID` | 対戦相手PlayerID. `Mode=friend` の場合に使用 |

### ArenaBattleResponse

GameServerが算出した勝敗・最終HP等の戦闘結果は返さない. ClientがGameServerと同一の戦闘ロジックを同一入力で実行するために必要な相手初期状態とSeedのみを返す.

| 項目 | 型 | 内容 |
|---|---|---|
| EnemyFormationID | `FormationID` | 戦闘開始時点の相手フォーメーションID |
| EnemyCharacters | `BattleCharacterStatus[]` | 戦闘開始時点の相手キャラクターステータス. 最大5件 |
| Seed | `Seed` | GameServerとClientが同じ戦闘を実行するために使用するシード値 |

### ArenaBattleErrorResponse

| 項目 | 型 | 内容 |
|---|---|---|
| ErrorCode | `ArenaBattleErrorCode` | アリーナ戦闘開始時のエラーコード |

## 騎士団戦

### UpdateGuildBattlePartyRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| FormationID | `FormationID` | 使用するフォーメーションID |
| Characters | `GuildBattlePartyCharacter[10]` | 編成キャラクター情報. 配列位置を0始まりの編成スロットIDとして使用 |

### UpdateGuildBattlePartyResponse

- 登録完了とする.

### JoinGuildBattleRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| GuildID | `GuildID` | 参加要求する騎士団ID |
| GuildBattleID | `GuildBattleID` | 参加対象の騎士団戦ID |

### GuildBattleJoinResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Characters | `FormationCharacterHP[10]` | 編成IDと現在HPの一覧 |
| RequestSequence | `RequestSequence` | 参加時に割り当てられたプレイヤー固有の要求シーケンス番号 |

### GetGuildBattleStatusRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| GuildBattleID | `GuildBattleID` | 対象騎士団戦ID |
| RequestSequence | `RequestSequence` | GameServerが当該PlayerIDについて現在保持している要求シーケンス番号と一致させる値 |

### GetGuildBattleStatusResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Characters | `FormationCharacterHP[10]` | 編成IDと現在HPの一覧 |
| NextRequestSequence | `RequestSequence` | 要求成功後の次要求シーケンス番号 |

### GuildBattleSortieRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| GuildBattleID | `GuildBattleID` | 対象騎士団戦ID |
| RequestSequence | `RequestSequence` | GameServerが当該PlayerIDについて現在保持している要求シーケンス番号と一致させる値 |
| SelectID | `FormationSlotID[5]` | 出撃する編成ID. 編成IDは`GuildBattlePartyCharacter[10]`の0始まり配列位置 |

`SelectID` は5件の固定長. 選択数が5件未満の場合, 未使用スロットには `FormationSlotID` の最大値`255`を格納する.

### GuildBattleCastleBreakResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Score | `Score` | キャッスルブレイクで取得したpt |
| Seed | `Seed` | 出撃で使用したシード値 |
| NextRequestSequence | `RequestSequence` | 要求成功後の次要求シーケンス番号 |

### GuildBattleAnnihilationResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Score | `Score` | 殲滅で取得したpt |
| EnemyCharacters | `BattleCharacterStatus[]` | 相手のキャラクターステータス. 最大5件 |
| Seed | `Seed` | 戦闘で使用したシード値 |
| EnemyTacticsID | `TacticsID[]` | 相手のタクティクスID. 可変長 |
| NextRequestSequence | `RequestSequence` | 要求成功後の次要求シーケンス番号 |

### UseTacticsRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| GuildBattleID | `GuildBattleID` | 対象騎士団戦ID |
| RequestSequence | `RequestSequence` | GameServerが当該PlayerIDについて現在保持している要求シーケンス番号と一致させる値 |
| TacticsID | `TacticsID` | 使用するタクティクスID |

### UseTacticsResponse

| 項目 | 型 | 内容 |
|---|---|---|
| TP | `TP` | 使用後の現在TP |
| RemainingCount | `Count` | 使用後の残り使用可能回数 |
| EffectCount | `Count` | 発生した効果数 |
| Effects | `TacticsEffectResult[]` | 発生した効果一覧 |
| NextRequestSequence | `RequestSequence` | 要求成功後の次要求シーケンス番号 |

### UseItemRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| GuildBattleID | `GuildBattleID` | 対象騎士団戦ID |
| RequestSequence | `RequestSequence` | GameServerが当該PlayerIDについて現在保持している要求シーケンス番号と一致させる値 |
| ItemID | `ItemID` | 使用するアイテムID |

### UseItemResponse

| 項目 | 型 | 内容 |
|---|---|---|
| BP | `BP` | 使用後の現在BP |
| RemainingCount | `Count` | 使用後の残り所持数 |
| NextRequestSequence | `RequestSequence` | 要求成功後の次要求シーケンス番号 |

### StartHealRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| GuildBattleID | `GuildBattleID` | 対象騎士団戦ID |
| RequestSequence | `RequestSequence` | GameServerが当該PlayerIDについて現在保持している要求シーケンス番号と一致させる値 |

### StartHealResponse

| 項目 | 型 | 内容 |
|---|---|---|
| WaitTime | `DurationSeconds` | 回復待機時間 |
| NextRequestSequence | `RequestSequence` | 要求成功後の次要求シーケンス番号 |

### CancelHealRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| GuildBattleID | `GuildBattleID` | 対象騎士団戦ID |
| RequestSequence | `RequestSequence` | GameServerが当該PlayerIDについて現在保持している要求シーケンス番号と一致させる値 |

### CancelHealResponse

| 項目 | 型 | 内容 |
|---|---|---|
| NextRequestSequence | `RequestSequence` | 要求成功後の次要求シーケンス番号 |

### CompleteHealRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| GuildBattleID | `GuildBattleID` | 対象騎士団戦ID |
| RequestSequence | `RequestSequence` | GameServerが当該PlayerIDについて現在保持している要求シーケンス番号と一致させる値 |

### CompleteHealResponse

| 項目 | 型 | 内容 |
|---|---|---|
| BP | `BP` | 回復後の現在BP |
| CharacterHP | `CharacterHP[]` | 回復後の編成キャラクターの現在HP |
| NextRequestSequence | `RequestSequence` | 要求成功後の次要求シーケンス番号 |

### StartReviveRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| GuildBattleID | `GuildBattleID` | 対象騎士団戦ID |
| RequestSequence | `RequestSequence` | GameServerが当該PlayerIDについて現在保持している要求シーケンス番号と一致させる値 |

### StartReviveResponse

| 項目 | 型 | 内容 |
|---|---|---|
| WaitTime | `DurationSeconds` | 復活待機時間 |
| NextRequestSequence | `RequestSequence` | 要求成功後の次要求シーケンス番号 |

`WaitTime` は5秒.

### CancelReviveRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| GuildBattleID | `GuildBattleID` | 対象騎士団戦ID |
| RequestSequence | `RequestSequence` | GameServerが当該PlayerIDについて現在保持している要求シーケンス番号と一致させる値 |

### CancelReviveResponse

| 項目 | 型 | 内容 |
|---|---|---|
| NextRequestSequence | `RequestSequence` | 要求成功後の次要求シーケンス番号 |

### CompleteReviveRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| GuildBattleID | `GuildBattleID` | 対象騎士団戦ID |
| RequestSequence | `RequestSequence` | GameServerが当該PlayerIDについて現在保持している要求シーケンス番号と一致させる値 |

### CompleteReviveResponse

| 項目 | 型 | 内容 |
|---|---|---|
| BP | `BP` | 復活後の現在BP |
| CharacterHP | `CharacterHP[]` | 復活後の編成キャラクターの現在HP |
| NextRequestSequence | `RequestSequence` | 要求成功後の次要求シーケンス番号 |

## PrivateAPI

### GetPlayerIDByDiscordUserIDRequest

| 項目 | 型 | 内容 |
|---|---|---|
| DiscordUserID | `DiscordUserID` | PlayerIDとの本人性Bindingを検索するDiscord User ID |

### GetPlayerIDByDiscordUserIDResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Exists | `Bool` | 対応するPlayerIDが存在する場合true |
| PlayerID | `PlayerID` | `Exists=true`の場合のPlayerID. `Exists=false`では予約値0 |

### CheckPlayerIDExistsRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 重複確認するPlayerID |

### CheckPlayerIDExistsResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Exists | `Bool` | 既に存在する場合true |

### SaveGuildRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID` | 保存する騎士団ID |
| GuildName | `Name` | 騎士団名 |
| LeaderPlayerID | `PlayerID` | 団長PlayerID |
| DaytimeStartTime | `GuildBattleStartTime` | 昼開始時刻.11:30 / 12:15 / 13:00のいずれか |
| NighttimeStartTime | `GuildBattleStartTime` | 夜開始時刻.21:00 / 22:00 / 23:00のいずれか |

### SetPlayerGuildRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 所属を更新するPlayerID |
| GuildID | `GuildID` | 所属先GuildID |


### SavePlayerIDRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 保存するPlayerID |
| DiscordUserID | `DiscordUserID` | PlayerIDの本人として永続的に結び付けるDiscord User ID |
| UserName | `UserName` | 保存するユーザー名 |

### SaveSessionIDRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | セッション所有PlayerID |
| SessionID | `SessionID` | 保存するSessionID |
| ExpiresAt | `SessionExpiresAt` | セッション有効期限 |

### SaveSessionIDErrorResponse

| 項目 | 型 | 内容 |
|---|---|---|
| ErrorCode | `SaveSessionIDErrorCode` | SessionID保存失敗理由. 現在定義される値は`SAVE_SESSION_ID_ERROR_SESSION_ID_CONFLICT` |

### GetActiveSessionRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 対象PlayerID |

### GetActiveSessionResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Exists | `Bool` | 有効なSessionが存在する場合true |
| SessionID | `SessionID` | `Exists=true`の場合の有効なSessionID. `Exists=false`の場合は参照しない |
| ExpiresAt | `SessionExpiresAt` | `Exists=true`の場合のセッション有効期限. `Exists=false`の場合は参照しない |

### InvalidateSessionRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | 無効化するSessionID |

### InvalidateSessionResponse

- 削除完了とする.

### ValidateSessionRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | 確認するSessionID |
| PlayerID | `PlayerID` | 所有関係を確認するPlayerID |

### ValidateSessionResponse

| 項目 | 型 | 内容 |
|---|---|---|
| IsValid | `Bool` | Sessionレコードが存在し, 有効期限内で, 指定PlayerIDの所有である場合true. それ以外はfalse |

### SaveArenaPartyRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 保存対象PlayerID |
| FormationID | `FormationID` | 使用するフォーメーションID |
| Characters | `ArenaPartyCharacter[]` | 編成キャラクター情報.1～5件 |

### GetArenaBattleDataRequest

| 項目 | 型 | 内容 |
|---|---|---|
| OpponentPlayerID | `PlayerID` | 対戦相手のPlayerID |

### GetArenaBattleDataResponse

| 項目 | 型 | 内容 |
|---|---|---|
| FormationID | `FormationID` | 対戦相手が使用するフォーメーションID |
| Characters | `ArenaPartyCharacter[]` | 対戦相手のキャラクター情報.1～5件 |

### SaveGuildBattlePartyRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 保存対象PlayerID |
| FormationID | `FormationID` | 使用するフォーメーションID |
| Characters | `GuildBattlePartyCharacter[10]` | 編成キャラクター情報 |

### CreateScheduledGuildBattlesRequest

| 項目 | 型 | 内容 |
|---|---|---|
| TargetDate | `DateTime` | 対象日. JSTの日付部分を使用する |
| StartTime | `GuildBattleStartTime` | 組み合わせを生成する固定開戦時刻 |

### CreateScheduledGuildBattlesResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Battles | `ScheduledGuildBattle[]` | 生成・保存した騎士団戦一覧 |

### ScheduledGuildBattle

| 項目 | 型 | 内容 |
|---|---|---|
| GuildBattleID | `GuildBattleID` | 騎士団戦ID |
| GuildID | `GuildID[2]` | 対戦する2騎士団のID |

### GetScheduledGuildsRequest

| 項目 | 型 | 内容 |
|---|---|---|
| TargetDate | `DateTime` | 対象日を表す日時. JSTの日付部分を使用する |
| StartTime | `GuildBattleStartTime` | 固定開戦時刻 |

### GetScheduledGuildsResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Battles | `ScheduledGuildBattle[]` | 指定時刻に開戦予定の騎士団戦一覧 |

### GetGuildBattleFormationRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 編成情報を取得するPlayerID |

### GetGuildBattleFormationResponse

| 項目 | 型 | 内容 |
|---|---|---|
| MaxBP | `BP` | 対象プレイヤーの最大BP. 騎士団戦開始時の現在BP初期値にも使用する |
| FormationID | `FormationID` | 使用するフォーメーションID |
| Characters | `GuildBattlePartyCharacter[10]` | 騎士団戦パーティ情報 |

### PlayerItemData

| 項目 | 型 | 内容 |
|---|---|---|
| ItemID | `ItemID` | アイテムID |
| Quantity | `Count` | 所持数 |

### GetPlayerItemsRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 対象プレイヤーID |

### GetPlayerItemsResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Items | `PlayerItemData[]` | 所持アイテム一覧 |

### UpdatePlayerItemRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 対象プレイヤーID |
| ItemID | `ItemID` | 更新対象アイテムID |
| Quantity | `Count` | 更新後の所持数 |

### GetAllPlayerIDsResponse

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID[]` | Databaseに存在する全PlayerID. PlayerID昇順で返す |

### GetGuildMembersRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID` | 対象騎士団ID |

### GetGuildMembersResponse

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID[]` | 所属プレイヤーID一覧. PlayerID昇順で返す |

### GuildLevelData

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID` | 騎士団ID |
| CastleLevel | `Count` | 城レベル |
| ArmoryLevel | `Count` | 武器庫レベル |
| FoodStorageLevel | `Count` | 食糧庫レベル |
| SmithyLevel | `Count` | 鍛冶屋レベル |
| StrategyOfficeLevel | `Count` | 兵法所レベル |
| TavernLevel | `Count` | 酒場レベル |

### GetGuildDataRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID` | 対象騎士団ID |

### GetGuildDataResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Guild | `GuildLevelData` | 騎士団レベル情報 |

### UpdateGuildBattleStatusRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GuildBattleID | `GuildBattleID` | 対象騎士団戦ID |
| Status | `GuildBattleStatus` | 更新後の状態 |

### GuildBattlePreloadPlayerData

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | プレイヤーID |
| MaxBP | `BP` | 最大BP |
| FormationID | `FormationID` | 騎士団戦フォーメーションID |
| Characters | `GuildBattlePartyCharacter[10]` | 騎士団戦編成 |
| Items | `PlayerItemData[]` | 所持アイテム一覧 |

### RetryGuildBattlePreloadRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GuildBattleID | `GuildBattleID` | 再取得対象の騎士団戦ID |
| PlayerID | `PlayerID[]` | GameServerが前回取得失敗として保持しているPlayerID一覧 |

### RetryGuildBattlePreloadResponse

| 項目 | 型 | 内容 |
|---|---|---|
| GuildBattleID | `GuildBattleID` | 対象騎士団戦ID |
| Players | `GuildBattlePreloadPlayerData[]` | 再取得に成功したプレイヤーのデータ. 再取得に失敗したPlayerIDは含めない |

このAPIはGameServerが保持する「開戦前データ取得失敗プレイヤー」の再取得に使用する. 利用可能期間は開戦前データ処理終了後から当該騎士団戦の開戦前までに限定する.

### SaveErrorLogRequest

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServerの受信時刻 |
| GuildBattleID | `GuildBattleID` | 騎士団戦に紐づく場合の騎士団戦ID |
| ErrorLog | `ErrorLogMessage` | 追記するエラーログ文字列 |

### UpdatePlayerGuildBattleRecordRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 更新対象PlayerID |
| Result | `GuildBattleResult` | 当該Playerの勝敗.drawの場合は更新しない |

### GuildBattleResultSaveRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GuildBattleID | `GuildBattleID` | 騎士団戦ID |
| GuildID | `GuildID` | 騎士団ID |
| Score | `Score` | 最終スコア |
| Result | `GuildBattleResult` | 勝敗結果 |


### GuildBattleReplayPlayerSnapshot

騎士団戦開始時点でGameServerの騎士団戦データとして保持するプレイヤーの可変データを保存する.

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | プレイヤーID |
| MaxBP | `BP` | 騎士団戦開始時点の最大BP. 開始時の現在BPはこの値と同じ |
| FormationID | `FormationID` | 開始時点の騎士団戦フォーメーションID |
| Characters | `GuildBattlePartyCharacter[10]` | 開始時点の騎士団戦編成 |
| Items | `PlayerItemData[]` | 開始時点の所持アイテム一覧 |

### GuildBattleReplayGuildSnapshot

| 項目 | 型 | 内容 |
|---|---|---|
| Guild | `GuildLevelData` | 開始時点の騎士団レベル情報 |
| MemberPlayerID | `PlayerID[]` | 開始時点の所属メンバー一覧 |
| Participants | `GuildBattleReplayPlayerSnapshot[]` | 開始時点でGameServerの騎士団戦データとして保持するプレイヤーのスナップショット |

`MemberPlayerID`には所属メンバー全員を保存する. 開戦前データ取得に失敗したPlayerIDは騎士団への所属・参加資格から除外せず, 当該騎士団戦でGameServerが保持する騎士団戦データからのみ除外する. `Participants`には開戦時点でGameServerの騎士団戦データとして保持できたプレイヤーのみを保存する.

### GuildBattleInitialSnapshot

| 項目 | 型 | 内容 |
|---|---|---|
| Guilds | `GuildBattleReplayGuildSnapshot[2]` | 対戦する2騎士団の開戦時スナップショット |

マスターデータそのものはスナップショットへ重複保存せず, `Version`で対象リプレイに使用する同一マスターデータとゲームロジックを特定する.

### GuildBattleCreateLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServer受信時刻 |
| GuildBattleID | `GuildBattleID` | ログ対象の騎士団戦ID |
| ProcessType | `GuildBattleReplayProcessType` | 処理の種類. `create` |
| InitialSeed | `Seed` | 騎士団戦の初期シード |
| GuildID | `GuildID[2]` | 対戦する2騎士団のID |
| InitialSnapshot | `GuildBattleInitialSnapshot` | 開戦時点の騎士団レベル, 所属メンバー, 参加者の最大BP・編成・所持アイテム等の初期状態 |
| Version | `Version` | リプレイに使用するマスターデータおよびゲームロジックのバージョン |

### GuildBattleSortieLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServer受信時刻 |
| GuildBattleID | `GuildBattleID` | ログ対象の騎士団戦ID |
| ProcessType | `GuildBattleReplayProcessType` | 処理の種類. `sortie` |
| Sequence | `Sequence` | 出撃時のシーケンス番号 |
| PlayerID | `PlayerID` | 出撃したPlayerID |
| SelectID | `FormationSlotID[5]` | 出撃時に選択した編成ID. 未使用スロットは`255` |

### GuildBattleTacticsLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServer受信時刻 |
| GuildBattleID | `GuildBattleID` | ログ対象の騎士団戦ID |
| ProcessType | `GuildBattleReplayProcessType` | 処理の種類. `tactics` |
| PlayerID | `PlayerID` | 使用したPlayerID |
| TacticsID | `TacticsID` | 使用したタクティクスID |

### GuildBattleItemLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServer受信時刻 |
| GuildBattleID | `GuildBattleID` | ログ対象の騎士団戦ID |
| ProcessType | `GuildBattleReplayProcessType` | 処理の種類. `item` |
| PlayerID | `PlayerID` | 使用したPlayerID |
| ItemID | `ItemID` | 使用したアイテムID |

### GuildBattleHealLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServer受信時刻 |
| GuildBattleID | `GuildBattleID` | ログ対象の騎士団戦ID |
| ProcessType | `GuildBattleReplayProcessType` | 処理の種類. `heal` |
| PlayerID | `PlayerID` | 対象PlayerID |
| HealState | `HealState` | 回復状態 |

### GuildBattleReviveLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServer受信時刻 |
| GuildBattleID | `GuildBattleID` | ログ対象の騎士団戦ID |
| ProcessType | `GuildBattleReplayProcessType` | 処理の種類. `revive` |
| PlayerID | `PlayerID` | 対象PlayerID |
| ReviveState | `ReviveState` | 復活状態 |


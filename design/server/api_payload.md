# APIPayload

## 共通

各項目の型は「[型定義](../shared/types.md)」を参照する.
Public APIのProtocol Buffers field numberおよびwire schemaは「[public_api.proto](../system/public_api.proto)」を正とする. 本書は各Payloadの意味・固定長・利用条件を正とし, `.proto`と不一致がある場合は意味・制約を本書で確認した上でfield number/wire型を`.proto`へ合わせる.

Public APIで内部`Float32`の現在HPを論理型`HP`（`uint32`）として返す場合は, 小数点以下を切り捨ててから変換する. HPはゲーム処理側で0以上へクランプした値を使用する.

`ArenaMode`は「[型定義](../shared/types.md)」を参照する.

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

### TacticsStatEffectResult

| 項目 | 型 | 内容 |
|---|---|---|
| Attack | `Float32` | 攻撃に対する効果値 |
| Defense | `Float32` | 防御に対する効果値 |
| Speed | `Float32` | 速度に対する効果値 |

### TacticsHpRecoveryEffectResult

| 項目 | 型 | 内容 |
|---|---|---|
| RecoveryType | `TacticsHpRecoveryType` | HP回復方式 |
| RecoveryRate | `Float32` | 対象最大HPに対する回復割合. HP0全回復型では1.0 |

### TacticsBattleSpecialEffectResult

| 項目 | 型 | 内容 |
|---|---|---|
| SpecialType | `TacticsBattleSpecialType` | 戦闘時特殊効果系列 |
| Parameters | `TacticsBattleSpecialParameters` | SpecialTypeの具体効果で使用する攻撃, 防御, 速度, スキル発動率, 最大TP, スコア, CB, ヘイト, 城Lv, BP/TP回復等の数値パラメータ |
| Trigger | `TacticsBattleSpecialTrigger` | 特殊効果の発動条件 |

Battle Specialの効果対象は外側の`TacticsEffectResult.Target`（`TacticsTarget`）を使用し, Battle Special専用のTargetフィールドは持たない.

### TacticsEffectResultData

`TacticsEffectResultData`は`TacticsEffectID`に応じて以下のいずれか1つを保持する共有体とする. Protocol Buffersで定義する際は`oneof`として表現する.

| 共有体フィールド | 型 | 使用対象 |
|---|---|---|
| ScalarValue | `Float32` | 浮動小数点のスカラー値で表現する効果 |
| UintValue | `Count` | `u32`の整数値で表現する効果. `TACTICS_EFFECT_BP_RECOVERY`で使用 |
| StatusEffect | `TacticsStatEffectResult` | 攻撃・防御・速度のステータス補正結果 |
| HpRecovery | `TacticsHpRecoveryEffectResult` | `TACTICS_EFFECT_HP_RECOVERY` |
| BattleSpecial | `TacticsBattleSpecialEffectResult` | `TACTICS_EFFECT_BATTLE_SPECIAL` |

`TACTICS_EFFECT_ATTACK_CORRECTION`, `TACTICS_EFFECT_DEFENSE_CORRECTION`, `TACTICS_EFFECT_SPEED_CORRECTION`では`StatusEffect`を使用し, 対象となるフィールドへ効果値を設定する. 対象外フィールドは0とする.
`TACTICS_EFFECT_BATTLE_SPECIAL`では`BattleSpecial`を使用し, `TacticsBattleSpecialParameters`の各数値効果を`BattleSpecial.Parameters`へまとめて返す. `special_type`固有の真偽型挙動は`SpecialType`から判定する.
`TACTICS_EFFECT_BP_RECOVERY`では`UintValue`を使用する.
それ以外で浮動小数点の単一値として表現できる効果は`ScalarValue`を使用する.

### TacticsEffectResult

| 項目 | 型 | 内容 |
|---|---|---|
| TacticsEffectID | `TacticsEffectID` | 適用したタクティクス効果種別 |
| Target | `TacticsTarget` | 効果対象 |
| EffectData | `TacticsEffectResultData` | 効果種別に応じた共有体の効果値 |

### FormationCharacterHP

| 項目 | 型 | 内容 |
|---|---|---|
| FormationSlotID | `FormationSlotID` | 編成ID |
| CurrentHP | `HP` | 現在HP |

固定長配列で未使用要素を表す場合は `FormationSlotID=255`, `CurrentHP=0` とする.

### GuildBattleTacticsStatus

| 項目 | 型 | 内容 |
|---|---|---|
| TacticsID | `TacticsID` | 使用可能なタクティクスID |
| RemainingUseCount | `Count` | 残り使用可能回数 |

### GuildBattleItemStatus

| 項目 | 型 | 内容 |
|---|---|---|
| ItemID | `ItemID` | 所持アイテムID |
| RemainingCount | `Count` | 現在の残り所持数 |

### GuildBattleCbcStatus

| 項目 | 型 | 内容 |
|---|---|---|
| IsActive | `Bool` | キャッスルブレイクチャンス中の場合true |
| InitiatorGuildID | `GuildID` | CBCを発生させた騎士団ID. 非CBC時は`0` |
| RemainingTime | `DurationSeconds` | CBC残り時間. 非CBC時は0 |
| RemainingCount | `Count` | CBC残りカウント. 非CBC時は0 |

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

### AuthenticatedContext

`AuthenticatedContext`はPublic API ServerがAccessToken検証成功後に生成する内部用データとする. Clientから受信しない.

| 項目 | 型 | 内容 |
|---|---|---|
| AccountID | `AccountID` | AccessTokenの`sub`から取得した認証アカウントID |
| PlayerID | `PlayerID` | AccessTokenの`player_id`から取得したプレイヤーID |
| SessionID | `SessionID` | AccessTokenの`sid`から取得したRefresh Session ID |

### ApiErrorResponse

| 項目 | 型 | 内容 |
|---|---|---|
| ErrorCode | `ApiErrorCode` | PublicAPI共通エラーコード |

PublicAPIで失敗レスポンスが必要な場合は, 個別に別構造が定義されている場合を除き本構造を使用する.

### RequiredOperationErrorResponse

Account作成後の初期騎士団作成等, 必須の後続処理を1回再実行しても完了できない場合に使用する.

| 項目 | 型 | 内容 |
|---|---|---|
| ErrorCode | `ApiErrorCode` | `API_ERROR_REQUIRED_OPERATION_FAILED` |
| Message | `String` | 固定文字列`必要な処理が実行できませんでした` |


## システム

### CreateAccountRequest

| 項目 | 型 | 内容 |
|---|---|---|
| LoginID | `LoginID` | ログイン認証に使用するユーザーID |
| Password | `Password` | ログイン認証に使用するPassword |
| UserName | `UserName` | ゲーム内表示用ユーザー名 |
| DiscordAuthorizationToken | `DiscordAuthorizationToken` | `DiscordAuthorizationRequired=true`の場合に必須. 無効な構成では空文字とし検証しない |

### CreateAccountResponse

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 新規生成されたPlayerID |

### LoginRequest

| 項目 | 型 | 内容 |
|---|---|---|
| LoginID | `LoginID` | ログイン認証に使用するユーザーID |
| Password | `Password` | ログイン認証に使用するPassword |
| ClientVersion | `Version` | Clientが使用しているゲームロジックおよびマスターデータのVersion |
| DiscordAuthorizationToken | `DiscordAuthorizationToken` | `DiscordAuthorizationRequired=true`の場合に必須. 無効な構成では空文字とし検証しない |

### LoginResponse

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | ログインしたAccountに結び付くPlayerID |
| AccessToken | `AccessToken` | 通常PublicAPIの認証に使用する5分有効の署名付きToken |

RefreshTokenはResponse Bodyへ含めず, Public API Serverが`__Host-RefreshToken` HttpOnly Cookieとして設定する.

### LoginVersionErrorResponse

| 項目 | 型 | 内容 |
|---|---|---|
| ErrorCode | `ApiErrorCode` | `API_ERROR_CLIENT_VERSION_MISMATCH` |
| RequiredVersion | `Version` | Public API Serverが要求するVersion. ClientはこのVersionへの更新をユーザーへ促す |

### ClientVersionMismatchResponse

アリーナ対戦開始・騎士団戦参加時にClientVersionと対象GameServerのVersionが一致しない場合に使用する.

| 項目 | 型 | 内容 |
|---|---|---|
| ErrorCode | `ApiErrorCode` | `API_ERROR_CLIENT_VERSION_MISMATCH` |
| RequiredVersion | `Version` | 対象GameServerが使用するVersion. ClientはこのVersionへの更新をユーザーへ促す |

### RefreshAccessTokenRequest

- Request Bodyは空とする.
- RefreshTokenは`__Host-RefreshToken` HttpOnly Cookieから取得する.

### RefreshAccessTokenResponse

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 新しく発行されたAccessToken |

Rotation後RefreshTokenはResponse Bodyへ含めず, Public API Serverが`__Host-RefreshToken` HttpOnly Cookieを更新する.

### LogoutRequest

- Request Bodyは空とする.
- RefreshTokenは`__Host-RefreshToken` HttpOnly Cookieから取得する.

### LogoutResponse

- Logout完了とする.

### CreateGuildRequest

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
| PlayerID | `PlayerID` | 騎士団を作成するプレイヤーID |
| GuildName | `Name` | 作成する騎士団名. UTF-8, 最大10文字, 空文字不可, 重複可 |
| DaytimeStartTime | `GuildBattleStartTime` | 昼開始時刻.11:30 / 12:15 / 13:00のいずれか |
| NighttimeStartTime | `GuildBattleStartTime` | 夜開始時刻.21:00 / 22:00 / 23:00のいずれか |

### CreateGuildResponse

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID` | 作成された騎士団ID |

作成成功時, `PlayerID`は作成された`GuildID`へ所属する.

### ApplyGuildJoinRequest

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
| PlayerID | `PlayerID` | 加入申請を送るPlayerID |
| GuildID | `GuildID` | 加入申請先GuildID |

### ApplyGuildJoinResponse

- 加入申請登録完了とする.

### ApproveGuildJoinApplicationRequest

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
| PlayerID | `PlayerID` | 加入申請の承認を行うPlayerID |
| GuildID | `GuildID` | 加入申請先GuildID |
| ApplicantPlayerID | `PlayerID` | 承認する加入申請のPlayerID |

### ApproveGuildJoinApplicationResponse

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID` | 加入成立後のGuildID |
| JoinedPlayerID | `PlayerID` | 加入したPlayerID |

### SendGuildInvitationRequest

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
| PlayerID | `PlayerID` | 招待を送る団長または副団長PlayerID |
| GuildID | `GuildID` | 招待元GuildID |
| InviteePlayerID | `PlayerID` | 招待対象PlayerID |

### SendGuildInvitationResponse

- 招待登録完了とする.

### AcceptGuildInvitationRequest

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
| PlayerID | `PlayerID` | 招待を承諾するPlayerID |
| GuildID | `GuildID` | 招待元GuildID |

### AcceptGuildInvitationResponse

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID` | 加入成立後のGuildID |

### LeaveGuildRequest

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
| PlayerID | `PlayerID` | 脱退するプレイヤーID. 初期騎士団のGuildID特定にも使用する |

### LeaveGuildResponse

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID` | 脱退後に戻った初期騎士団ID. 値はPlayerIDと同一 |

### UpdateGuildLeadershipRequest

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
| PlayerID | `PlayerID` | 変更要求を行うプレイヤーID |
| GuildID | `GuildID` | 役職を変更する騎士団ID |
| LeaderPlayerID | `PlayerID` | 変更後の団長PlayerID |
| SubleaderPlayerID | `PlayerID` | 変更後の副団長PlayerID. `0`は副団長未設定を表す |

### UpdateGuildLeadershipResponse

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID` | 役職変更対象の騎士団ID |
| LeaderPlayerID | `PlayerID` | 変更後の団長PlayerID |
| SubleaderPlayerID | `PlayerID` | 変更後の副団長PlayerID |

## アリーナ

### UpdateArenaPartyRequest

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
| PlayerID | `PlayerID` | プレイヤーID |
| FormationID | `FormationID` | 使用するフォーメーションID |
| Characters | `ArenaPartyCharacter[]` | 編成キャラクター情報.1～5件 |

### UpdateArenaPartyResponse

- 登録完了とする.

### ArenaBattleRequest

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
| PlayerID | `PlayerID` | プレイヤーID |
| ClientVersion | `Version` | Clientが現在使用しているゲームロジック・マスターデータVersion. GameServer自身のVersionと一致必須 |
| Mode | `ArenaMode` | 対戦モード |
| OpponentID | `PlayerID` | 対戦相手PlayerID. `Mode=friend` の場合に使用 |
| LocalFormationID | `FormationID` | Clientがローカル保存している自分側Arena編成のFormationID |
| LocalCharacters | `ArenaPartyCharacter[]` | Clientがローカル保存している自分側Arena編成.1～5件 |

### ArenaBattleResponse

GameServerが算出した勝敗・最終HP等の戦闘結果は返さない. ClientがGameServerと同一の戦闘ロジックを同一入力で実行するために必要な相手初期状態とSeedのみを返す.

| 項目 | 型 | 内容 |
|---|---|---|
| OwnPartyMatched | `Bool` | Client送信のローカル編成とDatabase上の自分側ArenaPartyが完全一致する場合true |
| OwnFormationID | `FormationID` | Database上の自分側FormationID. `OwnPartyMatched=false`の場合はClientが本値でローカル編成を更新して使用する |
| OwnCharacters | `ArenaPartyCharacter[]` | Database上の自分側ArenaParty. `OwnPartyMatched=false`の場合はClientが本値でローカル編成を更新して使用する |
| EnemyFormationID | `FormationID` | 戦闘開始時点の相手フォーメーションID |
| EnemyCharacters | `BattleCharacterStatus[]` | 戦闘開始時点の相手キャラクターステータス. 最大5件 |
| Seed | `Seed` | GameServerとClientが同じ戦闘を実行するために使用するシード値 |

### ArenaBattleErrorResponse

| 項目 | 型 | 内容 |
|---|---|---|
| ErrorCode | `ArenaBattleErrorCode` | アリーナ戦闘開始時のエラーコード. 要求元ArenaParty未登録も区別する |

## 騎士団戦

### UpdateGuildBattlePartyRequest

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
| PlayerID | `PlayerID` | プレイヤーID |
| FormationID | `FormationID` | 使用するフォーメーションID |
| Characters | `GuildBattlePartyCharacter[10]` | 編成キャラクター情報. 配列位置を0始まりの編成スロットIDとして使用 |

### UpdateGuildBattlePartyResponse

- 登録完了とする.

### JoinGuildBattleRequest

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
| PlayerID | `PlayerID` | プレイヤーID |
| ClientVersion | `Version` | Clientが現在使用しているゲームロジック・マスターデータVersion. 所有GameServerのVersionと一致必須 |
| GuildID | `GuildID` | 参加要求する騎士団ID |
| GuildBattleID | `GuildBattleID` | 参加対象の騎士団戦ID |
| LocalFormationID | `FormationID` | Clientがローカル保存している騎士団戦編成のFormationID |
| LocalCharacters | `GuildBattlePartyCharacter[10]` | Clientがローカル保存している騎士団戦編成 |

### GuildBattleJoinResponse

| 項目 | 型 | 内容 |
|---|---|---|
| PartyMatched | `Bool` | Client送信のローカル編成とGameServerがPreload済みのServer編成が完全一致する場合true |
| ServerFormationID | `FormationID` | GameServerが保持する騎士団戦FormationID. `PartyMatched=false`の場合はClientが本値でローカル編成を更新する |
| ServerCharacters | `GuildBattlePartyCharacter[10]` | GameServerが保持する騎士団戦編成. `PartyMatched=false`の場合はClientが本値でローカル編成を更新する |
| Characters | `FormationCharacterHP[10]` | Server編成の編成IDと現在HPの一覧 |
| RequestSequence | `RequestSequence` | 参加時に割り当てられたプレイヤー固有の要求シーケンス番号 |

### GetGuildBattleStatusRequest

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
| PlayerID | `PlayerID` | プレイヤーID |
| GuildBattleID | `GuildBattleID` | 対象騎士団戦ID |

`GetGuildBattleStatus`は再接続時の動的状態復元に使用するため`RequestSequence`を要求しない. CharacterID, Follower, MainSkill, Ability, FormationID等の静的な編成構成はClientがローカル保持した情報から復元し, 本APIでは再取得しない.

### GetGuildBattleStatusResponse

本Responseは動的状態だけを返す. CharacterID, Follower, MainSkill, Ability, FormationID等の静的編成構成はClientがローカル保持した値を使用する.


| 項目 | 型 | 内容 |
|---|---|---|
| Characters | `FormationCharacterHP[10]` | 編成IDと現在HPの一覧 |
| BP | `BP` | 現在BP |
| MaxBP | `BP` | 最大BP |
| TP | `TP` | 現在TP |
| MaxTP | `TP` | 現在の最大TP |
| HealState | `HealState` | 現在の治療状態 |
| HealRemainingTime | `DurationSeconds` | 治療中の残り待機時間. 治療中以外は0 |
| ReviveState | `ReviveState` | 現在の復活状態 |
| ReviveRemainingTime | `DurationSeconds` | 復活中の残り待機時間. 復活中以外は0 |
| SortieWaitRemainingTime | `DurationSeconds` | 出撃待機タイマーの残り時間 |
| Tactics | `GuildBattleTacticsStatus[]` | 使用可能タクティクスと残り使用回数 |
| ActiveTacticsEffects | `TacticsActiveEffectState[]` | 現在有効な継続タクティクス効果 |
| Items | `GuildBattleItemStatus[]` | 所持アイテムと現在個数 |
| AllyScore | `Score` | 所属騎士団の現在スコア |
| EnemyScore | `Score` | 相手騎士団の現在スコア |
| Chain | `Count` | 現在のチェイン数 |
| CbcStatus | `GuildBattleCbcStatus` | 現在のキャッスルブレイクチャンス状態 |
| RequestSequence | `RequestSequence` | GameServerが現在保持する要求シーケンス番号. 状態取得では加算しない |

### GuildBattleSortieRequest

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
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
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
| PlayerID | `PlayerID` | プレイヤーID |
| GuildBattleID | `GuildBattleID` | 対象騎士団戦ID |
| RequestSequence | `RequestSequence` | GameServerが当該PlayerIDについて現在保持している要求シーケンス番号と一致させる値 |
| TacticsID | `TacticsID` | 使用するタクティクスID |

### UseTacticsResponse

| 項目 | 型 | 内容 |
|---|---|---|
| TP | `TP` | 使用後の現在TP |
| RemainingCount | `Count` | 使用後の残り使用可能回数 |
| Effects | `TacticsEffectResult[]` | 発生した効果一覧. 効果数はこの配列長から判定する |
| NextRequestSequence | `RequestSequence` | 要求成功後の次要求シーケンス番号 |
| Seed | `Seed` | ランダム要素を持つタクティクスの固有疑似乱数生成器を再現するSeed. ランダム要素を使用しない場合は0 |

### UseItemRequest

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
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
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
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
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
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
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
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
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
| PlayerID | `PlayerID` | プレイヤーID |
| GuildBattleID | `GuildBattleID` | 対象騎士団戦ID |
| RequestSequence | `RequestSequence` | GameServerが当該PlayerIDについて現在保持している要求シーケンス番号と一致させる値 |

### StartReviveResponse

| 項目 | 型 | 内容 |
|---|---|---|
| WaitTime | `DurationSeconds` | 復活待機時間 |
| NextRequestSequence | `RequestSequence` | 要求成功後の次要求シーケンス番号 |

`WaitTime`は「[パーティランク](../../specification/game/party_rank.md)」で算出したパーティランクに対応する復活待機時間とする.

### CancelReviveRequest

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
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
| AccessToken | `AccessToken` | 認証に使用するAccessToken |
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

### CreateAccountPrivateRequest

| 項目 | 型 | 内容 |
|---|---|---|
| LoginID | `LoginID` | 新規作成するLoginID |
| Password | `Password` | Argon2idでHash化して保存するPassword |
| UserName | `UserName` | 新規Playerのゲーム内表示名 |
| DiscordUserID | `DiscordUserID` | `DiscordAuthorizationRequired=true`の場合は検証済みTokenの`sub`. 無効な構成では`0` |
| DiscordAuthorizationTokenID | `DiscordAuthorizationTokenID` | `DiscordAuthorizationRequired=true`の場合は検証済みTokenの`jti`. 無効な構成では予約済み無効値 |

### CreateAccountPrivateResponse

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 新規生成されたPlayerID |

### AuthenticateAccountRequest

| 項目 | 型 | 内容 |
|---|---|---|
| LoginID | `LoginID` | 認証対象LoginID |
| Password | `Password` | 検証するPassword |
| DiscordUserID | `DiscordUserID` | `DiscordAuthorizationRequired=true`の場合は検証済みTokenの`sub`. 無効な構成では`0` |
| DiscordAuthorizationTokenID | `DiscordAuthorizationTokenID` | `DiscordAuthorizationRequired=true`の場合は検証済みTokenの`jti`. 無効な構成では予約済み無効値 |

### AuthenticateAccountResponse

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 認証したAccountに結び付くPlayerID |
| AccessToken | `AccessToken` | 新しく発行したAccessToken |
| RefreshToken | `RefreshToken` | 新しく発行したRefreshToken |

### RefreshAccessTokenPrivateRequest

| 項目 | 型 | 内容 |
|---|---|---|
| RefreshToken | `RefreshToken` | 更新対象RefreshToken |

### RefreshAccessTokenPrivateResponse

| 項目 | 型 | 内容 |
|---|---|---|
| AccessToken | `AccessToken` | 新しく発行したAccessToken |
| RefreshToken | `RefreshToken` | Rotation後の新しいRefreshToken |

### LogoutPrivateRequest

| 項目 | 型 | 内容 |
|---|---|---|
| RefreshToken | `RefreshToken` | 無効化対象RefreshToken |

### LogoutPrivateResponse

- Logout完了とする.

### ValidateAccountSessionRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | 有効性を確認するRefresh Session ID |

### ValidateAccountSessionResponse

| 項目 | 型 | 内容 |
|---|---|---|
| IsValid | `Bool` | Sessionが存在し24時間の期限内である場合true |

### RevokeDiscordSessionsRequest

| 項目 | 型 | 内容 |
|---|---|---|
| DiscordUserID | `DiscordUserID` | 必要Roleを保持しなくなったDiscordUserID |

### RevokeDiscordSessionsResponse

- 対象DiscordUserIDにBindingされたAccountのRefresh Session失効完了とする.

### SaveGuildRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID` | 保存する騎士団ID |
| GuildName | `Name` | 騎士団名. UTF-8, 最大10文字, 空文字不可, 重複可 |
| LeaderPlayerID | `PlayerID` | 団長PlayerID. 初期騎士団作成時はDatabase側で副団長PlayerIDを0へ初期化する |
| DaytimeStartTime | `GuildBattleStartTime` | 昼開始時刻.11:30 / 12:15 / 13:00のいずれか |
| NighttimeStartTime | `GuildBattleStartTime` | 夜開始時刻.21:00 / 22:00 / 23:00のいずれか |

### SaveGuildJoinApplicationRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 申請PlayerID |
| GuildID | `GuildID` | 申請先GuildID |

### ApproveGuildJoinApplicationPrivateRequest

| 項目 | 型 | 内容 |
|---|---|---|
| RequesterPlayerID | `PlayerID` | 承認を行うPlayerID |
| GuildID | `GuildID` | 申請先GuildID |
| ApplicantPlayerID | `PlayerID` | 加入させる申請PlayerID |

### SaveGuildInvitationRequest

| 項目 | 型 | 内容 |
|---|---|---|
| RequesterPlayerID | `PlayerID` | 招待を送るPlayerID |
| GuildID | `GuildID` | 招待元GuildID |
| InviteePlayerID | `PlayerID` | 招待対象PlayerID |

### AcceptGuildInvitationPrivateRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 招待を承諾するPlayerID |
| GuildID | `GuildID` | 招待元GuildID |

### LeaveGuildPrivateRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 脱退するPlayerID |

### LeaveGuildPrivateResponse

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID` | 脱退Playerが所属した初期GuildID |
| SwappedPlayerID | `PlayerID` | 所属スワップを行った場合の相手PlayerID. スワップなしは0 |
| SwappedPlayerGuildID | `GuildID` | スワップ相手の新しい所属GuildID. スワップなしは0 |

### SaveGuildLeadershipRequest

| 項目 | 型 | 内容 |
|---|---|---|
| RequesterPlayerID | `PlayerID` | 役職変更を要求したPlayerID. 現在の団長であることをPrivate APIで検証する |
| GuildID | `GuildID` | 更新対象の騎士団ID |
| LeaderPlayerID | `PlayerID` | 保存する団長PlayerID. 対象Guild所属Playerのみ指定可能 |
| SubleaderPlayerID | `PlayerID` | 保存する副団長PlayerID. `0`は未設定. `0`以外は対象Guild所属Playerのみ指定可能かつLeaderPlayerIDと同一値不可 |

### SetGuildMembershipLockRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID[]` | 所属変更禁止状態を更新する騎士団ID一覧 |
| Locked | `Bool` | `true`で所属変更禁止, `false`で解除 |

### SetGuildMembershipLockResponse

- 指定Guildの`GUILD.membership_locked`更新完了とする.

### SaveArenaPartyRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 保存対象PlayerID |
| FormationID | `FormationID` | 使用するフォーメーションID |
| Characters | `ArenaPartyCharacter[]` | 編成キャラクター情報.1～5件 |

### GetArenaBattleDataRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | アリーナ戦闘用データを取得するPlayerID |

### GetArenaBattleDataResponse

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerExists | `Bool` | 対象PlayerIDがDatabaseに存在する場合true |
| ArenaPartyRegistered | `Bool` | 対象PlayerIDにArenaPartyが登録されている場合true |
| FormationID | `FormationID` | `PlayerExists=true`かつ`ArenaPartyRegistered=true`の場合のフォーメーションID |
| Characters | `ArenaPartyCharacter[]` | `PlayerExists=true`かつ`ArenaPartyRegistered=true`の場合のキャラクター情報.1～5件 |

### AssignScheduledGuildBattlesRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GameServerInstanceID | `GameServerInstanceID` | GuildBattleCoordinatorが割当先として選択したGameServer Instance ID |
| GuildBattleID | `GuildBattleID[]` | 対象GameServerへ割り当てる`scheduled`かつ未割当の騎士団戦ID一覧. 件数は対象GameServerの`AvailableGuildBattleCount`以下とする |

### AssignScheduledGuildBattlesResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Battles | `ScheduledGuildBattle[]` | 条件一致により指定GameServerへ原子的に割り当てられた騎士団戦一覧 |

### ReleaseScheduledGuildBattleAssignmentsRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GameServerInstanceID | `GameServerInstanceID` | 割当解除対象として確認する現在のGameServer Instance ID |
| GuildBattleID | `GuildBattleID[]` | 割当解除を要求する`scheduled`騎士団戦ID一覧 |

### ReleaseScheduledGuildBattleAssignmentsResponse

| 項目 | 型 | 内容 |
|---|---|---|
| ReleasedGuildBattleID | `GuildBattleID[]` | 条件一致により実際に未割当へ戻した騎士団戦ID一覧 |

### GetGameServerCapacityRequest

- 要求データなし.

### GetGameServerCapacityResponse

| 項目 | 型 | 内容 |
|---|---|---|
| GameServerInstanceID | `GameServerInstanceID` | 応答したGameServer Instance ID |
| AcceptNewGuildBattle | `Bool` | 新しい騎士団戦を割当可能な場合true. `draining`ではfalse |
| OwnedGuildBattleCount | `Count` | 現在所有している未完了騎士団戦数 |
| AvailableGuildBattleCount | `Count` | 現在追加で割当可能な騎士団戦数. `AcceptNewGuildBattle=false`の場合0 |
| AvailableGuildBattleThreadCount | `Count` | 現在1件も騎士団戦を担当していない騎士団戦専用スレッド数 |

### StartGuildBattlePreloadRequest

| 項目 | 型 | 内容 |
|---|---|---|
| Battles | `ScheduledGuildBattle[]` | GuildBattleCoordinatorが当該GameServerへ割当済みとしてPreload開始を要求する騎士団戦一覧 |

### StartGuildBattlePreloadResponse

| 項目 | 型 | 内容 |
|---|---|---|
| AcceptedGuildBattleID | `GuildBattleID[]` | 自身への割当を確認し, 新規Preload対象または既存Preload対象として受理した騎士団戦ID一覧 |

### GetGuildBattleAssignmentRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GuildBattleID | `GuildBattleID` | 所有GameServerを取得する騎士団戦ID |

### GetGuildBattleAssignmentResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Exists | `Bool` | GameServer割当が存在する場合true |
| GameServerInstanceID | `GameServerInstanceID` | `Exists=true`の場合の所有GameServer Instance ID |

### SaveGuildBattlePartyRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 保存対象PlayerID |
| FormationID | `FormationID` | 使用するフォーメーションID |
| Characters | `GuildBattlePartyCharacter[10]` | 編成キャラクター情報 |

### GetGuildsForBattleMatchingRequest

| 項目 | 型 | 内容 |
|---|---|---|
| TargetDate | `DateTime` | 対象日. JSTの日付部分を使用する |
| StartTime | `GuildBattleStartTime` | 対象となる固定開戦時刻 |

### GetGuildsForBattleMatchingResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Candidates | `GuildBattleMatchCandidate[]` | 対象開始時刻を設定している騎士団と現在所属人数の一覧 |

### GuildBattleMatchCandidate

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID` | 対象騎士団ID |
| MemberCount | `Count` | 現在の所属プレイヤー数 |

### SaveGuildBattleExcludedGuildsRequest

| 項目 | 型 | 内容 |
|---|---|---|
| TargetDate | `DateTime` | 対象日. JSTの日付部分を使用する |
| StartTime | `GuildBattleStartTime` | 固定開戦時刻 |
| GuildID | `GuildID[]` | 所属0人のため除外したGuildID一覧. GuildID昇順 |

### SaveGuildBattleExcludedGuildsResponse

- 保存完了とする.

### GetGuildBattleExcludedGuildsRequest

| 項目 | 型 | 内容 |
|---|---|---|
| TargetDate | `DateTime` | 対象日. JSTの日付部分を使用する |
| StartTime | `GuildBattleStartTime` | 固定開戦時刻 |

### GetGuildBattleExcludedGuildsResponse

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID[]` | 所属0人のため除外されたGuildID一覧. GuildID昇順 |

### ClearGuildBattleExcludedGuildsRequest

| 項目 | 型 | 内容 |
|---|---|---|
| TargetDate | `DateTime` | 対象日. JSTの日付部分を使用する |
| StartTime | `GuildBattleStartTime` | 固定開戦時刻 |

### ClearGuildBattleExcludedGuildsResponse

- 削除完了とする.

### SaveScheduledGuildBattlesRequest

| 項目 | 型 | 内容 |
|---|---|---|
| TargetDate | `DateTime` | 対象日. JSTの日付部分を使用する |
| StartTime | `GuildBattleStartTime` | 固定開戦時刻 |
| Battles | `ScheduledGuildBattle[]` | GuildBattleCoordinatorが生成した保存対象の騎士団戦一覧 |

### SaveScheduledGuildBattlesResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Battles | `ScheduledGuildBattle[]` | 保存済み騎士団戦一覧. 同一TargetDate・StartTimeの既存データがある場合は既存データを返す |

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

### GetGuildBattleCoordinationStateRequest

- 要求データなし.

### GetGuildBattleCoordinationStateResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Battles | `GuildBattleCoordinationState[]` | `status=scheduled`の騎士団戦生成・割当状態一覧. `StartAt`, GuildBattleID昇順 |

### GuildBattleCoordinationState

| 項目 | 型 | 内容 |
|---|---|---|
| Battle | `ScheduledGuildBattle` | 対象騎士団戦IDと対戦GuildID |
| StartAt | `DateTime` | Database上の開戦予定時刻 |
| EndAt | `DateTime` | Database上の終了予定時刻 |
| Status | `GuildBattleStatus` | Database上の現在状態. 本レスポンスでは`scheduled` |
| HasAssignment | `Bool` | `game_server_instance_id`がNULLでない場合true |
| GameServerInstanceID | `GameServerInstanceID` | `HasAssignment=true`の場合の割当先GameServer Instance ID |

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
| PlayerID | `PlayerID[]` | Database上でArenaParty登録済みの通常PlayerID一覧. ArenaParty未登録PlayerおよびシステムダミーPlayerID `0`は含めず, PlayerID昇順で返す |

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

### SaveGuildBattleInitialSeedRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GuildBattleID | `GuildBattleID` | 対象騎士団戦ID |
| InitialSeed | `Seed` | 開戦前Preload成功後に生成した初期Seed |

### UpdateGuildBattleStatusRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GuildBattleID | `GuildBattleID` | 対象騎士団戦ID |
| Status | `GuildBattleStatus` | 更新後の状態 |

### RematchPreloadFailedGuildBattlesRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GuildBattleID | `GuildBattleID[]` | 再抽籤対象の`PRELOAD_FAILED`騎士団戦ID一覧. GuildBattleID昇順 |
| Battles | `ScheduledGuildBattle[]` | GuildBattleCoordinatorが再抽籤したペア一覧. GuildBattleIDは対象IDを再利用する |

### RematchPreloadFailedGuildBattlesResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Battles | `ScheduledGuildBattle[]` | 保存後の再抽籤済み騎士団戦一覧 |

Private APIは再抽籤を行わない. `GuildBattleID[]`と`Battles[]`のID集合が一致すること, 対象がすべて`GUILD_BATTLE_STATUS_PRELOAD_FAILED`であることを確認し, `guild_a_id` / `guild_b_id`を更新して`status=scheduled`, `game_server_instance_id=NULL`へ戻す.

### RetryPreloadFailedGuildBattleRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GuildBattleID | `GuildBattleID` | 同一ペアで再開する`PRELOAD_FAILED`騎士団戦ID |
| RestartAt | `DateTime` | 再開後の新しい開戦時刻. `end_at`は本時刻+30分で保存する |

### RetryPreloadFailedGuildBattleResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Battle | `ScheduledGuildBattle` | 同一ペアのまま`scheduled`へ戻した騎士団戦 |
| StartAt | `DateTime` | 保存後の新しい開戦時刻 |
| EndAt | `DateTime` | 保存後の終了時刻 |

### RetryUnassignedGuildBattleAssignmentRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GuildBattleID | `GuildBattleID[]` | GuildBattleCoordinatorへ再割当を要求する未割当騎士団戦ID一覧 |

### RetryUnassignedGuildBattleAssignmentResponse

| 項目 | 型 | 内容 |
|---|---|---|
| AssignedGuildBattleID | `GuildBattleID[]` | 空きGameServerへ再割当できた騎士団戦ID一覧 |
| UnassignedGuildBattleID | `GuildBattleID[]` | 空き容量不足等により未割当のまま残った騎士団戦ID一覧 |

### DeleteUnassignedGuildBattlesRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GuildBattleID | `GuildBattleID[]` | 削除する未割当騎士団戦ID一覧 |

### DeleteUnassignedGuildBattlesResponse

| 項目 | 型 | 内容 |
|---|---|---|
| DeletedGuildBattleID | `GuildBattleID[]` | 実際に削除した騎士団戦ID一覧 |

### SaveErrorLogRequest

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServerの受信時刻 |
| GuildBattleID | `GuildBattleID` | 騎士団戦に紐づく場合の騎士団戦ID. 騎士団戦未生成の時間帯エラー等では`0`を指定し, Database保存時はNULLとして扱う |
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


騎士団戦Replayのwire形式は「[guild_battle_replay.proto](../system/guild_battle_replay.proto)」を正本とする. `ProcessType`は各個別Payloadではなく`GuildBattleReplayEnvelope.process_type`に保持する. 以下のReplay Payload表は`oneof payload`へ格納する論理項目の説明として維持する.

### GuildBattleReplayPlayerSnapshot

騎士団戦開始時点でGameServerの騎士団戦データとして保持するプレイヤーの可変データを保存する.

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | プレイヤーID |
| MaxBP | `BP` | 騎士団戦開始時点の最大BP. 開始時の現在BPはこの値と同じ |
| FormationID | `FormationID` | 開始時点の騎士団戦フォーメーションID |
| Characters | `GuildBattlePartyCharacter[]` | 開始時点の騎士団戦編成. 有効Characterだけを`party_slot_no`付きで保存する |
| Items | `PlayerItemData[]` | 開始時点の所持アイテム一覧 |

### GuildBattleReplayGuildSnapshot

| 項目 | 型 | 内容 |
|---|---|---|
| Guild | `GuildLevelData` | 開始時点の騎士団レベル情報 |
| MemberPlayerID | `PlayerID[]` | 開始時点の所属メンバー一覧 |
| Participants | `GuildBattleReplayPlayerSnapshot[]` | 開始時点でGameServerの騎士団戦データとして保持するプレイヤーのスナップショット |

`MemberPlayerID`には所属メンバー全員を保存する. 開戦前Preloadで必須データ取得に1件でも失敗した場合は当該対戦を`GUILD_BATTLE_STATUS_PRELOAD_FAILED`として開戦しないため, Create Replayは生成しない. `Participants`にはPreload成功後にGameServerが保持している通常Playerのスナップショットを保存する. システムダミーGuildを含む場合はPlayerID `0`のダミースナップショットも保存する.

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
| InitialSeed | `Seed` | 騎士団戦の初期シード |
| GuildID | `GuildID[2]` | 対戦する2騎士団のID |
| InitialSnapshot | `GuildBattleInitialSnapshot` | 開戦時点の騎士団レベル, 所属メンバー, 参加者の最大BP・編成・所持アイテム等の初期状態 |
| Version | `Version` | リプレイに使用するマスターデータおよびゲームロジックのバージョン |

### GuildBattleJoinLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServerが参加要求を受信した時刻 |
| GuildBattleID | `GuildBattleID` | 騎士団戦ID |
| PlayerID | `PlayerID` | 参加したPlayerID |

### GuildBattleSortieLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServer受信時刻 |
| GuildBattleID | `GuildBattleID` | ログ対象の騎士団戦ID |
| Sequence | `Sequence` | 出撃時のシーケンス番号 |
| PlayerID | `PlayerID` | 出撃したPlayerID |
| SelectID | `FormationSlotID[]` | 出撃時に選択した有効な編成IDを選択順で保存する. 最大5件 |

### GuildBattleTacticsLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServer受信時刻 |
| GuildBattleID | `GuildBattleID` | ログ対象の騎士団戦ID |
| PlayerID | `PlayerID` | 使用したPlayerID |
| TacticsID | `TacticsID` | 使用したタクティクスID |

### GuildBattleItemLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServer受信時刻 |
| GuildBattleID | `GuildBattleID` | ログ対象の騎士団戦ID |
| PlayerID | `PlayerID` | 使用したPlayerID |
| ItemID | `ItemID` | 使用したアイテムID |

### GuildBattleHealLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServer受信時刻 |
| GuildBattleID | `GuildBattleID` | ログ対象の騎士団戦ID |
| PlayerID | `PlayerID` | 対象PlayerID |
| HealState | `HealState` | 回復状態 |

### GuildBattleReviveLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServer受信時刻 |
| GuildBattleID | `GuildBattleID` | ログ対象の騎士団戦ID |
| PlayerID | `PlayerID` | 対象PlayerID |
| ReviveState | `ReviveState` | 復活状態 |


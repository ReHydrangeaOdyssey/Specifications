# APIPayload

## 共通

各項目の型は「[型定義](types.md)」を参照.

`ArenaMode`は「[型定義](types.md)」を参照.

### CharacterHP

| 項目 | 型 | 内容 |
|---|---|---|
| CharacterID | `CharacterID` | キャラクターID |
| CurrentHP | `HP` | 現在HP |

### BattleCharacterStatus

| 項目 | 型 | 内容 |
|---|---|---|
| CharacterID | `CharacterID` | キャラクターID |
| HP | `HP` | 現在HP |
| Attack | `Attack` | 攻撃力 |
| Defense | `Defense` | 防御力 |
| SpeedRank | `SpeedRank` | 速度ランク |
| AbilityID | `AbilityID[2]` | アビリティID |
| SkillID | `SkillID[4]` | スキルID |

### TacticsEffectResult

| 項目 | 型 | 内容 |
|---|---|---|
| EffectID | `EffectID` | 効果ID |
| EffectValue | `Float32` | 効果値 |

### FormationCharacterHP

| 項目 | 型 | 内容 |
|---|---|---|
| FormationSlotID | `FormationSlotID` | 編成ID |
| CurrentHP | `HP` | 現在HP |

### ArenaPartyCharacter

| 項目 | 型 | 内容 |
|---|---|---|
| CharacterID | `CharacterID` | キャラクターID |
| Position | `FormationSlotID` | 配置位置。フォーメーション内部番号を使用 |
| FollowerCharacterID | `CharacterID[2]` | 従者のキャラクターID |
| AbilityID | `AbilityID[2]` | アビリティID |
| MainSkillID | `SkillID` | メインスキルID |

### GuildBattlePartyCharacter

| 項目 | 型 | 内容 |
|---|---|---|
| CharacterID | `CharacterID` | キャラクターID |
| PriorityPosition | `FormationSlotID` | 優先配置位置。フォーメーション内部番号を使用 |
| FollowerCharacterID | `CharacterID[2]` | 従者のキャラクターID |
| AbilityID | `AbilityID[2]` | アビリティID |
| MainSkillID | `SkillID` | メインスキルID |

## システム

### AccessTokenRequest

| 項目 | 型 | 内容 |
|---|---|---|
| Token | `Token` | トークン |

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

## アリーナ

### GetArenaBattleSeedRequest

要求データなし.

### GetArenaBattleSeedResponse

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| Seed | `Seed` | GameServerが発行したアリーナ戦闘用初期シード |

### UpdateArenaPartyRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| FormationID | `FormationID` | 使用するフォーメーションID |
| Characters | `ArenaPartyCharacter[5]` | 編成キャラクター情報 |

### UpdateArenaPartyResponse

- 登録完了

### ArenaBattleRequest

| 項目 | 必須条件 | 型 | 内容 |
|---|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| Mode | 常時 | `ArenaMode` | 対戦モード |
| OpponentID | `Mode=friend` の場合 | `PlayerID` | 対戦相手PlayerID |

### ArenaBattleResponse

| 項目 | 型 | 内容 |
|---|---|---|
| EnemyCharacters | `BattleCharacterStatus[]` | 相手のキャラクターステータス。最大5件 |
| Seed | `Seed` | 戦闘で使用するシード値 |

## 騎士団戦

### UpdateGuildBattlePartyRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |
| FormationID | `FormationID` | 使用するフォーメーションID |
| Characters | `GuildBattlePartyCharacter[10]` | 編成キャラクター情報 |

### UpdateGuildBattlePartyResponse

- 登録完了

### JoinGuildBattleRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |

### GuildBattleJoinResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Characters | `FormationCharacterHP[10]` | 編成IDと現在HPの一覧 |

### GetGuildBattleStatusRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| PlayerID | `PlayerID` | プレイヤーID |

### GetGuildBattleStatusResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Characters | `FormationCharacterHP[10]` | 編成IDと現在HPの一覧 |

### GuildBattleSortieRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| SelectID | `FormationSlotID[5]` | 出撃する編成ID |

`SelectID` は5件の固定長. 選択数が5件未満の場合、未使用スロットには `FormationSlotID` の最大値`255`を格納する.

### GuildBattleCastleBreakResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Score | `Score` | キャッスルブレイクで取得したpt |
| Seed | `Seed` | 出撃で使用したシード値 |

### GuildBattleAnnihilationResponse

| 項目 | 型 | 内容 |
|---|---|---|
| Score | `Score` | 殲滅で取得したpt |
| EnemyCharacters | `BattleCharacterStatus[]` | 相手のキャラクターステータス。最大5件 |
| Seed | `Seed` | 戦闘で使用したシード値 |
| EnemyTacticsID | `TacticsID[]` | 相手のタクティクスID。可変長 |

### UseTacticsRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| TacticsID | `TacticsID` | 使用するタクティクスID |

### UseTacticsResponse

| 項目 | 型 | 内容 |
|---|---|---|
| TP | `TP` | 使用後の現在TP |
| RemainingCount | `Count` | 使用後の残り使用可能回数 |
| EffectCount | `Count` | 発生した効果数 |
| Effects | `TacticsEffectResult[]` | 発生した効果一覧 |

### UseItemRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |
| ItemID | `ItemID` | 使用するアイテムID |

### UseItemResponse

| 項目 | 型 | 内容 |
|---|---|---|
| BP | `BP` | 使用後の現在BP |
| RemainingCount | `Count` | 使用後の残り所持数 |

### StartHealRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |

### StartHealResponse

| 項目 | 型 | 内容 |
|---|---|---|
| WaitTime | `DurationSeconds` | 回復待機時間 |

### CancelHealRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |

### CancelHealResponse

- キャンセル成功

### CompleteHealRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |

### CompleteHealResponse

| 項目 | 型 | 内容 |
|---|---|---|
| BP | `BP` | 回復後の現在BP |
| CharacterHP | `CharacterHP[]` | 回復後の編成キャラクターの現在HP |

### StartReviveRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |

### StartReviveResponse

| 項目 | 型 | 内容 |
|---|---|---|
| WaitTime | `DurationSeconds` | 復活待機時間 |

`WaitTime` は5秒.

### CancelReviveRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |

### CancelReviveResponse

- キャンセル成功

### CompleteReviveRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | セッションID |

### CompleteReviveResponse

| 項目 | 型 | 内容 |
|---|---|---|
| BP | `BP` | 復活後の現在BP |
| CharacterHP | `CharacterHP[]` | 復活後の編成キャラクターの現在HP |

## PrivateAPI

### SavePlayerIDRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 保存するPlayerID |
| UserName | `UserName` | 保存するユーザー名 |

### SaveSessionIDRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | セッション所有PlayerID |
| SessionID | `SessionID` | 保存するSessionID |
| ExpiresAt | `SessionExpiresAt` | セッション有効期限 |

### GetActiveSessionRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 対象PlayerID |

### GetActiveSessionResponse

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | 有効なSessionID |
| ExpiresAt | `SessionExpiresAt` | セッション有効期限 |

### InvalidateSessionRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | 無効化するSessionID |

### InvalidateSessionResponse

- 無効化完了

### ValidateSessionRequest

| 項目 | 型 | 内容 |
|---|---|---|
| SessionID | `SessionID` | 確認するSessionID |

### ValidateSessionResponse

| 項目 | 型 | 内容 |
|---|---|---|
| IsValid | `Bool` | セッションが有効な場合true |

### SaveArenaPartyRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 保存対象PlayerID |
| FormationID | `FormationID` | 使用するフォーメーションID |
| Characters | `ArenaPartyCharacter[5]` | 編成キャラクター情報 |

### SaveGuildBattlePartyRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 保存対象PlayerID |
| FormationID | `FormationID` | 使用するフォーメーションID |
| Characters | `GuildBattlePartyCharacter[10]` | 編成キャラクター情報 |

### GetScheduledGuildsRequest

| 項目 | 型 | 内容 |
|---|---|---|
| DateTime | `DateTime` | 開戦予定を取得する対象時刻 |

### GetScheduledGuildsResponse

| 項目 | 型 | 内容 |
|---|---|---|
| GuildID | `GuildID[]` | 指定時刻に開戦予定の騎士団ID一覧 |

### GetGuildBattleFormationRequest

| 項目 | 型 | 内容 |
|---|---|---|
| PlayerID | `PlayerID` | 編成情報を取得するPlayerID |

### GetGuildBattleFormationResponse

| 項目 | 型 | 内容 |
|---|---|---|
| FormationID | `FormationID` | 使用するフォーメーションID |
| Characters | `GuildBattlePartyCharacter[10]` | 騎士団戦パーティ情報 |

### GuildBattleResultSaveRequest

| 項目 | 型 | 内容 |
|---|---|---|
| GuildBattleID | `GuildBattleID` | 騎士団戦ID |
| GuildID | `GuildID` | 騎士団ID |
| Score | `Score` | 最終スコア |
| Result | `GuildBattleResult` | 勝敗結果 |


### GuildBattleCreateLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServer受信時刻 |
| ProcessType | `GuildBattleReplayProcessType` | 処理の種類。`create` |
| InitialSeed | `Seed` | 騎士団戦の初期シード |
| GuildID | `GuildID[2]` | 対戦する2騎士団のID |
| Version | `Version` | リプレイに使用するマスターデータおよびゲームロジックのバージョン |

### GuildBattleSortieLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServer受信時刻 |
| ProcessType | `GuildBattleReplayProcessType` | 処理の種類。`sortie` |
| Sequence | `Sequence` | 出撃時のシーケンス番号 |
| PlayerID | `PlayerID` | 出撃したPlayerID |
| SelectID | `FormationSlotID[5]` | 出撃時に選択した編成ID。未使用スロットは`255` |

### GuildBattleTacticsLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServer受信時刻 |
| ProcessType | `GuildBattleReplayProcessType` | 処理の種類。`tactics` |
| PlayerID | `PlayerID` | 使用したPlayerID |
| TacticsID | `TacticsID` | 使用したタクティクスID |

### GuildBattleItemLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServer受信時刻 |
| ProcessType | `GuildBattleReplayProcessType` | 処理の種類。`item` |
| PlayerID | `PlayerID` | 使用したPlayerID |
| ItemID | `ItemID` | 使用したアイテムID |

### GuildBattleHealLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServer受信時刻 |
| ProcessType | `GuildBattleReplayProcessType` | 処理の種類。`heal` |
| PlayerID | `PlayerID` | 対象PlayerID |
| HealState | `HealState` | 回復状態 |

### GuildBattleReviveLogPayload

| 項目 | 型 | 内容 |
|---|---|---|
| Time | `GameServerTime` | GameServer受信時刻 |
| ProcessType | `GuildBattleReplayProcessType` | 処理の種類。`revive` |
| PlayerID | `PlayerID` | 対象PlayerID |
| ReviveState | `ReviveState` | 復活状態 |


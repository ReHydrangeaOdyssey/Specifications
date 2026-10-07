# テスト方針

## 目的

本書は本プロジェクトで最低限実施するテスト方針を定義する.
本プロジェクトは個人または極少人数での開発を前提とし, 大規模組織向けの網羅的な試験工程は採用しない.
最優先事項は, ゲーム仕様どおりの計算結果, 疑似乱数の再現性, 騎士団戦状態の整合性, リプレイによる完全再現を確認できることとする.

ゲーム仕様の正本は`specification/game`配下, 実装設計の正本は`design`配下とする.
テストコードは仕様に記載されていない挙動を期待値として補完しない.
仕様が未確定の項目はテストで任意の挙動を固定せず, 仕様確定後に期待値を追加する.

## 対象

最低限以下を対象とする.

* 戦闘ロジック.
* Skill, Ability, Tactics, 状態異常.
* FormationおよびFollower補正.
* PartyRank計算.
* Arena.
* GuildおよびGuild加入・招待・役職変更.
* GuildBattle.
* 疑似乱数.
* Public API / Private APIの主要状態遷移.
* Databaseの制約および冪等性.
* GuildBattle Replay.
* ProcessedMasterDataのValidation.
* 運営操作により状態を復旧する経路.

## テスト区分

### 単体テスト

数式, 状態遷移, Enum分岐, Validation等の外部I/Oを必要としない処理を対象とする.

以下は原則として単体テストを持つ.

* ダメージ計算.
* Skillダメージ計算.
* HP, BP, TPのClamp.
* PartyRank計算.
* Skill対象選択.
* Ability発動条件判定.
* Ability発動回数制限.
* Tactics段階効果計算.
* Tactics終了条件判定.
* Castle Break確率.
* GuildBattleスコア計算.
* GuildBattleID生成.
* Seed生成.
* PRNGの`next`, `next_bounded`, Shuffle, 重み付き抽選.
* Version比較.
* 編成Validation.
* MasterData Validation.

### 結合テスト

Database, Public API Server, Private API Server, GameServer, GuildBattleCoordinatorの境界をまたぐ処理を対象とする.

最低限以下を確認する.

* Account作成, Login, Session更新, Logout.
* Arena編成登録から対戦開始まで.
* Guild加入申請, 承認, 招待, 承諾, 脱退, 役職変更.
* GuildBattle編成登録, Preload, 参加, 出撃, Tactics, Item, 治療, 復活, 終了.
* `membership_locked`中のGuild所属変更拒否.
* GameServer割当とPreload開始.
* 複数の割当候補では`AvailableGuildBattleThreadCount`が多いGameServerを負荷判定で優先し, 同数の場合は`(TotalGuildBattleThreadCount - AvailableGuildBattleThreadCount) / TotalGuildBattleThreadCount`が低い順, `LastAssignedAt`が古い順, `GameServerInstanceID`昇順で決定する.
* `PRELOAD_FAILED`への遷移.
* `RetryPreloadFailedGuildBattle`による同一ペア再Preload.
* `RematchPreloadFailedGuildBattles`による再抽籤後の再割当.
* 未割当Battleの再割当および削除.
* Database Recoveryファイルの生成, 再送, 削除.
* `X-Operation-ID`によるDatabase更新の冪等性.

### 再現性テスト

本プロジェクトでは疑似乱数を使用する処理の再現性を重要項目とする.
固定Seed, 同一初期状態, 同一入力列から常に同一結果を得ることを確認する.

以下を確認する.

* 同一SeedのArenaでClient側計算とGameServer側計算が一致する.
* GuildBattle本体PRNGの消費順が同一入力列で一致する.
* Join成立によるRequestSequence生成時のPRNG消費を再現できる.
* 出撃ごとの戦闘専用PRNGを同一Sequenceから再生成できる.
* Skillの対象抽選, Ability同順位抽選, Formation競合抽選, Character抽選が同一Seedで一致する.
* PRNGを使用しない処理によってPRNG状態が変化しない.
* ランダム要素を持つタクティクス使用時にGuildBattle本体PRNGを1回だけ消費してSeedを生成し, 以後の固有抽選がSeedから生成した専用PRNGだけを消費する.

### Replayテスト

GuildBattle Replayは「[リプレイProtocol Buffers定義](../system/guild_battle_replay.proto)」を使用する.

最低限以下を確認する.

* 最初のEventがGuildBattle作成Eventである.
* `GuildBattleInitialSnapshot`だけから開戦時可変状態を復元できる.
* length-delimited Protocol Buffers列を成立順に読み出せる.
* `process_type`と`oneof payload`が一致する.
* Join EventによるGuildBattle本体PRNG消費を再現できる.
* Replay Event列を最後まで適用した結果が実戦終了時状態と一致する.
* 最終Guild Score, Player HP, BP, TP, Chain, Tactics状態, Item残数, 勝敗結果を比較する.
* Replay時は現在のDatabase可変値を初期状態として使用しない.
* Replayに記録された`Version`に対応するゲームロジックとMasterDataを使用する.

### 障害系テスト

通常系より件数を限定し, 運営判断に接続する異常状態を重点的に確認する.

最低限以下を確認する.

* GuildBattle Preloadで1件のPlayer取得が失敗した場合に対象1対戦だけが`PRELOAD_FAILED`になる.
* Preload失敗時に他のGuildBattleが継続する.
* 水平スケーリング要求失敗時に未割当Battleが`scheduled`かつ未割当のまま残る.
* Database送信失敗時に同一要求を1回だけ再試行する.
* 2回目も失敗した場合にRecoveryファイルへ切り替える.
* Recovery再送で同一`X-Operation-ID`が二重適用されない.
* GameServer再起動時にRecoveryファイルを検出して再送する.
* 最終結果保存が2回とも失敗した場合に`completed`へ遷移しない.
* GuildBattleCoordinator再起動時にDatabase状態から`scheduled` BattleをReconcileできる.

## 数値テスト

### 浮動小数点

ゲーム計算は仕様で指定された順序を変更せず, IEEE-754 32bit浮動小数点として検証する.
途中式を代数的に変形して同値とみなすテストは行わない.

最低限以下の境界値を含める.

* 0.
* 最小値直前, 最小値, 最小値直後.
* 最大値直前, 最大値, 最大値直後.
* Clamp境界.
* 割合0および1.
* 仕様上入力され得る負値.
* NaN, Infinity, -Infinityを明示的に処理する式.

### 整数化

小数点以下切り捨てを行う箇所は境界の直前・直後を確認する.
`as u32`, `as i32`等の変換を含む式は, 変換前Clampと変換後Clampを仕様順に確認する.

## 戦闘テスト

### 通常攻撃

以下を確認する.

* 騎士団戦とArenaで対応する攻撃力・防御力式を使用する.
* 最小ダメージ250を適用する.
* 通常攻撃の最大ダメージ上限を仕様どおり適用する.
* ダメージ乱数を指定位置で1回消費する.
* 回避, 回避無効化, 追撃, 反撃, 反撃無効化の分岐順を維持する.
* 暗闇による通常攻撃失敗時の追撃分岐を仕様どおり処理する.

### Skill

以下を確認する.

* Skill発動成功時は通常攻撃ダメージフローへ入らずSkill用処理へ分岐する.
* 攻撃SkillはSkillダメージ計算フローを使用する.
* `SKILL_DAMAGE_VALUE_TYPE_RATE`には最大99,999の上限を適用せず, `SKILL_DAMAGE_VALUE_TYPE_FIXED`はABILITY加算後も250以上99,999以下へクランプする.
* 回復Skillは`can_heal_incapacitated=true`ではHP0だけ, `false`ではHP1以上だけを対象候補とし, この絞り込みをTargetRange・単体優先条件より先に行うことを確認する.
* 対象ごと, HITごとにダメージ乱数を個別取得する.
* ランダム攻撃では候補リストをFormation内部番号順で固定し, 各HITで対象を削除しない.
* BUFF / DEBUFFの最大発動回数1を保持する.
* `SkillEffectID × SkillTargetRange`の許可組み合わせ以外をMasterData Pipelineで拒否する.
* `SkillTargetSide`で味方・敵・自身を一意に指定できることを確認する.

### Ability

以下を確認する.

* AbilityID単位でターン内発動済み状態を保持する.
* 同一AbilityEffectIDの重複装備を拒否する.
* `EVERY_N_TURNS`を`AbilityTurnTiming`の4タイミングそれぞれで評価する.
* 状態異常回避判定を状態異常付与率判定より先に行う.
* AbilityによるBUFF / DEBUFFをSkillと同じ`BuffDebuffEffectState`へ反映する.
* `ABILITY_EFFECT_DAMAGE_INCREASE`は通常攻撃だけへ適用し, `correction_value`乗算後に通常攻撃最大ダメージ上限99,999を適用する.
* `ABILITY_EFFECT_COVER`は攻撃対象リスト取得後に候補をフォーメーション内部番号順で抽選し, 発動時は元対象の計算値を使用したダメージを対象数分だけかばうキャラクターへ反映する.
* `ABILITY_EFFECT_DRAW_AGGRO`は攻撃対象リスト取得前に候補をフォーメーション内部番号順へ並べ, 1キャラクターだけを抽選してその候補だけ発動率判定する. 不成立時に再抽選しない.
* `ABILITY_EFFECT_FIXED_DAMAGE_INCREASE`は`SKILL_DAMAGE_VALUE_TYPE_FIXED`の攻撃スキルだけへ加算し, RATE型へ適用しない. 固定ダメージは加算後も250以上99,999以下へクランプする.
* Ability MasterDataは`AbilityEffectID × AbilityConditionID × AbilityTarget`許可表に一致し, 表外の組み合わせをPipelineが拒否することを確認する. 戦闘不能味方人数連動補正は0～4人のMasterData entryを現在人数に応じて動的参照する.
* `ABILITY_EFFECT_HEAL`の算出回復量が`最大HP * (1 + アビリティの回復割合)`になり, 回復量自体を最大HPで上限クランプした後に`AbilityTarget`へ適用されることを確認する. `EVERY_N_TURNS`では`turn_timing`, `INCAPACITATED`では戦闘不能確定時に発動し, 回復後HPも最大HPを超えないことを確認する.
* 攻撃スキルは回避, 反撃, COVER, DRAW_AGGRO, 追撃のAbility処理を通らない.
* ELYSIONの回避効果はAbility回避判定後に通常攻撃だけへ適用し, スキルには適用しない.

### Tactics

以下を確認する.

* 同一系列の効果値を加算し, 異なる系列の系列内合計を乗算する.
* 速度補正だけは系列に関係なく全効果値を加算する.
* `TACTICS_EFFECT_BATTLE_SPECIAL`の数値パラメータは`TacticsBattleSpecialType`を系列として統合する.
* Battle Special MasterDataはTypeごとの`Target / Trigger / EndType / UseCondition / 非0Parameter`許可表に完全一致し, 許可されていない組み合わせをPipelineが拒否することを確認する.
* 継続Tactics効果は発動時の`source_player_id` / `source_guild_id`を保持し, `GetGuildBattleStatus.ActiveTacticsEffects`でも同じ値が返ることを確認する.
* `TACTICS_BATTLE_SPECIAL_HEAL`は`hp_recovery_value`をそのまま加算し, 回復後HPを0以上最大HP以下へクランプする.
* `TACTICS_BATTLE_SPECIAL_REVIVE`および`TACTICS_BATTLE_SPECIAL_RESURRECTION`は対象キャラクターごとに1回復帰判定し, 成功時に現在HPを最大HPと同じ値へ設定する.
* `TACTICS_USE_CONDITION_ALL_ANNIHILATED`を満たさないRESURRECTION要求は使用不可とし, TP・使用回数・RequestSequenceを変更しない.
* ランダム要素を持つタクティクスは騎士団戦RandomからSeedを1回生成し, Seedから生成したタクティクス固有Randomだけで固有ランダム結果を決定する. 同じSeedと同じ対象順序を与えたClient/Serverで結果が一致することを確認する. ランダム要素なしではSeed=0を確認する.
* HIDE / PROVOKE / CLAUSTRUMが被弾重み式へ反映され, NaN・Infinity・-Infinityと最小/最大clampが仕様式どおりになることを確認する.
* 強襲無効効果中は通常の`CB発生?`判定を行わず殲滅へ進む.
* 開戦時にPlayerの`attack_count=0`, `acquired_score=0`であること, 出撃実行確定時に`attack_count`を先に1加算して当該出撃のEXTERLIZE補正へ使用し, スコア確定後に今回取得スコアを`acquired_score`へ加算することを確認する.
* Battle SpecialのBP/TP回復は出撃完了時にTrigger条件成立を確認して反映し, 最大値へクランプする.
* Public APIへ現在HPを整数で返す場合は小数点以下を切り捨てる.

`TACTICS_BATTLE_SPECIAL_EXTERLIZE`は加算後の`attack_count * attack_count_score`を当該出撃のバトル獲得スコア補正として使用し, 初回成功出撃では`attack_count=1`になることを確認する. `REVIVE` / `RESURRECTION`は対象を`FormationSlotID`昇順へ並べた順で同一Seedの乱数を消費し, Client/Serverで同一結果になることを確認する.

## Arenaテスト

最低限以下を確認する.

* ランダム候補にはArenaParty登録済み通常Playerだけが入る.
* PlayerID `0`を候補に含めない.
* Friend Arenaで存在しないPlayerとArenaParty未登録Playerを別エラーにする.
* 要求元Player自身のArenaParty未登録を専用エラーにする.
* `ClientVersion`不一致時に対戦を開始しない.
* Clientローカル編成とServer編成が一致する場合はそのまま開始する.
* 編成不一致時はServer編成をClientへ返し, Server編成を使用して戦闘する.
* 同じ初期状態とSeedでClient / GameServerの最終結果が一致する.

## GuildBattleテスト

最低限以下を確認する.

* 開戦5分前に対象Guildの`membership_locked=true`となる.
* 0人Guildをマッチング対象から除外する.
* 通常候補0件時にロック解除, Error Log保存, Bot通知条件判定を行う.
* GuildID昇順からSeed Shuffleし, PairIndex=0でGuildBattleIDを生成する.
* 奇数候補ではSystem Dummy GuildID `0`を使用する.
* System Dummyを通常マッチング候補へ含めない.
* Join初回だけGuildBattle本体PRNGを1回消費し, 再Joinでは現在RequestSequenceを返す.
* 30:00時点で新規受付を停止し, 受付済みQueueをすべて解決してから勝敗判定する.
* 勝敗数は1回以上出撃成立した通常PlayerとDummy PlayerID `0`だけを対象にする.
* 最終結果保存成功後だけPlayer勝敗数を更新する.

## Guildテスト

最低限以下を確認する.

* 加入申請承認権限は団長・副団長だけにある.
* 招待送信権限は団長・副団長だけにある.
* 20人上限をDatabaseトランザクション内で再確認する.
* `membership_locked=true`では加入承認, 招待承諾, 脱退を成立させない.
* 団長と副団長に同一PlayerIDを設定できない.
* 副団長`0`を未設定として扱う.
* 副団長がGuild移動した場合に元Guildの`subleader_player_id=0`となる.
* 他メンバーがいないGuildの団長が移動した場合に元Guildの`leader_player_id=0`となる.
* 他メンバーが存在するGuildの団長は移動できない.

## MasterData Validationテスト

「[マスターデータ](../game/master_data.md)」および「[マスターデータ生成](../game/master_data_pipeline.md)」に従う.

生成処理について正常Fixtureと異常Fixtureを保持する.
異常FixtureはValidation失敗理由を1件以上確認できる最小データとする.

最低限以下を確認する.

* ID重複.
* 存在しない参照ID.
* EffectIDと`oneof`の不一致.
* Ability EffectIDと固有データの不一致.
* Tactics Stage Effectの`effect_index`範囲外.
* `effect_index`対象Effectと`effect_id` / `target`の不一致.
* SkillのEffectIDと固有データの不一致.
* Characterから存在しないSkill / Ability / Tacticsへの参照.
* Tactics EndTypeとDuration / Count関連値の不整合.

## 実行タイミング

### 通常開発時

変更対象に直接関係する単体テストと結合テストを実行する.
ゲームロジックまたはPRNG消費順を変更した場合は再現性テストとReplayテストも実行する.

### Mainへ統合する前

以下を実行する.

* 全単体テスト.
* MasterData Validationテスト.
* 主要API結合テスト.
* Arena再現性テスト.
* GuildBattle固定Seed Replayテスト.

### リリース前

以下を追加実行する.

* Preload失敗からの再Preload.
* Preload失敗からの再抽籤.
* 未割当Battle再割当.
* Database Recovery.
* GuildBattle 30:00受付停止とQueue drain.
* ClientVersion不一致.
* 編成不一致時のServer編成同期.

## Regressionルール

不具合を修正した場合は, 再現可能な不具合について同じ不具合が再発しないテストを追加する.
仕様変更で既存期待値が変更された場合は, 仕様文書の変更と同じ変更単位でテスト期待値を更新する.
テストだけを変更して仕様との差異を吸収しない.

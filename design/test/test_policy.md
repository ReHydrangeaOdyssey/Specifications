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
* Clientのログイン・Server未接続時のゲームプレイ制御.
* タイトル画面のキャッシュクリア・アセット追加とキャラクター画像の割り当て.
* Rust/WASM ClientのWebGL 2・PNG・HCA/Web Audio・OPFSの実機検証.
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
* `MarkGuildBattlePreloadFailed`による`scheduled -> PRELOAD_FAILED`遷移と所有GameServer不一致時の拒否.
* `StartGuildBattle`でInitialSeed保存, Create Replay保存, `scheduled -> in_progress`が同一トランザクションで確定すること.
* `BeginGuildBattleResolving`による`in_progress -> resolving`以外の遷移拒否.
* `CompleteGuildBattle`で最終結果, Player勝敗数, `completed`, membership lock解除, 除外一覧削除が同一トランザクションで確定すること.
* `CompleteGuildBattle`で対戦外Player, PlayerID重複, Guild結果とPlayer結果の不一致, 最終Scoreと不整合な2Guild勝敗組み合わせを拒否すること.
* Lifecycle APIで定義されていない`GuildBattleStatus`遷移を拒否すること.
* `RetryPreloadFailedGuildBattle`による同一ペア再Preload.
* BPを`u16`として保持し, ダミー最大BP500を正常に初期化・送受信できること.
* 出撃計算・出撃Response・`acquired_score`は小数を維持し, 1出撃の騎士団合計加算時だけ小数を切り捨てること.
* 城防御補正が`TACTICS_EFFECT_BATTLE_SPECIAL.parameters.castle_level`を参照し, 効果IDとの二重計上がないこと.
* Retryの旧IDが`replaced`で残り, 新規IDが高位領域で採番されて新しい`scheduled`対戦として割当・Preloadされること.
* `CancelPreloadFailedGuildBattle`で中止した対戦が`canceled`になり, 同枠のCompleted/Canceled混在時にだけ除外Guild解除が成立すること.
* 同枠にRetry新IDの未完了対戦が残る限り除外Guildを解除せず, 完了時に解除すること.
* Retry・Cancel・Completeの並行実行時に旧ID重複使用, 後継ID重複, 誤った除外Guild解除がないこと.
* `RematchPreloadFailedGuildBattles`による再抽選後の再割当.
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
* `CompleteGuildBattle`が2回とも失敗した場合にTransaction全体がRollbackされ, `completed`, Player勝敗数, membership lock, 除外一覧のいずれも部分更新されない.
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

## Clientテスト

以下を確認する.

* ログイン不可またはServer未接続の場合はタイトルからホーム画面への移動のみ可能で, その他の機能を利用できない.
* 必要な認証とServer接続が復帰すると, 接続状態と同じすべての機能を使用可能に戻す.
* タイトル画面にキャッシュクリアボタンとアセット追加ボタンがある.
* 「アセットの追加」ボタンから専用シーンへ遷移し, PNG/HCAをOPFSへ取り込める. 選択ディレクトリ配下を再帰的に探索し, ファイル名のSHA-256ハッシュ値に対応するServer配布辞書に基づき画像が自動配置され, OPFSへ割当情報を保存・復元する. 同名ファイルはファイル内容のSHA-256によって配置先を区別する. それ以上のハッシュ衝突処理は検証対象としない.
* キャッシュクリアがOPFSの`cache`フォルダだけを対象とし, その他のアセット・割当情報が維持される.

Clientの選定済み実装方式については, `design/programming/test/test_design.md`の「ブラウザ実装・アセット・音声の検証」を参照し, iPhone Safari/PWA, Android Chrome/PWA, WebGL 2, PNG, OPFS, HCA/音声を検証する. PNG/HCAファイル本体のOPFS保存は定義済みである一方, HCAデコーダーの最終採用には実機検証を要する. ClientとPublic API Server間のHTTP/2 over TLS 1.3・Protocol Buffersおよび騎士団戦通知のHTTP/2 Response streamを通信仕様として確認し, WebSocketをPublic API通信方式として使用しない.

HCA 22,050Hz・非暗号化・一部ループ・SE同時最大5, 性能閾値GPU80%以下・メモリ2GB以下・FPS30以上・WASM 500MB以下の検証計画を作成する. 実機と測定方法に関する未確定事項は勝手に補わない.

### 今回確定した施設・配布ルールのテスト対象

* 騎士団戦中の施設補正量：武器庫レベル×10, 食糧庫レベル×20, 鍛冶屋レベル×10. 計算順序/適用位置の検証は未確定事項として除外する.
* 酒場の回復量：`floor(酒場レベル / 3)`およびJST 0:00の使用回数リセット. 回数集計主体や最大BP適用は未定義であり仮定しない.
* BP50回復薬：通常Playerへの毎日JST 0:00の10個配布, 配布実績による二重加算防止. ジョブ・対象Player確定時刻・未配布日処理は未定義として扱う.

## 編成Validationテスト

以下を確認する.

* FormationIDがDatabase固定参照データ`FORMATION`に存在し, 本体CharacterID・従者CharacterIDがCharacter MasterDataに存在することを確認する.
* 本体CharacterIDの重複を拒否し, 別本体キャラクター間で同一従者CharacterIDを使用することは許可する.
* 各本体CharacterIDと, その本体へ指定した有効な従者CharacterIDが同一の場合は拒否する. Arena編成とGuildBattle編成の双方で確認する.
* 編成で指定するAbilityIDは当該本体キャラクターの`CharacterMasterData.ability_ids`に含まれるものだけを許可する.
* `AbilityID[2]`の配列順をAbilityスロット番号0, 1として保持し, 同時成立時の処理順へ使用する.
* 編成のMainSkillIDは当該本体キャラクターまたは現在編成している従者の`CharacterMasterData.skill_ids`に含まれるものだけを許可する.
* ArenaのPositionは1～9かつ重複不可, GuildBattleのPriorityPositionは1～9かつ重複可であることを確認する.

## 騎士団施設・アイテム配布テスト

以下を確認する.

* 城・武器庫・食糧庫・鍛冶屋・兵法所・酒場の施設Levelは既存仕様の1～150の範囲を使用する.
* 武器庫は騎士団戦の攻撃力, 食糧庫は最大HP, 鍛冶屋は防御力に対応し, 兵法所にはゲーム上の効果を設定しない. 未確定の補正式について数値期待値を設定しない.
* 酒場の効果は騎士団戦中のBP回復であり, 回数上限は3回である. 発動条件・回復量・回数集計単位の未確定部分について数値期待値を設定しない.
* 施設レベルアップにはゴールドの概念が必要であるが, 取得クエストおよび未定義のレベルアップ処理のテスト期待値を作成しない.
* BP50回復薬の配布量は1日10個であり, 配布後の所持数が配布前より10増加する. 対象所持数行がない場合は10個を保持する新規行を作成する.
* 日次境界はJST午前0時であり, 同一Playerへの同一JST日付の二重配布で所持数が再加算されない. 翌JST日付は別の配布対象日として扱う.
* 日次配布の所持数加算と配布実績の登録が同一トランザクションで成立し, 一方だけが反映されないことを確認する.

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
* 状態異常回避判定を状態異常付与率判定より先に行う. 状態異常回避Abilityが同一ターンに発動済みの場合, 再度発動率判定せず状態異常攻撃の発動率判定へ進む.
* `ABILITY_EFFECT_AVOIDANCE_DISABLE`および`ABILITY_EFFECT_COUNTER_DISABLE`が同一ターンに発動済みの場合, 当該Abilityの発動率を再判定しない.
* 暗闇で攻撃失敗となった場合も`ABILITY_EFFECT_PURSUIT`のAbilityID単位のターン内発動済み判定を通す.
* `ABILITY_EFFECT_COUNTER`の発動率判定がNoの場合, 2回目の相手HP処理ではなく相手HP確認へ進む.
* `ABILITY_EFFECT_AVOIDANCE_COUNTER`のターン内発動済み判定・発動率判定は通常攻撃成立後, 相手HP処理より前に行い, 発動した場合は通常攻撃ダメージを与えず味方HP処理へ進む.
* 味方HP処理後は2回目の相手HP処理を行わず, 相手HP確認へ進む.
* 追撃候補は行動キャラクターを除いた追撃Ability保持者とし, 複数候補ならフォーメーション内部番号順に並べて1キャラクターを抽選する. 選択したAbilityIDの発動済み判定・発動率判定を実施する.
* 回避無効化・反撃無効化・状態異常攻撃・状態異常回避・COVER・DRAW_AGGROの発動成立時に, 対応AbilityIDの発動処理を通過する.
* AbilityによるBUFF / DEBUFFをSkillと同じ`BuffDebuffEffectState`へ反映する.
* `ABILITY_EFFECT_DAMAGE_INCREASE`は通常攻撃だけへ適用し, `correction_value`乗算後に通常攻撃最大ダメージ上限99,999を適用する.
* `ABILITY_EFFECT_COVER`は攻撃対象リスト取得後に候補をフォーメーション内部番号順で抽選し, 発動したターンの対象リスト内のすべての味方に代わって, 元対象の計算値を使用したダメージを対象数分だけかばうキャラクターへ反映する. 同一ターンの再発動判定を行わない.
* `ABILITY_EFFECT_DRAW_AGGRO`は攻撃対象リスト取得前に候補をフォーメーション内部番号順へ並べ, 1キャラクターだけを抽選してその候補だけ発動率判定する. 不成立時に再抽選しない.
* `ABILITY_EFFECT_FIXED_DAMAGE_INCREASE`は`SKILL_DAMAGE_VALUE_TYPE_FIXED`の攻撃スキルだけへ加算し, RATE型へ適用しない. 固定ダメージは加算後も250以上99,999以下へクランプする.
* Ability MasterDataは`AbilityEffectID × AbilityConditionID × AbilityTarget`許可表に一致し, 表外の組み合わせをPipelineが拒否することを確認する. 戦闘不能味方人数連動補正は0～4人のMasterData entryを現在人数に応じて動的参照する.
* `ABILITY_EFFECT_HEAL`の算出回復量が`最大HP * (1 + アビリティの回復割合)`になり, 回復量自体を最大HPで上限クランプした後に`AbilityTarget`へ適用されることを確認する. `EVERY_N_TURNS`では`turn_timing`, `INCAPACITATED`では戦闘不能確定時に発動し, 回復後HPも最大HPを超えないことを確認する.
* 攻撃スキルは回避, 反撃, COVER, DRAW_AGGRO, 追撃のAbility処理を通らない.
* ELYSIONの回避効果はAbility回避判定後に通常攻撃だけへ適用し, スキルには適用しない.

### キャッスルブレイク専用Ability

* `ABILITY_CONDITION_CASTLE_BREAK`を選択キャラクターごとに処理し, 攻撃力UPの`ABILITY_EFFECT_BUFF`とダメージUPの`ABILITY_EFFECT_CASTLE_BREAK_DAMAGE_INCREASE`の条件・発動確率をそれぞれ独立に判定する.
* 両方の効果が成立したキャラクターには攻撃力補正と最終ダメージ倍率の両方が計算式どおりに作用する.
* 同一キャラクター・同一効果種別の発動は1回のキャッスルブレイクにつき最大1度であり, 他の効果種別の発動を妨げない.
* 次のキャッスルブレイクでは改めて判定し, 通常戦闘の`AbilityBattleState`の発動回数・ターン内フラグを消費しない.
* 発動しない場合は攻撃力補正値/ダメージ補正値0を適用し, ダメージ倍率は`correction_value - 1.0`を式に渡す.

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
* `CompleteGuildBattle`成功時だけ最終結果, Player勝敗数, 当該対戦の`completed`, 当該対戦2Guildのmembership lock解除を同時に確定する.
* 同じ元マッチング枠の対戦が複数ある場合, 未完了対戦が残る間は除外Guildのロックと除外一覧を保持し, 最後の対戦が`completed`または`canceled`の終端状態になったトランザクションで除外Guildのロック解除と除外一覧削除を確定する. 旧`replaced`対戦だけでは解除せず新IDの対戦も判定し, 並行Complete/Cancel/Retryでも同じ結果となる.

### GuildBattle 出撃・通知の追加検証

* キリ番条件を満たす場合でもCBCが先に成立すればイベント種別はCBCとなる. キリ番CB・強襲CB・CBC・殲滅のEnumの区別を確認する.
* `EX_DRIVE`・`SLASHER`のキリ番CB専用スコア効果と`ENDER_BREAK`のキリ番上限補正は`GUILD_BATTLE_SORTIE_EVENT_NUMBERED_CASTLE_BREAK`だけに適用する. 強襲CBとCBCでは適用しない.
* CBスコアは出撃基本値, 防御, 各キャラクターの攻撃力/ダメージAbility, フォーメーション, Tactics, チェイン補正, スコア上限を仕様で定義された順番で算出する. 未確定の`TACTICS_EFFECT_CASTLE_DEFENSE_CORRECTION`の数値期待値は固定しない.
* 殲滅Responseの`OwnCharacters`・`EnemyCharacters`・`EnemyPlayerID`・`EnemyFormationID`・`BattleTacticsEffects`・`Seed`をClient/Server双方へ同一入力として与え, 戦闘過程と結果を一致させる. 最大HP使用時にも一致し, 前回表示状態への依存がない.
* 1出撃のResponse送信はBattle Special回復, acquired_score/Score/Chain加算, Replay Event, ScoreUpdate通知より前に行う. その後処理は次のキュー要求の前に直列完了し, 他の一般状態変更操作のReplay→Response順序とは区別する.
* `SubscribeGuildBattleUpdates`の購読直後に初回スナップショットを1件送り, 以降は両騎士団の全購読Playerへ所属基準で`AllyScore`・`EnemyScore`・`Chain`・`ChainRemainingMilliseconds`を配信する. 未参加・他対戦への配信はしない.
* `ChainRemainingMilliseconds`は0～300000で, Chain=0, 前回加算から5分経過（加算不成立）, 5分ちょうどの加算成立, 加算直後, 継続中の各条件で定義どおりとなる. 連続同一Player出撃などチェイン非加算では残り時間を再始動しない.
* チェイン5分超過で値が0に変わっただけでは通知を発行しない. Clientの表示用カウントダウンとServer正本を区別する. ストリーム切断・再購読時は`GetGuildBattleStatus`同期後に再度初回スナップショットを受信する.
* 開戦30:00で新規受付を停止し, 当該Playerに30:00以前の受付済みキュー待機要求がなければ通知ストリームを終了する. 当該Playerに処理待ちがある場合だけそのPlayerの受付済み処理が完了次第ストリームを終了する. 他Playerのキュー待ちはそのPlayerの終了時点へ影響しない.
* 30:00前にキューへ受付けた要求は30:00後に処理開始しても完了まで処理し, 最終勝敗判定は受付済み要求全件処理後に行う.

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
* Preload失敗からの再抽選.
* 未割当Battle再割当.
* Database Recovery.
* GuildBattle 30:00受付停止とQueue drain.
* ClientVersion不一致.
* 編成不一致時のServer編成同期.

## Regressionルール

不具合を修正した場合は, 再現可能な不具合について同じ不具合が再発しないテストを追加する.
仕様変更で既存期待値が変更された場合は, 仕様文書の変更と同じ変更単位でテスト期待値を更新する.
テストだけを変更して仕様との差異を吸収しない.

## Clientライブラリ選定の情報源

* 添付`rust_wasm_png_hca_library_selection(1).md`（2026-10-09）, 第1～7節.

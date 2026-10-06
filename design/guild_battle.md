## フロー

### 騎士団戦

```mermaid
flowchart TD;
    Start[騎士団戦開始];
    ChackTimeLimit{30分経過?};
    ChackAttack{出撃要求がある?};
    CheckCBC{CBC発生中?};
    CheckCBCCondition{CBC発生条件を満たした?};
    Reflected[結果反映];
    StopAccept[新規処理受付停止];
    CheckQueue{処理キューが空?};
    ResolveQueue[キュー先頭処理を実行];
    Judgment[最終合計pt算出・勝敗判定];
    End[騎士団戦終了];
    StartPlayerAttack[出撃開始];
    EndPlayerAttack[出撃終了];
    CB[キャッスルブレイク];

    Start --> ChackTimeLimit;
    ChackTimeLimit -- Yes --> StopAccept;
    StopAccept --> CheckQueue;
    CheckQueue -- No --> ResolveQueue;
    ResolveQueue --> CheckQueue;
    CheckQueue -- Yes --> Judgment;
    Judgment --> End;
    ChackTimeLimit -- No --> ChackAttack;
    ChackAttack -- Yes --> StartPlayerAttack;
    ChackAttack -- No --> ChackTimeLimit;
    EndPlayerAttack --> Reflected;
    Reflected --> ChackTimeLimit

    subgraph 出撃
        CheckChain{キリ番?};
        CheckCB{CB発生?};
        Attack[殲滅];

        StartPlayerAttack --> CheckCBC;        
        CheckCBC -- Yes --> CB;
        CheckCBC -- No --> CheckCBCCondition;
        CheckCBCCondition -- Yes --> CB;
        CheckCBCCondition -- No --> CheckChain;
        CheckChain -- Yes --> CB;
        CheckChain -- No --> CheckCB;
        CheckCB -- Yes --> CB;
        CheckCB -- No --> Attack;
        CB --> EndPlayerAttack;
        Attack --> EndPlayerAttack;
    end
```


## 遷移



### 状態

```mermaid
stateDiagram-v2
    [*] --> 通常

    通常 --> 回復中: 治療開始
    全滅 --> 回復中: 治療開始
    回復中 --> 通常: 治療キャンセル（通常から開始）
    回復中 --> 全滅: 治療キャンセル（全滅から開始）
    回復中 --> 回復完了: 回復待機時間経過
    回復完了 --> 通常: 治療完了

    全滅 --> 復活中: 復活開始
    復活中 --> 全滅: 復活キャンセル
    復活中 --> 復活完了: パーティランクに応じた復活待機時間経過
    復活完了 --> 通常: 復活完了待機終了
```

出撃待機は上記のプレイヤー状態とは別の独立タイマーとして保持する. 出撃処理が成功した時点でタイマーを設定し, 0より大きい間は出撃のみ不可とする. 治療・復活・タクティクス等の状態とは併存できる.
出撃要求送信後から結果応答を受信するまではClientが通信中として追加操作送信を抑止する. GameServerはこの通信待ちを独立したプレイヤー状態として保持しない.


### UI

```mermaid
stateDiagram-v2
    [*] --> 騎士団戦
    騎士団戦 --> 出撃
    騎士団戦 --> 回復

    出撃 --> 戦闘
    出撃 --> キャッスルブレイク
    戦闘 --> 騎士団戦
    キャッスルブレイク --> 騎士団戦

    回復 --> 騎士団戦
    回復 --> アイテム回復
    回復 --> 治療

    アイテム回復 --> 騎士団戦
    治療 --> 騎士団戦
```

## シーケンス

騎士団戦参加時, GameServerは`GuildBattleID`単位で`PlayerID -> RequestSequence`マップを作成する. 初期値は0で, 参加成功時に騎士団戦本体PRNGを1回消費して`next_bounded(1,000,000,000) + 1`を求め, `RequestSequence`として割り当てる. 他プレイヤーとの`RequestSequence`重複は許可する. 参加後の要求は保持値と一致する`RequestSequence`のみ処理し, 成功するたびに1加算した`NextRequestSequence`をClientへ返す. 失敗時は加算しない. JoinによるPRNG消費もリプレイ再現対象とする.

相手プレイヤーの重み付き抽選へ渡す候補PlayerIDはPlayerID昇順とする.


### 編成登録時

```mermaid
sequenceDiagram
    actor User
    participant Client
    participant PublicAPIServer
    participant GameServer
    participant PrivateAPIServer
    participant DB

    User->>Client: 編成変更完了
    Client->>+PublicAPIServer: UpdateGuildBattleParty
    PublicAPIServer->>GameServer: UpdateGuildBattleParty
    GameServer->>GameServer: 編成変更可否判定

    alt 編成変更可能
        GameServer->>PrivateAPIServer: SaveGuildBattleParty
        PrivateAPIServer->>DB: 編成情報登録
        DB-->>PrivateAPIServer: 登録完了
        PrivateAPIServer-->>GameServer: SaveGuildBattleParty
        GameServer-->>PublicAPIServer: 編成完了通知(UpdateGuildBattlePartyResponse)
        PublicAPIServer-->>-Client: 編成完了通知(UpdateGuildBattlePartyResponse)
    else 編成変更不可
        PublicAPIServer-->>Client: UpdateGuildBattleParty
        Client->>User: 変更失敗表示
    end
```

### 騎士団戦参加時

```mermaid
sequenceDiagram
    actor User
    participant Client
    participant PublicAPIServer
    participant GameServer
    participant PrivateAPIServer
    participant DB

    User ->> Client: 参加ボタン押下
    Client ->> PublicAPIServer: JoinGuildBattle(AccessToken, PlayerID, GuildID, GuildBattleID)
    PublicAPIServer ->> GameServer: JoinGuildBattle(PlayerID, GuildID, GuildBattleID, AuthenticatedContext)
    GameServer ->> GameServer: 要求GuildBattleIDが騎士団戦中であることを確認
    GameServer ->> GameServer: 要求GuildIDが要求GuildBattleIDの対戦騎士団であることを確認
    GameServer ->> GameServer: PlayerIDの現在所属GuildIDと要求GuildIDが一致することを確認

    alt 両条件を満たし参加可能
        GameServer ->> PrivateAPIServer: ValidateAccountSession(AuthenticatedContext.SessionID)
        PrivateAPIServer ->> DB: ACCOUNT_SESSION存在・24時間期限確認
        DB -->> PrivateAPIServer: 確認結果
        PrivateAPIServer -->> GameServer: ValidateAccountSession(IsValid)
        GameServer->>GameServer: IsValid=trueを確認
        alt すでにJoin済み
            GameServer->>GameServer: 現在保持しているRequestSequenceを取得. 騎士団戦本体PRNGは消費しない
        else 初回Join
            GameServer->>GameServer: 騎士団戦本体PRNGでnext_bounded(1,000,000,000)+1を取得し初期RequestSequenceへ割り当て
            GameServer->>PrivateAPIServer: SaveGuildBattleJoinLog(GuildBattleID, PlayerID)
            PrivateAPIServer->>DB: Join成立ログ保存
        end
        GameServer -->> PublicAPIServer: GuildBattleJoinResponse(Characters, RequestSequence)
        PublicAPIServer -->> Client: GuildBattleJoinResponse(Characters, RequestSequence)
        Client ->> User: 結果表示
    else 参加不可
        PublicAPIServer -->> Client: JoinGuildBattle
        Client ->> User: 結果表示
    end

```

### 騎士団戦

#### 騎士団戦開戦前

騎士団戦開戦前処理は開戦5分前に開始する.
対象開始時刻の騎士団は, 対戦組み合わせ生成前にDatabaseの`GUILD.membership_locked=true`へ更新して加入・脱退を禁止し所属を固定する. 所属変更禁止状態の正本はDatabaseとする.
所属固定後に対戦組み合わせを生成する.
Kubernetes上で複数GameServerが稼働する場合, 対戦組み合わせ生成はLeader Electionで選出された1つのGameServerだけが行う.
生成後の各騎士団戦は`ClaimScheduledGuildBattles`で1つのGameServerへ割り当て, 以降は割当先GameServerだけが当該騎士団戦を処理する.

```mermaid
sequenceDiagram
    participant Bot
    participant LeaderGameServer
    participant GameServer
    participant PrivateAPIServer
    participant DB

    Note over LeaderGameServer,DB: 開戦5分前. Leader GameServerが対象開始時刻の騎士団戦開戦前処理を開始
    LeaderGameServer->>PrivateAPIServer: GetGuildsForBattleMatching(TargetDate, GuildBattleStartTime)
    PrivateAPIServer->>DB: 対象開始時刻のGuildID・所属人数一覧を取得
    DB-->>PrivateAPIServer: GuildBattleMatchCandidate[]
    PrivateAPIServer-->>LeaderGameServer: GetGuildsForBattleMatching
    LeaderGameServer->>PrivateAPIServer: SetGuildMembershipLock(対象GuildID[], true)
    PrivateAPIServer->>DB: GUILD.membership_locked = true
    Note over LeaderGameServer,DB: 対象開始時刻の騎士団の加入・脱退を禁止し所属を固定
    LeaderGameServer->>PrivateAPIServer: GetGuildsForBattleMatching(TargetDate, GuildBattleStartTime)
    PrivateAPIServer->>DB: ロック後のGuildID・所属人数一覧を再取得
    DB-->>PrivateAPIServer: GuildBattleMatchCandidate[]
    PrivateAPIServer-->>LeaderGameServer: GetGuildsForBattleMatching
    LeaderGameServer->>PrivateAPIServer: GetScheduledGuilds(TargetDate, GuildBattleStartTime)
    PrivateAPIServer->>DB: 同一日付・開始時刻の既存GUILD_BATTLEを取得
    DB-->>PrivateAPIServer: 既存ScheduledGuildBattle[]
    PrivateAPIServer-->>LeaderGameServer: GetScheduledGuilds
    alt 既存データあり
        LeaderGameServer->>LeaderGameServer: 既存ScheduledGuildBattle[]をそのまま使用
    else 既存データなし
        LeaderGameServer->>LeaderGameServer: 取得済みGuildBattleMatchCandidate[]から所属0人の騎士団を除外
        LeaderGameServer->>LeaderGameServer: GuildID昇順へ並べ替え
        LeaderGameServer->>LeaderGameServer: 共通内部API GenerateTimeBasedSeed でマッチング用Seedを生成
        LeaderGameServer->>LeaderGameServer: Seedを使用して騎士団一覧をシャッフルしペア生成
        LeaderGameServer->>LeaderGameServer: PairIndex=0からGuildBattleIDを生成
        LeaderGameServer->>PrivateAPIServer: SaveScheduledGuildBattles(TargetDate, StartTime, Battles[])
        PrivateAPIServer->>DB: GameServer生成済みGUILD_BATTLEをscheduledとして保存
        DB-->>PrivateAPIServer: 保存済みまたは既存ScheduledGuildBattle[]
        PrivateAPIServer-->>LeaderGameServer: SaveScheduledGuildBattles
    end
    Note over LeaderGameServer,DB: 0人で組み合わせ生成対象から除外された騎士団も所属変更禁止解除対象として保持

    GameServer->>PrivateAPIServer: ClaimScheduledGuildBattles(GameServerInstanceID, TargetDate, GuildBattleStartTime, 空き容量)
    PrivateAPIServer->>DB: 未割当scheduled騎士団戦を原子的にClaim
    DB-->>PrivateAPIServer: Claim済みScheduledGuildBattle[]
    PrivateAPIServer-->>GameServer: ClaimScheduledGuildBattles

    loop Claimした騎士団戦すべて
        loop 対戦する2騎士団
                GameServer->>PrivateAPIServer: GetGuildData(GuildID)
                PrivateAPIServer->>DB: 騎士団レベル情報要求
                DB-->>PrivateAPIServer: 騎士団レベル情報返答
                PrivateAPIServer-->>GameServer: GetGuildData
                GameServer->>GameServer: 騎士団レベル情報保管

                GameServer->>PrivateAPIServer: GetGuildMembers(GuildID)
                PrivateAPIServer->>DB: 所属PlayerID一覧要求
                DB-->>PrivateAPIServer: 所属PlayerID一覧返答
                PrivateAPIServer-->>GameServer: GetGuildMembers

                loop 所属しているメンバー全員
                    GameServer->>PrivateAPIServer: GetGuildBattleFormation(PlayerID)
                    PrivateAPIServer->>DB: 最大BP・編成情報要求
                    DB-->>PrivateAPIServer: 最大BP・編成情報返答
                    PrivateAPIServer-->>GameServer: GetGuildBattleFormation

                    GameServer->>PrivateAPIServer: GetPlayerItems(PlayerID)
                    PrivateAPIServer->>DB: PLAYER_ITEM要求
                    DB-->>PrivateAPIServer: PLAYER_ITEM返答
                    PrivateAPIServer-->>GameServer: GetPlayerItems

                    alt 取得成功
                        GameServer->>GameServer: 最大BP・編成・アイテム情報保管
                    else 処理失敗
                        GameServer->>GameServer: 当該GuildBattleIDをPreload失敗として記録
                        GameServer->>GameServer: エラーログ追記
                        GameServer->>PrivateAPIServer: SaveErrorLog(GuildBattleID)
                        PrivateAPIServer->>DB: エラーログ保存
                    end
                end
            end

            alt いずれかのPlayerでPreload失敗
                GameServer->>PrivateAPIServer: UpdateGuildBattleStatus(GuildBattleID, preload_failed)
                PrivateAPIServer->>DB: GUILD_BATTLE.status = preload_failed
                opt DiscordNotificationEnabled=true
                    GameServer->>Bot: Preload失敗通知
                end
                Note over GameServer: 当該1対戦だけ開戦しない. 他の騎士団戦は継続. 以後は運営判断
            else Preload成功
                GameServer->>GameServer: InitialSeed = 固定値 XOR GuildBattleID
                Note over GameServer: 開戦前データ処理終了. 所属変更禁止は開戦前処理開始時点から継続中
                Note over GameServer: 開戦時刻到達
                GameServer->>GameServer: 開戦時に保持する騎士団戦データを確定しGuildBattleInitialSnapshotを生成
                GameServer->>PrivateAPIServer: SaveGuildBattleCreateLog(GuildBattleID, InitialSeed, GuildID[2], InitialSnapshot, Version)
                PrivateAPIServer->>DB: リプレイ作成ログ・開戦時スナップショット保存
                GameServer->>PrivateAPIServer: UpdateGuildBattleStatus(GuildBattleID, in_progress)
                PrivateAPIServer->>DB: GUILD_BATTLE.status更新
            end
    end

    opt DiscordNotificationEnabled=true
        GameServer->>Bot: 処理終了通知
    end
```

GetGuildDataまたはGetGuildMembersを含む開戦前Preloadの必須データ取得に失敗した場合も, Player単位の取得失敗と同様に当該GuildBattleIDをPreload失敗として扱う.

`GUILD_BATTLE_STATUS_PRELOAD_FAILED`となった対戦は運営判断待ちとする. 問題解決後に運営が再抽籤を選択した場合, GameServerは対象GuildをGuildID昇順へ並べ, 共通時刻ベースSeedを新規生成してShuffleする. `PRELOAD_FAILED`のGuildBattleIDを昇順へ並べて新しいペアを割り当て, Private APIの`RematchPreloadFailedGuildBattles`へ保存を要求する. 保存後は`scheduled`かつ未Claimへ戻し, 通常のClaimと開戦前Preloadを再実行する. 運営が当該対戦を中止する場合は, 対象Guildについて`SetGuildMembershipLock(..., false)`を実行して所属変更禁止を解除する.

#### 騎士団戦中

```mermaid
sequenceDiagram
    actor User
    participant Client
    participant PublicAPIServer
    participant GameServer
    participant PrivateAPIServer
    participant DB

    loop 30分経過するまで
        User ->> Client: 出撃ボタン押下
        Client ->> PublicAPIServer: GuildBattleSortie(AccessToken, PlayerID, GuildBattleID, RequestSequence, SelectID[5])
        PublicAPIServer ->> GameServer: GuildBattleSortie(PlayerID, GuildBattleID, RequestSequence, SelectID[5], AuthenticatedContext)
        GameServer ->> GameServer: GuildBattleID・PlayerID・RequestSequence一致確認
        GameServer ->> GameServer: 出撃可否チェック
        GameServer ->> GameServer: 騎士団戦全体Sequence加算
        GameServer ->> GameServer: 相手PlayerID候補をPlayerID昇順, 相手Character候補を編成ID昇順で構築して出撃内容抽選

        alt キャッスルブレイク
            GameServer ->> GameServer: キャッスルブレイク処理
            GameServer->>GameServer: 成功した要求のRequestSequenceを1加算
            GameServer -->> PublicAPIServer: GuildBattleSortie(NextRequestSequence)
            PublicAPIServer -->> Client: GuildBattleSortie(NextRequestSequence)
        else 殲滅
            GameServer ->> GameServer: 戦闘処理
            GameServer->>GameServer: 成功した要求のRequestSequenceを1加算
            GameServer ->> PublicAPIServer: GuildBattleSortie(NextRequestSequence)
            PublicAPIServer ->> Client: GuildBattleSortie(NextRequestSequence)
        end

        GameServer ->> GameServer: チェイン処理

        GameServer ->> PrivateAPIServer: SaveGuildBattleSortieLog
        PrivateAPIServer ->> DB: ログ送信(GuildBattleID, Time, PlayerID)
    end
```

#### Battle Specialイベント処理

騎士団戦中は出撃判定, キャッスルブレイク判定, 戦闘開始, 迎撃, 敵全滅, スコア反映の各処理で有効な`TACTICS_EFFECT_BATTLE_SPECIAL`を評価する. `TacticsBattleSpecialType`ごとの具体効果は「[タクティクス仕様](../specification/tactics.md#特殊効果系列)」を正本とする. 騎士団全体効果は対象Guildの各出撃処理へ反映し, 対戦騎士団全体へのデバフは相手Guildの各出撃処理へ反映する.

#### 要求処理順

GameServerが受信するあらゆる要求は先に到達した順に処理する. GameServer受信時刻が異なる要求は受信時刻の早い要求を先に処理する. GameServer上で完全に同時として扱われる要求同士の順序は処理系定義とし, 疑似乱数による順序決定は行わない.

出撃要求についても同じ規則を使用する. Clientは出撃要求送信後から処理結果応答受信まで通信中として追加操作送信を抑止するため, GameServer側に出撃処理中・処理待ちを表す独立状態は持たせない.


#### 再接続・状態復元

`GetGuildBattleStatus`は再接続用の状態復元APIとして扱う.
ClientはAccessToken, PlayerID, GuildBattleIDだけを送信し, GameServerは現在のRequestSequenceを要求しない.
GameServerは現在HP, BP, TP, 治療・復活状態と残り時間, 出撃待機時間, タクティクス状態, アイテム残数, 両騎士団スコア, チェイン, CBC状態, 現在RequestSequenceを返す.
`GetGuildBattleStatus`の実行ではRequestSequenceを加算しない.
CharacterID, Follower, MainSkill, Ability, FormationID等の静的な編成構成はClientが編成確定時からローカルに保持し, 再接続時もそのローカル情報から復元する. `GetGuildBattleStatus`では静的な編成構成を再送しない.

##### タクティクス使用時

``` mermaid
sequenceDiagram
    actor User
    participant Client
    participant PublicAPIServer
    participant GameServer
    participant PrivateAPIServer
    participant DB

    User->>Client: タクティクス使用
    Client->>Client: TP, 使用回数チェック
    Client->>PublicAPIServer: UseTactics(AccessToken, PlayerID, GuildBattleID, RequestSequence, TacticsID)
    PublicAPIServer->>GameServer: UseTactics(PlayerID, GuildBattleID, RequestSequence, TacticsID, AuthenticatedContext)

    GameServer->>GameServer: GuildBattleID・PlayerID・RequestSequence一致確認
    GameServer->>GameServer: 要求TacticsIDが編成から使用可能なタクティクスか確認
    GameServer->>GameServer: TP, 使用回数チェック

    alt 使用可能
        GameServer->>GameServer: 使用可能回数, TP処理
        GameServer->>GameServer: タクティクス固有効果を適用
        GameServer->>GameServer: 継続効果はend_type・count_consume_triggerを含むTacticsActiveEffectStateとして保持
        GameServer->>GameServer: 成功した要求のRequestSequenceを1加算
        GameServer-->>PublicAPIServer: UseTactics
        PublicAPIServer-->>Client: UseTactics

        GameServer ->> PrivateAPIServer: SaveGuildBattleTacticsLog
        PrivateAPIServer ->> DB: ログ送信(GuildBattleID, Time, PlayerID, TacticsID)
    else 使用不可
        GameServer-->>PublicAPIServer: UseTactics
        PublicAPIServer-->>Client: UseTactics
    end
    
    Client->>Client: TP, 使用回数更新
```

##### 回復アイテム使用時

```mermaid
sequenceDiagram
    actor User
    participant Client
    participant PublicAPIServer
    participant GameServer
    participant PrivateAPIServer
    participant DB

    User->>Client: BP回復アイテム使用
    Client->>Client: 所持数チェック
    Client->>PublicAPIServer: UseItem(AccessToken, PlayerID, GuildBattleID, RequestSequence, ItemID)
    PublicAPIServer->>GameServer: UseItem(PlayerID, GuildBattleID, RequestSequence, ItemID, AuthenticatedContext)

    GameServer->>GameServer: GuildBattleID・PlayerID・RequestSequence一致確認
    GameServer->>GameServer: 所持数チェック

    alt 使用可能
        GameServer->>GameServer: アイテム使用処理
        GameServer->>PrivateAPIServer: UpdatePlayerItem(PlayerID, ItemID, 更新後所持数)
        PrivateAPIServer->>DB: PLAYER_ITEM更新
        DB-->>PrivateAPIServer: 更新完了
        PrivateAPIServer-->>GameServer: UpdatePlayerItem
        GameServer->>GameServer: 成功した要求のRequestSequenceを1加算
        GameServer-->>PublicAPIServer: UseItem
        PublicAPIServer-->>Client: UseItem

        GameServer ->> PrivateAPIServer: SaveGuildBattleItemLog
        PrivateAPIServer ->> DB: ログ送信(GuildBattleID, Time, PlayerID, ItemID)
    else 使用不可
        GameServer-->>PublicAPIServer: UseItem
        PublicAPIServer-->>Client: UseItem
    end

```

##### 治療時

```mermaid
sequenceDiagram
    actor User
    participant Client
    participant PublicAPIServer
    participant GameServer
    participant PrivateAPIServer
    participant DB

    User->>Client: 治療開始
    Client->>PublicAPIServer: StartHeal(AccessToken, PlayerID, GuildBattleID, RequestSequence)
    PublicAPIServer->>GameServer: StartHeal(PlayerID, GuildBattleID, RequestSequence, AuthenticatedContext)

    GameServer->>GameServer: GuildBattleID・PlayerID・RequestSequence一致確認
    GameServer->>GameServer: 回復状態でないことを確認

    alt 開始可能
        GameServer->>GameServer: 回復待機時間算出
        GameServer->>GameServer: 回復中状態へ変更
        GameServer->>GameServer: 成功した要求のRequestSequenceを1加算
        GameServer-->>PublicAPIServer: StartHeal
        PublicAPIServer-->>Client: StartHeal

        GameServer ->> PrivateAPIServer: SaveGuildBattleHealLog
        PrivateAPIServer ->> DB: ログ送信(GuildBattleID, Time, PlayerID, HealState)

        Note over GameServer: 回復待機時間経過

        GameServer->>GameServer: 回復完了状態へ変更
    else 開始不可
        GameServer-->>PublicAPIServer: StartHeal
        PublicAPIServer-->>Client: StartHeal
    end
```


##### 治療キャンセル

```mermaid
sequenceDiagram
    actor User
    participant Client
    participant PublicAPIServer
    participant GameServer
    participant PrivateAPIServer
    participant DB

    User->>Client: 治療キャンセル
    Client->>PublicAPIServer: CancelHeal(AccessToken, PlayerID, GuildBattleID, RequestSequence)
    PublicAPIServer->>GameServer: CancelHeal(PlayerID, GuildBattleID, RequestSequence, AuthenticatedContext)

    GameServer->>GameServer: GuildBattleID・PlayerID・RequestSequence一致確認
    GameServer->>GameServer: 回復中状態を確認

    alt キャンセル可能
        GameServer->>GameServer: 回復待機時間をリセット
        GameServer->>GameServer: 回復中状態を解除
        alt 治療開始前が全滅状態
            GameServer->>GameServer: 全滅状態へ戻す
        else 治療開始前が全滅状態ではない
            GameServer->>GameServer: 通常状態へ戻す
        end
        Note over GameServer: HP/BPは回復しない
        GameServer->>GameServer: 成功した要求のRequestSequenceを1加算
        GameServer-->>PublicAPIServer: CancelHeal
        PublicAPIServer-->>Client: CancelHeal

        GameServer ->> PrivateAPIServer: SaveGuildBattleHealLog
        PrivateAPIServer ->> DB: ログ送信(GuildBattleID, Time, PlayerID, HealState)
    else キャンセル不可
        GameServer-->>PublicAPIServer: CancelHeal
        PublicAPIServer-->>Client: CancelHeal
    end
```

##### 治療完了状態解除

```mermaid
sequenceDiagram
    actor User
    participant Client
    participant PublicAPIServer
    participant GameServer
    participant PrivateAPIServer
    participant DB

    User->>Client: 回復完了状態解除
    Client->>PublicAPIServer: CompleteHeal(AccessToken, PlayerID, GuildBattleID, RequestSequence)
    PublicAPIServer->>GameServer: CompleteHeal(PlayerID, GuildBattleID, RequestSequence, AuthenticatedContext)

    GameServer->>GameServer: GuildBattleID・PlayerID・RequestSequence一致確認
    GameServer->>GameServer: 回復完了状態を確認

    alt 完了可能
        GameServer->>GameServer: BP, HP回復処理
        GameServer->>GameServer: 回復状態を解除
        GameServer->>GameServer: 成功した要求のRequestSequenceを1加算
        GameServer-->>PublicAPIServer: CompleteHeal 
        PublicAPIServer-->>Client: CompleteHeal

        GameServer ->> PrivateAPIServer: SaveGuildBattleHealLog
        PrivateAPIServer ->> DB: ログ送信(GuildBattleID, Time, PlayerID, HealState)
    else 完了不可
        GameServer-->>PublicAPIServer: CompleteHeal
        PublicAPIServer-->>Client: CompleteHeal
    end
```

##### 復活

```mermaid
sequenceDiagram
    actor User
    participant Client
    participant PublicAPIServer
    participant GameServer
    participant PrivateAPIServer
    participant DB

    User->>Client: 復活開始
    Client->>PublicAPIServer: StartRevive(AccessToken, PlayerID, GuildBattleID, RequestSequence)
    PublicAPIServer->>GameServer: StartRevive(PlayerID, GuildBattleID, RequestSequence, AuthenticatedContext)

    GameServer->>GameServer: GuildBattleID・PlayerID・RequestSequence一致確認
    GameServer->>GameServer: 使用可能かチェック

    alt 復活可能
        GameServer->>GameServer: パーティランク仕様に従ってパーティランクを算出
        GameServer->>GameServer: パーティランクに応じた復活待機時間を設定
        GameServer->>GameServer: 復活中状態へ変更
        GameServer->>GameServer: 成功した要求のRequestSequenceを1加算
        GameServer-->>PublicAPIServer: StartRevive
        PublicAPIServer-->>Client: StartRevive

        GameServer ->> PrivateAPIServer: SaveGuildBattleReviveLog
        PrivateAPIServer ->> DB: ログ送信(GuildBattleID, Time, PlayerID, ReviveState)

        Note over GameServer: パーティランクに応じた復活待機時間経過

        GameServer->>GameServer: 復活完了状態へ変更
        Note over GameServer: この時点ではBP消費・HP回復なし
    else 復活不可
        GameServer-->>PublicAPIServer: StartRevive
        PublicAPIServer-->>Client: StartRevive
    end
```


##### 復活キャンセル

```mermaid
sequenceDiagram
    actor User
    participant Client
    participant PublicAPIServer
    participant GameServer
    participant PrivateAPIServer
    participant DB

    User->>Client: 復活キャンセル
    Client->>PublicAPIServer: CancelRevive(AccessToken, PlayerID, GuildBattleID, RequestSequence)
    PublicAPIServer->>GameServer: CancelRevive(PlayerID, GuildBattleID, RequestSequence, AuthenticatedContext)

    GameServer->>GameServer: GuildBattleID・PlayerID・RequestSequence一致確認
    GameServer->>GameServer: 復活中状態を確認

    alt キャンセル可能
        GameServer->>GameServer: 復活待機時間を破棄
        GameServer->>GameServer: 全滅状態へ戻す
        GameServer->>GameServer: 成功した要求のRequestSequenceを1加算
        GameServer-->>PublicAPIServer: CancelRevive
        PublicAPIServer-->>Client: CancelRevive

        GameServer ->> PrivateAPIServer: SaveGuildBattleReviveLog
        PrivateAPIServer ->> DB: ログ送信(GuildBattleID, Time, PlayerID, ReviveState)
    else キャンセル不可
        GameServer-->>PublicAPIServer: CancelRevive
        PublicAPIServer-->>Client: CancelRevive
    end
```


##### 復活完了状態解除

```mermaid
sequenceDiagram
    actor User
    participant Client
    participant PublicAPIServer
    participant GameServer
    participant PrivateAPIServer
    participant DB

    User->>Client: 復活完了状態解除
    Client->>PublicAPIServer: CompleteRevive(AccessToken, PlayerID, GuildBattleID, RequestSequence)
    PublicAPIServer->>GameServer: CompleteRevive(PlayerID, GuildBattleID, RequestSequence, AuthenticatedContext)

    GameServer->>GameServer: GuildBattleID・PlayerID・RequestSequence一致確認
    GameServer->>GameServer: 復活完了状態を確認

    alt 完了可能
        GameServer->>GameServer: BP, HP処理
        GameServer->>GameServer: 全滅状態を解除
        GameServer->>GameServer: 成功した要求のRequestSequenceを1加算
        GameServer-->>PublicAPIServer: CompleteRevive
        PublicAPIServer-->>Client: CompleteRevive

        GameServer ->> PrivateAPIServer: SaveGuildBattleReviveLog
        PrivateAPIServer ->> DB: ログ送信(GuildBattleID, Time, PlayerID, ReviveState)
    else 完了不可
        GameServer-->>PublicAPIServer: CompleteRevive
        PublicAPIServer-->>Client: CompleteRevive
    end
```

### Database送信失敗時

騎士団戦中にDatabaseへの送信が失敗した場合は, 同一送信を1回だけ再試行する. 再試行も失敗した場合, GameServerは当該騎士団戦についてDB障害発生状態へ移行する.

DB障害発生状態では, それ以降の騎士団戦中Database送信を行わず, 本来送信するデータをGameServerローカルのファイルへ保存する.
保存形式はUTF-8 JSONとし, 保存先はGameServerプロセスのカレントディレクトリ直下とする.
ローカルファイルはGameServer再起動後も保持する.
騎士団戦終了時にローカル保存したデータをDatabaseへ一括送信する.
一括送信に失敗した場合はローカルファイルを残し, 一括送信に成功した場合は対応するローカルファイルを削除する.

騎士団戦最終結果の保存は下記終了シーケンスの専用規則を使用する.

#### 騎士団戦終了時

```mermaid
sequenceDiagram
    participant GameServer
    participant PublicAPIServer
    participant PrivateAPIServer
    participant DB
    participant Bot

    Note over GameServer: 騎士団戦開始から30:00到達

    GameServer->>GameServer: 新規処理受付停止
    GameServer->>PrivateAPIServer: UpdateGuildBattleStatus(GuildBattleID, resolving)
    PrivateAPIServer->>DB: GUILD_BATTLE.status = resolving

    loop 処理キューが空になるまで
        GameServer->>GameServer: キュー先頭の処理を実行
        GameServer->>GameServer: 結果を状態へ反映
    end

    GameServer->>GameServer: 最終合計pt算出
    GameServer->>GameServer: 勝敗判定

    loop 対象騎士団
        GameServer->>PrivateAPIServer: SaveGuildBattleResult
        PrivateAPIServer->>DB: スコア・勝敗結果保存
        DB-->>PrivateAPIServer: 保存結果
        PrivateAPIServer-->>GameServer: SaveGuildBattleResult

        opt 初回保存失敗
            GameServer->>PrivateAPIServer: SaveGuildBattleResult 再試行（1回）
            PrivateAPIServer->>DB: スコア・勝敗結果再保存
            DB-->>PrivateAPIServer: 再保存結果
            PrivateAPIServer-->>GameServer: SaveGuildBattleResult
            opt 再試行も失敗
                GameServer->>GameServer: エラーログ追記
                GameServer->>PrivateAPIServer: SaveErrorLog
                PrivateAPIServer->>DB: エラーログ保存
                opt DiscordNotificationEnabled=true
                    GameServer->>Bot: エラーメッセージ送信
                end
                Note over GameServer: 原因調査および復旧は運営が手動で行う
            end
        end
    end


    alt 最終結果保存が完了
        Note over GameServer: 最終結果保存成功後にPlayer勝敗数を更新
        loop 勝敗数更新対象Player
            GameServer->>PrivateAPIServer: UpdatePlayerGuildBattleRecord(PlayerID, Result)
            PrivateAPIServer->>DB: 勝利ならwin_count+1 / 敗北ならlose_count+1 / 引き分けは更新なし
        end
        GameServer->>PrivateAPIServer: UpdateGuildBattleStatus(GuildBattleID, completed)
        PrivateAPIServer->>DB: GUILD_BATTLE.status = completed
        GameServer->>PrivateAPIServer: SetGuildMembershipLock(対象2騎士団 + 同じ開始時刻に0人除外された騎士団, false)
        PrivateAPIServer->>DB: GUILD.membership_locked = false
    else 再試行後も最終結果保存失敗
        Note over GameServer: ErrorLog保存済み. DiscordNotificationEnabled=trueの場合はBot通知済み. 運営が原因調査し手動復旧する
    end
```


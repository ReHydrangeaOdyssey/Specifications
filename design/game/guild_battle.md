## フロー

### 騎士団戦

```mermaid
flowchart TD;
    Start[騎士団戦開始];
    ChackTimeLimit{30分経過?};
    ChackAttack{GuildBattleSortie要求がある?};
    CheckCBC{GuildBattleCbcStatus.IsActive?};
    CheckCBCCondition{キャッスルブレイクチャンス発生条件を満たした?};
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
        CheckChain{キリ番キャッスルブレイク?};
        CheckAssaultDisable{強襲無効Battle Special有効?};
        CheckCB{強襲キャッスルブレイク発生?};
        Attack[殲滅];

        StartPlayerAttack --> CheckCBC;        
        CheckCBC -- Yes --> CBChance[イベント種別 CBC];
        CBChance --> CB;
        CheckCBC -- No --> CheckCBCCondition;
        CheckCBCCondition -- Yes --> CBChance;
        CheckCBCCondition -- No --> CheckChain;
        CheckChain -- Yes --> CBNumbered[イベント種別 キリ番CB];
        CBNumbered --> CB;
        CheckChain -- No --> CheckAssaultDisable;
        CheckAssaultDisable -- Yes --> Attack;
        CheckAssaultDisable -- No --> CheckCB;
        CheckCB -- Yes --> CBAssault[イベント種別 強襲CB];
        CBAssault --> CB;
        CheckCB -- No --> Attack;
        Attack --> SetAnnihilation[イベント種別 殲滅];
        CB --> EndPlayerAttack;
        SetAnnihilation --> EndPlayerAttack;
    end
```


強襲無効Battle Specialは通常の確率による強襲キャッスルブレイク判定の直前だけで評価する. `CheckAssaultDisable=Yes`ではキャッスルブレイクへ進まず殲滅へ進む. `GuildBattleCbcStatus.IsActive=true`, キャッスルブレイクチャンス発生条件成立, キリ番キャッスルブレイクは従来どおり先に判定する.

GameServerは各Playerについて騎士団戦単位の`GuildBattlePlayerRuntimeState`を保持し, 開戦時に`attack_count=0`, `acquired_score=0`で初期化する. 出撃可否・RequestSequence検証を通過して当該出撃の実行が確定した時点で`attack_count`を1増加し, 加算後の値を当該出撃のEXTERLIZE補正へ使用する. 結果スコア確定後, 当該出撃でPlayerが取得したスコアを`acquired_score`へ加算する.

## キャッスルブレイクスコア計算フロー

`GuildBattleSortieEventType`で確定した種別を条件判定に使用する. 出撃開始時チェインが10以上かつ10の倍数でも, CBCで確定した出撃はキリ番CB専用効果を使用しない. 数式・統合順の正本は「[キャッスルブレイクスコア](../../specification/game/guild_battle.md#キャッスルブレイクスコア)」とする.

```mermaid
flowchart TD
    Start[出撃種別確定・スコア計算開始] --> Basic[選択キャラクター累計BPから出撃基本スコア算出]
    Basic --> Enemy[相手平均防御力・城レベル補正・タクティクス防御力補正を算出]
    Enemy --> Loop{未計算の選択キャラクターがある?}
    Loop -->|Yes| Ability[各キャラクターの攻撃力UP・ダメージUP Abilityを効果別に各1度判定]
    Ability --> Attack[Ability・Formation・Tactics補正で攻撃力算出]
    Attack --> Damage[相手最終防御力・城防御補正を差引き Ability倍率反映]
    Damage --> Clamp[最終ダメージを0以上へ補正]
    Clamp --> Individual[打属性出撃補正を適用して個別スコアを加算]
    Individual --> Loop
    Loop -->|No| BaseTactics[通常のGuildBattleスコア・CBスコア補正を統合]
    BaseTactics --> GeneralLimit[通常のスコア上限補正を取得]
    GeneralLimit --> Numbered{イベント種別がキリ番CB?}
    Numbered -->|Yes| NumberedTactics[EX_DRIVE・SLASHERのCBスコア補正を統合]
    NumberedTactics --> NumberedLimit[キリ番CB専用スコア上限補正を統合]
    Numbered -->|No| Assault{イベント種別が強襲CB?}
    Assault -->|Yes| AssaultTactics[強襲CB専用スコア補正を統合]
    Assault -->|No CBC| Score[チェイン補正とタクティクススコア補正を適用]
    AssaultTactics --> Score
    NumberedLimit --> Score
    Score --> Limit[スコアリミットで上限適用]
    Limit --> End[キャッスルブレイクスコア確定]
```

## 遷移



### 状態

```mermaid
stateDiagram-v2
    state "REVIVE_STATE_NORMAL / HEAL_STATE_NONE" as Normal
    state "REVIVE_STATE_ANNIHILATED / HEAL_STATE_NONE" as Annihilated
    state "HEAL_STATE_HEALING" as Healing
    state "HEAL_STATE_COMPLETED" as HealCompleted
    state "REVIVE_STATE_REVIVING" as Reviving
    state "REVIVE_STATE_COMPLETED" as ReviveCompleted

    [*] --> Normal

    Normal --> Healing: StartHeal
    Annihilated --> Healing: StartHeal
    Healing --> Normal: CancelHeal（治療開始前がREVIVE_STATE_NORMAL）
    Healing --> Annihilated: CancelHeal（治療開始前がREVIVE_STATE_ANNIHILATED）
    Healing --> HealCompleted: 回復待機時間経過
    HealCompleted --> Normal: CompleteHeal

    Annihilated --> Reviving: StartRevive
    Reviving --> Annihilated: CancelRevive
    Reviving --> ReviveCompleted: 復活待機時間経過
    ReviveCompleted --> Normal: CompleteRevive
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


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
        CheckCBC -- Yes --> CB;
        CheckCBC -- No --> CheckCBCCondition;
        CheckCBCCondition -- Yes --> CB;
        CheckCBCCondition -- No --> CheckChain;
        CheckChain -- Yes --> CB;
        CheckChain -- No --> CheckAssaultDisable;
        CheckAssaultDisable -- Yes --> Attack;
        CheckAssaultDisable -- No --> CheckCB;
        CheckCB -- Yes --> CB;
        CheckCB -- No --> Attack;
        CB --> EndPlayerAttack;
        Attack --> EndPlayerAttack;
    end
```


強襲無効Battle Specialは通常の確率による強襲キャッスルブレイク判定の直前だけで評価する. `CheckAssaultDisable=Yes`ではキャッスルブレイクへ進まず殲滅へ進む. `GuildBattleCbcStatus.IsActive=true`, キャッスルブレイクチャンス発生条件成立, キリ番キャッスルブレイクは従来どおり先に判定する.

GameServerは各Playerについて騎士団戦単位の`GuildBattlePlayerRuntimeState`を保持し, 開戦時に`attack_count=0`, `acquired_score=0`で初期化する. 出撃可否・RequestSequence検証を通過して当該出撃の実行が確定した時点で`attack_count`を1増加し, 加算後の値を当該出撃のEXTERLIZE補正へ使用する. 結果スコア確定後, 当該出撃でPlayerが取得したスコアを`acquired_score`へ加算する.

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


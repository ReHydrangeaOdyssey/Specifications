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
        CheckAssaultDisable{強襲無効効果中?};
        CheckCB{CB発生?};
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


強襲無効効果は通常の確率による強襲キャッスルブレイク判定の直前だけで評価する. `CheckAssaultDisable=Yes`ではキャッスルブレイクへ進まず殲滅へ進む. CBC発生中, CBC発生条件成立, キリ番の確定キャッスルブレイクは従来どおり先に判定する.

GameServerは各Playerについて騎士団戦単位の`GuildBattlePlayerRuntimeState`を保持し, 開戦時に`attack_count=0`, `acquired_score=0`で初期化する. 出撃可否・RequestSequence検証を通過して当該出撃の実行が確定した時点で`attack_count`を1増加し, 加算後の値を当該出撃のEXTERLIZE補正へ使用する. 結果スコア確定後, 当該出撃でPlayerが取得したスコアを`acquired_score`へ加算する.

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


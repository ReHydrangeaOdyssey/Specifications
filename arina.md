# アリーナ仕様

## 概要

アリーナはキャラクター同士で行う戦闘形式である.
戦闘の基本処理は[戦闘仕様](battle.md)に従う.

相手は2つのパターンがあり, どちらのパターンを選ぶかはプレイヤーが選ぶことができる.
* 任意の相手と戦闘する.
* ランダムな相手と戦闘する.

## 制約

* 30ターンの制限がある.
* 1ターンに行動できるのは1キャラクターのみ.
* 同一キャラクターを複数編成できない.
* 最低1キャラクターを編成する必要がある.
  - 最大5キャラクター
* 初期シード値はサーバーに問い合わせて得た値を使用する.

## 勝敗条件

以下のいずれかで勝敗を決定する.

* 相手を全滅させた側が勝利.
* 30ターン経過時は総合残HPが最も高い側が勝利する.
  - 同一の場合は以下の順序で判定していく
    1. `総合残HP / 総合最大HP`の割合で比較する.
    1. 総合ステータス(全キャラクターの最大HP+攻撃+防御の合計)が高いほうが勝利する.
    1. 総合最大HPが高いほうが勝利する.
    1. 最初に行動したほうが勝利する.

## 表示・進行操作

以下の操作が可能.

* 勝敗までスキップ
* 戦闘中の2倍速
* 戦闘中の4倍速


## 遷移

```mermaid
stateDiagram-v2
    [*] --> アリーナ
    アリーナ --> ランダム対戦
    アリーナ --> フレンド対戦
    アリーナ --> 編成
    編成 --> アリーナ

    ランダム対戦 --> 戦闘
    フレンド対戦 --> 戦闘
    戦闘 --> 結果
    結果 --> アリーナ
```

## シーケンス

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
    Client->>PublicAPIServer: 編成変更
    PublicAPIServer->>GameServer: 編成情報登録
    GameServer->>PrivateAPIServer: 編成情報登録
    PrivateAPIServer->>DB: 編成情報登録
    DB-->>PrivateAPIServer: 登録完了
    PrivateAPIServer-->>GameServer: 登録完了
    GameServer-->>PublicAPIServer: 登録完了通知
    PublicAPIServer-->>Client: 登録完了通知
    Client-->>User: 変更完了通知
```

### 対戦時

```mermaid
sequenceDiagram
    actor User
    participant Client
    participant PublicAPIServer
    participant GameServer
    participant PrivateAPIServer
    participant DB

    User->>Client: 対戦開始
    Client->>PublicAPIServer: GetArenaBattleSeed
    PublicAPIServer->>GameServer: seed発行依頼
    GameServer-->>PublicAPIServer: initial_seed
    PublicAPIServer-->>Client: initial_seed

    alt ランダム対戦
        Client->>PublicAPIServer: StartArenaBattle(mode=random)
    else フレンド対戦
        Client->>PublicAPIServer: StartArenaBattle(mode=friend, opponent_id)
    end

    PublicAPIServer->>GameServer: 戦闘実行
    GameServer->>PrivateAPIServer: 必要データ取得
    PrivateAPIServer->>DB: 必要データ取得
    DB-->>PrivateAPIServer: データ返却
    PrivateAPIServer-->>GameServer: データ返却
    GameServer-->>PublicAPIServer: 戦闘結果
    PublicAPIServer-->>Client: 戦闘結果
    Client->>User: 戦闘内容表示
```

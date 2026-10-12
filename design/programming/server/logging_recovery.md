# Logging / Replay / Recoveryプログラミング設計

## 概要

System Log、GuildBattle Replay、DB Recoveryは目的と耐欠損性が異なるため、Queue・Worker・保存形式を分離します。GuildBattle Hot Pathは自身では同期I/Oを行わず、Replayだけは欠損禁止としてQueue満杯時にBackpressureを許容します。出撃は専用WorkerによるDB先行保存の完了通知を成功Responseの条件とします。

## 3系統の分離

```mermaid
flowchart LR
    Hot[GuildBattle Hot Path] -->|Log Event| LQ[System Log Queue]
    Hot -->|成立Replay Event| RQ[ReplayQueue]
    Hot -->|DB送信予定| DBW[DB送信処理]

    LQ --> LW[Log Worker]
    LW --> OUT[stdout / stderr JSON]

    RQ --> RW[Replay Worker]
    RW --> FILE[Replay .pb]
    RW --> PA[Private API]

    DBW --> PA
    DBW -->|確定失敗・同一IDの1回Retry失敗・通算5秒| REC[Recovery Writer]
    RW -->|確定失敗・同一IDの1回Retry失敗・通算5秒| REC
    REC --> RF[/Persistent Recovery JSON/]
```

## System Log Queue

- bounded queueです。
- GuildBattle専用Threadは構造化前Eventを追加するだけです。
- JSON Serializeと`stdout` / `stderr`出力はWorkerが行います。
- 本番`DEBUG` / `TRACE`は既定無効です。
- Queue高負荷時は`DEBUG` / `INFO`を破棄可能です。
- `WARN` / `ERROR`優先領域を確保します。
- 破棄件数はMetricで保持します。
- Log Queue待ちでGuildBattle Threadを停止させません。

正常なゲームルール拒否を要求ごとにLogへ出さずMetric集約します。

## ReplayQueue

- bounded queueです。
- 成立した操作だけを追加します。
- 状態反映とRequestSequence更新後に追加します。
- 追加順は処理成立順と一致させます。
- Eventを破棄しません。
- Queue満杯時だけ、空きができるまで要求処理を待機します。
- Replay WorkerがSerialize、file追記、Private API保存を担当します。出撃Eventは成功Responseより前に同Worker経由でDB保存を完了し、後続の通常QueueではDBを重複書込みせずFile追記だけを行います。

System Log Queueの大量発生でReplayを阻害しないよう、Queueを共有しません。

## Replay file

仕様のファイル名を使用します。

```text
./log/guild_battle/<生成時刻(YYYY_MMDD_HHMMSS)(JST)>_<GuildBattleID>_replay.pb
```

Formatは`GuildBattleReplayEnvelope`のlength-delimited Protocol Buffers列です。

- 各Message前にprotobuf varint長を付与します。
- DBへのEvent先行確定が済んでもFile未追記の場合は、起動後にDBの`event_index`順に不足Eventを補完します。
- JSONへ変換しません。
- `process_type`と`oneof payload`を対応させます。
- 最初のEventは`event_index=1`のCreate Eventです。以降はGuildBattleIDごとにEvent番号を1ずつ増やし、DB/Fileへ同じ番号を記録します。
- Create EventにInitialSeed、Guild、`GuildBattleInitialSnapshot`、Versionを含めます。

## Replay復元

```mermaid
flowchart TD
    F[Replay file] --> C[Create Event読込]
    C --> I[InitialSnapshot + InitialSeed + VersionでRuntime復元]
    I --> E[Eventを成立順に1件ずつ適用]
    E --> M{残Event?}
    M -->|Yes| E
    M -->|No| X[最終状態]
```

復元時は現在のDB可変値を初期状態として使用しません。

Replay fileは`event_index`を1から連続する順番で検証する。欠落・重複・順序異常・末尾の不完全なlength-delimited Envelopeは、DB側の同一GuildBattleID・同一番号のEventを照合して復元可能な場合だけ復旧する。DBとFile双方に該当番号がない場合は破損扱いとし、再生しない。DBとFileの同一番号でPayloadが異なれば自動採用せず破損扱いとする。DB側にも必要なデータがなければ、当該Replayを破損データとして扱い再生しない。出撃の成功Response後のClient通信状態はServer上の成立済み操作を巻き戻す条件としない。同一出撃の重複適用は既存のRequestSequenceとOperation IDの規則に従う。

## Credential Redaction

以下はSystem Logへ出しません。

- Password
- AccessToken
- RefreshToken
- DiscordAuthorizationToken
- Cookie全体
- Authorization相当Header
- mTLS秘密鍵

Request/ResponseをLog化する場合は該当fieldを削除または固定文字列化します。

## Request / Trace ID

Public APIがRequest IDを生成します。Trace対象ならTrace IDも生成・伝播します。

Clientが指定したIDを正本にしません。

## Security Event集約

RequestSequence不一致や不正ID等の高頻度Security EventはMemoryで集約し、最初の発生と一定期間ごとのSummaryをSystem Log Queueへ流します。

集約期間等の「推奨初期値」は運用Configurationであり、設計上の不変定数にはしません。

## DB送信Failure State

GuildBattle中のDB更新またはReplay保存が失敗した場合、Retry可能な一時的な失敗・Timeout・結果不明に限り、初回から通算5秒の枠内で同一Operation IDを最大1回だけ再試行します。確定失敗・再試行失敗・通算5秒経過のいずれかでRecoveryへ移行します。

```mermaid
stateDiagram-v2
    [*] --> normal
    normal --> retrying: Retry可能な一時障害（5秒内）
    normal --> recovery: 確定失敗・通算5秒
    retrying --> normal: 同一要求Retry成功
    retrying --> recovery: Retry失敗・通算5秒
    recovery --> recovery: 以後の送信予定をlocal保存
```

Recovery状態では、それ以降の対象GuildBattle中DB送信を停止して送信予定データをGameServerの永続ローカルJournalへ保存します。ここでいう**Journal**とは、DB障害中に成立した操作をDB確定まで一時的に記録する、Event Index・Operation ID・元要求・チェックサム付きの追記型ログであり、通常のSystem LogやPlayer向けReplay画面ではありません。

## Event採番と耐久確定順序

同一GuildBattleの成立操作はGameServer上の単一のEvent確定キューで番号を順に予約し、番号`n`のDB COMMIT（正常時）またはJournal耐久保存（Recovery時）が確定するまで番号`n+1`の成立確定・成功応答を行わない。Createは`event_index=1`とする。Event番号・Operation ID・Payloadの対応はDBとJournalとReplay fileで同一に維持する。DBへは同一Operation ID・Event Indexを使うため、Retry/再送で二重加算をしない。

ローカルJournalはEventごとのJSON不変レコードとし、`/var/lib/game-server/recovery/guild_battle_<GuildBattleID>_<InstanceID>/event_<index>_<operation-id>.json`へ保存する。一時ファイル作成→Payloadと検査用SHA-256書込→ファイル`fsync`→原子的rename→親ディレクトリ`fsync`完了を1レコードの成立境界とする。永続化が未完了なら成功応答を返さない。再起動時にはHash・Event Index・Operation ID・Payloadを検証し、未完成の一時ファイルは成立扱いしない。

## Recovery file

保存先:

```text
/var/lib/game-server/recovery
```

ファイル名:

```text
guild_battle_<GuildBattleID>_<GameServerInstanceID>/event_<EventIndex>_<OperationID>.json
```

UTF-8 JSONに以下を保存します。

- 元Private API名
- `X-Operation-ID`
- Request Payload（protobufバイト列のBase64）
- Event Indexおよび保存順序
- Payloadを検証するSHA-256

本番ではPersistent Volumeへmountします。

## Recovery再送

騎士団戦終了時には対象Battleの保存済みEventを番号順で再送します。GameServer起動時はJournalの検証と状態照会を行い、**終了済みBattle**のEventのみ再送します。進行中Battleの保存Eventは保全し、Battle終了時までDB送信を再開しません。

- 保存済みOperation IDを変更しません。
- 1件でも失敗した場合、fileを残します。
- 全件成功した場合だけfileを削除します。

Recovery file容量・file件数の仕様に記載された推奨値は監視・運用Configurationとして扱います。

## CompleteGuildBattle例外規則

CompleteGuildBattleは一般Recovery送信規則と別です。

- 初回失敗後、同一Operation IDで1回だけRetryします。
- Retryも失敗した場合、Error Logを保存します。
- 通知有効ならDiscord Botへ通知します。
- 原因調査・復旧は運営手動です。
- 完了Transactionが部分Commitされないことを保証します。

## Metrics

少なくとも仕様にある以下をCollectorへ渡します。

- API要求 / 拒否数
- GuildBattle処理時間
- RequestSequence不一致件数
- Owner不一致件数
- ReplayQueue要素数 / 高水位
- System Log破棄数
- DB送信失敗数
- Recovery file件数

PlayerID、GuildBattleID、Request ID等を高Cardinality Metric Labelにしません。

## 参照資料

- `design/system/log.md`
- `design/server/game_server.md`
- `design/server/guild_battle.md`
- `design/server/data_base.md`
- `design/system/guild_battle_replay.proto`
- `design/operation/operation.md`

## 5秒上限とBattle終了時の一括送信

- 騎士団戦のDB送信Workerは初回要求開始から5秒以内にCOMMIT確認できない場合、明示的な確定失敗または1回Retry失敗の場合に当該BattleをRecovery状態へ移行する。同BattleのDB送信は終了まで停止する。1回Retryは合計5秒の範囲内に限る。
- 正常時の出撃の成立条件はDB COMMIT、Recovery移行後は専用永続Journalのファイル`fsync`・原子的rename・親ディレクトリ`fsync`完了とする。ローカル保存に失敗した要求は成功応答しない。
- Eventの番号・Operation ID・要求Payloadを失わないようReplayQueueとRecovery Workerを連携し、DB結果不明時も同一Operation IDで保存する。Battle終了後にEvent番号順で一括再送し、DB側で既存COMMIT済みのEventを冪等に照合する。
- 旧図の「Retry失敗」だけでなく**5秒経過**もRecovery遷移条件とする。GameServer起動時に進行中BattleのDB送信を勝手に再開しない。

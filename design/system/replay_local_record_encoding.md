# ローカルReplay記録・Event Hash・署名検証形式（v2）

## 目的と成立境界

騎士団戦の処理スレッドはディスク・DB I/Oを直接行わない。通常の非出撃Eventは専用Workerが**署名付きReplay WALを耐久保存した後**に正本状態とRequestSequenceを確定して成功応答を返す。DB反映とReplay File保存は成立順に非同期処理する。出撃は通常時DB COMMIT、Recovery中は署名付きJournal耐久保存、酒場は正常時DB同一Transactionを優先する。書込待機を無くすことは保証せず、同期DB往復を通常Eventの成功条件にしない。

**Eventの同一性を表す`event_hash`と、保存媒体ごとの署名済みレコードを表す`record_hash`を分離する。** Event HashはWAL・Journal・DBのいずれに保存しても同一値となる。媒体を切り替える際に同じEventへ新しいEvent番号を振ったり、媒体別Record Hashを次Eventの前Hashに使用したりしない。現段階は実行前の仕様のためv1形式を生成せず、本v2のみを生成・受理する。既存署名記録の互換移行を暗黙に行わない。

## 共通のByte Encoding

- `u8`は符号なし1byte、`u32`と`u64`は符号なし固定長Big Endian。`str`は`u32`で示したByte長＋UTF-8 Raw Bytes、`bytes`は`u32` Byte長＋Raw Bytes。Unicode正規化は行わず、長さ超過、不正UTF-8、無効IDは拒否する。
- `envelope_wire`は成立Eventの`GuildBattleReplayEnvelope`をフィールド番号昇順で決定的にSerializeした生Byte列。未知フィールドは拒否し、proto3既定値は通常のwire規則に従い省略、繰返しフィールドは定義された要素順を保持する。Serialize後の**生Byte列を一度固定**し、再生・再送時に別のByte列へ再Serializeして置き換えない。`process_type`・`oneof payload`・`event_index`と元Requestの整合を検証する。
- `event_bytes = ASCII("GB-EVENT-V2\0") || u64(guild_battle_id) || u64(event_index) || str(operation_id) || bytes(envelope_wire) || prev_event_hash[32]`、`event_hash = SHA256(event_bytes)`とする。初回Createの`event_index=1`は`prev_event_hash`を32byteのゼロ、以後は**直前の成立Eventの`event_hash`**とする。これによりDBと媒体の連鎖が一致する。
- `record_kind`は最初の成立経路を表す`1=WAL`、`2=Recovery Journal`、`3=DB先行（Create・通常時出撃・酒場等）`。これは**保存先を表す可変フラグではない**。`record_bytes = ASCII("GB-LOCAL-RECORD-V2\0") || u8(record_kind) || str(instance_id) || str(signing_key_id) || bytes(event_bytes) || str(private_api_method) || bytes(private_request_wire)`とする。`private_request_wire`は対応するPrivate APIの送信Requestの固定済みwire Byte列。`event_bytes`でバインドしたReplayとRequestの意味上の不一致は拒否する。DB先行イベントで別途Journalへ退避する場合も最初に確定したRequest Byte列を使う。
- `record_hash = SHA256(record_bytes)`、`signature = Ed25519.sign(private_key(signing_key_id), ASCII("GB-LOCAL-SIGN-V2\0") || record_hash)`。記録は`version=2`、EventとRecordの全フィールド、`event_hash`、`record_hash`、`signature`を保存する。JSONではbyte配列をpaddingなしBase64url、32byte Hashと64byte署名を小文字Hexとし、検証時には上記のRaw Bytesから全Hashと署名を再計算する。署名鍵IDは別途保護した公開鍵台帳で解決し、秘密鍵はWAL/Journal/DBのイベント本文やSystem Logへ置かない。

## WAL・Journal・DBの同一Event照合

1. GuildBattle単位の直列SequencerがIndex、Operation ID、前Event Hash、Envelope Byte列を**仮予約**する。先行Eventの成立確定前に後続Eventを成功応答しない。先行EventがWAL/Journalで耐久保存されれば、DBが未COMMITでも次Eventの成立に進める。未成立Eventの番号は再利用可能だが、成立済み番号は再利用しない。
2. 通常Eventは署名付きv2記録をReplay WALの不変ファイルへ保存する。一時ファイル→file `fsync`→同一Filesystemの原子的rename→親ディレクトリ`fsync`の完了が成立境界。DB Workerは番号順にCOMMITし、DBのEvent Hashを同一Transactionで更新する。独立したReplay FileはDBから欠損分を再構築できる。
3. DB先行EventはPrivate APIがOperation ID、Event番号、Raw EnvelopeとDBアンカーから`event_hash`を計算し、**Replay Eventの保存・Anchor更新・当該操作の状態更新を同一TransactionでCOMMIT**する。GameServerは同じEvent Bytesを算出・保持し、DB結果不明でRecoveryへ切り替える場合は元Requestと同一Event Index/Operation IDの署名付きv2記録（`record_kind=3`）をJournalへ耐久化する。既にCOMMITしていた場合はDBの既存Eventと一致することを検証し、二重適用しない。
4. WAL耐久化済みのEventをJournal側にも残す場合は**署名済み不変記録をByte単位で複製**し、`record_kind`・署名・Event Hashを変更しない。同じEventの複数媒体レコードでは`(GuildBattleID,event_index,OperationID,event_hash,envelope_wire)`の完全一致を必要とし、異なる`record_hash`であっても同じEventを別番号として扱わない。ただし同一署名記録の複製以外でRecord内容が不一致なら隔離する。
5. ローカル記録の検証では**署名、鍵ID、全Byte長、`record_hash`、`event_hash`、`prev_event_hash`、連続Index、DB確定済みOperation ID/Raw Envelope/Anchorの一致**を確認する。DB既存確定値と不一致の記録は上書きしない。DB未反映部分は検証済みの連続EventだけをPrivate APIの同一Operation IDで冪等適用し、Replay Fileの最終欠損判定はその後に行う。DBへ送信するRequestは署名に結び付いた固定済みRequestと一致させる。
6. 鍵交替は新Recordから新`signing_key_id`を使用し、既存Recordの署名を付け替えない。未処理Eventの公開鍵は削除しない。署名・Anchor検証に失敗した場合は隔離し、復旧を成功扱いにしない。ローカルWAL/Journalを**DBの署名なしReplay Fileよりも無条件に優先**することはない。

## 性能・故障時の保証範囲

- 署名生成と耐久書込みは専用Workerが担当し、Battle処理Threadでは実行しない。順序が維持できる場合は、既に待機している複数記録を**追加の待機時間を意図的に設けず**同一Group Commitで同期してよい。DBの往復待機を全通常Eventへ追加しない。
- Queue高水位、Persistent Volume容量不足、署名・同期・renameの失敗時は**成功応答を返さない**。作業状態・PRNG・RequestSequenceを正本に反映せず、未成立番号の予約を解放する。異なる署名記録の連鎖枝分かれ、DBとLocalの不一致を自動修復しない。
- 過去DB COMMIT済みのEventはDB正本として保持する。異常終了で未耐久の受付Queueが消えた場合の自動復元・他InstanceへのVolume移管は必須としない。完全消失したローカル末尾を**Hash/署名のみで検出できるとは主張しない**。復旧できないBattleは完了扱いせず保留・障害状態とし、個人運営方針どおりデータ消失を許容する。
- 最低限のテスト対象は、Createの全ゼロ初期Hash、WALからJournalへの切替、同一Eventの二重配置、DB先行EventのTimeout、異Payload・不正署名・鍵世代変更・末尾切断・DBアンカー不一致、WAL `fsync`失敗時の非応答、通常EventがDB COMMITを待たず応答できることとする。

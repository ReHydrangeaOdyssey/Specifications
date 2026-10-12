# ローカルReplay記録の署名対象と検証形式（v1）

通常EventのReplay WALとDB障害時のRecovery Journalで同じバイナリエンコーディングを使用する。JSON保存形式は転送用の器であり、JSONの空白・キー順序を署名対象としない。**署名対象は以下の規則で組み立てたByte列のみ**とする。未認証・不完全な記録をDB正本に昇格させない。

## Canonical Bytes

- `u8`は符号なし1byte、`u32`/`u64`は符号なし整数のBig Endian固定長。文字列はUTF-8で、`u32`のByte長＋Raw Bytesで表す。文字列にUnicode正規化を加えない。各長さが規定範囲外なら拒否する。
- `bytes`は`u32 length || raw bytes`。ProtoBuf Payloadはイベント成立時に確定した**Raw wire bytes**を保存し、復旧時に再Serializeしたバイト列とすり替えない。
- フィールド順は`ASCII("GB-LOCAL-EVENT-V1\0") || u8(record_kind) || u64(guild_battle_id) || str(instance_id) || u64(event_index) || str(operation_id) || str(signing_key_id) || bytes(payload) || prev_hash[32]`。`record_kind=1`がReplay WAL、`2`がRecovery Journal、それ以外は拒否。
- `record_hash = SHA256(canonical_bytes)`。`signature = Ed25519.sign(private_key(signing_key_id), ASCII("GB-LOCAL-SIGN-V1\0") || record_hash)`。署名は64bytes、Hashは32bytes。JSONではPayloadをunpadded Base64url、Hash/prev_hash/署名を小文字Hexで記録し、再読込時にはCanonical Bytesを組み直して再検証する。
- `event_index=1`の前Hashは`00`を32byte並べた固定値とし、以降は**直前の成立Event**の`record_hash`を使用する。WAL→Journal切替も直前EventのHashを継承する。鍵切替では新Eventに新しい`signing_key_id`を記録し、旧署名の検証用公開鍵を未処理Recordが存在する間は保持する。

## 成立条件と信頼境界

- WAL/Journalの原子的書込・file fsync・親ディレクトリfsyncが成功した後でのみ成立する。未成立予約のHashはチェーンに含めず、同Event番号は未成立要求へ再割当可能。成功応答後の番号は再利用しない。
- 復元時はVersion・Byte長・署名・Hash鎖・連番・Operation IDとDBの確定Anchorを検証し、一致した記録だけ冪等にDBへ適用する。秘密鍵が失われて検証不能なら自動的な正本化を行わない。
- v1と異なるエンコーディングへの変更は新Versionで行い、既存Recordの解釈を暗黙に変更しない。テストではCreate先頭ゼロHash、通常2Event、WAL→Journal、鍵世代変更、各1byte改ざん、JSONキー順序入替が署名検証結果へ及ぼす影響を確認する。

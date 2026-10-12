# 本設計で固定しない事項

## 未決定事項

設計上未確定の実装契約と運用値を以下に列挙する.

- [U-03] Public API ServerのHTTPS Origin（静的Clientの配布先は`https://rehydrangeaodyssey.github.io/`）.
- [U-05] HTTP/2 + TLS 1.3の対象ブラウザでの実通信検証結果.
- [U-07/08] 最小対応ブラウザを含む各端末でのフォルダ一括選択・元ファイル削除権限と実装可否（未対応環境はコピーのみ）.
- [U-09] AssetDictionaryのRelease Asset内の実ファイル名・配布物の完全性検証方法。最新/指定tagの取得方法と辞書Schemaは`design/client/client.md`で確定済み。
- [U-11/12] 手動区分・対象ID・原本ファイル名と取込中のPathを持つ割当メタデータの正確なSchema（保留/一時保存PathはClient仕様で確定）。
- [U-14/15] Versionごとの具体的な配置差分、移行対象と衝突時の移行表。中断後は移行マーカーで最初から再実行し、個別取込は自動再開しない。
- [U-19] `cridecoder`のiPhone Safari/WASM実機動作・依存ライセンス検証後の最終採否.
- [U-20] HCA出力は常にステレオ2ch、1ch入力は左右へ複製し、ループ真偽は`hca_config.json`で設定。設定ファイルと各HCAの実際の対応Path・鍵探索ライブラリの採否・実機検証結果は未確定。
- [U-21] 暫定先読み500ms/補充250msの実機欠音評価結果（数値は最終最適値ではない）.
- [U-22] 実機FPS試験に使用する具体端末, 実測結果. GPU/RAM利用率は合否閾値として使用しない.
- [U-24] OPFSの非同期APIとWorker内同期APIの用途別比較結果.
- [U-29] Discord Botの本番配置先（保留）.
- [U-30] Coordinator運営用APIのListener/Portおよび操作ごとの運営Payload. 通信方式とPath形式は`design/system/api_transport.md`に従う.
- [U-31] `design/operation/operation.md`の推奨初期値の最終運用値.
- [U-44] 進行中GuildBattleのGameServer異常終了後の別GameServerへの自動復旧方式.


## 参照資料

- `design/system/public_api.proto`
- `design/server/public_api.md`
- `design/system/rust_dependencies.md`
- `design/system/network.md`
- `design/game/master_data_pipeline.md`
- `design/server/game_server.md`
- `design/server/guild_battle_coordinator.md`
- `design/test/test_policy.md`
- `design/client/client.md`
- `design/client/scene_transition.md`

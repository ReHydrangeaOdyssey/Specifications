# 本設計で固定しない事項

## 未決定事項

設計上未確定の実装契約と運用値を以下に列挙する.

- [U-03] Public API ServerのHTTPS Origin（静的Clientの配布先は`https://rehydrangeaodyssey.github.io/`）.
- [U-05] HTTP/2 + TLS 1.3の対象ブラウザでの実通信検証結果.
- [U-07/08] 最小対応ブラウザを含む各端末でのフォルダ一括選択・元ファイル削除権限と実装可否（未対応環境はコピーのみ）.
- [U-09] AssetDictionaryリポジトリ内の辞書配布ファイルURL, シリアライズ形式, 更新時の整合検証.
- [U-11/12] ユーザー用素材区分から具体的Pathへの対応, 任意素材に関する割当メタデータの形式.
- [U-14/15] `game_info.json`の具体的キー・差分移行定義.
- [U-19] `cridecoder`のiPhone Safari/WASM実機動作・依存ライセンス検証後の最終採否.
- [U-20] HCAの再生出力はステレオ2チャンネルに確定. 1チャンネル素材の扱い, 辞書におけるループ区間のデータ形式, 対象端末のステレオ実機検証結果は未確定.
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

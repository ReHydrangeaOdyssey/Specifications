# 本設計で固定しない事項

## 未決定事項

回答済みの変更は各個別仕様・設計に反映した. ここではユーザー回答だけで確定できない内容と, 今回回答対象外の既存項目だけを残す.

- [U-03] GitHub Pagesの正式URL・独自ドメイン採否, 公開Public APIのHTTPS Origin.
- [U-04] 認証Origin/戻り先URI, 一度限りの認可コード交換APIのMethod/Path/Protocol Buffers schema等の実装契約. 方式は`design/system/network.md`に確定.
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
- [U-25] Public APIのHTTP Method / Path.
- [U-26] `public_api.proto`へのgRPC Service追加の採否.
- [U-27/28] Private APIなどComponent間通信のMethod / Path, Protocol Buffers field number・wire schema・正本ファイル.
- [U-29] Discord Botの本番配置先（保留）.
- [U-30] Coordinator運営用APIの具体的Listener・Port・Method/Path・wire schema（mTLS認証と通信経路のみ既定）.
- [U-31] `design/operation/operation.md`の推奨初期値の最終運用値.
- [U-32/33] 騎士団の武器庫/食糧庫/鍛冶屋補正を既存戦闘計算へ入れる位置・順序・スナップショット反映段階.
- [U-34/35/36] 酒場最大3回の集計主体, 最大BP上限, 回復操作API・RequestSequence・永続化方式.
- [U-37/38] 施設レベルアップ用ゴールド所持主体・初期量・保有量, 消費量・権限・更新API/処理.
- [U-44] 進行中GuildBattleのGameServer異常終了後の別GameServerへの自動復旧方式.

## プロトタイプで検証済みの事項

- [U-02] PWAインストール・ホーム画面からの起動等はプロトタイプで検証済み（開発者申告）. 検証端末・OS・ブラウザ・試験記録の詳細は提供されていないため, アルファ/ベータの合格判定へ転用しない.

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

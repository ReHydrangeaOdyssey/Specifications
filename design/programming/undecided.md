# 本設計で固定しない事項

## 未決定事項

設計上未確定の実装契約と運用値を以下に列挙する.

- [U-03] Public API ServerのHTTPS Origin（静的ClientはCloudflare Pagesで配布し、Originは実配備時に`client_origin`で設定する）.
- [U-05] HTTP/2 + TLS 1.3の対象ブラウザでの実通信検証結果.
- [U-07/08] 最小対応ブラウザを含む各端末でのフォルダ一括選択・元ファイル削除権限と実装可否（未対応環境はコピーのみ）.
- [U-09] AssetDictionaryの実公開Release Assetの有無および実際の配布内容との照合。辞書本体Asset名と同一Release内のSHA-256検査値Asset名との照合方式はClient保存契約で確定済み。
- [U-11/12] 手動割当メタデータはClient保存契約で定義済み。Character/Actionの機械生成不能な全件対応表は必須要件としない。ユーザー登録済み構成セットの実データに応じてClient内で参照を解決する。
- [U-19] `cridecoder`のiPhone Safari/WASM実機動作・依存ライセンス検証後の最終採否.
- [U-20] HCA出力は常にステレオ2ch、1ch入力は左右へ複製し、ループ真偽は`./assets/sound/bgm/`（ディレクトリ境界と大文字小文字を区別し、配下のサブディレクトリを含む）への配置で判定。個別のループ設定Fileは使用しない。鍵キャッシュ形式はClient保存契約で定義済み。鍵探索ライブラリの採否と実機検証は別途確認する。
- [U-21] 暫定先読み500ms/補充250msの実機欠音評価結果（数値は最終最適値ではない）.
- [U-22] 実機FPS試験に使用する具体端末, 実測結果. GPU/RAM利用率は合否閾値として使用しない.
- [U-24] OPFSの非同期APIとWorker内同期APIの用途別比較結果.
- [U-29] Discord Botの本番配置先（保留）.
- [U-30] Coordinator運営用APIのListener/Portおよび操作ごとの運営Payload. 通信方式とPath形式は`design/system/api_transport.md`に従う.
- [U-31] `design/operation/operation.md`の推奨初期値の最終運用値.
- [U-44] 進行中GuildBattleの別GameServerへの完全な戦闘続行は現行要件外。Owner消失後の別GameServerへの完全再現とWAL/Journal Volumeの自動再Attachは要件外。取得可能な確定済みデータだけ保全し、検証不能なら保留する（未保存データの消失は許容）。


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

## 実体確定時のみ埋める運用値

- GameAssetsの代替画像は実ReleaseにAssetが公開された時点で、**論理代替画像ID→Release tag→実Asset名→検証用情報**を配布設定で一意に対応付け、実体と照合してからゲーム開始条件の検証対象へ登録する。未公開の名前・tag・URLを仕様へ仮置きしない。公開前または取得失敗時には未検証画像を有効とせず既存のゲーム開始エラーを表示する。
- Public APIのHTTPS Originは**配備先確定時のみ**静的設定の`public_api_origin`へ登録し、Client接続先・Public API側の許可Client Origin/CORS・認証Callback URI・CookieのHost/SameSite/Domain設定を同じ環境で照合する。仮のドメインを設定しない。未設定中はClientのローカル機能だけを提供する。
- アセット辞書のPathは生成側がOPFS Root相対`./assets/`始まりとして出力する。Clientの二重連結はしない。辞書更新時の不要素材はcache退避する。

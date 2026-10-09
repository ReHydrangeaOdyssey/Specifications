# 本設計で固定しない事項

## 結論

以下は現行仕様で固定されていない、または明示的に定義しないとされているため、プログラミング設計でも決定しません。

- ログイン・Server未接続時に利用できる具体的なゲーム機能と必要なローカルデータ
- ログイン・Server未接続状態から接続可能状態へ戻った場合のClient側状態の扱い
- 追加画像のPNG以外の受け入れ可否, 容量・解像度制限, キャラクターへの画像割当情報の保存先・保持期間・復元方法, 再割り当て・削除規則（PNG/HCAファイル本体の保存先はOPFSに確定済み）
- キャッシュクリアの対象範囲および追加した画像・キャラクターとの対応付けへの影響
- アセット追加操作の具体的UIフロー（独立シーンの有無を含む）, Safari/Chromeにおけるユーザーフォルダ選択の具体的実現方法
- 汎用2D描画エンジンは不採用とするが, 描画以外のUI Frameworkの採否は未指定
- HTTP/2 over TLS 1.3 + Protocol BuffersおよびHTTP/2 Response streamに対応するWebブラウザ側のAPI呼び出し方法と具体的な通信API・ライブラリ（通信方式は定義済み）
- 対応するiOS / Android / Safari / Chromeの最小バージョン, PWA配布・インストール方法
- `cridecoder`のiPhone Safari/WASM上でのビルド・音声再生・ピークメモリ・ライセンス監査を経た最終採否
- HCAのループ・サンプリングレート・暗号化条件, PCM先読み量, 同時SE数など実機検証に基づく対応範囲・性能基準
- GPU負荷・メモリ・FPS・WASMサイズの合格閾値と本番Release最適化設定
- OPFS内のバージョン命名規則・検証内容・容量制限・保存可能期間およびブラウザごとの制限
- 細かなランダムアクセス用`FileSystemSyncAccessHandle`の必要性と採否（初期方式は通常の非同期API）
- MasterData編集原本の具体形式
- Public APIのHTTP method / HTTP path
- `public_api.proto`にgRPC Serviceを追加すること
- Discord Botの本番配置先
- GuildBattleCoordinatorが内部APIを受信する場合のServer構成
- 推奨初期値として記載された運用値の最終運用値
- 仕様上未確定のゲーム効果・数値式
- 騎士団施設の武器庫・食糧庫・鍛冶屋について, レベルごとの攻撃力・最大HP・防御力補正量および計算式への適用位置
- 酒場のBP回復量・回復方法・発動条件, 最大3回の集計単位とリセット条件
- 施設レベルアップ用ゴールドの所持主体・初期値・保有量管理, 施設ごとの消費量・権限・更新API/処理方式（ゴールド獲得クエスト自体は現段階の再現対象外）
- BP50回復薬の日次10個配布を実行する契機・対象Playerの確定タイミング・未配布日の扱い, 対象ItemIDの確定方法
- 日次配布の所持数加算と騎士団戦中のGameServer所持数スナップショット・`UpdatePlayerItem`絶対所持数更新が重なった場合の同期方法
- 進行中GuildBattleをGameServer異常終了後に別GameServerへ自動復旧する方式

## ライブラリ選定と既存仕様の確認により定義済みとなった事項

- ClientはRust/WASMのWeb Clientとし, iPhone Safari/PWA・Android Chrome/PWAを対象とする.
- WebGL 2の独自スプライトバッチ描画とブラウザ`createImageBitmap()`によるPNGデコードを使用する.
- `wasm-bindgen`, `web-sys`, `js-sys`, `wasm-bindgen-futures`をブラウザ接続に用いる. `cridecoder`はHCAデコードの採用候補とし, 実機検証まで最終確定とはしない.
- Web Audio APIでPCM再生し, 長い音声は`AudioWorklet`と`MessagePort`によってPCMチャンクを供給する.
- PNG/HCAファイルは選択フォルダからOPFSへコピーし, OPFSのバージョン別ディレクトリへ配置する. GameServerからPNG/HCAを配信しない.
- ClientとPublic API Server間はHTTP/2 over TLS 1.3 + Protocol Buffersを正とし, `SubscribeGuildBattleUpdates`はHTTP/2 Response streamを使用する. WebSocketはPublic API通信方式に採用しない.

## 実装時の扱い

未定義事項について、既存挙動を想定したDomain Logicやテスト期待値を追加しません。必要になった時点で仕様書を更新してから実装へ反映します。

## 情報源

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
- 添付`rust_wasm_png_hca_library_selection(1).md`（2026-10-09）, 第1～7節.

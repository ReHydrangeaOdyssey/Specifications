# 本設計で固定しない事項

## 未決定事項

- 対応iOS/Androidの最小OSバージョン, PWAインストール手順, 初期プロトタイプのローカルWebサーバーのIPアドレス・ポート・サーバーソフトウェア, 正式公開先（Vercel／GitHub Pages）・公開URL・独自ドメイン
- 正式公開先とPublic APIのSite/Origin構成（`SameSite=Strict` Cookieを維持できる構成）, HTTP/2 + TLS 1.3の対象ブラウザ実通信検証
- アセット追加シーンの戻り先・戻り操作, Safari/Chromeでのファイル/フォルダ取り込み操作, 元ファイル削除を伴う「移動」の権限と実現方式
- Server配布の二段SHA-256辞書の取得API・配布時期・シリアライズ形式, ファイル名SHA-256入力前のUnicode正規化の扱い, OPFS内の割当情報の具体形式, 同名時の上書き規則
- OPFSセマンティックバージョン別ディレクトリの詳細なPath・検証基準・中断復旧手順, ブラウザ固有のquota/退避/削除, `cache`フォルダの具体的配置階層
- `cridecoder`のiPhone Safari/WASM上のビルド・再生・メモリ・ライセンス監査を経た最終採否
- 22,050Hz HCAのループ開始/終了位置とチャンネル数, 最適PCM先読み量, 実機性能・欠音検証
- GPU負荷80%, メモリ2GB, FPS30, WASMサイズ500MBの測定方法・範囲・評価端末・測定時間, 本番Release最適化設定の最終値
- `FileSystemSyncAccessHandle`の非同期API比較計測を経た最終採否
- Public APIのHTTP Method / HTTP Path, `public_api.proto`へのgRPC Service追加の採否
- Private APIおよびその他Component間APIの未定義HTTP Method / HTTP Path, Protocol Buffers field number・wire schema・正本ファイル
- Discord Botの本番配置先
- GuildBattleCoordinatorが内部APIを受信する場合のServer構成
- 推奨初期値として記載された運用値の最終運用値
- 騎士団の武器庫/食糧庫/鍛冶屋補正を既存戦闘計算へ入れる位置・順序・スナップショット反映段階
- 酒場最大3回の使用回数の集計主体（Player/Guild等）, 最大BP上限の取扱い, 酒場回復のGameServer API・RequestSequence・永続化方式
- 施設レベルアップ用ゴールドの所持主体・初期値・保有量管理, 施設ごとの消費量・権限・更新API/処理方式
- BP50回復薬の日次0:00配布の実行主体とJob/API, 対象Playerの確定タイミング, 未配布日の取扱い, 対象ItemIDの特定方式
- 日次配布と騎士団戦中のGameServer所持数スナップショット・`UpdatePlayerItem`絶対所持数更新が異常時・遅延時等に重なる場合の同期方式
- 進行中GuildBattleをGameServer異常終了後に別GameServerへ自動復旧する方式

### Client初期プロトタイプの残る詳細

- `proto_type_title.png`・`proto_type_home.png`の画像内容・具体的な保存Path, テスト用ボタンの個数・ラベル・配置先・反応の詳細, プロトタイプ専用ビルド設定の具体値
- 正式な公開先をVercel／GitHub Pagesのどちらにするか, 選択後の配信URLと設定

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

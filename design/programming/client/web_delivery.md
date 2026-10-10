# Web Client配布・プロトタイプ設計

## 概要

本書は`design/client/web_application.md`のブラウザ実行仕様を実装へ接続する。既存のRust/WASM、WebGL 2、OPFS、Web Audio、Server非接続時のゲームプレイ規則を変更しない。

## 静的ファイルの構成

- 静的Webサーバーの公開成果物ルートに`index.html`を配置する。HTMLは`viewport`設定、ゲーム用Canvas、初期化状態・エラー表示領域、ES Module起動処理への参照を持つ。
- JavaScript起動処理は`wasm-bindgen --target web`の生成したES Moduleを読み込み、WASM初期化成功後にRust側のClientを起動する。
- HTML、JS、WASM、CSS、Manifest等の参照URLには配布ルートからの相対Pathを使用し、GitHub Pagesのプロジェクトサイト（`/<repository>/`）でも配布できる構成にする。各ファイルの配置が変わる場合は、ビルド出力の内部参照も同じ公開ルートを基準にする。
- 初期はLAN内のローカル静的Webサーバーを利用する。正式公開先のVercel／GitHub Pagesの選択は未確定とする。いずれの静的配信先にもゲーム状態を更新するサーバー処理や認証秘密情報を置かない。

## ビルドと公開

1. Rustの依存を`Cargo.lock`で固定し、`wasm32-unknown-unknown`ターゲットへReleaseビルドする。
2. Rust crateの`wasm-bindgen`と対応するCLIのバージョンを揃え、`--target web`形式のJavaScript glueとWASMを生成する。
3. HTML、JS、WASM、CSS、およびその段階で利用するManifest・静的ファイルを1つの公開ディレクトリへ収集する。GitHub Pagesを採用する場合は`.nojekyll`も配置する。
4. 初期プロトタイプではこの静的ファイル群をLAN内のローカルWebサーバーから配信し、試験端末から当該サーバーのIPアドレスを直接指定してアクセスする。ホストの具体的なIPアドレス・ポートとWebサーバー実装は未指定とする。
5. HTML・JavaScript・WASM・PNGの取得、WebGL 2初期化、タイトル表示、仮ホームへの遷移、テスト用ボタンの入力反応、再読み込みを確認する。
6. 正式公開先をGitHub Pagesに決定した場合は、GitHub Actions上のビルド・静的参照検証、Pages向けArtifact Upload、`actions/deploy-pages`によるHTTPS配信を使用する。Vercelを選択した場合のデプロイ設定は未定義とする。

## リポジトリ

- Client：`https://github.com/ReHydrangeaOdyssey/Client.git`
- 純粋なゲームロジック：`https://github.com/ReHydrangeaOdyssey/GameLogic.git`
- Server：`https://github.com/ReHydrangeaOdyssey/Server.git`

これらのソース管理先はユーザー指定のものとし、静的ファイルのローカル配信先とは区別する。初期プロトタイプからServerへは接続しない。

## 描画・入力

- WebGL 2のCanvasのCSS表示寸法とDrawing Buffer寸法を区別し、`ResizeObserver`と画面回転後の表示領域変化を検知して`viewport`および描画対象寸法を更新する。
- 最初の論理描画領域は高さ720、幅は表示領域の比率に応じて可変とする。重要UIはSafe Areaと画面端を基準とするアンカー配置を使い、背景は全体表示領域を埋める。
- `devicePixelRatio`とGPU能力に応じて描画バッファを決定し、測定前に高解像度を前提としてGPUメモリを無制限に確保しない。最大描画ピクセル数の具体値は実機測定で決める。
- `PointerEvent`の位置をCanvasの表示領域から論理描画座標へ変換し、同じ領域でHit Testを行う。初期化中は入力を受け付けない。
- 画面方向の固定APIには依存せず、縦画面時は回転案内を表示する。PWA Manifestの`orientation`指定は希望値にすぎない。

## ブラウザAPIと例外処理

- WebGL 2のコンテキスト取得・WASMロード・OPFSアクセス・AudioContext初期化は失敗を検知し、初期化エラーをHTMLの表示領域へ通知する。
- Web Audioの実際の再生・`AudioContext.resume()`はユーザー操作を入口にする。
- OPFSに書き込む機能では`navigator.storage.getDirectory()`を使用し、必要に応じて`navigator.storage.estimate()`で利用状況の近似値を取得する。quota超過は書き込み失敗として扱い、既存の「Clientが自動削除しない」方針を維持する。
- ファイル選択はユーザー操作を起点とする。`webkitdirectory`等はSafari 16.3で動作保証できないため、再帰的なフォルダ取り込みの提供方法は実機検証事項として残す。元ファイルの自動削除は行わない。
- Cookie・Origin・CORSの制約はWASM使用によって回避しない。APIを使用する段階では既存の`design/system/network.md`を優先する。

## プロトタイプと完成版の分離

- 初期プロトタイプ専用ビルドではGameServer・Public API Serverへの通信を行わず、LAN内の静的配信によるWASM・WebGL 2・横画面可変表示・入力・再読込を確認する。認証、MasterData、戦闘結果の正本処理を仮の実装で置き換えない。
- プロトタイプのタイトルには`proto_type_title.png`を表示し、タイトルから遷移する仮ホームには`proto_type_home.png`を表示する。PNGの具体的な画像内容は任意の試験用とし、ゲーム固有の正式UI・アセットとは扱わない。
- 複数のテスト用ボタンを配置し、タッチ・マウスによる入力への反応を確認する。ボタンの個数・ラベル・配置先と各反応の詳細は未指定とする。
- 初期プロトタイプに含めるゲーム画面はタイトルと仮ホームの表示・遷移に限定する。ほかのScene・本番MasterData・戦闘再現・OPFSアセット取り込み・HCA音声は、追加範囲が別途確定するまでこの初期試験の合否条件に含めない。完成版の未接続時制限を取り除かない。
- 本番用ビルドにはプロトタイプ専用の状態変更・仮データ・試験用操作を含めない。両ビルドをコンパイル時の設定で区別し、デプロイ成果物の区分を明確にする。
- 初期プロトタイプではService Workerを登録しない。今後オフラインキャッシュを採用する場合は、更新時の旧WASM/JS混在を防ぐキャッシュバージョン規則を先に追加する。

## 検証項目

| 区分 | 確認事項 |
|---|---|
| 起動 | LAN内の試験端末からローカルWebサーバーのIPアドレスを指定し、HTML・JS・WASMを読み込んでWebGL 2を初期化できる |
| タイトル | `proto_type_title.png`を表示できる |
| 遷移 | タイトルから仮ホームへ遷移し、`proto_type_home.png`を表示できる |
| ボタン | 複数のテスト用ボタンがタッチ・マウス入力に反応する |
| 画面 | 16:9・4:3で重要UIが切れず、背景サイズ・UI配置が再計算される |
| 回転 | 縦画面で案内表示になり、横画面復帰後に描画領域と入力が一致する |
| タッチ | タップとマウスクリックが同じ論理位置を指定できる |
| 配信 | LAN内の複数の試験端末から同じローカル配信先へ接続でき、静的ファイルの相対Path参照が成立する。公開サービスへ移行する場合は採用先別に検証する |
| 異常 | WASMロード失敗・WebGL 2初期化失敗を検知し、再読込操作が可能 |
| 継続 | リロード後も初期化でき、表示はServer通信に依存しない |
| 対応環境 | iOS Safari 16.3以上、Android Chrome 120以上の実機試験結果を記録する |

## 試験環境の制約

- IPアドレス直指定のLAN内配信は静的ファイルの取得・描画・入力を検証するためのものとする。OPFSやPWA等、安全なコンテキストに依存する機能は、LAN内でのHTTPアクセス結果のみを合格根拠にしない。
- 試験用PNG2件はファイル名だけが確定しており、実データの作成・格納Pathは未指定とする。

## 参照資料

- `design/client/web_application.md`
- `design/client/client.md`
- `design/programming/client/client.md`
- `design/programming/directory_structure.md`
- `https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site`
- `https://wasm-bindgen.github.io/wasm-bindgen/examples/without-a-bundler.html`
- `https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API/WebGL_best_practices`
- `https://developer.mozilla.org/en-US/docs/Web/API/HTMLInputElement/webkitdirectory`
- `https://developer.mozilla.org/en-US/docs/Web/API/StorageManager/estimate`

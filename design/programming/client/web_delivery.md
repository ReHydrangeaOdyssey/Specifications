# Web Client配布・プロトタイプ設計

## 概要

本書は`design/client/web_application.md`のブラウザ実行仕様を実装へ接続する。既存のRust/WASM、WebGL 2、OPFS、Web Audio、Server非接続時のゲームプレイ規則を変更しない。

## 静的ファイルの構成

- GitHub Pagesで公開する成果物のルートに`index.html`を配置する。HTMLは`viewport`設定、ゲーム用Canvas、初期化状態・エラー表示領域、ES Module起動処理への参照を持つ。
- JavaScript起動処理は`wasm-bindgen --target web`の生成したES Moduleを読み込み、WASM初期化成功後にRust側のClientを起動する。
- HTML、JS、WASM、CSS、Manifest等の参照URLには配布ルートからの相対Pathを使用し、GitHub Pagesのプロジェクトサイト（`/<repository>/`）でも配布できる構成にする。各ファイルの配置が変わる場合は、ビルド出力の内部参照も同じ公開ルートを基準にする。
- GitHub Pagesは静的ホスティングとして利用し、ゲーム状態を更新するサーバー処理や認証秘密情報を置かない。

## ビルドと公開

1. Rustの依存を`Cargo.lock`で固定し、`wasm32-unknown-unknown`ターゲットへReleaseビルドする。
2. Rust crateの`wasm-bindgen`と対応するCLIのバージョンを揃え、`--target web`形式のJavaScript glueとWASMを生成する。
3. HTML、JS、WASM、CSS、およびその段階で利用するManifest・静的ファイルを1つの公開ディレクトリへ収集する。`.nojekyll`も配置し、Jekyllによる予期しない処理を避ける。
4. GitHub Actions上でビルドと静的参照検証を行い、Pages向けArtifactをUploadし、`actions/deploy-pages`で公開する。デプロイ権限は必要な範囲へ限定する。
5. HTTPSの公開URLへアクセスし、WASM・JS・必要な静的ファイルの取得成功、初期描画、再読込を確認する。リポジトリ名と配布URLは実際の公開設定を確定した時点で指定する。

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

- 初期プロトタイプ専用ビルドではServerへの通信を行わず、WASM・WebGL 2・横画面可変表示・入力・再読込をまず確認する。認証、MasterData、戦闘結果の正本処理を仮の実装で置き換えない。
- 初期の表示確認には、権利問題のない単純図形や開発用の固定表示要素を利用できる。試験で使用したものをゲーム固有の正式UI・アセットと扱わない。
- OPFS・PNG・HCAやゲーム画面のデモが必要になった段階では、その試験用データの仕様が確定してから、プロトタイプ専用ビルドに追加する。完成版の未接続時制限を取り除かない。
- 本番用ビルドにはプロトタイプ専用の状態変更・仮データ・試験用操作を含めない。両ビルドをコンパイル時の設定で区別し、デプロイ成果物の区分を明確にする。
- 初期プロトタイプではService Workerを登録しない。今後オフラインキャッシュを採用する場合は、更新時の旧WASM/JS混在を防ぐキャッシュバージョン規則を先に追加する。

## 検証項目

| 区分 | 確認事項 |
|---|---|
| 起動 | GitHub PagesのHTTPSからJS/WASMを読み込み、初期化状態と画面を表示できる |
| 画面 | 16:9・4:3で重要UIが切れず、背景サイズ・UI配置が再計算される |
| 回転 | 縦画面で案内表示になり、横画面復帰後に描画領域と入力が一致する |
| タッチ | タップとマウスクリックが同じ論理位置を指定できる |
| 設置 | URLの下位Pathを含むGitHub Pages配信でJS/WASM/Manifest等の参照が成立する |
| 異常 | WASMロード失敗・WebGL 2初期化失敗を検知し、再読込操作が可能 |
| 継続 | リロード後も初期化でき、表示はServer通信に依存しない |
| 対応環境 | iOS Safari 16.3以上、Android Chrome 120以上の実機試験結果を記録する |

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

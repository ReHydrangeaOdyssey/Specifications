# Web Client配布・プロトタイプ設計

## 概要

Rust/WASM製Web Clientの静的配布とプロトタイプ実装を定義する。

## 静的ファイルの構成

- 静的Webサーバーの公開成果物ルートに`index.html`を配置する。HTMLは`viewport`設定、ゲーム用Canvas、初期化状態・エラー表示領域、ES Module起動処理への参照を持つ。
- JavaScript起動処理は`wasm-bindgen --target web`の生成したES Moduleを読み込み、WASM初期化成功後にRust側のClientを起動する。
- HTML、JS、WASM、CSS、Manifest等の参照URLには配布ルートからの相対Pathを使用し、GitHub Pagesのプロジェクトサイト（`/<repository>/`）でも配布できる構成にする。各ファイルの配置が変わる場合は、ビルド出力の内部参照も同じ公開ルートを基準にする。
- 初期はLAN内のローカル静的Webサーバーを利用する。正式公開先のVercel／GitHub Pagesの選択は未確定とする。いずれの静的配信先にもゲーム状態を更新するサーバー処理や認証秘密情報を置かない。

## ビルドと公開

1. Rustの依存を`Cargo.lock`で固定し、`wasm32-unknown-unknown`ターゲットへReleaseビルドする。
2. Rust crateの`wasm-bindgen`と対応するCLIのバージョンを揃え、`--target web`形式のJavaScript glueとWASMを生成する。
3. HTML、JS、WASM、CSS、およびその段階で利用するManifest・静的ファイルを1つの公開ディレクトリへ収集する。GitHub Pagesを採用する場合は`.nojekyll`も配置する。
4. 初期プロトタイプではこの静的ファイル群をLAN内のローカルWebサーバーから配信し、試験端末から当該サーバーのIPアドレスを直接指定してアクセスする。
5. HTML・JavaScript・WASM・PNGの取得、WebGL 2初期化、タイトル表示、仮ホームへの遷移、テスト用ボタンの入力反応、再読み込みを確認する。
6. 正式公開先をGitHub Pagesに決定した場合は、GitHub Actions上のビルド・静的参照検証、Pages向けArtifact Upload、`actions/deploy-pages`によるHTTPS配信を使用する。

## リポジトリ

- Client：`https://github.com/ReHydrangeaOdyssey/Client.git`
- 純粋なゲームロジック：`https://github.com/ReHydrangeaOdyssey/GameLogic.git`
- Server：`https://github.com/ReHydrangeaOdyssey/Server.git`

プロトタイプからGameServerおよびPublic API Serverへ接続しない。

## 描画・入力

- WebGL 2のCanvasのCSS表示寸法とDrawing Buffer寸法を区別し、`ResizeObserver`と画面回転後の表示領域変化を検知して`viewport`および描画対象寸法を更新する。
- 基準の16:9背景・UI領域を1280×720とし、論理高さ720・論理幅可変の表示領域中央に配置する。4:3等の幅が狭い表示では背景の左右を切り取りUIを中央へ収め、16:9より幅が広い表示では不足する左右を別背景画像で補完し、UIは中央の基準背景内に配置する。高さ320 CSSピクセル以上を対応対象とする。Safe Areaを考慮する。
- `devicePixelRatio`とGPU能力に応じて描画バッファを決定し、測定前に高解像度を前提としてGPUメモリを無制限に確保しない。最大描画ピクセル数の具体値は実機測定で決める。
- `PointerEvent`の位置をCanvasの表示領域から論理描画座標へ変換し、同じ領域でHit Testを行う。初期化中は入力を受け付けない。
- 起動時に横画面設定を試み、回転案内は表示しない。PWA Manifestの`orientation: landscape`は希望値とし、`ScreenOrientation.lock()`の成否を検出する。
- 表示領域が縦長の場合は、有効表示領域の幅を`W`、高さを`H`として`s = min(W / 1280, H / 720)`で基準ゲーム領域を等倍比率のまま縮小する。縮小後の幅を`1280s`、高さを`720s`とし、ゲーム領域を表示領域の下端中央へ配置する。上側に残る領域だけを補助背景で覆い、画像は中央基準の`cover`相当で描画する。上部背景は入力を受け付けず、UIの当たり判定とCanvas入力座標の逆変換はゲーム領域の配置と倍率を用いる。Safe Area内に操作可能UIを置く。
- 端末の画面方向、ブラウザUIの変化、リサイズ後に基準領域の位置・倍率・補助背景・入力判定を再計算する。

## ブラウザAPIと例外処理

- WebGL 2のコンテキスト取得・WASMロード・OPFSアクセス・AudioContext初期化は失敗を検知し、初期化エラーをHTMLの表示領域へ通知する。
- Web Audioの実際の再生・`AudioContext.resume()`はユーザー操作を入口にする。
- OPFSに書き込む機能では`navigator.storage.getDirectory()`を使用し、必要に応じて`navigator.storage.estimate()`で利用状況の近似値を取得する。quota超過は書き込み失敗として扱い、既存の「Clientが自動削除しない」方針を維持する。
- ファイル選択はユーザー操作を起点とする。`webkitdirectory`等はSafari 16.3で動作保証できないため、再帰的なフォルダ取り込みの提供方法は実機検証事項として残す。元ファイルの自動削除は行わない。
- Cookie・Origin・CORSの制約はWASM使用によって回避しない。APIを使用する段階では既存の`design/system/network.md`を優先する。

## プロトタイプと完成版の分離

- 初期プロトタイプ専用ビルドではGameServer・Public API Serverへの通信を行わず、LAN内の静的配信によるWASM・WebGL 2・横画面可変表示・入力・再読込を確認する。認証、MasterData、戦闘結果の正本処理を仮の実装で置き換えない。
- プロトタイプはタイトルと仮ホームの2画面とする。試験用画像の相対Pathは`assets/prototype/proto_type_title.png`、`assets/prototype/proto_type_home.png`、`assets/prototype/proto_type_fill.png`とし、公開ディレクトリへ同梱する。画像はいずれも1280×720ピクセル、非透過PNGとする。タイトル画像には`TITLE`、ホーム画像には`HOME`を表示し、異なる配色とする。補助背景は操作部品と誤認しない図柄とし、縦画面の上部余白と横長画面の左右余白に用いる。
- タイトル画面は`proto_type_title.png`を表示し、ゲーム領域内のタップ・クリック1回で仮ホームへ遷移する。初期プロトタイプのタイトルにアセット追加・キャッシュ削除の操作ボタンは表示しない。
- 仮ホーム画面には`proto_type_home.png`と`COUNT: N`（初期値`0`）を表示し、「タイトルへ」と「カウント+1」の2ボタンを配置する。「タイトルへ」でタイトル画面へ遷移し、「カウント+1」で`N`に1を加算する。再び仮ホームへ入ったときは`N`を0にする。操作ごとに1回だけ反応させ、タッチ入力から重複したクリックイベントによる二重実行を行わない。
- 16:9基準座標では、「タイトルへ」ボタンを`x=360, y=560, 幅=240, 高さ=80`、「カウント+1」ボタンを`x=680, y=560, 幅=240, 高さ=80`に置く。`COUNT: N`の表示中心は`x=640, y=500`とする。座標原点は基準ゲーム領域の左上とする。
- 縦画面ではカウント表示をゲーム領域の上部中央へ置き、2ボタンをゲーム領域の下部中央に縦並びで配置する。ボタン間隔は8 CSSピクセル、各ボタンの幅はゲーム領域の75%（上限240 CSSピクセル）、高さは48 CSSピクセルを上限としてゲーム領域内に収まるよう縮小する。タップの当たり判定は描画されたボタンの矩形と一致させ、補助背景では操作を受け付けない。
- ボタンはWebGL 2で描画し、`PointerEvent`によるヒットテストで処理する。本プロトタイプの入力と表示状態はClientのローカル状態のみで管理する。
- 初期プロトタイプに含めるゲーム画面はタイトルと仮ホームの表示・遷移に限定する。ほかのScene・戦闘再現・OPFSアセット取り込み・HCA音声は初期試験の対象外とする。
- 本番用ビルドにはプロトタイプ専用の状態変更・仮データ・試験用操作を含めない。両ビルドをコンパイル時の設定で区別し、デプロイ成果物の区分を明確にする。
- 初期プロトタイプではService Workerを登録しない。今後オフラインキャッシュを採用する場合は、更新時の旧WASM/JS混在を防ぐキャッシュバージョン規則を先に追加する。

## 検証項目

| 区分 | 確認事項 |
|---|---|
| 起動 | LAN内の試験端末からローカルWebサーバーのIPアドレスを指定し、HTML・JS・WASMを読み込んでWebGL 2を初期化できる |
| タイトル | `assets/prototype/proto_type_title.png`を表示でき、ゲーム領域へのタップ・クリック1回で仮ホームへ遷移できる |
| 遷移 | 仮ホームで`assets/prototype/proto_type_home.png`を表示でき、「タイトルへ」でタイトルへ戻れる |
| ボタン | 「カウント+1」を1回押すごとに`COUNT: N`が1増え、仮ホームへの再遷移時は0に戻る。タッチとマウスで二重実行しない |
| 画面 | 16:9・4:3・横長画面で背景を中央基準に切り取り・左右追加し、UIを中央配置する。高さ320 CSSピクセル以上で検証する |
| 縦画面 | 縦長表示領域では1280×720のゲーム領域が全体表示されて下端中央へ配置され、上部だけ`proto_type_fill.png`で余白を埋める。2ボタンとカウント表示をゲーム領域内に配置し、タップ位置が一致する |
| 回転 | 起動時の横画面設定を試み、端末が許可しない場合も案内画面を表示せず、縦画面表示およびリサイズで描画領域と入力を再計算する |
| タッチ | タップとマウスクリックが同じ論理位置を指定できる |
| 配信 | LAN内の複数の試験端末から同じローカル配信先へ接続でき、静的ファイルの相対Path参照が成立する。公開サービスへ移行する場合は採用先別に検証する |
| 異常 | WASMロード失敗・WebGL 2初期化失敗を検知し、再読込操作が可能 |
| 継続 | リロード後も初期化でき、表示はServer通信に依存しない |
| 対応環境 | iOS Safari 16.3以上、Android Chrome 120以上の実機試験結果を記録する |

## 試験環境の制約

- IPアドレス直指定のLAN内配信は静的ファイルの取得・描画・入力を検証するためのものとする。OPFSやPWA等、安全なコンテキストに依存する機能は、LAN内でのHTTPアクセス結果のみを合格根拠にしない。

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

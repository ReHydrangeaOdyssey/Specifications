# Web Client配布設計

## 概要

Rust/WASM製Web Clientの静的配布を定義する。

## 静的ファイルの構成

- 静的Webサーバーの公開成果物ルートに`index.html`を配置する。HTMLは`viewport`設定、ゲーム用Canvas、初期化状態・エラー表示領域、ES Module起動処理への参照を持つ。
- JavaScript起動処理は`wasm-bindgen --target web`の生成したES Moduleを読み込み、WASM初期化成功後にRust側のClientを起動する。
- HTML、JS、WASM、CSS、Manifest等の参照URLには配布ルートからの相対Pathを使用し、GitHub Pagesのプロジェクトサイト（`/<repository>/`）でも配布できる構成にする。各ファイルの配置が変わる場合は、ビルド出力の内部参照も同じ公開ルートを基準にする。
- 正式公開先のVercel／GitHub Pagesの選択は未確定とする。いずれの静的配信先にもゲーム状態を更新するサーバー処理や認証秘密情報を置かない。

## ビルドと公開

1. Rustの依存を`Cargo.lock`で固定し、`wasm32-unknown-unknown`ターゲットへReleaseビルドする。
2. Rust crateの`wasm-bindgen`と対応するCLIのバージョンを揃え、`--target web`形式のJavaScript glueとWASMを生成する。
3. HTML、JS、WASM、CSS、およびその段階で利用するManifest・静的ファイルを1つの公開ディレクトリへ収集する。GitHub Pagesを採用する場合は`.nojekyll`も配置する。
4. 正式公開先をGitHub Pagesに決定した場合は、GitHub Actions上のビルド・静的参照検証、Pages向けArtifact Upload、`actions/deploy-pages`によるHTTPS配信を使用する。

## リポジトリ

- Client：`https://github.com/ReHydrangeaOdyssey/Client.git`
- 純粋なゲームロジック：`https://github.com/ReHydrangeaOdyssey/GameLogic.git`
- Server：`https://github.com/ReHydrangeaOdyssey/Server.git`

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

## 検証項目

| 区分 | 確認事項 |
|---|---|
| 画面 | 16:9・4:3・横長画面で背景を中央基準に切り取り・左右追加し、UIを中央配置する。高さ320 CSSピクセル以上で検証する |
| 縦画面 | 縦長表示領域では1280×720のゲーム領域が全体表示されて下端中央へ配置され、上部のみ補助背景で余白を埋める。UIをゲーム領域内に配置し、タップ位置が一致する |
| 回転 | 起動時の横画面設定を試み、端末が許可しない場合も案内画面を表示せず、縦画面表示およびリサイズで描画領域と入力を再計算する |
| タッチ | タップとマウスクリックが同じ論理位置を指定できる |
| 異常 | WASMロード失敗・WebGL 2初期化失敗を検知し、再読込操作が可能 |
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

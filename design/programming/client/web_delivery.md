# Web Client配布設計

## 概要

Rust/WASM製Web Clientの静的配布を定義する。

## 静的ファイルの構成

- 静的Webサーバーの公開成果物ルートに`index.html`を配置する。HTMLは`viewport`設定、ゲーム用Canvas、初期化状態・エラー表示領域、ES Module起動処理への参照を持つ。
- JavaScript起動処理は`wasm-bindgen --target web`の生成したES Moduleを読み込み、WASM初期化成功後にRust側のClientを起動する。
- HTML、JS、WASM、CSS、Manifest等の参照URLには配布ルートからの相対Pathを使用する。配布ルートはGitHub Pagesのユーザー／組織サイトの`/`とする。各ファイルの配置が変わる場合は、ビルド出力の内部参照も同じ公開ルートを基準にする。
- 静的Clientは`https://rehydrangeaodyssey.github.io/`で配布する。配布リポジトリは`https://github.com/ReHydrangeaOdyssey/ReHydrangeaOdyssey.github.io`とし, 独自ドメインは採用しない。静的配布先へGameServerの実行処理・ゲーム状態を更新するサーバー処理や認証秘密情報を置かない。Public API ServerのHTTPS Originは静的配布先とは別途定義する。

## 認証Callbackと配布設定

- GitHub Pages公開成果物の`/auth/callback/index.html`にClient起動用HTMLを配置し、直接アクセス時にもCode交換処理を起動する。
- 静的設定`public_api_origin`は**実配備先が確定した時だけ**指定する単一のHTTPS Origin文字列とし、Path・Query・Fragmentや資格情報付きURLを拒否する。仮のホスト名を埋め込まず、未設定時はローカル機能のみを提供する。設定する際はPublic API側の許可Client Origin・CORS、認証Callback URI、CookieのSameSite/Domain/Host条件を一括照合する。
- Public APIと認証Originは同一とし、`/auth/authorize`の画面はPublic API ServerがHTTPSで配信する。

## ビルドと公開

1. Rustの依存を`Cargo.lock`で固定し、`wasm32-unknown-unknown`ターゲットへReleaseビルドする。
2. Rust crateの`wasm-bindgen`と対応するCLIのバージョンを揃え、`--target web`形式のJavaScript glueとWASMを生成する。
3. Clientの`Cargo.lock`で固定したRust依存関係を対象に`cargo-about`を実行し, ライセンス情報をHTML形式で生成する。Client配布物に含まれるRust依存ライブラリの必要表記と, 自動生成の対象外となる同梱物・ゲーム本体の必要表記をクレジット画面に組み込む。表示用の生成結果がない状態ではRelease配布しない。
4. HTML、JS、WASM、CSS、Manifestに加え, クレジット画面で読むライセンス情報を配布ディレクトリへ同梱する。GitHub Pages向けに`.nojekyll`も配置し, 公開後のクレジット画面から同梱した情報を閲覧可能にする。
5. GitHub Pages向けのGitHub Actionsビルド・静的参照検証、Pages向けArtifact Upload、`actions/deploy-pages`によるHTTPS配信を使用する。

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

## オフライン時のクレジット

クレジット画面が参照するライセンス本文はClient静的配布成果物に同梱し、PWAのオフラインキャッシュ対象へ含める。初回取得とキャッシュ成立後はServer未接続でも閲覧できる。Client更新時はHTML/JS/WASMとライセンス本文を同じバージョンとして切り替える。

## 検証項目

| 区分 | 確認事項 |
|---|---|
| 画面 | 16:9・4:3・横長画面で背景を中央基準に切り取り・左右追加し、UIを中央配置する。高さ320 CSSピクセル以上で検証する |
| 縦画面 | 縦長表示領域では1280×720のゲーム領域が全体表示されて下端中央へ配置され、上部のみ補助背景で余白を埋める。UIをゲーム領域内に配置し、タップ位置が一致する |
| 回転 | 起動時の横画面設定を試み、端末が許可しない場合も案内画面を表示せず、縦画面表示およびリサイズで描画領域と入力を再計算する |
| タッチ | タップとマウスクリックが同じ論理位置を指定できる |
| 異常 | WASMロード失敗・WebGL 2初期化失敗を検知し、再読込操作が可能 |
| 対応環境 | iOS 16.3以上のSafari 16.3以上、Android 8.0以上のChrome 120以上で実機試験結果を記録する（ブラウザを導入可能なOS下限であり, ゲーム動作保証とは区別する） |
| クレジット | タイトルから開いてスクロール閲覧し, 戻るとタイトルへ復帰する。オフラインでも必要なライセンス情報を閲覧できる。生成ファイルの同梱漏れと手動追加分の記載漏れがないか検証する |

## 参照資料

- `design/client/web_application.md`
- `design/client/client.md`
- `design/programming/client/client.md`
- `design/programming/directory_structure.md`
- `https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site`
- `https://embarkstudios.github.io/cargo-about/`
- `https://developer.apple.com/documentation/safari-release-notes/safari-16_3-release-notes`
- `https://support.google.com/chrome/thread/243346420/sunsetting-chrome-support-for-android-7-0-nougat?hl=en`
- `https://wasm-bindgen.github.io/wasm-bindgen/examples/without-a-bundler.html`
- `https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API/WebGL_best_practices`
- `https://developer.mozilla.org/en-US/docs/Web/API/HTMLInputElement/webkitdirectory`
- `https://developer.mozilla.org/en-US/docs/Web/API/StorageManager/estimate`

## アセット辞書の運営設定

Web配布ルートに`./config.cfg`をYAMLで設置する。運営は配布ファイルを差し替えて辞書更新を一時停止できる。`update_asset_dictionary`の既定値は`true`、`asset_dictionary_version`の既定値は`latest`。この設定は静的配布物であり、Clientから変更してServerへ書き戻す機能は設けない。辞書のReleaseの探索は`design/client/client.md`の「アセット辞書取得の設定」に従う。


## 端末側の例外設定

タイトルの設定画面は静的配布設定を直接編集せず、OPFSに保存した`./settings/config_cfg_override.yaml`にある端末上書きの`update_asset_dictionary`・`asset_dictionary_version`、`config.cnf`の2つのbooleanを表示・検証して原子的に保存する。辞書Hash照合OFF時の警告、設定初期化、オフライン編集を確認する。

Web配布ルートの`config.cfg`（運営側YAML）とは独立に、ユーザーが端末内OPFSの`./config.cnf`（YAML）で`verify_asset_dictionary_sha256`と`allow_user_asset_override`を明示設定できる。両者の初期値はそれぞれ`true`・`false`であり、設定の省略や不正時は安全側の初期値とする。Clientが静的配布ファイルをユーザー権限で上書きする経路は設けない。SHA-256検査値Assetとの照合を無効化してもPath/Schema等の構造検証は必須とする。

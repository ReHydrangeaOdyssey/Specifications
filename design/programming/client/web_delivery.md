# Web Client配布設計

## 概要

Rust/WASM製Web Clientの静的配布を定義する。

## 静的ファイルの構成と配布先

- 配布基盤には**Cloudflare Pages**を使用する。実際の公開HTTPS Originは配備時に`client_origin`として設定し、確定していない`*.pages.dev`名や独自ドメインを仮置きしない。Clientの固定Callback URIは`<client_origin>/auth/callback/`で生成し、認証Server側の許可URIとも完全一致させる。
- 公開ルートの`index.html`にViewport、Canvas、初期化・エラー表示、ES Module起動処理を設ける。`/auth/callback/index.html`は直接アクセス時にも認可コード交換処理を開始できるようにする。JSは`wasm-bindgen --target web`の生成ES ModuleからWASMをロードする。全ての内部参照URLはCloudflare Pagesの配布ルートに対する相対Pathとし、ビルド・Service Worker・PWA Manifestの参照先を一致させる。
- **配布用HTML・JavaScript（ES Module、分割チャンク、Service WorkerのJSを含む）・WASMは各ファイルの非圧縮サイズを25,000,000 byte以下（25MB以下）**とする。ファイル群の合計サイズには上限を設けない。ZIP/Gzip/Brotliで圧縮した転送量では判定しない。CIはビルド成果物を個別に検査し、いずれかが`25,000,000 byte`を超えれば不合格とする。Cloudflare Pages自体の単一ファイル上限25MiB（26,214,400 byte）より厳しいプロジェクト上限を適用する。
- PNG/HCAなど後続取得するゲーム用素材・アセット辞書はプログラムのサイズ判定対象外とする。CSS・PWA Manifest・ライセンス本文等の付属ファイルとCloudflare Pagesに配置するその他の静的ファイルにも配布基盤の単一ファイル上限を適用し、オフライン起動に必要なものは取得・完全性確認対象とする。ゲームの開始条件である有効辞書と検証済み代替画像は既存のアセット検証規則に従う。
- 公開用の静的成果物にGameServer・Public/Private API Serverの実行処理や認証秘密鍵を含めない。静的配布の通信量・リクエスト回数についてアプリ固有の上限は設けないが、配布事業者の実際の利用条件・制限は適用される。

## ビルドと公開

1. `Cargo.lock`で依存を固定して`wasm32-unknown-unknown`へReleaseビルドし、対応する`wasm-bindgen --target web`のJS/WASMを生成する。
2. `cargo-about`でClientに同梱するRust依存のライセンス情報を生成し、Rust以外の必要な表記もクレジットに含める。必要情報が欠けたReleaseを配布しない。
3. HTML/JS/WASMの各成果物の非圧縮ファイルサイズをCIで検査し、**各ファイル25,000,000 byte以下**とCloudflare Pagesの単一ファイル制限を確認する。配布用のCSS、PWA Manifest、Service Worker、ライセンス情報と初期起動用のファイル参照も検査する。
4. Cloudflare Pagesへ静的成果物をHTTPS公開する。ビルドにはGitHub Actionsを利用してもよいが、公開先はCloudflare Pagesとする。公開後の`client_origin`、Callback URI、CORS、PWA Scopeを照合する。

## シーン別JSONの静的配布

- `./scene_assets/<scene_id>.json`をClient Versionに属する静的成果物としてCloudflare Pagesの公開ルートで配布し、**WASMのデータセクションへJSON本文を埋め込まない**。対象全シーンのJSONをビルド/配布検証対象に含め、各JSONにもCloudflare Pagesの単一ファイルサイズ制限を適用する。
- 初回のVersion一式取得と更新では、Scene JSONもOPFS `./game/scene_assets/`およびService Workerの**同Version**のCache Storageに保存・検証する。初期取得の完全性確認とClient Version切替は既存のプログラム全量置換契約に従う。これはJSONの事前キャッシュであり、PNG/HCA実素材を全シーン分GPU/音声メモリへロードする要件ではない。
- 実ファイルのJSON名は`design/client/scene_asset_manifest.md`で定めたシーンIDと一致させ、Scene Manifestの検証失敗時はそのシーンへの遷移を成立させない。辞書Releaseとの混同や、Client Versionを跨いだ旧JSONの流用を禁止する。

## オフライン起動と`./game/`の保持

- 初回のオンライン起動で取得した**HTML/JS/WASM一式を端末のOPFS `./game/`配下に保存**する。公開ルートで必要となる関連起動ファイルも保持する。`./game/`はゲームプログラム専用であり、`./assets/`、`./cache/`、`./settings/`、`./game_info.json`および`./config.cnf`と分離する。
- **OPFSへの保存だけではブラウザのURLリクエストをオフラインで解決できない。** HTTPSで同一Origin・適切なScopeに登録したService Workerを使用して、起動ページと必要な静的URLをCache Storageからオフライン提供する。配布一式を`./game/`へ保存すると同時にService Worker用のVersion別Cacheにも展開し、両方の検証が終わってから当該Versionを有効化する。Service WorkerがOPFSを直接読めることは必須条件にしない。
- 有効化前に対象Versionの**起動に必要な全ファイル**を取得・保存・照合する。SWは同じVersionのHTML/JS/WASM/ライセンス等を一式として返し、旧HTMLと新WASMを混在させない。SWのリクエスト捕捉はCloudflare Pages上の静的Client Origin内に限定し、Public API/認証Originへの通信をオフライン用Cacheに差し替えない。
- 通信断のままPWA/ブラウザを再起動しても、端末に保存済みで検証済みのHTML・JS・WASMをService Worker経由で読み込めることを目標とする。初回ダウンロード未完了、ブラウザのストレージ消去、SW未制御等ではオフライン起動を保証せず、接続を必要とする旨を表示する。サーバー通信が必要なゲーム機能は利用不可であり、素材の利用は保存済み辞書・代替画像の開始前検査に従う。

## Client更新（全量置換）

1. 新Versionをダウンロードし、OPFSの作業領域と新Version用のService Worker Cacheへ**全ファイルを一時保存**して欠落・容量・サイズ・Hashを検証する。この段階では旧Versionでの起動を継続する。
2. 既存`./game/`の内容をロールバック可能な状態で保持してから、**`./game/`配下の旧ファイルをすべて削除し、新Versionの全ファイルを配置**する。操作中はローディング状態とし、ゲーム起動・キャッシュクリア・他の素材入替などの競合操作を受け付けない。`./assets/`と端末設定は削除しない。
3. OPFS内`./game/`一式と新Version用Cacheの整合を再検証した後で初めてSWのActive Versionを切り替え、旧Versionのバックアップと旧Cacheを削除する。途中失敗・電源断・容量不足時は旧Versionへ復帰し、次回起動では未完了更新を検出して復旧を完了するまで新旧混在を許可しない。
4. Service Worker更新はブラウザの制御切替タイミングに依存するため、既に開いている旧ページを途中で新WASMへ変更せず、再読込後に新Versionを使う。更新と再起動の実機試験では、端末内`./game/`と配信中のVersionの一致を検証する。

## 認証Callbackと配布設定

- `client_origin`はCloudflare Pagesへ実配備したHTTPS Originを表す単一の設定値とし、認証戻り先を`<client_origin>/auth/callback/`に固定する。未設定中はServer認証を有効化しない。登録したCallback URIとPublic API側のCORS許可Client Originを同一設定から構成する。
- 静的設定`public_api_origin`は**実配備先が確定した時だけ**指定する単一のHTTPS Origin文字列とし、Path・Query・Fragmentや資格情報付きURLを拒否する。未設定時はローカル機能のみを提供する。
- Public APIと認証Originは同一とし、`/auth/authorize`の画面はPublic API ServerがHTTPSで配信する。異なるOriginでのCookie/PKCE認証は`design/system/api_transport.md`に従う。

## リポジトリ

- Client：`https://github.com/ReHydrangeaOdyssey/Client.git`
- 純粋なゲームロジック：`https://github.com/ReHydrangeaOdyssey/GameLogic.git`
- Server：`https://github.com/ReHydrangeaOdyssey/Server.git`

## 描画・入力

- WebGL 2のCanvasのCSS表示寸法とDrawing Buffer寸法を区別し、`ResizeObserver`と画面回転後の表示領域変化を検知して`viewport`および描画対象寸法を更新する。
- 基準の16:9背景・UI領域を1280×720とし、論理高さ720・論理幅可変の表示領域中央に配置する。4:3等の幅が狭い表示では背景の左右を切り取りUIを中央へ収め、16:9より幅が広い表示では不足する左右を別背景画像で補完し、UIは中央の基準背景内に配置する。高さ320 CSSピクセル以上を対応対象とする。Safe Areaを考慮する。
- `devicePixelRatio`とGPU能力に応じて描画バッファを決定し、測定前に高解像度を前提としてGPUメモリを無制限に確保しない。最大描画ピクセル数の具体値は実機測定で決める。
- `PointerEvent`の位置をCanvasの表示領域から論理描画座標へ変換し、同じ領域でHit Testを行う。初期化中は入力を受け付けない。
- インストール済みアプリのPWA Manifestでは`display: fullscreen`と`orientation: landscape`を指定する。起動時に対応環境で全画面表示を適用し、許可された環境では`ScreenOrientation.lock("landscape")`を試みる。通常ブラウザではユーザー操作に応じてFullscreen APIを試み、失敗した場合は既存の可変レイアウトで描画を継続する。回転案内は表示しない。
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
| Cloudflare / 容量 | HTML/JS/WASMの各ファイルが非圧縮25,000,000 byte以下（合計制限なし）。その他の配布物もCloudflare Pagesの単一ファイル上限以内 |
| オフライン | OPFS `./game/`保存とSW Cache Storage取得後に通信断でPWAを終了・再起動しても起動できる。通信必須機能は無効 |
| 更新 | `./game/`の全量置換・中断復帰・SWのVersion切替・他OPFS領域保護 |
| 表示 | アプリ起動時のfullscreen・横画面固定の成功/拒否、通常ブラウザのフォールバック |

## 参照資料

- `design/client/web_application.md`
- `design/client/client.md`
- `design/programming/client/client.md`
- `design/programming/directory_structure.md`
- `https://developers.cloudflare.com/pages/platform/limits/`
- `https://developer.mozilla.org/ja/docs/Web/Progressive_web_apps/Guides/Offline_and_background_operation`
- `https://embarkstudios.github.io/cargo-about/`
- `https://developer.apple.com/documentation/safari-release-notes/safari-16_3-release-notes`
- `https://support.google.com/chrome/thread/243346420/sunsetting-chrome-support-for-android-7-0-nougat?hl=en`
- `https://wasm-bindgen.github.io/wasm-bindgen/examples/without-a-bundler.html`
- `https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API/WebGL_best_practices`
- `https://developer.mozilla.org/en-US/docs/Web/API/HTMLInputElement/webkitdirectory`
- `https://developer.mozilla.org/en-US/docs/Web/API/StorageManager/estimate`

## アセット辞書の運営設定

Web配布ルートに`./config.cfg`をYAMLで設置する。運営は配布ファイルを差し替えて辞書更新を一時停止できる。`update_asset_dictionary`の既定値は`true`、`asset_dictionary_version`の既定値は`latest`。この設定は静的配布物であり、Clientから変更してServerへ書き戻す機能は設けない。辞書のRelease探索は`design/client/client.md`の「アセット辞書取得の設定」に従う。配布対象は`<ext>/assets_dict.json`の集合であり、Release上の取得Asset名・パッケージ方式と各ファイルの検査値対応はU-09として確定後に反映する。


## 端末側の例外設定

タイトルの設定画面は静的配布設定を直接編集せず、OPFSに保存した`./settings/config_cfg_override.yaml`にある端末上書きの`update_asset_dictionary`・`asset_dictionary_version`、`config.cnf`の2つのbooleanを表示・検証して原子的に保存する。辞書Hash照合OFF時の警告、設定初期化、オフライン編集を確認する。

Web配布ルートの`config.cfg`（運営側YAML）とは独立に、ユーザーが端末内OPFSの`./config.cnf`（YAML）で`verify_asset_dictionary_sha256`と`allow_user_asset_override`を明示設定できる。両者の初期値はそれぞれ`true`・`false`であり、設定の省略や不正時は安全側の初期値とする。Clientが静的配布ファイルをユーザー権限で上書きする経路は設けない。SHA-256検査値との照合を無効化しても拡張子別の各辞書と`paths`配列全要素のPath/Schema検証は必須とする。

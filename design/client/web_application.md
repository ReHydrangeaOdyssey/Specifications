# Webアプリケーション仕様

## 概要

Clientは静的Webアプリケーションとし、ブラウザ上でRust/WebAssemblyを実行し、主描画には既定のWebGL 2を使用する。初期プロトタイプはLAN内のローカルWebサーバーから配布し、試験端末がサーバーのIPアドレスを直接指定してアクセスする。GameServerおよびPublic API Serverと通信せず、タイトル画面の表示、仮ホーム画面への遷移、テスト用ボタンの入力反応、画面サイズ変更・基本描画を検証する。正式な公開先はVercelまたはGitHub Pagesのいずれかであり、現時点では確定しない。

対象ブラウザは`design/client/client.md`で確定済みのiOS Safari 16.3以降およびAndroid Chrome 120以降とする。これらの最小バージョンでの機能動作は実機試験で確認する。

## 画面方向と可変レイアウト

- 横画面を前提とし、16:9および4:3を推奨する。両比率で操作に必要なUIが見切れず、主要表示内容が欠落しないようにする。
- 画面比率に応じて背景の描画領域・倍率とUIの倍率・配置を更新する。背景は表示領域を満たすように描画し、端末比率に応じた背景の周辺部分の切り取りは許容するが、操作に必要なUIや重要情報を切り取らない。
- UI配置は画面端とSafe Areaを基準とし、縦横を単純に一律拡大して左右端を欠落させない。表示可能領域の変化に応じてUI位置を再計算する。
- 初期のレイアウト論理座標は高さ720を基準とし、表示領域のアスペクト比に従って論理幅を可変とする。16:9では論理幅1280、4:3では論理幅960とする。この値はUI配置の計算基準であり、ブラウザ描画バッファの物理解像度を固定するものではない。
- Safe Area（画面の切り欠き、ホームインジケータなど）を考慮し、重要な操作部品をその内側へ配置する。ページのViewportは`width=device-width, initial-scale=1, viewport-fit=cover`を採用し、Safe Areaのinset値を参照する。ユーザーによるブラウザの拡大操作を一律禁止しない。
- 端末回転、ブラウザUIの表示・非表示、ウィンドウリサイズ、PWA表示領域の変化を検知して、Canvasサイズ・ViewPortと入力座標変換を更新する。
- 縦画面ではゲーム用の縦長レイアウトを新設せず、回転を案内する画面を表示する。画面方向の強制固定を動作要件とはせず、`ScreenOrientation.lock()`の成功に依存しない。
- 16:9、4:3以外の比率でも画面の利用可能領域から再計算する。ただし、ゲームの主要UIを維持できない領域では横画面案内を表示し、寸法を根拠なく固定してコンテンツを見切れさせない。

## 表示と操作

- Canvasをブラウザ表示領域へ適合させ、CSS上の表示サイズとWebGL描画バッファのピクセル数を分けて管理する。`devicePixelRatio`を考慮し、描画バッファは必要に応じた上限と端末性能を考慮して確保する。具体的な上限値は初期実測に基づき確定する。
- ゲーム操作入力はタッチ入力とマウス入力を`PointerEvent`で共通化し、画面拡縮後も表示座標から論理座標への変換を一致させる。ゲームCanvas上で操作に必要な既定タッチジェスチャーの制御を行うが、文書全体のブラウザ操作まで無効化しない。
- OS標準のファイル選択、初期ロード・エラー表示には必要最小限のHTML要素を利用できる。既定の「追加UI Frameworkを採用しない」方針は維持する。
- WASM・WebGL 2・OPFS等の初期化に失敗した場合は、白画面で放置せず、失敗した機能と再読込手段を表示する。対応しない機能を利用可能と表示しない。

## 音声・保存に関するブラウザ制約

- Web Audioの再生開始と停止中の`AudioContext`の再開は、ブラウザの自動再生制約に従いユーザー操作を契機に実施する。既定のHCA→PCM→Web Audio構成は維持する。
- OPFSは同一Origin内のアプリ専用保存域とし、HTTPSの安全な文脈で利用する。保存可能容量はブラウザに依存し、空き容量照会値は近似値として扱う。ブラウザの容量超過・データ消去・非永続化の可能性をUI上で取り扱う。
- ユーザーの元ファイルを自動削除しない。アセット追加の端末側ファイル選択UIはブラウザ互換性を確認したうえで決定し、既存の再帰探索要件を満たすことを検証する。

## 初期プロトタイプの配布と正式公開

- 公開対象はHTML、ES Module JavaScript、WASM、CSS、Manifestおよび試験に必要な静的アセットとし、GameServer・API Serverの処理や秘密鍵を配布しない。
- 初期プロトタイプの配布はLAN内のローカル静的Webサーバーを使用し、試験端末のブラウザから当該サーバーのIPアドレスを直接指定してアクセスする。ローカルWebサーバーは静的成果物の配信を担当し、GameServerやPublic API Serverの代わりとしてゲーム処理・認証を行わない。具体的なIPアドレス・ポート・サーバーソフトウェアは未指定とする。
- 正式公開先はVercelとGitHub Pagesを候補とし、採用先は未決定とする。GitHub Pagesを採用した場合のGitHub ActionsによるReleaseビルド・検証・HTTPS静的配布の設計は維持する。配信ルートが変わっても静的資源を取得できるように相対Pathを使用する。
- 初期試作ではJavaScriptのES Moduleと`wasm-bindgen --target web`による生成物をブラウザから読み込む。WASMロード処理の成功後に描画初期化する。
- 初期試作では自動Service Worker登録とオフラインキャッシュを導入しない。PWA用Manifestは配布できる構成とし、初期のインストール検証では`display: standalone`・`orientation: landscape`を希望値とする。`start_url`と`scope`はPages公開ルート内の相対URLで指定する。これらの指定によってすべてのブラウザで画面方向や表示モードが強制されるとは扱わない。
- PWAインストールの操作案内はiOS Safariでは共有メニューの「ホーム画面に追加」、Android Chromeではメニューの「アプリをインストール」または「ホーム画面に追加」とする。実際の項目名称・表示可否は端末やブラウザバージョンによって変わるため実機で検証する。アプリ名・アイコン素材は正式名称の確定後に指定する。
- 初期プロトタイプでは試験用PNG`proto_type_title.png`をタイトル画面に、`proto_type_home.png`を仮ホーム画面に表示する。画像の内容は試験用でよく、正式なゲーム画像としない。タイトル画面から仮ホーム画面への遷移と、複数のテスト用ボタンに対する入力反応を端末から確認する。ボタンの個数・配置・ラベル・各操作の具体的な反応内容は未指定とする。
- 現行のServer非接続時のゲームプレイ制限は完成版の規則として維持する。試験用の画面遷移・表示・入力は**プロトタイプ専用のビルド設定でのみ有効化**し、本番用の認証・状態管理と混同しない。試作のローカル表示・仮データはGameServer正本を代替しない。
- 公開する試験データは再配布可能なものだけを含め、Token、個人データ、秘密鍵を同梱しない。

## 検証条件

- 初期プロトタイプはLAN内の別端末からローカルWebサーバーのIPアドレスを指定してHTML・JavaScript・WASM・試験用PNGを取得し、WebGL 2を初期化できることを確認する。タイトル画像`proto_type_title.png`が表示され、仮ホーム画面への遷移後に`proto_type_home.png`が表示されること、テスト用ボタンが入力に反応すること、再読み込み後も起動できることを確認する。
- 16:9と4:3で背景・UIの可変配置とタップ座標の整合を確認し、縦画面での案内表示、画面回転による再配置、Safe Areaへの侵入がないことを確認する。
- 対象ブラウザの最小バージョンで動作確認を行う。機能を追加する場合は、追加した機能ごとに試験を増やす。
- 初期のLAN接続による起動・画面・入力試験と、HTTPS等の安全なコンテキストを要するOPFS・PWA機能の検証は区別する。LAN内IPアドレスへの接続結果だけでOPFS・PWAの動作を合格としない。WASM・WebGL 2・OPFS・Web Audioの対応有無と実際の動作は対象機能ごとに端末で確認し、数値性能要件を測定なしに合格としない。

## 制約・未確定事項

- Clientのソースリポジトリは`https://github.com/ReHydrangeaOdyssey/Client.git`、純粋なゲームロジックは`https://github.com/ReHydrangeaOdyssey/GameLogic.git`、Serverは`https://github.com/ReHydrangeaOdyssey/Server.git`とする。これらのURLはソース管理先であり、初期プロトタイプの静的配信URLを示さない。
- 初期ローカルWebサーバーのIPアドレス・ポート、正式公開先（Vercel／GitHub Pages）・公開URL・独自ドメイン・APIとのSite/Origin構成は未確定とする。Public APIを使う段階では既存の`SameSite=Strict` Cookie要件を優先する。
- `proto_type_title.png`と`proto_type_home.png`の画像内容・配備先、テスト用ボタンの個数・配置・動作の詳細、プロトタイプ専用ビルド設定の具体値は未確定とする。完成版のUIデザイン、ゲーム画像、サーバー正本の代替となる試験データ、アセット辞書配布形式、アセットの取り込み操作も本書だけでは確定しない。
- 最小対応OSバージョン、実測による描画解像度上限、音声・保存容量の実機検証結果は別途確定する。

## 参照資料

- `design/client/client.md`（既存のClient基本仕様・通信・Server未接続制限）
- `design/programming/client/client.md`（Rust/WASM・WebGL 2・OPFSの実装方針）
- `https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site`
- `https://wasm-bindgen.github.io/wasm-bindgen/examples/without-a-bundler.html`
- `https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/meta/name/viewport`
- `https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API/WebGL_best_practices`
- `https://developer.mozilla.org/en-US/docs/Web/API/ScreenOrientation/lock`
- `https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Manifest/Reference/orientation`
- `https://developer.mozilla.org/en-US/docs/Web/API/StorageManager/getDirectory`
- `https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria`
- `https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Best_practices`
- `https://developer.mozilla.org/ja/docs/Web/Progressive_web_apps/Guides/Installing`

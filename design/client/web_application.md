# Webアプリケーション仕様

## 概要

ClientはRust/WebAssemblyをブラウザ上で実行する静的Webアプリケーションとする。描画にはWebGL 2を使用する。

対象ブラウザはiOS Safari 16.3以降、Android Chrome 120以降とする。

## 画面方向と可変レイアウト

- 横画面・16:9の基準画面（論理サイズ1280×720）を使用する。4:3および他のアスペクト比では画面高さへ収まる倍率とし、背景の左右がはみ出す場合は両端を切り取る。UIは中央へ寄せ、必要な操作領域を中央に収める。
- 16:9より横幅が広く、中央の基準背景だけでは両側が不足する場合は、不足する左右に別途の背景画像を描画する。UIは中央の基準背景内に収める。左右追加背景の具体素材は別途指定する。
- Canvasの論理高さは720を計算基準とし、ブラウザ描画領域の論理幅は表示アスペクト比に応じて可変とする。16:9の基準背景・UI領域は中央に配置し、画面のアスペクト比が4:3の場合の論理幅は960とする。この値はブラウザ描画バッファの物理解像度を固定しない。
- UIはSafe Areaを考慮した中央の背景領域内へ収め、表示領域の変更時に位置・倍率・入力判定領域を再計算する。
- Safe Area（画面の切り欠き、ホームインジケータなど）を考慮し、重要な操作部品をその内側へ配置する。ページのViewportは`width=device-width, initial-scale=1, viewport-fit=cover`を採用し、Safe Areaのinset値を参照する。ユーザーによるブラウザの拡大操作を一律禁止しない。
- 端末回転、ブラウザUIの表示・非表示、ウィンドウリサイズ、PWA表示領域の変化を検知して、Canvasサイズ・ViewPortと入力座標変換を更新する。
- 起動直後に横画面へ設定する方針とし、画面方向の固定APIが利用できる実行環境では横画面設定を試みる。回転案内画面は表示しない。ただしiOS Safari等ではブラウザが端末の画面方向を強制変更できないため、横画面への切替成功はWebアプリケーションから保証できない。
- 対応する表示領域の高さは最低320px（CSSピクセル）とする。16:9・4:3以外の横画面も同じ背景の切り取り・左右追加・中央UI配置規則に従う。

## 表示と操作

- Canvasをブラウザ表示領域へ適合させ、CSS上の表示サイズとWebGL描画バッファのピクセル数を分けて管理する。`devicePixelRatio`を考慮し、描画バッファは必要に応じた上限と端末性能を考慮して確保する。具体的な上限値は初期実測に基づき確定する。
- ゲーム操作入力はタッチ入力とマウス入力を`PointerEvent`で共通化し、画面拡縮後も表示座標から論理座標への変換を一致させる。ゲームCanvas上で操作に必要な既定タッチジェスチャーの制御を行うが、文書全体のブラウザ操作まで無効化しない。
- OS標準のファイル選択、初期ロード・エラー表示には必要最小限のHTML要素を利用できる。既定の「追加UI Frameworkを採用しない」方針は維持する。
- WASM・WebGL 2・OPFS等の初期化に失敗した場合は、白画面で放置せず、失敗した機能と再読込手段を表示する。対応しない機能を利用可能と表示しない。

## 音声・保存に関するブラウザ制約

- Web Audioの再生開始と停止中の`AudioContext`の再開は、ブラウザの自動再生制約に従いユーザー操作を契機に実施する。既定のHCA→PCM→Web Audio構成は維持する。
- OPFSは同一Origin内のアプリ専用保存域とし、HTTPSの安全な文脈で利用する。保存可能容量はブラウザに依存し、空き容量照会値は近似値として扱う。ブラウザの容量超過・データ消去・非永続化の可能性をUI上で取り扱う。
- ユーザーの元ファイルを自動削除しない。アセット追加の端末側ファイル選択UIはブラウザ互換性を確認したうえで決定し、既存の再帰探索要件を満たすことを検証する。

## 配布とプロトタイプ

- 公開対象はHTML、ES Module JavaScript、WASM、CSS、Manifestおよび試験に必要な静的アセットとし、GameServer・API Serverの処理や秘密鍵を配布しない。
- 初期プロトタイプの配布はLAN内のローカル静的Webサーバーを使用し、試験端末のブラウザから当該サーバーのIPアドレスを直接指定してアクセスする。ローカルWebサーバーではゲーム処理・認証を実行しない。
- 正式公開先はVercelとGitHub Pagesから選択する。GitHub Pages採用時はGitHub ActionsでReleaseビルド・検証・HTTPS静的配布を実行する。静的資源は相対Pathで参照する。
- 初期試作ではJavaScriptのES Moduleと`wasm-bindgen --target web`による生成物をブラウザから読み込む。WASMロード処理の成功後に描画初期化する。
- 初期試作では自動Service Worker登録とオフラインキャッシュを導入しない。PWA用Manifestは配布できる構成とし、初期のインストール検証では`display: standalone`・`orientation: landscape`を希望値とする。`start_url`と`scope`は公開ルート内の相対URLで指定する。これらの指定によってすべてのブラウザで画面方向や表示モードが強制されるとは扱わない。
- PWAインストールの操作案内はiOS Safariでは共有メニューの「ホーム画面に追加」、Android Chromeではメニューの「アプリをインストール」または「ホーム画面に追加」とする。実際の項目名称・表示可否は端末やブラウザバージョンによって変わるため実機で検証する。アプリ名・アイコン素材は正式名称の確定後に指定する。
- 初期プロトタイプでは試験用PNG`proto_type_title.png`をタイトル画面に、`proto_type_home.png`を仮ホーム画面に表示する。タイトル画面から仮ホーム画面への遷移と、複数のテスト用ボタンに対する入力反応を端末から確認する。
- 試験用の画面遷移・表示・入力はプロトタイプ専用ビルドでのみ有効にする。本番ビルドではGameServerをゲーム状態の正本とする。
- 公開する試験データは再配布可能なものだけを含め、Token、個人データ、秘密鍵を同梱しない。

## 検証条件

- 初期プロトタイプはLAN内の別端末からローカルWebサーバーのIPアドレスを指定してHTML・JavaScript・WASM・試験用PNGを取得し、WebGL 2を初期化できることを確認する。タイトル画像`proto_type_title.png`が表示され、仮ホーム画面への遷移後に`proto_type_home.png`が表示されること、テスト用ボタンが入力に反応すること、再読み込み後も起動できることを確認する。
- 16:9と4:3、16:9より横長の比率で、背景の左右切り取り・追加背景・中央UI配置とタップ座標の整合を確認する。高さ320px以上での表示と画面回転による再配置、Safe Areaへの侵入がないことを確認する。横画面への切替要求結果を実機で記録する。
- 対象ブラウザの最小バージョンで動作確認を行う。機能を追加する場合は、追加した機能ごとに試験を増やす。
- 初期のLAN接続による起動・画面・入力試験と、HTTPS等の安全なコンテキストを要するOPFS・PWA機能の検証は区別する。LAN内IPアドレスへの接続結果だけでOPFS・PWAの動作を合格としない。WASM・WebGL 2・OPFS・Web Audioの対応有無と実際の動作は対象機能ごとに端末で確認し、数値性能要件を測定なしに合格としない。

## 制約

- Clientのソースリポジトリは`https://github.com/ReHydrangeaOdyssey/Client.git`、純粋なゲームロジックは`https://github.com/ReHydrangeaOdyssey/GameLogic.git`、Serverは`https://github.com/ReHydrangeaOdyssey/Server.git`とする。
- 初期ローカルWebサーバーのIPアドレス・ポート、正式公開先（Vercel／GitHub Pages）・公開URL・独自ドメイン・APIとのSite/Origin構成は未確定とする。Public APIを使う段階では既存の`SameSite=Strict` Cookie要件を優先する。
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

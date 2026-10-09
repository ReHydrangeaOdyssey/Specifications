# クライアント仕様

## 実行環境・描画方式

* Clientの実装方式はRustをWebAssembly（WASM）へコンパイルするWeb Clientとする.
* 対象環境はiPhoneのSafari / PWAおよびAndroidのChrome / PWAとする. 配布先はGitHub Pagesを予定する. 対象ブラウザの最小バージョンはiOS Safari 16.3, Android Chrome 120とする. 対応OSの最小バージョンは未確定とする. PWAインストール手順の詳細は未確定とする.
* 対象は2Dゲームとし, 最大20対20のリアルタイム騎士団戦での表示を想定する. 「最大20対20」は性能検証の対象条件であり, この選定資料によって新たなゲームルールを定義するものではない.
* 主描画方式はWebGL 2とし, `web-sys`を介した独自のスプライトバッチレンダラーを使用する. 汎用2DエンジンとCanvas 2Dを主レンダラーとしては使用しない. 別途UI Frameworkも使用しない.
* PNGのデコードにはブラウザの`createImageBitmap()`を使用し, `ImageBitmap`からWebGL 2テクスチャへアップロードして描画する. PNGの全画素RGBAを描画のためにWASMメモリへ複製することは前提としない.
* 描画順を維持しながらスプライト描画をバッチ化する. 同一テクスチャの共有, 可視範囲に応じた段階ロード, 不要なテクスチャと`ImageBitmap`の解放を実施する. テクスチャアトラス・インスタンシングをどの範囲に適用するかは実測で判断する.
* 実行時RAM・CPU/GPU負荷, 配布WASMサイズ, 依存の少なさ, 実装容易性の順に最適化の優先度を置く. 目標閾値はGPU負荷80%以下, 実行時メモリ2GB以下, FPS30以上, WASMサイズ500MB以下とする. GPU負荷の計測方式, メモリの計測対象, WASMサイズの圧縮前後, 測定時間・対象機種などは未確定で, 数値を満たすことは未検証とする.

## 音声形式・再生

* HCAを再生対象形式とし, Rust/WASM側でHCAからPCMへデコードしたうえでWeb Audio APIで出力する.
* HCAデコーダーはPure Rustの`cridecoder`（選定資料の候補バージョン`0.3.6`）を採用候補とする. iPhone Safari/WASM上のビルド・動作・ピークメモリは未検証であり, 実機検証を通過するまで最終採用確定とは扱わない.
* 短い効果音・ボイスは必要に応じて全体をデコードし, `AudioBuffer`を再利用する.
* 長いBGM・ボイスは全体PCMを常駐させず, 小容量のPCMチャンクを逐次供給して`AudioWorklet`で再生する. 初期実装での供給経路は`MessagePort`とする.
* `AudioWorkletProcessor`のリアルタイム処理内でHCAデコードや大容量のメモリ確保を行わず, 制御側またはWorker側で先行デコードする.
* HCAのサンプリングレートは22,050Hzとし, 暗号化HCAは扱わない. ループ再生する音源としない音源がある. SEの同時再生数は最大5とする. ループ区間・チャンネル数・実機での発音結果は検証する. PCM先読み量の最適値はデコード所要時間・I/O遅延・端末別スケジューリングの測定値がないため現時点では算出できず, 実測で決定する. `SharedArrayBuffer`は現時点では採用しない.

## アセットの取得・保存

* PNGおよびHCAのファイル本体はGameServerから配信しない. アセットの配置に使用するファイル名SHA-256ハッシュ対応辞書はServerから配布する. 辞書取得API・配布時期・シリアライズ形式は未確定とする.
* タイトル画面の「アセットの追加」ボタンから専用シーン「アセット追加」へ遷移する. このシーンでユーザーが選択した画像・音声をClientへ取り込む. ユーザーがファイルをコピーまたは移動する操作を想定するが, OS側の元ファイルを削除する「移動」の可否・許可取得・ブラウザ別実現方法は未確定とする.
* 追加できる画像の形式はPNGだけとし, 音声は選定済みのHCAを対象とする. Client独自のファイル容量・画像解像度制限・保存期間は設けない. ブラウザの容量quotaやデータ消去・ストレージ退避等による制約はClientで解除できないため, 永続保持を保証するものではない.
* 取り込んだPNG/HCAファイル本体とキャラクター画像割当情報はすべてOPFSへ保存する. Serverから配布される辞書とファイル名のSHA-256ハッシュ値の対応に基づき, Clientがアセットを自動配置・割当する. 保存済みの対応情報はOPFSから復元する. 復元時期・割当情報のデータ形式, 辞書の配信時期, 同名ファイルの上書き規則は未確定とする.
* アセット取り込み時は選択されたディレクトリの配下を再帰的に探索し, 対象となるPNG/HCAファイルのファイル名からSHA-256ハッシュ値を算出する. Server配布辞書にはファイル名のSHA-256ハッシュ値と配置先ディレクトリの対応を保持する. 同名ファイルが複数存在する場合はファイル内容のSHA-256ハッシュ値を算出し, 辞書中の同名ファイルに対する内容ハッシュ値と照合して配置先を特定する. これ以外のハッシュ衝突に対する判定・回避処理は設けない.
* 追加済みファイルと割当情報をClientが自動削除しない. ユーザーによるOPFSの明示的な消去を削除契機とする. ブラウザ自身によるストレージデータの削除やquota超過の扱いは別途検証が必要とする.
* OPFS内ではセマンティックバージョニングで識別するバージョン別ディレクトリにアセットを配置する. 新バージョンの検証後に使用先を切り替え, インポート途中の中断から回復できるようにする. `MAJOR.MINOR.PATCH`の意味を採用し, 接頭辞やディレクトリ配置規則・検証内容は未確定とする.
* PNGはOPFSから`File` / `Blob`として読み, `createImageBitmap()`でデコードする. HCAは必要なメタデータと圧縮ブロックを読み, 圧縮ファイル全体とPCM全体の同時常駐を避ける.
* タイトル画面の「キャッシュクリア」はOPFS内の`cache`フォルダに置かれたファイルだけを削除対象とする. それ以外のアセット本体・画像割当情報は対象外とする. `cache`フォルダの階層上の位置は未確定とする.
* GPUテクスチャ, デコード済みPCM, WASMヒープ, ブラウザ内部の一時メモリを分けて測定する. 不要な`ImageBitmap`, WebGLテクスチャ, `AudioBuffer`の保持を終了する.
* OPFSへ保存するアセットと認証情報は区別し, AccessTokenをOPFSへ永続化しない.

## ログイン・サーバー未接続時のゲームプレイ

* ログインできない, またはServerへ接続できない場合, タイトルからホーム画面へ移動することのみ可能とし, ホーム画面でのゲーム操作を含むその他の機能は使用できない.
* Serverとの接続および必要な認証が回復した場合は, 接続状態と同じすべての機能を利用可能に戻す. 使用可否は現在の接続・認証状態に従う.
* Serverを正本とする状態を未接続中にClientだけで変更しない.

## タイトル画面の操作

* タイトル画面に「キャッシュクリア」ボタンと「アセットの追加」ボタンを配置する. ただしServer未接続・ログイン不可時にはホーム画面への移動以外の操作はできない.
* 「アセットの追加」から専用の「アセット追加」シーンへ遷移し, PNG画像・HCA音声を取り込む. キャラクター画像の対応付けはServer配布辞書に基づく自動割当とする.
* キャラクター画像・UVデータはClient側のアセットとして扱い, Server用ProcessedMasterDataの対象としない. 詳細は「[マスターデータ](../game/master_data.md)」を参照する.
* 「キャッシュクリア」で削除する対象はOPFSの`cache`フォルダ内のファイルだけとする.

## アニメーション


すべてイベントキューに入れて各イベントに応じてアニメーションなどを行う.

## サーバーへの接続

ゲーム結果はGameServerの計算結果を正とする.

アリーナではClientとGameServerが同一バージョンの戦闘ロジックを保持する. `StartArenaBattle`の成功レスポンスでは, Clientが戦闘を再現するために必要な相手PlayerID・相手キャラクター初期状態（最大HP含む）・Seedを返し, GameServerが算出した勝敗や最終HP等の戦闘結果自体は返さない. Clientは自身の初期状態, レスポンスで受け取った相手初期状態, Seedを入力としてGameServerと同一の戦闘ロジックを実行し, 表示用の戦闘進行を再現する.

同一の初期状態, Seed, 戦闘ロジックからClientとGameServerは同一結果を算出することを前提とし, 結果の正本はGameServer側の計算結果とする.

騎士団戦の殲滅でもClientはGameServerと同じ`game-core`で戦闘を再計算する. `GuildBattleAnnihilationResponse`には確定した相手PlayerID, 対戦相手のFormationID, 両パーティの戦闘開始時キャラクターステータス（最大HP含む）, この戦闘で有効なタクティクス継続効果, Seedを返す. 結果の正本はGameServer側とし, Clientへ戦闘結果の最終HP・行動ログを別途送らない.

騎士団戦参加中は`SubscribeGuildBattleUpdates`の通知ストリームで, 所属騎士団に応じたチェイン値・チェイン残り時間（ミリ秒）と両騎士団のスコアを受信する. チェインの時間経過リセットだけによる通知はないため, 残り時間をClient側で表示用に減算する. 30:00到達で通知購読を終了し, 30:00までにキューへ入った当該Playerの要求が残っている場合のみその処理完了後に終了する. 出撃結果レスポンスを返した後のGameServer処理で変更された状態を接続中の全参加者へ通知し, 再接続時は`GetGuildBattleStatus`の現在値を正本とする.



## 編成のローカル保持とServer照合

* ClientはArena編成と騎士団戦編成の静的構成をローカルへ保存する.
* `StartArenaBattle`ではローカル保存したArena編成を要求へ含める. GameServerはDatabase上のArenaPartyと比較し, 不一致の場合はServer保存編成を返す. Clientは返されたServer編成でローカルArena編成を上書きし, その編成を戦闘再現に使用する.
* `JoinGuildBattle`ではローカル保存した騎士団戦編成を要求へ含める. GameServerはPreload済み編成と比較し, 不一致の場合はServer編成を返す. Clientは返されたServer編成でローカル騎士団戦編成を上書きする.
* `StartArenaBattle`および`JoinGuildBattle`ではClientVersionを送信し, GameServer Versionと不一致の場合は更新を促して処理を開始しない.

## 認証情報

* AccessTokenはClientのプロセスメモリ上だけに保持し, OPFS, LocalStorage, IndexedDB等の永続Storageへ保存しない.
* RefreshTokenはClient JavaScriptから読み取らず, Public API Serverが設定する`__Host-RefreshToken` HttpOnly Cookieを使用する.
* Client起動時または再読み込み時にAccessTokenを保持していない場合は, `RefreshAccessToken`で新しいAccessTokenを取得する.
* Logout時はClientが保持するAccessTokenを破棄する. RefreshToken CookieはPublic API Serverが削除する.

## Public API通信方式

* ClientとPublic API Server間の通信方式は「[ネットワーク](../system/network.md)」に従い, HTTP/2 over TLS 1.3とし, API PayloadにはProtocol Buffersを使用する.
* `SubscribeGuildBattleUpdates`はHTTP/2 Response streamを使用し, `GuildBattleScoreUpdate`をProtocol Buffers varint長prefix付きで順次受信する.
* ライブラリ選定資料に記載された`WebSocket`はPublic API通信方式として採用しない.
* ブラウザ標準の`fetch()`（Rustからは選定済み`web-sys`/`wasm-bindgen-futures`等を使用）をPublic API通信に使用する. 通常のAPIは`fetch()`で送受信し, 通知はResponse Bodyの`ReadableStream`を逐次読み取りProtocol Buffers varint長prefixでフレーム復元する. HTTP/2とTLS 1.3のネゴシエーションはブラウザと接続先が担当し, JavaScriptが直接バージョンを強制しない. ブラウザからのHTTP/2 + TLS 1.3接続成立は配置先で検証する. Rust専用HTTPライブラリの追加は不要とする. HTTP method/pathは未定義のままとする.
* WebAssemblyはブラウザ内で実行され, Rust/WASMからの通信もブラウザの`fetch()`を介するため, WASMとJavaScriptをGitHub Pagesから取得した後のAPI通信にもOrigin・CORS・Cookieの規則が適用される. `SameSite=Strict` CookieはCross-Site要求へ送信されない. ClientからGameServerへ直接通信せず, Public API Serverへ接続する構成を維持する.
* GitHub Pages標準の`github.io`ホストと異なるSiteのPublic APIへアクセスする場合, 既存の`SameSite=Strict` RefreshToken Cookieは`credentials: include`でも送信できない. 配布先とAPIのSite構成（同一Siteの独自ドメイン等）は未確定とし, 認証設計を維持できる配置を検証する. Cross-Originの場合はPublic API側の厳密なCORS設定・Credentials許可が必要となる. RefreshToken Cookieの属性は変更しない.

## 参照資料

* 添付`rust_wasm_png_hca_library_selection(1).md`（2026-10-09）, 第1～7節.
* `design/system/network.md`「通信暗号化要件」.
* `design/game/master_data.md`.

* 2026-10-09のユーザー確定事項（オフライン, アセット追加, OPFS, HCA音源条件, 性能閾値, GitHub Pages配布予定, 通信方式）.
* MDN Fetch API / OPFS / Cookie, WebKit OPFS, GitHub Pages公式ドキュメント（ブラウザ制約の根拠は`design/programming/client/client.md`を参照）.

# クライアント仕様

## 実行環境・描画方式

* Clientの実装方式はRustをWebAssembly（WASM）へコンパイルするWeb Clientとする.
* 対象環境はiPhoneのSafari / PWAおよびAndroidのChrome / PWAとする. 対応OS・ブラウザの最小バージョンやPWAの配布・インストール方式は本選定資料では定義されていない.
* 対象は2Dゲームとし, 最大20対20のリアルタイム騎士団戦での表示を想定する. 「最大20対20」は性能検証の対象条件であり, この選定資料によって新たなゲームルールを定義するものではない.
* 主描画方式はWebGL 2とし, `web-sys`を介した独自のスプライトバッチレンダラーを使用する. 汎用2DエンジンとCanvas 2Dを主レンダラーとしては使用しない.
* PNGのデコードにはブラウザの`createImageBitmap()`を使用し, `ImageBitmap`からWebGL 2テクスチャへアップロードして描画する. PNGの全画素RGBAを描画のためにWASMメモリへ複製することは前提としない.
* 描画順を維持しながらスプライト描画をバッチ化する. 同一テクスチャの共有, 可視範囲に応じた段階ロード, 不要なテクスチャと`ImageBitmap`の解放を実施する. テクスチャアトラス・インスタンシングをどの範囲に適用するかは実測で判断する.
* 実行時RAM・CPU/GPU負荷, 配布WASMサイズ, 依存の少なさ, 実装容易性の順に最適化の優先度を置く. 数値の合格閾値は選定資料では定めていない.

## 音声形式・再生

* HCAを再生対象形式とし, Rust/WASM側でHCAからPCMへデコードしたうえでWeb Audio APIで出力する.
* HCAデコーダーはPure Rustの`cridecoder`（選定資料の候補バージョン`0.3.6`）を採用候補とする. iPhone Safari/WASM上のビルド・動作・ピークメモリは未検証であり, 実機検証を通過するまで最終採用確定とは扱わない.
* 短い効果音・ボイスは必要に応じて全体をデコードし, `AudioBuffer`を再利用する.
* 長いBGM・ボイスは全体PCMを常駐させず, 小容量のPCMチャンクを逐次供給して`AudioWorklet`で再生する. 初期実装での供給経路は`MessagePort`とする.
* `AudioWorkletProcessor`のリアルタイム処理内でHCAデコードや大容量のメモリ確保を行わず, 制御側またはWorker側で先行デコードする.
* 先読み量・同時発音性能・HCAループ区間・暗号化HCAの入力条件・音声開始時の端末制約は実機で検証する. `SharedArrayBuffer`は現時点では採用しない.

## アセットの取得・保存

* PNGおよびHCAアセットはGameServerから配信しない.
* ユーザーが初回に選択するフォルダのファイルをClientへ取り込み, ブラウザのOrigin Private File System（OPFS）へコピーする. 選択元フォルダをゲームが恒久的に直接監視する方式にはしない.
* OPFS内ではバージョン別ディレクトリへアセットを配置する. 新バージョンの検証後に使用先を切り替え, インポート途中の中断から回復できるようにする.
* PNGはOPFSから`File` / `Blob`として読み, `createImageBitmap()`でデコードする. HCAは必要なメタデータと圧縮ブロックを読み, 圧縮ファイル全体とPCM全体の同時常駐を避ける.
* PNGを取り込み対象形式に含める. PNG以外の追加画像形式の可否, 画像の容量・解像度の制限, キャラクターとの割当情報の永続化先・保持期間, 再割り当て・削除規則は別途未定義とする.
* GPUテクスチャ, デコード済みPCM, WASMヒープ, ブラウザ内部の一時メモリを分けて測定する. 不要な`ImageBitmap`, WebGLテクスチャ, `AudioBuffer`の保持を終了する.
* OPFSへ保存するアセットと認証情報は区別し, AccessTokenをOPFSへ永続化しない.


## ログイン・サーバー未接続時のゲームプレイ

* ログインの可否およびサーバーへの接続可否にかかわらず, ゲーム自体はプレイできる.
* アリーナ, 騎士団戦, その他サーバーとの通信が必要な処理は, ログインできない状態やサーバーへ接続できない状態では利用を制限する.
* サーバー接続が必要な処理は, オフラインプレイによってServerの正本状態を変更しない.
* 接続不要で利用可能な具体的ゲーム機能とデータの準備方法は, 現時点では定義しない.

## タイトル画面の操作

* タイトル画面にはキャッシュクリアとアセット追加のボタンを設置する.
* アセット追加ボタンから, プレイヤーは任意の画像をゲーム内のキャラクターに割り当てられる.
* キャラクター画像はClient側のアセットとして扱い, Server用ProcessedMasterDataの対象としない. 詳細は「[マスターデータ](../game/master_data.md)」を参照する.
* アセット追加時のPNG取り込みとOPFSへのコピー, バージョン別配置は前節を正とする. 追加画像のキャラクターとの対応付けの永続化・復元, PNG以外の受け入れ形式, 再割り当て時の扱い, キャッシュクリアの対象およびOPFSアセットへの影響は現時点では定義しない.

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
* この通信仕様をブラウザ側で利用する具体的な通信API・ライブラリは未定義とする. RefreshToken Cookieの属性と認証上の制約は既存のネットワーク・認証仕様を正とする.

## 情報源

* 添付`rust_wasm_png_hca_library_selection(1).md`（2026-10-09）, 第1～7節.
* `design/system/network.md`「通信暗号化要件」.
* `design/game/master_data.md`.

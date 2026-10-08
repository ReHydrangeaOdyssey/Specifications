# クライアント仕様

## ログイン・サーバー未接続時のゲームプレイ

* ログインの可否およびサーバーへの接続可否にかかわらず, ゲーム自体はプレイできる.
* アリーナ, 騎士団戦, その他サーバーとの通信が必要な処理は, ログインできない状態やサーバーへ接続できない状態では利用を制限する.
* サーバー接続が必要な処理は, オフラインプレイによってServerの正本状態を変更しない.
* 接続不要で利用可能な具体的ゲーム機能とデータの準備方法は, 現時点では定義しない.

## タイトル画面の操作

* タイトル画面にはキャッシュクリアとアセット追加のボタンを設置する.
* アセット追加ボタンから, プレイヤーは任意の画像をゲーム内のキャラクターに割り当てられる.
* キャラクター画像はClient側のアセットとして扱い, Server用ProcessedMasterDataの対象としない. 詳細は「[マスターデータ](../game/master_data.md)」を参照する.
* アセット追加画像の形式, 保存・復元方法, 再割り当て時の扱い, キャッシュクリアとの関係は現時点では定義しない.

## アニメーション


すべてイベントキューに入れて各イベントに応じてアニメーションなどを行う.

## サーバーへの接続

ゲーム結果はGameServerの計算結果を正とする.

アリーナではClientとGameServerが同一バージョンの戦闘ロジックを保持する. `StartArenaBattle`の成功レスポンスでは, Clientが戦闘を再現するために必要な相手キャラクター初期状態とSeedのみを返し, GameServerが算出した勝敗や最終HP等の戦闘結果自体は返さない. Clientは自身の初期状態, レスポンスで受け取った相手初期状態, Seedを入力としてGameServerと同一の戦闘ロジックを実行し, 表示用の戦闘進行を再現する.

同一の初期状態, Seed, 戦闘ロジックからClientとGameServerは同一結果を算出することを前提とし, 結果の正本はGameServer側の計算結果とする.



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

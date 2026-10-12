# クライアント仕様

## 実行環境・描画方式

* Clientの実装方式はRustをWebAssembly（WASM）へコンパイルするWeb Clientとする.
* 対象環境はiPhoneのSafari / PWAおよびAndroidのChrome / PWAとする. ブラウザ下限はiOS Safari 16.3 / Android Chrome 120とし, これらが利用できるOSの下限をiOS 16.3 / Android 8.0とする. これはブラウザの対応OSに基づく配布要件であり, 当該下限端末でのゲーム動作・性能の実機保証を意味しない. Clientの公開先は`https://rehydrangeaodyssey.github.io/`（GitHub Pages）とし, 配布リポジトリは`https://github.com/ReHydrangeaOdyssey/ReHydrangeaOdyssey.github.io`とする. 独自ドメインは採用しない. GameServerをClientの公開URLで直接公開しない. Public API ServerのHTTPS Originは別途定義する.
* 対象は2Dゲームとし, 最大20対20のリアルタイム騎士団戦での表示を想定する. 最大20対20を描画性能試験の条件とする.
* 主描画方式はWebGL 2とし, `web-sys`を介した独自のスプライトバッチレンダラーを使用する. 汎用2DエンジンとCanvas 2Dを主レンダラーとしては使用しない. 別途UI Frameworkも使用しない.
* PNGのデコードにはブラウザの`createImageBitmap()`を使用し, `ImageBitmap`からWebGL 2テクスチャへアップロードして描画する. PNGの全画素RGBAを描画のためにWASMメモリへ複製することは前提としない.
* 描画順を維持しながらスプライト描画をバッチ化する. 同一テクスチャの共有, 可視範囲に応じた段階ロード, 不要なテクスチャと`ImageBitmap`の解放を実施する. テクスチャアトラス・インスタンシングをどの範囲に適用するかは実測で判断する.
* 実行時RAM・CPU/GPU負荷, 配布WASMサイズ, 依存の少なさ, 実装容易性の順に最適化する. 合否を判定する数値はFPS30以上と配布前の非圧縮WASMファイル500MB以下とする. FPSは最大40キャラクター表示で初期10秒を除外した連続60秒の平均を記録する. WASMサイズはCIで生成された`.wasm`のバイト数とする. 50MBを超えた時点で追加最適化の検討対象とする（直ちに不合格とはしない）. GPU使用率とブラウザを含むRAM消費の統一的な計測手段がないため80%/2GBの閾値は合否要件から外し, 可能な範囲で参考計測する. 未測定の性能合格は宣言しない.

## 音声形式・再生

* HCAを再生対象形式とし, Rust/WASM側でHCAからPCMへデコードしたうえでWeb Audio APIで出力する.
* HCAデコーダーはPure Rustの`cridecoder`（選定資料の候補バージョン`0.3.6`）を採用候補とする. iPhone Safari/WASM上のビルド・動作・ピークメモリは未検証であり, 実機検証を通過するまで最終採用確定とは扱わない.
* 短い効果音・ボイスは必要に応じて全体をデコードし, `AudioBuffer`を再利用する.
* 長いBGM・ボイスは全体PCMを常駐させず, 小容量のPCMチャンクを逐次供給して`AudioWorklet`で再生する. 初期実装での供給経路は`MessagePort`とする.
* `AudioWorkletProcessor`のリアルタイム処理内でHCAデコードや大容量のメモリ確保を行わず, 制御側またはWorker側で先行デコードする.
* HCAのサンプリングレートは22,050Hzとする。鍵が必要なHCAは既知の鍵キャッシュを優先し、失敗時または未登録時に鍵探索を実施する。1ch入力はL/Rへ同一PCMサンプルを複製し、2ch入力は元の左右を維持する。 SE同時再生は最大5とする. ループ可否は保存先の素材区分で判定する。`./assets/`配下のBGM専用フォルダへ配置されたHCAは音源全体をループ再生し、それ以外のHCAはループ再生しない。設定用`hca_config.json`は使用しない。ループ区間の部分指定は現行スキーマでは行わない。 出力は常に2ch PCMとしWeb Audio APIへ渡す。  2チャンネル再生の実機確認は未実施とする. 長尺音声のPCM先読みは実装初期値として500msとし, 残量250msを下回る前に追加供給する. この初期値は測定前の暫定設計値であり, 欠音の有無を実機計測して変更する. `SharedArrayBuffer`は初期実装では採用しない.

## アセットの取得・保存

* PNG/HCAファイル本体はGameServerから配信しない. 各ユーザーが端末上で用意する素材の権利許諾をClientが自動審査する機能は設けない. Clientが配布するソフトウェアおよび同梱素材のライセンス確認は別扱いとする. アセット辞書は`https://github.com/ReHydrangeaOdyssey/AssetDictionary/releases`のRelease Assetから取得する。ログイン成功時は原則取得するが、Clientの`./config.cfg`に従う。`update_asset_dictionary: false`なら自動取得せず前回保存済みの辞書を使用する。`asset_dictionary_version: latest`なら最新Release、その他なら指定したVersion文字列に対応するReleaseを選択する。取得に失敗した場合は1回だけ再試行し、なお失敗するなら旧辞書を使用する。辞書はGameServerから取得しない。
* タイトル画面の「アセットの追加」から専用シーンへ遷移する. PNG/HCAの個別選択とディレクトリの一括選択を提供する. 「コピー」と「移動」を選択できるようにし, 移動には「ゲーム内へファイルの移動はゲーム終了時に消える可能性がある」と表示する. 移動で元ファイルを削除するのはブラウザの削除権限が取得できる場合のみとし, OPFSへの保存成功を確認してからユーザーの明示操作で削除する. 対応しない端末では元ファイルを削除できない旨を表示し, コピーのみ利用可能にする.
* 追加できる画像の形式はPNGだけとし, 音声は選定済みのHCAを対象とする. 取り込み時に拡張子が`.png`・`.hca`のいずれかであることを確認し、拡張子と実データ形式を照合する。PNGは画像デコード成功、HCAはヘッダー・デコード初期化成功を取り込みの成立条件とする。形式が一致しないファイルや解析できないファイルはOPFSへの保存・既存ファイル上書きを行わず、当該ファイルの取り込み失敗として表示する。 Client独自のファイル容量・画像解像度制限・保存期間は設けない. ブラウザの容量quotaやデータ消去・ストレージ退避等による制約はClientで解除できないため, 永続保持を保証するものではない.
* 取り込みファイルはまずOPFS `./cache/temp/user_impoert/`へ一時配置する。辞書に一致したファイル本体のみを`./assets/`配下の対応Pathへ確定保存し、一致しないファイルは`./cache/unknown_resouce/`へ移して保管する。`./cache/`内のこの2領域はキャッシュクリアで削除される。キャラクターの骨格・アニメーション・アトラス等の本体は原則ユーザーが各自用意する。Clientが例外的に配布する代替画像等はユーザー取込先とは別領域に配置し、通常のアセット追加・上書き・削除操作からはアクセスできないようにする。 辞書と一致する素材は、元ファイル名から一意Pathまたは内容SHA-256別Pathを選ぶ。 再表示時もOPFS上の保存Pathを参照し, 自動割当用に別の配置先推測を行わない. 辞書未一致の手動区分・対象ID・元ファイル名・一時Pathを端末側へ保持するが、辞書照合成功前はゲーム内で使用しない。ログイン後の辞書照合でも元の割当を無断で変更しない。 Character区分では一時保存前にPlayerへCharacterIDを選択させ、割当メタデータに保持する。照合用の元ファイル名を保持し、辞書一致後の実保存先は辞書Pathとする。`character_<CharacterID>.png`への強制改名は行わない。同一Pathへの上書きはユーザー確認を適用する。
* タイトル画面の通常の取り込み対象はPNG/HCAとし、拡張子を除くファイル名に許可する文字は英字`A-Z`・`a-z`、数字`0-9`、`_`、`-`、`(`、`)`のみとする。拡張子区切りの`.`はこの文字制限の対象外とする。条件外の名前は取り込みを受け付けない。選択されたディレクトリ配下を再帰的に取り込む. 拡張子付き元ファイル名を辞書の第1キーへ完全一致照合する。`path`が非空ならその一意Pathを使用し、`path`が空なら内容SHA-256の小文字16進64文字を算出して`paths`オブジェクトの同一Hashキーに対応するPathを選択する。いずれにも一致しない素材はゲーム内表示・再生に使用しない。手動指定した区分・対象IDは端末側に記録できるが辞書の照合条件を迂回しない。 辞書一致素材のPathは辞書を正本とする。手動取り込みの保留先は`./cache/unknown_resouce/`とする。 ファイル名は英語表記とする運用方針を前提とし, ファイル名照合前にUnicode正規化・大文字小文字変換を行わない。辞書生成側も同一ファイル名文字列を使用する。 既存Pathへの上書きはユーザー確認後に限り, 複数件には「一括で上書き」「一括でキャンセル」を提供する. ハッシュ衝突の追加回避規則は設けない.
* 追加済みファイルをClientが容量都合で自動削除しない. タイトル画面に「アセット削除」を設け, `./assets/`内の全素材または任意の個別/複数素材を選択して明示的に削除できる. OPFS容量不足時は容量不足を表示し, 解消されるまでゲーム操作を不可とするが, タイトルからのアセット削除は可能とする. ブラウザのquota/自動退避・ユーザー操作によるストレージ削除は別途のブラウザ制約とする.
* OPFSの配置基準は`./game_info.json`, `./assets/`, `./cache/`とし, バージョンごとの専用アセットディレクトリは原則設けない. `game_info.json`に現在と前回のバージョン情報を保持する. ゲームVersion変更時の明示的な配置差分だけに基づき`./assets/`内の配置を移行する。同一ゲームVersionで辞書だけが更新された場合は既存素材の配置先を移動せず、新規に取り込む素材から新辞書Pathを用いる。 `game_info.json`の検証と必要な差分処理にエラーがないことを切替成功条件とする. 差分移行時は`./cache/asset_migration/`を作業領域とし、移行中マーカーに移行元Version・移行先Versionを保持する。新配置先を作業領域で全件検証し、成功後にのみ`game_info.json`の現行Versionを更新する。移行途中に終了した場合はマーカーの存在で未完了を検出し、次回起動時に同じ差分を最初から再実行する。元の配置先は切替完了まで維持する。 バージョンは`version.major`, `version.minor`, `version.patch`の非負整数（u32）で表現し, 前回値は`previous_version`に同じ構造で保持する. 不正なバージョン値の場合は初期値に再生成する.  取り込み中断後の自動再開を保証する仕様は設けない.
* PNGはOPFSから`File` / `Blob`として読み, `createImageBitmap()`でデコードする. HCAは必要なメタデータと圧縮ブロックを読み, 圧縮ファイル全体とPCM全体の同時常駐を避ける.
* OPFSの階層は`./game_info.json`, `./assets/<something>`, `./cache/<something>`とする. タイトル画面の「キャッシュクリア」はVersion差分移行中を除いて`./cache/`配下のみを消去し, `./assets/`と`./game_info.json`は削除しない.
* GPUテクスチャ, デコード済みPCM, WASMヒープ, ブラウザ内部の一時メモリを分けて測定する. 不要な`ImageBitmap`, WebGLテクスチャ, `AudioBuffer`の保持を終了する.
* OPFSへ保存するアセットと認証情報は区別し, AccessTokenをOPFSへ永続化しない.

## ログイン・サーバー未接続時のゲームプレイ

* タイトルから認証用ログイン画面へ遷移できる. LoginID・Password入力とログイン操作はClient画面が担当し, 資格情報の検証とSession発行は認証OriginとServerが担当する. 認証コード・PKCEと第一者Cookieの通信方式は既存の認証仕様に従う.
* ログイン未実施・失敗・キャンセルでもホームへ遷移でき, Server通信が必要な機能のみ無効とする.

* ログイン不可またはServer未接続時は, Server通信を必須とする操作だけを利用不可とする. Server通信を必要としない画面遷移・表示・端末内処理は利用可能とする. これにはタイトル・ホーム間の遷移, アセットの追加・削除, キャッシュクリア, クレジット画面の表示とタイトルへの復帰を含む.
* ローカル操作であっても必要なブラウザAPI・端末保存域が使用できない場合には, 各機能の失敗時規則および容量不足時の制限を適用する. Server通信を必要とする情報の取得や更新は通信・認証の回復まで行わない.
* Serverとの接続および必要な認証が回復した場合は, Server通信を必要とする操作も利用可能に戻す. 使用可否は各操作に必要な通信・認証状態に従う.
* Serverを正本とする状態を未接続中にClientだけで変更しない.

## タイトル画面の操作

* タイトル画面に「キャッシュクリア」「アセットの追加」「アセット削除」「クレジット」ボタンを配置する. これらのローカル操作はログイン不可・Server未接続時も使用できる. OPFS容量不足の場合はゲーム操作を制限するが, 容量解消用のアセット削除は利用可能とする.
* 「アセットの追加」から専用シーンへ遷移し, PNG/HCAを読み込む。辞書が利用可能なら元ファイル名の一致を確認し、同名候補が複数の場合だけ内容SHA-256を照合して配置し、辞書が未取得ならユーザーによる区分・割当先指定で取り込む。ログイン後に辞書を取得したときは既存の手動割当素材を照合し、一致先へ変更する場合はユーザーに確認する。戻るボタンでタイトルへ戻る.
* キャラクター画像・UVデータはClient側のアセットとして扱い, Server用ProcessedMasterDataの対象としない. 詳細は「[マスターデータ](../game/master_data.md)」を参照する.
* 「キャッシュクリア」はOPFSの`./cache/`だけを削除する。ただしVersion差分移行中は作業マーカーを消さないため操作を拒否する。 「アセット削除」は`./assets/`の任意素材を個別または一括で削除する.
* 「クレジット」から専用画面へ遷移し, 「戻る」でタイトルへ復帰する. ライセンス情報の閲覧はログイン・Server接続を要しない.

## アセット保存Path

取得辞書の`path`および`paths`内の配置先Pathを`./assets/`配下の相対Pathへ限定し、親ディレクトリ参照・絶対Path・URL形式・制御文字を拒否する。一括取込みの途中終了では処理済みファイルを保持し、未処理ファイルを変更しない。削除後は当該素材へのローカル参照を無効化する。

## クレジット・ライセンス表記

* ゲーム本体・Client配布物に関係するライセンス, 著作権表示, 必要な帰属表記等はすべて専用のクレジット画面に掲載する. 内容は縦スクロールで閲覧可能とする.
* Rust製Clientおよび配布に含めるRust依存crateのライセンス一覧と必要な本文は`cargo-about`で生成し, Clientの静的配布物に組み込んでクレジット画面から表示する. Rust依存以外の同梱配布物に必要な表記, および自動生成対象外の必要な記載は同じ画面に追加する. 実際の著作権者名・ライセンス本文は依存や同梱物が確定した時点の内容を使用し, 未確認の記載を作成しない.
* 各ユーザーが自身の端末から取り込むPNG/HCAについて, Clientによる個別素材ライセンスの自動審査やクレジット画面への自動追加は行わない. Client自身が配布するソフトウェア/同梱物の必要な表記とは区別する.

## アニメーション

* キャラクター画像は複数のスプライトで構成し、骨格（`ArmatureData`）とボーン（`BoneData`）に対応する表示データ（`DisplayData`、`SkinData`）を用いて描画する.
* アニメーションデータはモーション（`MovementData`）、ボーンごとのタイムライン（`BoneTimeline`）、各フレーム（`FrameData`）を保持する. フレームには表示スプライトのIndex、位置・奥行・拡縮・傾き、補間関連値、色・ブレンド値、イベント名を保持する.
* スプライトの参照情報は`TextureData`および画像・アトラスの参照Pathを保持する. PNG画像の画素情報およびアトラスファイル本体はアニメーションデータに含めず、Client側の画像アセットとして扱う.
* スプライトアトラスのデータ構造は「[スプライトアトラス定義](../system/plist.proto)」に従う. `PlistRoot.frames.entries`でスプライト識別名をキーとした各画像領域の座標（`x`、`y`）、大きさ（`width`、`height`）、オフセット（`offsetX`、`offsetY`）、元画像サイズ（`originalWidth`、`originalHeight`）を保持する. `metadata`および`texture`はテクスチャ名・サイズ等の参照情報を保持する.
* データ構造と各フィールドの型・番号は「[スプライトアニメーション定義](../system/sprite_animation.proto)」を正とし、配列の要素順を維持する. キャラクター表示には既定のWebGL 2スプライト描画方式を使用する.
* アトラス復元・ボーン変換・モーション評価と描画順は「[スプライトアニメーション実行規則](sprite_animation_runtime.md)」に従う。左右で別の骨格・画像データが存在する場合は対応するデータ一式を使用し、単純な左右画素反転による代用は行わない。
* CharacterID・向き・Actionと骨格・モーションの対応は、アセットのPath照合辞書とは別の対応情報で決める。対応情報がない場合は代替画像に切り替え、`path`/`paths`やファイル名からモーションを推測しない。各ユーザーが各自用意する骨格・アニメーション・画像・アトラスをClientのローカルデータとして扱い、Clientが提供する一部の代替画像等は別リポジトリから配布する。ユーザーの通常取込操作からClient配布画像の上書きを認めない。
* キャラクターの**表示モーション遷移**は「[キャラクター表示モーションの状態遷移](character_motion_state.md)」に従う。通常待機`wait`・防御系待機`def_wait`・特殊待機`flatline`、`run`、`attack`・`attack2`、`attack_out`・`attack_in`・`landing`、`damage`・`escape`・`dead`、`skill_in`・`skill_out`、`win`を区別する。`def_damage`・`entry`・`skill_all`も参照可能なモーション名に含めるが、用途や切替経路の推定部分を確定動作として扱わない。表示演出はServer正本のBattle状態と区別し、`attack_out`・`attack_in`の完了経路、被弾後の生死判定、`endSkill`による切替を同文書に従って処理する。
* Clientで発生するイベントはイベントキューに入れ、各イベントに応じたアニメーションなどの表示処理を行う。
* 画像素材の欠落・画像読込失敗・アニメーション構造の必須値欠落または未知値による読込失敗時は、該当キャラクターを事前に用意した代替画像で表示する。代替画像はユーザー取り込み用`./assets/`およびOPFS辞書に依存しないClient配布物として別リポジトリから取得し、取得後は描画に先立ち読み込み可能な状態にする。取得できない場合は画像を描画せずエラー表示する。エラーのあるアニメーションは再生しない。

アセット辞書は`./config.cfg`の更新設定が有効なログイン成功時に、指定リポジトリのReleaseから取得する。未ログイン状態では新たに取得しない。取得失敗時は1回だけ再試行し、再失敗時は保存済みの前回辞書を使用する。前回辞書が存在しない場合は空の辞書状態を新規作成する。利用可能な辞書がない間は自動割当を停止し、手動区分・割当先指定によるローカル取り込みは維持する。辞書の有無は手動指定による新規取り込みの可否を変更しない。

アセットの**新規取り込み**は未ログイン・通信未接続時も利用可能とする。未ログイン時は辞書を取得せず、手動の素材区分・割当先指定で保存する。ログイン後に辞書を取得できた場合は`./cache/unknown_resouce/`内の素材をファイル名、必要時には内容SHA-256で照合し、保存先の変更が必要なら移動・上書きの確認を行う。照合未完了の素材を自動削除しない。既存素材の閲覧・削除とローカル画面も未ログインで利用可能とする。

## サーバーへの接続

ゲーム結果はGameServerの計算結果を正とする.

アリーナではClientとGameServerが同一バージョンの戦闘ロジックを保持する. `StartArenaBattle`の成功レスポンスでは, Clientが戦闘を再現するために必要な相手PlayerID・相手キャラクター初期状態（最大HP含む）・Seedを返し, GameServerが算出した勝敗や最終HP等の戦闘結果自体は返さない. Clientは自身の初期状態, レスポンスで受け取った相手初期状態, Seedを入力としてGameServerと同一の戦闘ロジックを実行し, 表示用の戦闘進行を再現する.

同一の初期状態, Seed, 戦闘ロジックからClientとGameServerは同一結果を算出することを前提とし, 結果の正本はGameServer側の計算結果とする.

騎士団戦の殲滅でもClientはGameServerと同じ`game-core`で戦闘を再計算する. `GuildBattleAnnihilationResponse`には確定した相手PlayerID, 対戦相手のFormationID, 両パーティの戦闘開始時キャラクターステータス（最大HP含む）, この戦闘で有効なタクティクス継続効果, Seedを返す. 結果の正本はGameServer側とし, Clientへ戦闘結果の最終HP・行動ログを別途送らない.

騎士団戦参加中は`SubscribeGuildBattleUpdates`の通知ストリームで, 所属騎士団に応じたチェイン値・チェイン残り時間（ミリ秒）と両騎士団のスコアを受信する. チェインの時間経過リセットだけによる通知はないため, 残り時間をClient側で表示用に減算する. 30:00到達で通知購読を終了し, 30:00までにキューへ入った当該Playerの要求が残っている場合のみその処理完了後に終了する. 出撃結果レスポンスを返した後のGameServer処理で変更された状態を接続中の全参加者へ通知し, 再接続時は`GetGuildBattleStatus`の現在値を正本とする.


回復・復活・出撃待機の残り時間は、Clientが受信した値を基準にローカルで表示する。動作中の定期的な時刻同期は行わない。Client表示が先に終了した場合はServerから正本の残時間を取得して反映し、Server側が先に終了した場合はServerの終了通知で正しい残時間を反映する。`SubscribeGuildBattleUpdates`は既存のスコア・チェイン更新受信手段を指し、残り時間の定期同期とは別の機能である。

Login成功後に`GetArenaParty`および`GetGuildBattleParty`を実行し、Serverに保存された最新編成でローカル編成を更新する。端末変更やローカル保存消去後もこの2 APIの応答を編成編集の初期状態とする。未登録の場合は登録済み編成を推測で生成しない。

## 編成のローカル保持とServer照合

* ClientはArena編成と騎士団戦編成の静的構成をローカルへ保存する.
* `StartArenaBattle`ではローカル保存したArena編成を要求へ含める. GameServerはDatabase上のArenaPartyと比較し, 不一致の場合はServer保存編成を返す. Clientは返されたServer編成でローカルArena編成を上書きし, その編成を戦闘再現に使用する.
* `JoinGuildBattle`ではローカル保存した騎士団戦編成を要求へ含める. GameServerはPreload済み編成と比較し, 不一致の場合はServer編成を返す. Clientは返されたServer編成でローカル騎士団戦編成を上書きする.
* `StartArenaBattle`および`JoinGuildBattle`ではClientVersionを送信し, GameServer Versionと不一致の場合は更新を促して処理を開始しない.

## 認証情報

* AccessTokenはClientのプロセスメモリ上だけに保持し, OPFS, LocalStorage, IndexedDB等の永続Storageへ保存しない.
* RefreshTokenはClient JavaScriptから読み取らず, Public API Serverが設定する`__Host-RefreshToken` HttpOnly Cookieを使用する.
* Client起動時または再読み込み時にAccessTokenを保持していない場合は, 認証Originのトップレベルページで`RefreshAccessToken`を実行し, 一度限りの認可コード・PKCE検証を経てAccessTokenをClientへ取得する. そのためページ遷移を伴う.
* Logout時はClientが保持するAccessTokenを破棄する. RefreshToken CookieはPublic API Serverが削除する.

認証失効が判明した場合は、Clientメモリ上のAccessTokenを破棄してログアウト状態に移行し、Server未接続として扱う。進行中の認証必須RPCや通知Streamを中止し、復帰まで騎士団戦・Arena等の通信必須操作を許可しない。ローカル画面・アセット操作は引き続き使用できる。

## Public API通信方式

* ClientとPublic API Server間の通信方式は「[ネットワーク](../system/network.md)」に従い, HTTP/2 over TLS 1.3とし, API PayloadにはProtocol Buffersを使用する.
* `SubscribeGuildBattleUpdates`はHTTP/2 Response streamを使用し, `GuildBattleScoreUpdate`をProtocol Buffers varint長prefix付きで順次受信する.
* Public API通信には`WebSocket`を使用しない.
* ブラウザ標準の`fetch()`（Rustからは選定済み`web-sys`/`wasm-bindgen-futures`等を使用）をPublic API通信に使用する. 通常のAPIは`fetch()`で送受信し, 通知はResponse Bodyの`ReadableStream`を逐次読み取りProtocol Buffers varint長prefixでフレーム復元する. HTTP/2とTLS 1.3のネゴシエーションはブラウザと接続先が担当し, JavaScriptが直接バージョンを強制しない. ブラウザからのHTTP/2 + TLS 1.3接続成立は配置先で検証する. Rust専用HTTPライブラリの追加は不要とする. HTTP Method/Pathは`design/system/api_transport.md`を正とする.
* WebAssemblyはブラウザ内で実行され, Rust/WASMからの通信もブラウザの`fetch()`を介するため, WASMとJavaScriptを静的配布先から取得した後のAPI通信にもOrigin・CORS・Cookieの規則が適用される. `SameSite=Strict` CookieはCross-Site要求へ送信されない. ClientからGameServerへ直接通信せず, Public API Serverへ接続する構成を維持する.
* 配布OriginがPublic API認証Originと異なるSiteになる場合, Cookieを利用するLogin/Refresh/Logoutは認証Originのトップレベルページ内で実施し, 一度限りの認可コード+PKCE S256でClientへAccessTokenを受け渡す. `SameSite=Strict`を維持し, Third-party Cookieは使用しない. 認証OriginはPublic API配布設定値、Client戻り先は`https://rehydrangeaodyssey.github.io/auth/callback/`に固定し、認可コード交換のwire契約は`design/system/public_api.proto`を正とする. 詳細は`design/system/network.md`を正とする.

## 参照資料

* 添付`rust_wasm_png_hca_library_selection(1).md`（2026-10-09）, 第1～7節.
* `design/system/network.md`「通信暗号化要件」.
* `design/game/master_data.md`.

* `design/programming/client/client.md`（ブラウザAPIの制約と出典）.

## フレンド・プロフィール表示

* 騎士団画面から所属メンバーのプロフィールを開き、`GetPlayerProfile`の名前・騎士団戦参加回数・勝利数・累計騎士団スコアを表示する。
* プロフィールの申請操作は`SendFriendRequest`、ホーム通知一覧は`ListNotifications`、承認・拒否は`RespondFriendRequest`を使用する。同方向の再申請時は「申請済み」、相互申請の一方が承認済みの状態で逆方向に応答した際は「既にフレンド」を表示する。拒否による申請者向け通知は発行しない。
* ホームのフレンド一覧は`ListFriends`から取得し、本人からの解除操作は`RemoveFriend`を実行する。Arenaのフレンド選択一覧は`ListFriends`から取得し、選択したPlayerIDをFriend対戦の`OpponentID`へ渡す。

### `game_info.json`のバージョンデータ

```json
{
  "version": { "major": 0, "minor": 0, "patch": 0 },
  "previous_version": null
}
```

`major`・`minor`・`patch`はJSON数値の非負整数（`0`～`4294967295`）とする。過去版がある場合`previous_version`にも同じ構造を保存する。初回の前回版は`null`とする。構造や型が不正な場合は`version=0.0.0`, `previous_version=null`の初期値へ再生成する。バージョンの更新に伴う実ファイルの差分移行の定義は別途必要とする。

音声素材の欠落、HCAのデコード失敗、再生エラー時は音声を出力せず無音とする。音声エラーによってServer正本の戦闘状態や進行結果を変更しない。

## アセット辞書の形式と照合規則

辞書はUTF-8 JSON Objectとし、拡張子付き元ファイル名を第1キーとする。各エントリは`path`（一意の保存先、同名衝突時は空文字）と`paths`（ファイル内容SHA-256の小文字16進64文字 → 保存先PathのObject）を持つ。**JSON配列の中へHash名付きプロパティを置く形式は採用しない**。

```json
{
  "example.png": {
    "path": "characters/example.png",
    "paths": {}
  },
  "collision.png": {
    "path": "",
    "paths": {
      "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef": "characters/one.png",
      "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789": "characters/two.png"
    }
  }
}
```

- 元ファイル名はディレクトリ名を除いた拡張子付き文字列そのものとし、Unicode正規化、大文字小文字変換、ファイル名SHA-256変換は行わない。未登録名は照合失敗とする。
- `path`が非空ならそのPathへ配置する。`path`が空文字なら内容全体のSHA-256を計算して`paths`のキーに一致する保存先を使用する。`path`と`paths`の双方に有効な割当を記載する曖昧なエントリは拒否する。内容Hashを必要としない一意名では`paths={}`とする。
- `path`/`paths`で解決した非空Pathは`./assets/`からの相対Pathであり、絶対Path、URL、`..`、空セグメント、制御文字、逆向き区切りを拒否する。辞書JSONが不正なら以前の有効な辞書へ切り替える。
- 未一致の素材は`./cache/unknown_resouce/`で保留し、Runtimeで使用しない。OPFSキャッシュを消去すると未一致素材と取込一時データは消去される。元ファイル名、仮区分、CharacterID、現在Pathを保存済みの割当メタデータから再照合する。

端末内のRelease辞書更新・割当JSON・HCAのBGM判定・鍵キャッシュの具体的Path/原子的切替は「[ローカルアセット保存契約](local_asset_storage.md)」に従う。
## アセット辞書取得の設定

静的Clientの配布ルートにYAMLの`./config.cfg`を置く。以下を初期値とする。

```yaml
update_asset_dictionary: true
asset_dictionary_version: latest
```

ユーザーが端末で明示的に信頼境界を変更する場合だけ、OPFS Rootの`./config.cnf`（YAML形式）を別に使用する。仕様ZIPのRootに含める`config.cnf`は初期値のテンプレートであり、これを配布サイトから読んだだけで端末OPFSに自動的な検証解除を適用しない。未作成の場合の安全側初期値は次のとおり。静的配布物`config.cfg`とローカル`config.cnf`は別ファイルであり、静的ファイルをブラウザから書き換えない。

```yaml
verify_asset_dictionary_source: true
allow_user_asset_override: false
```

- `update_asset_dictionary=true`ならログイン成功のたびに指定Releaseから辞書を取得する。`false`ならログイン時の自動更新を行わず、端末保存の辞書をそのまま使う。
- `asset_dictionary_version=latest`なら`ReHydrangeaOdyssey/AssetDictionary`の最新Releaseを選ぶ。それ以外は指定文字列をReleaseのtag名として扱う。Release一覧の参照とAssetダウンロードはGitHubのRelease APIから得る実URLを使用する。Release Asset名が`asset_dictionary.json`のものだけを選択し、存在しないか同名Assetが複数なら更新失敗とする。受信したJSONとSafe Pathの全件検証・旧辞書保持・原子的切替は`design/client/local_asset_storage.md`に従う。失敗時は1回再試行し、旧辞書がなければ空辞書を作成する。
- `config.cfg`はGitHub Pages上の静的配布物であり、ブラウザ内でこの配布ファイルを書き換えない。運営側が配布設定を変更した場合に次の配布設定読込から適用する。設定が不正な場合は上記初期値を用いる。

### 外部素材の信頼確認とユーザーの明示的な例外

- 通常は指定された配布リポジトリ・Release Asset名・署名検証用の信頼済み公開鍵で配布物の出所と完全性を検証する。取得だけで自動信頼せず、検証不可・署名不正なら新規Generation/代替画像へ切り替えない。実公開物に署名が存在しない場合は検証成功とみなさず、前回の検証済み素材を使用する。
- 利用者が端末内`./config.cnf`で`verify_asset_dictionary_source: false`を**明示設定**した場合にのみ未検証Release辞書の受入れを許可する。この例外でもSchema・Path安全性・サイズ・内容Hashの整合検証を省略しない。未検証Generationの状態を表示し、既存の検証済みGenerationをロールバック用に保持する。
- 利用者が端末内`./config.cnf`で`allow_user_asset_override: true`を明示設定した場合は、ゲーム内に表示する素材をユーザーの指定素材で代替できる。ただしClientのローカル描画・再生に限り、Server正本や他Playerの素材・Battle計算には反映しない。実行データの構造検証・Path隔離は引き続き必須とする。初期値`false`では辞書不一致を通常使用できない。
- ローカル設定ファイルはブラウザのOPFS上にあり利用者の操作で変更可能とする。設定不正は初期値に戻し、画面から検証無効化を案内する際は外部配布物の信頼性を保証しないことを明示する。署名用公開鍵の値・実際の署名File名は配布側の実体確定前に架空の値で埋めない。


## HCA設定と鍵キャッシュ

- HCA入力1chは左右へ同一PCMを複製して2ch出力し、入力2chは左右を維持する。`./assets/`のBGM専用フォルダに配置されたHCAだけを音源全体ループ、それ以外は非ループとする。`hca_config.json`やループ区間の個別設定は使用しない。
- 鍵が必要なHCAをデコードする前にOPFS `./cache/temp/decode/keys.json`のファイル名・内容SHA-256複合キーを持つキャッシュを調べる。鍵があれば先に試し、存在しないか鍵が誤りでデコードできない場合に鍵探索を実施し、成功した鍵をキャッシュへ反映する。ファイル名衝突や内容変更で誤った鍵を再利用した場合は探索し直す。鍵探索・音声デコードが失敗した場合は無音とする。キャッシュクリア時に鍵キャッシュも削除する。

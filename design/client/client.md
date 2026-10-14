# クライアント仕様

独自実装のソースコードはClient・Serverを含めすべて公開し、MIT Licenseで提供する。公開範囲・秘密情報・第三者素材の扱いは[ソースコードの公開とライセンス](../system/source_publication.md)を正とする。


## 実行環境・描画方式

* Clientの実装方式はRustをWebAssembly（WASM）へコンパイルするWeb Clientとする.
* 対象環境はiPhoneのSafari / PWAおよびAndroidのChrome / PWAとする. ブラウザ下限はiOS Safari 16.3 / Android Chrome 120とし, これらが利用できるOSの下限をiOS 16.3 / Android 8.0とする. これはブラウザの対応OSに基づく配布要件であり, 当該下限端末でのゲーム動作・性能の実機保証を意味しない. Clientの配布先はCloudflare Pagesとし、公開HTTPS Originは実配備時の`client_origin`とする。URLは未確定のまま固定しない。HTML・JavaScript・WASMの**各ファイルの非圧縮サイズを25,000,000 byte以下**とし、合計サイズに上限を設けない。 GameServerをClientの公開URLで直接公開しない. Public API ServerのHTTPS Originは別途定義する.
* 対象は2Dゲームとし, 最大20対20のリアルタイム騎士団戦での表示を想定する. 最大20対20を描画性能試験の条件とする.
* 主描画方式はWebGL 2とし, `web-sys`を介した独自のスプライトバッチレンダラーを使用する. 汎用2DエンジンとCanvas 2Dを主レンダラーとしては使用しない. 別途UI Frameworkも使用しない.
* PNGのデコードにはブラウザの`createImageBitmap()`を使用し, `ImageBitmap`からWebGL 2テクスチャへアップロードして描画する. PNGの全画素RGBAを描画のためにWASMメモリへ複製することは前提としない.
* 描画順を維持しながらスプライト描画をバッチ化する. 同一テクスチャの共有, 可視範囲に応じた段階ロード, 不要なテクスチャと`ImageBitmap`の解放を実施する. テクスチャアトラス・インスタンシングをどの範囲に適用するかは実測で判断する.
* 実行時RAM・CPU/GPU負荷, 配布WASMサイズ, 依存の少なさ, 実装容易性の順に最適化する. 合否を判定する数値はFPS30以上と配布HTML・JavaScript・WASMの**各ファイル非圧縮25,000,000 byte以下**とする。FPSは最大40キャラクター表示で初期10秒を除外した連続60秒の平均を記録する。サイズはCIで実配布する対象ファイルごとに検査する。 GPU使用率とブラウザを含むRAM消費の統一的な計測手段がないため80%/2GBの閾値は合否要件から外し, 可能な範囲で参考計測する. 未測定の性能合格は宣言しない.

## 音声形式・再生

* HCAを再生対象形式とし, Rust/WASM側でHCAからPCMへデコードしたうえでWeb Audio APIで出力する.
* HCAデコーダーはPure Rustの`cridecoder`（選定資料の候補バージョン`0.3.6`）を採用候補とする. iPhone Safari/WASM上のビルド・動作・ピークメモリは未検証であり, 実機検証を通過するまで最終採用確定とは扱わない.
* 短い効果音・ボイスは必要に応じて全体をデコードし, `AudioBuffer`を再利用する.
* 長いBGM・ボイスは全体PCMを常駐させず, 小容量のPCMチャンクを逐次供給して`AudioWorklet`で再生する. 初期実装での供給経路は`MessagePort`とする.
* `AudioWorkletProcessor`のリアルタイム処理内でHCAデコードや大容量のメモリ確保を行わず, 制御側またはWorker側で先行デコードする.
* HCAのサンプリングレートは22,050Hzとする。鍵が必要なHCAは既知の鍵キャッシュを優先し、失敗時または未登録時に鍵探索を実施する。1ch入力はL/Rへ同一PCMサンプルを複製し、2ch入力は元の左右を維持する。 SE同時再生は最大5とする. ループ可否は保存先の素材区分で判定する。`./assets/sound/bgm/`（ディレクトリ境界と大文字小文字を区別し、配下のサブディレクトリを含む）へ配置されたHCAは音源全体をループ再生し、それ以外のHCAはループ再生しない。設定用`hca_config.json`は使用しない。ループ区間の部分指定は現行スキーマでは行わない。 出力は常に2ch PCMとしWeb Audio APIへ渡す。  2チャンネル再生の実機確認は未実施とする. 長尺音声のPCM先読みは実装初期値として500msとし, 残量250msを下回る前に追加供給する. この初期値は測定前の暫定設計値であり, 欠音の有無を実機計測して変更する. `SharedArrayBuffer`は初期実装では採用しない.

## アセットの取得・保存

* PNG/HCAファイル本体はGameServerから配信しない. 各ユーザーが端末上で用意する素材の権利許諾をClientが自動審査する機能は設けない. Clientが配布するソフトウェアおよび同梱素材のライセンス確認は別扱いとする. アセット辞書は`https://github.com/ReHydrangeaOdyssey/AssetDictionary/releases`のRelease Assetから取得する。ログイン成功時は原則取得するが、Clientの`./config.cfg`に従う。`update_asset_dictionary: false`なら自動取得せず前回保存済みの辞書を使用する。`asset_dictionary_version: latest`なら最新Release、その他なら指定したVersion文字列に対応するReleaseを選択する。取得に失敗した場合は1回だけ再試行し、なお失敗するなら旧辞書を使用する。辞書はGameServerから取得しない。
* タイトル画面の「アセットの追加」から専用シーンへ遷移する. PNG/HCAの個別選択とディレクトリの一括選択を提供する. 「コピー」と「移動」を選択できるようにし, 移動には「ゲーム内へファイルの移動はゲーム終了時に消える可能性がある」と表示する. 移動で元ファイルを削除するのはブラウザの削除権限が取得できる場合のみとし, OPFSへの保存成功を確認してからユーザーの明示操作で削除する. 対応しない端末では元ファイルを削除できない旨を表示し, コピーのみ利用可能にする.
* 追加できる画像の形式はPNGだけとし, 音声は選定済みのHCAを対象とする. 取り込み時に拡張子が`.png`・`.hca`のいずれかであることを確認し、拡張子と実データ形式を照合する。PNGは画像デコード成功、HCAはヘッダー・デコード初期化成功を取り込みの成立条件とする。形式が一致しないファイルや解析できないファイルはOPFSへの保存・既存ファイル上書きを行わず、当該ファイルの取り込み失敗として表示する。 Client独自のファイル容量・画像解像度制限・保存期間は設けない. ブラウザの容量quotaやデータ消去・ストレージ退避等による制約はClientで解除できないため, 永続保持を保証するものではない.
* 取り込みファイルはまずOPFS `./cache/temp/user_impoert/`へ一時配置する。辞書に一致したファイル本体のみを`./assets/`配下の対応Pathへ確定保存し、一致しないファイルは`./cache/unknown_resouce/`へ移して保管する。`./cache/`内のこの2領域はキャッシュクリアで削除される。キャラクターの骨格・アニメーション・アトラス等の構造モデルは同梱モデルまたはClientへのセッション内読込みで供給し、通常のPNG/HCA取込み・`./assets/`内のProtoBuf保存とは区別する。Clientが例外的に配布する代替画像等はユーザー取込先とは別領域に配置し、通常のアセット追加・上書き・削除操作からはアクセスできないようにする。 辞書と一致する素材は拡張子別`<ext>/assets_dict.json`の元ファイル名から、単一`path`または内容SHA-256に一致した`paths`配列の全Pathを解決する。 再表示時もOPFS上の保存Pathを参照し, 自動割当用に別の配置先推測を行わない. 辞書未一致の手動区分・対象ID・元ファイル名・一時Pathを端末側へ保持するが、辞書照合成功前はゲーム内で使用しない。ログイン後の辞書照合でも元の割当を無断で変更しない。 Character区分では一時保存前にPlayerへCharacterIDを選択させ、割当メタデータに保持する。照合用の元ファイル名を保持し、辞書一致後の実保存先は辞書Pathとする。`character_<CharacterID>.png`への強制改名は行わない。同一Pathに異なる内容を上書きする場合は設定`allow_user_asset_override=true`とユーザー確認を必須とする。
* タイトル画面の通常の取り込み対象はPNG/HCAとし、拡張子を除くファイル名に許可する文字は英字`A-Z`・`a-z`、数字`0-9`、`_`、`-`、`(`、`)`のみとする。拡張子区切りの`.`はこの文字制限の対象外とする。条件外の名前は取り込みを受け付けない。選択されたディレクトリ配下を再帰的に取り込む. 拡張子付き元ファイル名を辞書の第1キーへ完全一致照合する。`path`が非空ならその相対Pathを使用し、`path`が空なら内容SHA-256の小文字16進64文字を算出して`paths`オブジェクトの同一HashキーにあるPath配列の**全要素**を複製先とする。部分的なPath選択は行わない。いずれにも一致しない素材はゲーム内表示・再生に使用しない。手動指定した区分・対象IDは端末側に記録できるが辞書の照合条件を迂回しない。 辞書一致素材のPathは辞書を正本とする。手動取り込みの保留先は`./cache/unknown_resouce/`とする。 ファイル名は英語表記とする運用方針を前提とし, ファイル名照合前にUnicode正規化・大文字小文字変換を行わない。辞書生成側も同一ファイル名文字列を使用する。 既存Pathへの**異なる内容の上書き**は`allow_user_asset_override=true`かつユーザー確認後に限り、複数件には「一括で上書き」「一括でキャンセル」を提供する。同一内容の再取込みは変更なしとして扱い、未配置Pathの新規取込みは同設定がOFFでも許可する。 ユーザーの明示的な差替え時も辞書未登録のファイル名・辞書未登録Pathの使用は認めない。`paths`方式は設定ONでも実内容SHA-256と選択候補Hashの一致を必須とし、Hash不一致を手動指定で迂回できない. ハッシュ衝突の追加回避規則は設けない.
* 追加済みファイルをClientが容量都合で自動削除しない. タイトル画面に「アセット削除」を設け, `./assets/`内の全素材または任意の個別/複数素材を選択して明示的に削除できる. OPFS容量不足時は容量不足を表示し, 解消されるまでゲーム操作を不可とするが, タイトルからのアセット削除は可能とする. ブラウザのquota/自動退避・ユーザー操作によるストレージ削除は別途のブラウザ制約とする.
* OPFSの配置基準は`./game_info.json`, `./assets/`, `./cache/`とし、バージョンごとの専用アセットディレクトリは設けない。`game_info.json`には現在のゲームVersionのみを記録する。同一ゲームVersionで辞書のみ更新された場合も旧辞書集合と新辞書集合の**拡張子・Path配列の全要素・元ファイル名・内容Hash条件の差分**を計算し、旧辞書にのみ存在するPathまたは**共通Pathでも新条件に不適合な実ファイル**を`./cache/obsolete_assets/`へ退避する。新辞書で引き続き許可されることを検証できた実ファイルのみ維持し、新辞書にしかないPathへ旧素材を推測で自動割当しない。 辞書更新の切替成功条件は新辞書と保存素材の検証完了とする。ゲームVersionは`version.major`, `version.minor`, `version.patch`の非負整数（u32）で表現し、不正な値は初期値に再生成する。  取り込み中断後の自動再開を保証する仕様は設けない.
* PNGはOPFSから`File` / `Blob`として読み, `createImageBitmap()`でデコードする. HCAは必要なメタデータと圧縮ブロックを読み, 圧縮ファイル全体とPCM全体の同時常駐を避ける.
* OPFSの階層は`./game/<HTML・JS・WASM等のプログラムファイル>`, `./game_info.json`, `./assets/<something>`, `./cache/<something>`, `./settings/<something>`および`./config.cnf`とする。初回オンライン取得したプログラムは`./game/`へ保存し、Service WorkerのVersion別Cache Storageを通じてオフライン時にも起動URLを提供する。Client更新では検証・バックアップ後に`./game/`配下を全量削除して新一式を配置し、成功後にActive Versionを切り替える。`./assets/`・`./settings/`は更新対象外とする。 タイトル画面の「キャッシュクリア」は辞書差分退避・構成素材入替・Clientプログラム更新の処理中を除いて`./cache/`配下のみを消去し, `./game/`・`./assets/`・`./settings/`・`./config.cnf`・`./game_info.json`は削除しない.
* GPUテクスチャ, デコード済みPCM, WASMヒープ, ブラウザ内部の一時メモリを分けて測定する. 不要な`ImageBitmap`, WebGLテクスチャ, `AudioBuffer`の保持を終了する.
* OPFSへ保存するアセットと認証情報は区別し, AccessTokenをOPFSへ永続化しない.

## シーン別アセット参照（外部JSON）

シーンごとのBGM/SE/Voice（HCA）および背景/UI/アニメーション参照画像（PNG）の**元ファイル名と論理キー**は、Rust/WASMの固定テーブルではなく、Clientと同じVersionで配布する静的`./scene_assets/<scene_id>.json`で管理する。シーン遷移時（または事前）にJSONを読み、拡張子別AssetDictionaryで許可された`./assets/`内の実体だけを読み込む。優先ロード`critical`、任意の先読み`prefetch`、失敗時の扱い、解放・キャッシュ失効は[シーン別Asset Manifest](scene_asset_manifest.md)を正本とする。これにより、実素材の同梱や既存のHCAループ判定・キャラクター構造モデルの扱いは変更しない。

## ログイン・サーバー未接続時のゲームプレイ

* タイトルから認証用ログイン画面へ遷移できる. LoginID・Password入力とログイン操作はClient画面が担当し, 資格情報の検証とSession発行は認証OriginとServerが担当する. 認証コード・PKCEと第一者Cookieの通信方式は既存の認証仕様に従う.
* ログイン未実施・失敗・キャンセルでも、有効辞書と検証済み代替画像の共通ゲーム開始前検査に合格すればホームへ遷移でき、Server通信が必要な機能のみ無効とする。

* ログイン不可またはServer未接続時は, Server通信を必須とする操作だけを利用不可とする. Server通信を必要としない画面遷移・表示・端末内処理は利用可能とする. これには**アセット開始前検査に合格した場合の**タイトル・ホーム間の遷移、アセットの追加・削除、キャッシュクリア、クレジット画面の表示とタイトルへの復帰を含む。
* ローカル操作であっても必要なブラウザAPI・端末保存域が使用できない場合には, 各機能の失敗時規則および容量不足時の制限を適用する. Server通信を必要とする情報の取得や更新は通信・認証の回復まで行わない.
* Serverとの接続および必要な認証が回復した場合は, Server通信を必要とする操作も利用可能に戻す. 使用可否は各操作に必要な通信・認証状態に従う.
* Serverを正本とする状態を未接続中にClientだけで変更しない.

## タイトル画面の操作

* タイトル画面に「キャッシュクリア」「アセットの追加」「アセット削除」「クレジット」ボタンを配置する. これらのローカル操作はログイン不可・Server未接続時も使用できる. OPFS容量不足の場合はゲーム操作を制限するが, 容量解消用のアセット削除は利用可能とする.
* 「アセットの追加」から専用シーンへ遷移し, PNG/HCAを読み込む。辞書が利用可能なら拡張子付き元ファイル名を完全一致させ、対応する`path`が非空なら単一の相対Pathへ、`path`が空なら内容SHA-256と`paths`のHashキーが一致した**全相対Path**へ複製する。いずれも保存先を`./assets/`起点に安全に解決する。辞書が未取得ならユーザーによる区分・割当先指定で取り込む。ログイン後に辞書を取得したときは既存の手動割当素材を照合し、一致先へ変更する場合はユーザーに確認する。戻るボタンでタイトルへ戻る.
* キャラクター画像・UVデータはClient側のアセットとして扱い, Server用ProcessedMasterDataの対象としない. 詳細は「[マスターデータ](../game/master_data.md)」を参照する.
* 「キャッシュクリア」はOPFSの`./cache/`だけを削除する。ただし辞書差分退避中・構成素材入替中・Clientプログラム更新中は処理の旧素材とマーカーを消さないため操作を拒否する。 「アセット削除」は`./assets/`の任意素材を個別または一括で削除する.
* 「クレジット」から専用画面へ遷移し, 「戻る」でタイトルへ復帰する. ライセンス情報の閲覧はログイン・Server接続を要しない.

## アセット保存Path

取得辞書の`path`および`paths`配列内の非空配置先は、**アセット領域`./assets/`を基準とする相対Path**（例：`dir_a/sample.png`）とする。保存先は`./assets/`と相対Pathを結合したOPFS Root相対Path（例：`./assets/dir_a/sample.png`）へ一度だけ正規化し、`..`・`.`・空セグメント・絶対Path・URL・バックスラッシュ・制御文字・`./assets/`などの不要な接頭辞を拒否する。通常複数ファイル取込みは**元ファイル単位**で確定し、`paths`配列の全複製先を同一単位で成功/復元させる。キャラクター構成セットの一括入替は`local_asset_storage.md`のセット単位ロールバック規則を優先する。削除後は当該素材へのローカル参照を無効化する。

## クレジット・ライセンス表記

Clientを含む全独自プログラムはMIT Licenseでソース公開する。Clientのクレジット画面には自作品のMIT License表示と、第三者ライブラリ・配布素材の権利表記を混同せず掲載する。詳細は[ソースコードの公開とライセンス](../system/source_publication.md)による。


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
* CharacterID・向き・Actionと骨格・モーションの対応は、アセットのPath照合辞書とは別の対応情報で決める。Clientが既に利用できる構造モデルと、ユーザーが当該セッションで提供して検証した構造モデルだけを使用し、`./assets/`にProtoBufファイルがあると仮定しない。明示選択したCharacterID/向きのモデル参照とArmature名は端末の`./settings/character_display_selections.json`へ必要な分だけ保存し、再起動時に参照先を再検証する。対応情報がない場合は代替画像に切り替え、`path`/`paths`やファイル名からモーションを推測しない。各ユーザーが各自用意する骨格・アニメーション・画像・アトラスをClientのローカルデータとして扱い、Clientが提供する一部の代替画像等は別リポジトリから配布する。ユーザーの通常取込操作からClient配布画像の上書きを認めない。
* キャラクターの**表示モーション遷移**は「[キャラクター表示モーションの状態遷移](character_motion_state.md)」に従う。通常待機`wait`・防御系待機`def_wait`・特殊待機`flatline`、`run`、`attack`・`attack2`、`attack_out`・`attack_in`・`landing`、`damage`・`escape`・`dead`、`skill_in`・`skill_out`、`win`を区別する。`def_damage`・`entry`・`skill_all`も参照可能なモーション名に含めるが、用途や切替経路の推定部分を確定動作として扱わない。表示演出はServer正本のBattle状態と区別し、`attack_out`・`attack_in`の完了経路、被弾後の生死判定、`endSkill`による切替を同文書に従って処理する。
* Clientで発生するイベントはイベントキューに入れ、各イベントに応じたアニメーションなどの表示処理を行う。
* 画像素材の欠落・画像読込失敗・アニメーション構造の必須値欠落または未知値による読込失敗時は、該当キャラクターを事前に用意した代替画像で表示する。代替画像はユーザー取り込み用`./assets/`およびOPFS辞書に依存しないClient配布物として別リポジトリから取得し、取得後は描画に先立ち読み込み可能な状態にする。取得できない場合は画像を描画せずエラー表示する。エラーのあるアニメーションは再生しない。

アセット辞書は`./config.cfg`の更新設定が有効なログイン成功時に、指定リポジトリのReleaseから取得する。未ログイン状態では新たに取得しない。取得失敗時は1回だけ再試行し、再失敗時は保存済みの前回辞書を使用する。前回辞書が存在しない場合は空の辞書状態を新規作成する。利用可能な辞書がない間は自動割当を停止し、手動区分・割当先指定によるローカル取り込みは維持する。辞書の有無は手動指定による新規取り込みの可否を変更しない。

アセットの**新規取り込み**は未ログイン・通信未接続時も利用可能とする。未ログイン時は辞書を取得せず、手動の素材区分・割当先指定で保存する。ログイン後に辞書を取得できた場合は`./cache/unknown_resouce/`内の素材をファイル名、必要時には内容SHA-256で照合し、保存先の変更が必要なら移動の確認を行い、既存Pathへの異内容上書きは設定ONのときだけ確認操作を行う。照合未完了の素材を自動削除しない。既存素材の閲覧・削除とローカル画面も未ログインで利用可能とする。

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
* Public API通信には`WebSocket`を使用しない。
* 認証付き通常Public RPCは`Authorization: Bearer <AccessToken>`を付加し、既存のRequest Bodyに`access_token`がある場合はHeaderと同一値を設定する。値が欠落・不一致ならHTTP 401になることを前提とし、Bodyだけで認証されたとみなさない。認証Origin専用手順は既存の別契約に従う。
* ブラウザ標準の`fetch()`（Rustからは選定済み`web-sys`/`wasm-bindgen-futures`等を使用）をPublic API通信に使用する. 通常のAPIは`fetch()`で送受信し, 通知はResponse Bodyの`ReadableStream`を逐次読み取りProtocol Buffers varint長prefixでフレーム復元する. HTTP/2とTLS 1.3のネゴシエーションはブラウザと接続先が担当し, JavaScriptが直接バージョンを強制しない. ブラウザからのHTTP/2 + TLS 1.3接続成立は配置先で検証する. Rust専用HTTPライブラリの追加は不要とする. HTTP Method/Pathは`design/system/api_transport.md`を正とする.
* WebAssemblyはブラウザ内で実行され, Rust/WASMからの通信もブラウザの`fetch()`を介するため, WASMとJavaScriptを静的配布先から取得した後のAPI通信にもOrigin・CORS・Cookieの規則が適用される. `SameSite=Strict` CookieはCross-Site要求へ送信されない. ClientからGameServerへ直接通信せず, Public API Serverへ接続する構成を維持する.
* 配布OriginがPublic API認証Originと異なるSiteになる場合, Cookieを利用するLogin/Refresh/Logoutは認証Originのトップレベルページ内で実施し, 一度限りの認可コード+PKCE S256でClientへAccessTokenを受け渡す. `SameSite=Strict`を維持し, Third-party Cookieは使用しない. 認証OriginはPublic API配布設定値、Client戻り先は`<client_origin>/auth/callback/`に固定し、認可コード交換のwire契約は`design/system/public_api.proto`を正とする. 詳細は`design/system/network.md`を正とする.

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
  "version": { "major": 0, "minor": 0, "patch": 0 }
}
```

`major`・`minor`・`patch`はJSON数値の非負整数（`0`～`4294967295`）とする。構造や型が不正な場合は`version=0.0.0`へ再生成する。

音声素材の欠落、HCAのデコード失敗、再生エラー時は音声を出力せず無音とする。音声エラーによってServer正本の戦闘状態や進行結果を変更しない。

代替表示画像の取得元は`https://github.com/ReHydrangeaOdyssey/GameAssets/releases`のRelease Assetsとする。実際のAsset名・必要ファイル・Version対応はそのReleaseに公開された配布情報を参照し、未知の画像を任意選択しない。取得・デコード不正なら以前に検証済みの代替画像を優先し、それも無い場合は既定の素材取得エラー表示とする。素材がこのリポジトリ由来というだけで辞書未掲載のランタイム素材を許可しない。

Version別の素材配置差分（旧Path→新Path）は該当VersionのRelease時に実データを根拠に作成する。差分が無いVersionでは移行を実施しない。移行を要するVersionだけ明示的なPath衝突処理を定義し、仮の素材Pathを現在仕様へ追加しない。

## アセット辞書の形式と照合規則

辞書は**拡張子ごと**の`./<ext>/assets_dict.json`に分離されたUTF-8 JSON Objectとする。`./png/assets_dict.json`、`./jpg/assets_dict.json`、`./hca/assets_dict.json`など、辞書Root直下の拡張子名ディレクトリを使用する。ここで`./`は**辞書配布物のRoot相対**でありOPFS保存先を意味しない。元ファイルの拡張子から該当辞書ファイルを選び、その中でディレクトリ名を除いた拡張子付きファイル名を第1キーとして完全一致照合する。辞書が拡張子に対応して存在しても、Clientの通常取込対象は現行どおりPNG/HCAであり、JPG/TXT等の取込対応追加を意味しない。

各エントリは`path`（同名ファイルの分岐がない場合の**単一**相対Path、同名衝突時は空文字）と`paths`（ファイル内容のSHA-256小文字16進64文字 → **相対Path文字列の配列**）を必須とする。`paths`はHash名をキーに持つJSON Objectであり、各ValueのみがJSON Arrayである。例えば、同名かつ同一内容のファイルを複数位置で利用する場合は、**一致したHashの配列に列挙された全Pathへ同じ内容を複製する**。

```json
{
  "document.txt": {
    "path": "document.txt",
    "paths": {}
  },
  "sample.txt": {
    "path": "",
    "paths": {
      "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef": [
        "dir_a/sample.txt",
        "dir_c/sample.txt"
      ],
      "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789": [
        "dir_b/sample.txt"
      ]
    }
  }
}
```

上記は**構造例**であり、`document.txt`/`sample.txt`を通常取り込み対象に追加するものではない。例の`sample.txt`と同じ構造を持つ`sample.png`なら、`png/assets_dict.json`内の対応エントリを照合する。

- 元ファイル名はディレクトリ名を除いた拡張子付き文字列そのものとし、Unicode正規化、大文字小文字変換、ファイル名SHA-256変換は行わない。拡張子名ディレクトリとエントリ内の拡張子が一致することを検証する。未登録名・未対応の拡張子・未取得の拡張子別辞書では自動割当しない。
- `path`が非空なら`paths={}`を要求して単一Pathに配置する。`path`が空なら`paths`に1件以上のHashキーと非空・重複なしのPath配列を要求し、**元の内容全体**のSHA-256と一致するHashキーの配列の全Pathに配置する。一部のPathだけを任意選択できない。各配列が空、Pathの重複、異なる元名/Hash間での同一保存Pathの再使用、`path`と`paths`の二重指定、未知のフィールド型は不正辞書とする。
- 辞書内のPathは`document.txt`・`dir_a/sample.txt`のような**`./assets/`からの相対Path**とする。Clientはその値へ`./assets/`を一度だけ前置して保存する。先頭`/`、`./`、`assets/`、`./assets/`、`.`/`..`、空セグメント、URL、制御文字、バックスラッシュ、末尾`/`は拒否する。大文字小文字と区切りを勝手に変換しない。辞書が不正なら既存の有効辞書集合を保持する。
- `paths`配列の一部に既存ファイルとの競合や書込み失敗がある場合、**当該元ファイルの全Pathを成功扱いにしない**。全Pathを一時書込み・検証し、必要な上書き確認をすべて得てから複製先一式を切り替える。中断時にはその元ファイルについて更新前の状態へ復元する。別の元ファイルの確定済み取込みは維持する。
- 辞書に**元ファイル名が存在しない**素材は設定値にかかわらず`./cache/unknown_resouce/`で保留し、Runtimeで使用しない。辞書登録名に変更して明示的に取り込んだ場合は、その時点のファイル名を辞書に照合する。OPFSキャッシュを消去すると未一致素材と取込一時データは消去される。元ファイル名、仮区分、CharacterID、現在Pathを保存済みの割当メタデータから再照合する。

端末内のRelease辞書更新・割当JSON・HCAのBGM判定・鍵キャッシュの具体的Path/原子的切替は「[ローカルアセット保存契約](local_asset_storage.md)」に従う。
設定画面はタイトルから利用し、運営が配布する`config.cfg`の既定値と端末で保存する上書き値、`config.cnf`の安全側既定値を区別して表示する。各boolはトグル、Release tagは検証付き文字列入力とし、保存失敗時は旧設定を残す。端末による`config.cfg`の編集は**静的配布ファイルの変更ではなくローカル上書き**である。

## アセット辞書取得の設定

静的Clientの配布ルートにYAMLの`./config.cfg`を置く。以下を初期値とする。

```yaml
update_asset_dictionary: true
asset_dictionary_version: latest
```

ユーザーが端末で明示的に信頼境界を変更する場合だけ、OPFS Rootの`./config.cnf`（YAML形式）を別に使用する。`config.cnf`は端末で作成する実行時設定であり、仕様ZIPへの同梱を要しない。既定値から自動生成しただけで検証解除を適用しない。未作成の場合の安全側初期値は次のとおり。静的配布物`config.cfg`とローカル`config.cnf`は別ファイルであり、静的ファイルをブラウザから書き換えない。

```yaml
verify_asset_dictionary_sha256: true
allow_user_asset_override: false
```

- `update_asset_dictionary=true`ならログイン成功のたびに指定Releaseから辞書を取得する。`false`ならログイン時の自動更新を行わず、端末保存の辞書をそのまま使う。
- `asset_dictionary_version=latest`なら`ReHydrangeaOdyssey/AssetDictionary`の最新Release、それ以外は指定tagを選択する。辞書の論理的な配布構成はReleaseに対応した`<ext>/assets_dict.json`の集合であり、従来の単一`asset_dictionary.json`は新形式の正本ではない。**実際にどのRelease Asset/アーカイブを取得・展開してこの階層へ到達するかは配布契約未確定**（`design/programming/undecided.md`のU-09）。存在が確認できないAsset名を仮定した自動選択は行わず、既存辞書集合を保持する。取得できた辞書集合の全件検証と更新の切替は`local_asset_storage.md`に従う。失敗は1回再試行し、旧辞書がなければ空辞書状態へ移行する。
- `config.cfg`はCloudflare Pages上の静的配布物であり、ブラウザ内でこの配布ファイルを書き換えない。タイトルの設定画面ではOPFS `./settings/config_cfg_override.yaml`の端末ローカル上書き値を変更する。実効値は「端末上書きが有効なら上書き、なければ配布`config.cfg`、どちらも不正なら初期値」の順とする。運営による変更は上書きの無い項目に次回読込みから反映する。

### 外部素材の信頼確認とユーザーの明示的な例外

- 辞書の**配布署名検証は使用しない**。従来の単一`asset_dictionary.json`とそのRaw Bytes Digest名を用いた検査値Assetとの1対1対応は、拡張子別の複数`assets_dict.json`にはそのまま適用しない。`verify_asset_dictionary_sha256=true`の場合、取得した**全辞書ファイル**それぞれのRaw Bytesと、配布側が明示する当該ファイルに対応した検査値との照合が必須である。対応付けの配布形式・取得手順はU-09の未確定事項であり、整合する検査値を確定できない場合は**更新を失敗扱い**として旧辞書を保持する。署名による配布元真正性の保証はない。
- 利用者が端末内`./config.cnf`で`verify_asset_dictionary_sha256: false`を**明示設定**した場合だけRelease配布物から得た各辞書の検査値との照合を省略できる。未検証状態を画面で明示し、Schema・安全Path・サイズのValidationは必須、旧検証済みGenerationを維持する。旧設定名`verify_asset_dictionary_source`は廃止する。
- `allow_user_asset_override`は**すでに実ファイルがある辞書許可Pathを、異なるバイト列で明示的に置き換える操作だけ**を制御する。`false`（既定）では異なる内容での上書きを拒否し、同一内容の再取込みは変更なしとする。未配置Pathへの通常の新規取込みはOFFでも許可する（元名・辞書Path・必要時の`paths`内容Hash・形式検証を通る場合に限る）。`true`では確認操作後に既存実ファイルを差し替えられるが、辞書登録済み元名と許可Path、画像/音声の実体形式の検証は必須である。`path`が一意なら**辞書に期待内容Hashは存在しない**ので元バイト列の同一性を配布元と照合したと主張しない。`path`が空で`paths`を使う場合は、**overrideの設定値にかかわらず**実バイト列のSHA-256が辞書の候補Hashと一致したPathだけに新規配置・上書きを許可する。候補Hashと不一致のファイルを、辞書に登録された別候補Pathへ手動指定して使用することも認めない。候補Hashの一致する既存Pathを異内容で置換する場合は、新しい実バイト列もそのPathに対応するHashと一致しなければならない。未登録ファイル名・辞書にないPath・Server正本・他Playerの変更は設定値にかかわらず不可とする。
- ローカル設定ファイルはブラウザのOPFS上にあり、タイトルの「設定」画面から編集する。設定不正は各項目の既定値に戻し、Hash照合OFF時は不整合を検出できないことを警告する。辞書配布署名・公開鍵の管理機能は設けない。


## HCA設定と鍵キャッシュ

- HCA入力1chは左右へ同一PCMを複製して2ch出力し、入力2chは左右を維持する。`./assets/`のBGM専用フォルダに配置されたHCAだけを音源全体ループ、それ以外は非ループとする。`hca_config.json`やループ区間の個別設定は使用しない。
- 鍵が必要なHCAをデコードする前にOPFS `./cache/temp/decode/keys.json`のファイル名・内容SHA-256複合キーを持つキャッシュを調べる。鍵があれば先に試し、存在しないか鍵が誤りでデコードできない場合に鍵探索を実施し、成功した鍵をキャッシュへ反映する。ファイル名衝突や内容変更で誤った鍵を再利用した場合は探索し直す。鍵探索・音声デコードが失敗した場合は無音とする。キャッシュクリア時に鍵キャッシュも削除する。

## ゲーム開始時の必須アセット検証

タイトル画面からゲームプレイ画面へ進む前に、**有効なアセット辞書と描画可能な検証済み代替画像の両方**が存在することをClientで確認する。どちらか一方でも欠落・不正・参照不能ならゲーム開始を許可せず、原因を表示してタイトル画面に留める。ログイン不要のローカル素材管理・削除・辞書再取得の案内は維持する。起動済みゲームで通常素材が欠落した場合だけ代替画像へ表示を切り替える。未検証素材を代替として自動採用しない。辞書未取得時の手動素材**取込み**許可と、辞書未取得のまま**ゲーム開始**することは区別する。

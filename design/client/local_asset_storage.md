# ローカルアセットの取り込み・保存契約

この文書は`design/client/client.md`のデータ規則を端末側の具体的な保存と更新に適用する。ユーザーが取り込む画像・音声の正本と、ゲームが自動取得する辞書/代替画像は区別する。パスはOPFSのRoot相対表記であり、Clientが実際のWeb Host filesystemに自由にアクセスできるという意味ではない。

代替画像は`https://github.com/ReHydrangeaOdyssey/GameAssets/releases`から取得する。Releaseで明示されたAsset名・検査値と有効辞書の有無を検証し、既知の検証済み画像へだけ参照を切り替える。代替画像は通常素材と異なるClient管理物だが、ゲーム開始には有効辞書も必須とする。実配布Asset名は提供側が公開する実体に合わせ、未提示の名称を固定しない。

## プログラム保存領域との分離

- Cloudflare Pagesから取得したClientのHTML/JavaScript/WASM一式はOPFS `./game/`へ保存する。`./game/`はプログラム用であり、辞書許可対象の`./assets/`や一時保存用`./cache/`の規則を流用しない。Service Worker用Version別Cache Storageもオフライン起動に必要であり、OPFS保存だけでは代替しない。
- Clientのバージョン更新時は`./game/`だけを全量入れ替え、`./assets/`、`./settings/`、`./config.cnf`と現在Versionを記録する`./game_info.json`を削除しない。更新中のキャッシュクリアは拒否し、更新失敗・容量不足時は更新前のプログラムへ復帰する。詳細は`../programming/client/web_delivery.md`を参照。

## シーンJSONと端末素材の保存境界

`./scene_assets/<scene_id>.json`はClientが配布する参照定義であり、同VersionのOPFS `./game/scene_assets/`とService Worker Version別Cacheに置く。`./cache/asset_dictionary/`の**拡張子別辞書集合**、ユーザー提供の`./assets/`実体、キャラクター構成セットに関する「永続Manifestを作らない」規則とは独立する。Schema・`sha256`による同名ファイル解決・表示準備は[シーン別Asset Manifest](scene_asset_manifest.md)を正本とする。`paths`配列について、**取込時は全Pathへ複製**、**Runtimeは検証済みの一つの実体を使ってよい**という責務の差を維持する。辞書のキャッシュクリア時には既存のゲーム開始条件に従いRuntimeの辞書参照を無効化するが、`./game/`のJSONや`./assets/`の実体は自動削除しない。

## Release辞書の取得・原子的更新

1. ログイン成功後、実効`update_asset_dictionary=true`なら`asset_dictionary_version=latest`または指定tagのReleaseを選ぶ。取得対象は**拡張子別`<ext>/assets_dict.json`の集合**であり、単一の`asset_dictionary.json`ではない。各相対Pathは辞書配布物のRootからのもので、`png/assets_dict.json`、`jpg/assets_dict.json`、`hca/assets_dict.json`などを意味する。GitHub ReleasesのどのAsset名/パッケージからこの内部階層を取得するか、および検査値ファイルとの対応付けは未確定（`design/programming/undecided.md`のU-09）。配布実体が判明するまで、推測したAsset名・アーカイブ形式・Web URLから取得を開始しない。
2. 取得した全拡張子別辞書についてHTTPS応答・受信量上限・UTF-8・JSON Object・拡張子DirectoryとFile名の一致・`path`/`paths`型・Hashキーの小文字16進64桁・配列全要素のPath安全性・保存Pathの集合全体での衝突有無を検証する。`path`非空なら`paths={}`、`path`空なら各Hashに非空配列を要求する。`verify_asset_dictionary_sha256=true`では**各辞書ファイル**のRaw BytesのSHA-256を、それぞれに対応するRelease側の検査値と照合できた場合に限り成功とする。検査値の対応付け不明・欠落・不一致・取得途中終了は旧Generation保持とし、照合を自動OFFにしない。利用者が`verify_asset_dictionary_sha256=false`を明示した場合も全件のSchemaと安全Pathは必須とする。Release tag・辞書配布物の識別子・拡張子別ファイル名とDigest・検証結果を履歴に保存する。配布Assetそのものの署名検証は行わない。
3. 新辞書の各`<ext>/assets_dict.json`を`./cache/temp/asset_dictionary/<generation_id>/<ext>/assets_dict.json`へ一時保存して再読込検証し、集合全体の検証・素材照合・退避が終了してから`./cache/asset_dictionary/active.json`のActive参照を切り替える。Activeはgeneration ID・tag・各拡張子とファイルごとのSHA-256・Sizeを参照する。新Generation全体を原子的な論理単位とし、一部拡張子だけ先に有効化しない。旧Generationと新Generationは全辞書の`path`および`paths`配列の**全要素**をOPFS保存Pathへ正規化して比較し、各Pathの元ファイル名・拡張子・内容Hash条件も照合する。新条件から外れる実ファイルは`./cache/obsolete_assets/<更新ID>/`へ退避する。共通Pathは旧辞書の一意なPath→元名の逆引き（`paths`では実内容Hashの一致も必要）と新辞書の許可を確認したものだけ維持する。旧Generation消失・不正・来歴の曖昧な素材を推測で移行しない。更新中マーカーと旧素材の退避により中断・検証失敗時は旧辞書集合と元の`./assets/`状態へ復元する。
4. `update_asset_dictionary=false`ならネットワーク取得しない。初回に有効辞書がない場合は空辞書として手動割当だけを使う。HTTP失敗は1回だけ再試行してから保存済み正本へ戻す。
5. `./cache/temp/`配下はプロセス再起動で自動消去しないが、ユーザーが**キャッシュクリアを明示実行した場合は辞書Generationも消去される**。次回ログインで再取得する。辞書更新・構成素材入替・プログラム更新中はキャッシュクリアを拒否する。

## 取り込みと割当レコード

- ファイルは`./cache/temp/user_impoert/<import_id>/`へ一時取込みし、`import_id`は暗号学的乱数で一意に発行する。辞書一致は`./assets/`へ確定し、不一致は`./cache/unknown_resouce/<import_id>/`へ保存する。未一致は描画・再生に使用しない。
- 割当レコードは`./cache/unknown_resouce/assignments.json`のUTF-8 JSONとする。`schema_version=1`、`items`は`import_id`をキーにしたObjectとする。各項目は`original_filename`（改名・Unicode正規化なし）、`content_sha256`（小文字16進64桁）、`current_path`（実体が現在存在するOPFS Root相対Path）、`category`（`BGM`/`SE`/`Voice`/`Character`/`SD Character`/`Character Icon`）、`target_id`（Character系は指定ID、その他は空文字）、`dictionary_status`（`unmatched`/`matched_pending_confirmation`/`invalid`）、`assigned_path`（未確定なら空文字）、`created_at`（UTC epoch milliseconds）を必須とする。
- 辞書に一致して保存済みの素材の元ファイル名は、旧検証済みGenerationの**全拡張子別辞書**を展開してPath→元ファイル名が一意な場合だけ逆引きする。`paths`方式では一致Hashの配列に含まれる各保存Pathについて、実ファイルのSHA-256も再計算して照合する。旧辞書喪失・同一Pathの複数元名候補・内容Hash不一致の場合は元名を推測しない。確証できない素材は`./cache/obsolete_assets/`へ退避してRuntime参照を停止する。構成セットの永続Manifestは作らない。
- 端末内の割当レコードは元ファイル名と実ファイル名を別に保持する。`target_id`やユーザーの手動区分は辞書一致を証明しない。ログイン後に辞書更新した場合は元ファイル名および必要に応じた内容SHA-256で再照合し、保存先変更はユーザー確認後に行う。既存Pathへの異なる内容の上書きはさらに`allow_user_asset_override=true`を要する。
- ユーザー確認により辞書一致素材を`./assets/`へ確定配置した後は、対応する保留素材の割当レコードを削除する。実行時の利用可否は有効AssetDictionaryと配置済み素材の検証結果を正本とし、削除済み割当レコードを参照しない。
- 割当レコードは現在実体Pathを唯一の参照正本として保存する。再配置時は移動先へコピー→内容Hashの再検証→割当レコードの原子的な参照切替→旧実体削除の順で処理する。保存済み`current_path`が存在しない場合は旧一時Pathを勝手に正本化せず`invalid`の修復対象とする。割当レコードは一時ファイルへ全件書込み→読戻しValidation→参照切替の順に更新する。レコードと素材の一方が欠落した場合は一致とみなさず当該レコードを`invalid`として表示・修復対象にする。キャッシュクリアでは保留素材と割当レコードの両方を消す。

## キャラクター構成データ（端末内完結）

- キャラクター描画の構造モデルは、Client同梱モデルまたは利用者が**通常のPNG/HCA取込みとは別の「構造モデル読込み」操作**で選んだデータを当該セッションに読み込み、受入可能な内部モデルへ変換した上で同一の構造Validationを通した場合だけ登録する。読込み失敗時は既存の検証済みモデルを維持し理由を表示する。入力ファイルの拡張子・内容形式は実入力データとClientの対応形式が決まるまで固定せず、未対応形式を推測変換しない。ServerへのRPC、`./assets/`へのProtoBuf保存、セッションモデルの次回起動までの保存は要求しない。
- キャラクター描画の構造情報（`SpriteAnimationData`/`PlistRoot`の論理モデル）とユーザーが取り込む**画像PNG/HCAの実ファイル**は区別する。通常の`./assets/`にProtoBufファイルを取り込んだり、そこから列挙したりしない。構造情報の供給元は、**Clientが起動時に利用可能な同梱/読み込み済みモデル**または**利用者がClientへ渡してそのセッションで検証済みのモデル**に限り、読み込み時に同じ構造検証を行う。セッション内だけのモデルは再起動後に再提供されるまで利用可能とみなさず、アセット辞書やPNG名から復元しない。Clientでのみ検証・登録・入替・削除・利用可能な参照の再確認を行い、Public API/Private API/GameServer/DBへ素材を送信・保存しない。
- 画像等の取込対象ファイルの元名・内容Hash・保存先Pathは取込時に検証する。Clientが保持する構造情報の参照とPNGの実体を照合し、セット外の任意Pathやディレクトリ脱出を禁止する。対象実ファイルを一時領域で検証し、既存ファイルの退避と原子的な置換手順を用いる。永続Manifestは作らない。
- ProtoBufは描画用データ型の定義であり、`./assets/`内のユーザーファイルの形式・保存対象を意味しない。名称から骨格/Movementを自動生成しない。実データから機械的に作れない`CharacterID × 向き × Action`の全件対応表を別途必須Schemaとして要求しない。ゲーム内の表示対象と使用セットはClient側の明示選択・既存素材参照で決定し、参照不能なCharacterは代替表示を行う。
- **アセット辞書をRuntime素材使用許可の最上位規則**とする。`path`一意方式の置換は設定ON・ユーザー確認で許可できるが、`paths`方式は設定ONでも一致HashのPath配列**全要素**に同一内容を複製し、各保存Pathに対応する内容SHA-256の一致を必須とする。Hash不一致素材の候補Path手動選択・上書き・Runtime利用を拒否する。`allow_user_asset_override=false`は既存辞書許可Pathの異なる内容への置換を禁止する設定であり、未配置Pathへの辞書一致素材の新規取込みは禁止しない。Runtimeでユーザー供給素材として読むPNG/HCAについて、各ファイルの元ファイル名が有効辞書に存在し、辞書で許可されたPathに解決できなければ使用不可とする。骨格・モーション・アトラスの内部データ構造そのものを辞書登録済みの`./assets/`ファイルだと解釈しない。構成セットの端末内登録だけでは使用権限を生じない。辞書登録名でのユーザー素材差替えは`config.cnf`の明示設定とClient仕様の許可Path制限に従う。セット削除時は共有PNGを他セットが参照しているか確認する。


### 構成セットの保存・入替

- 独立した`manifest.json`・`index.json`や`generation_id`台帳は作らない。Clientが取得した描画構造情報と参照PNGの関係を**メモリ上で**検査し、辞書一致したPNG/HCAの実体だけを辞書が許可する`./assets/`始まりの完全Pathへ保存する。ProtoBufは`./assets/`に保存しない。辞書の一致しないファイルをRuntimeには渡さない。
- キャラクター構成セットの一括登録・一括入替では、取込対象のPNG/HCAの形式・画像参照・Hash・辞書許可を検証し、変更対象の旧ファイルをOPFSの一時領域へ退避した後に新ファイルを配置する。**このセット単位の操作**では全件成功時だけ退避を削除し、中断・失敗時には既存の旧ファイルを復元する。通常の独立したPNG/HCA複数ファイル取込みは**元ファイルごと**に確定し（`paths`配列に複数保存先があるときは全複製先を同一単位で切替・失敗時は全先を復元する）、完了済みの別ファイルを保持する（`design/programming/client/client.md`のファイル単位取込規則を参照）。処理中マーカーは一時領域に保持し、起動時に未完了処理を検出したらロールバックする。構成セットの永続Manifest・世代管理は必要としない。
- 次回起動時は同梱/再読込済みの描画構造モデルを検証し、利用可能な構造情報の参照と有効辞書の完全PathからPNG実体を再検証する。前回セッションのメモリ専用モデルは再起動だけでは復元されたとみなさない。`./assets/`をProtoBuf探索先とせず、存在しない構造情報を推測で生成しない。壊れたFrameや参照が1件でもあれば、その読込対象の構成一式を拒否する。存在しない全件自動対応表・Movement名を推測で補わない。Client以外のAPI/DBへ素材を送信しない。

### 明示した表示選択の保持

- 利用者が明示的に選択した対象だけ、OPFS `./settings/character_display_selections.json`へ`schema_version=1`と選択レコードを保存する。レコードは`character_id`、`orientation`、`structure_ref`（Client内で使用中の構造モデルを参照する論理識別子）、`armature_name`を含む。`(character_id,orientation)`は一意とし、存在しないモデルやArmatureの名前を推測生成しない。保存は一時ファイルの読戻し検証後に原子的に切り替え、`./cache/`消去では設定を削除しない。
- `structure_ref`はClient内に登録済みの構造モデルを指す登録IDとし、同時に有効な異なる構造モデルへ同じIDを割り当てない。利用者のセッション読込みモデルは登録時に衝突を検査し、別モデルとしての再読込み・差替えで既存の選択が同一モデルと検証できなくなれば、その選択を無効化して代替画像を使用する。同梱モデルはClientの既存論理IDを使い、再起動時に参照モデルとArmatureの有効性を再検証する。IDの一致だけで異なる構造モデルを同一と扱わない。
- 参照は**Client内で利用可能な構造モデルへの選択結果**であり、ProtoBuf実ファイルの所在や全Action/Movementの対応表を意味しない。再起動時・素材削除時・辞書更新時にはモデル/Armature/参照PNGが有効か再検証し、参照先が失われた選択を有効として使用しない（保存値は修復/解除のため残せる）。有効な代替画像へ切り替える。端末内の明示選択解除はレコードを削除する。セッションだけで提供されたモデルは再起動後に再供給されるまで選択を利用できない。永続Manifestは作らない。

## HCAループ指定と鍵探索キャッシュ

- **`./assets/sound/bgm/`**（ディレクトリ境界と大文字小文字を区別し、配下のサブディレクトリを含む）へ配置されたHCAは音源全体をループ再生する。それ以外のHCAはループしない。区分は端末の`./assets/`配下の実際の保存先フォルダによって決まり、拡張子やファイル名から推測しない。`hca_config.json`を新規生成・取り込み・参照せず、利用者によるloopチェックUIも設けない。キャッシュクリア後も`./assets/`の配置は維持するためループ判定が復元される。BGM Pathは`./assets/sound/bgm/`で固定し、`./assets/sound/bgmmusic`や`./assets/Sound/bgm/`を含めない。辞書指定保存先がこのディレクトリ境界の中にある場合のみ全曲ループする。
- `./cache/temp/decode/keys.json`は`schema_version=1`と`entries` Objectを持つ。Keyは`<UTF-8元ファイル名をBase64url化した文字列>.<内容SHA-256小文字16進64桁>`、Valueは`{"filename": "...", "sha256": "...", "key_decimal": "0以上の整数の10進文字列"}`とする。Keyを受け入れる前にfilename/Hashと復号成功を検証する。浮動小数点や先頭ゼロ・負値の鍵表現は拒否する。鍵の許容上限は採用したHCAデコーダーの鍵型と同一にする。
- キャッシュ一致時はその鍵で復号を検証し、失敗なら鍵を破棄して探索を行う。探索で復号成功を確認した時だけ、`keys.json`を一時生成・読戻しValidation・参照切替して更新する。鍵および復号結果をログへ出さない。キャッシュクリアでは鍵キャッシュも消える。鍵の探索自体が失敗した場合は無音にする。

### 辞書の保存Pathの基準

辞書Rootの`<ext>/assets_dict.json`内で、`path`文字列または`paths`配列の各文字列は、**アセット領域Root `./assets/`からの相対Path**である。例えば値`dir_a/sample.png`はOPFS `./assets/dir_a/sample.png`へ保存する。辞書Rootの`png/`を保存Pathに付与せず、逆に辞書の値へ`./assets/`を埋め込むことも認めない。先頭の`/`・`./`・`assets/`・`./assets/`、URL、空/`.`/`..`セグメント、制御文字、バックスラッシュ、末尾`/`を拒否する。全配列要素を検証し、同じ正規化後Pathが配列内・Hash間・元ファイル名間・拡張子間で重複していれば辞書全体を不正とする。既存の`./assets/sound/bgm/`以下かどうかは変換**後**のOPFS Pathで判定する。

`path`が空でSHA-256が一致する`paths`配列が複数Pathを含むときは、**その全Pathへ同じバイト列を複製する**。元ファイル単位の処理では全保存先へ一時ファイルを用意し、既存内容との差分と上書き権限を全件検証・確認してから確定する。未配置Pathへの新規作成と既存同一内容の保持は設定OFFでも可能だが、いずれかのPathで異内容上書きが必要なら全対象のユーザー承認と`allow_user_asset_override=true`を要求する。1Pathでも容量不足・書込失敗・検証不適合・キャンセルがあれば、その元ファイルの保存先全体を変更前へ戻し、成功扱いにしない。既に成功した別の元ファイルは保持する。配列にないPathへ自動補完しない。

### 辞書更新で不要となった素材の退避

旧辞書集合と新辞書集合を全拡張子・全`path`・全`paths`配列要素の**OPFS保存Path**へ展開し、Pathごとの元名・拡張子・`path`/`paths`方式・条件SHA-256を比較する。新辞書にないPath、または新条件に現存実ファイルが適合しないPathは、`./cache/obsolete_assets/<更新ID>/`へ元Pathを保ったまま退避する。共通Pathでも旧Generationの逆引きで元名が一意と確認できない場合は維持しない。`paths`の条件がある場合は実内容Hashも照合する。`path`方式には期待Hashがないので存在しない配布元Hashを検証済みとして扱わない。更新中マーカーは完了/ロールバックまで維持し、更新中はキャッシュクリア・新規素材の変更を受け付けない。手動キャッシュクリアは確定済み退避ファイルを消すことをUIで示す。

### 構成素材の入替中の画面保護

構成素材の全ファイルの検証・退避・切替・完了までClientをローディング表示とし、ユーザーの画面操作・キャッシュクリア・素材削除・新たな入替を受け付けない。ローディングによる操作禁止だけではブラウザの強制終了を防げないため、既定の作業マーカー・退避・起動時ロールバックは残す。再起動後に未完了マーカーがあれば復元が済むまで同じローディング状態で操作を無効化する。永続Manifestは導入しない。

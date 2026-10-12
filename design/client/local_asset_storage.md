# ローカルアセットの取り込み・保存契約

この文書は`design/client/client.md`のデータ規則を端末側の具体的な保存と更新に適用する。ユーザーが取り込む画像・音声の正本と、ゲームが自動取得する辞書/代替画像は区別する。パスはOPFSのRoot相対表記であり、Clientが実際のWeb Host filesystemに自由にアクセスできるという意味ではない。

代替画像は`https://github.com/ReHydrangeaOdyssey/GameAssets/releases`から取得する。Releaseで明示されたAsset名と辞書許可を照合し、既知の検証済み画像へだけ参照を切り替える。実配布Asset名は提供側が公開する実体に合わせ、未提示の名称を固定しない。

## Release辞書の取得・原子的更新

1. ログイン成功後、配布`./config.cfg`とタイトル設定画面で保存した端末上書き値を統合した実効`update_asset_dictionary`が`true`の場合、`asset_dictionary_version=latest`なら最新Release、それ以外は指定tagのReleaseをGitHub Releases APIで取得する。辞書本体は`asset_dictionary.json`という名前のRelease Assetを**ちょうど1件**選び、同じReleaseから検査値を表す**小文字16進64桁のAsset名**を1件取得する（実効`verify_asset_dictionary_sha256=false`では当該Asset不在も許容する）。Assetの実URLはRelease APIの返却値から取得し、任意の未知Assetを辞書として選ばない。
2. HTTPSレスポンス正常性、Content-Lengthと実受信量、最大受信量上限、UTF-8、JSON Object、すべての`path`/`paths`とハッシュキー形式、相対Path安全性、File名の重複と空値を全件検証する。**辞書本体のRaw Bytes全体**にSHA-256を計算し、同じRelease内でファイル名がこのDigestと完全一致する検査値Assetがちょうど1件だけある場合に照合成功とする。`verify_asset_dictionary_sha256=true`（初期値）で検査値Asset欠落・曖昧・不一致なら切替えない。利用者が設定画面で明示的にfalseとしたときだけ検査値照合を省略できるが、Schema/Path検査は常に実施する。tag・辞書Asset ID・検査値Asset ID・ETag・計算Digest・検証結果を履歴へ保存する。ETagはHashの代用にならず、同一Release内のDigest名ではRelease改ざん自体を検出できない。
3. `./cache/temp/asset_dictionary/`に`generation_<id>.json`として一時書込みし、読戻し検証後に`active.json`参照（generation ID・tag・SHA-256・Size）を一時ファイルから切替える。旧Generationは新Generationの参照確定まで削除しない。再起動時はActiveのHashとJSONを検証し、不完全なら直前の検証済みGenerationへ戻す。`./assets/`内の素材を辞書更新だけで移動しない。
4. `update_asset_dictionary=false`ならネットワーク取得しない。初回に有効辞書がない場合は空辞書として手動割当だけを使う。HTTP失敗は1回だけ再試行してから保存済み正本へ戻す。
5. `./cache/temp/`配下はプロセス再起動で自動消去しないが、ユーザーが**キャッシュクリアを明示実行した場合は辞書Generationも消去される**。次回ログインで再取得する。Version差分移行中は既存仕様に従いキャッシュクリアを拒否する。

## 取り込みと割当レコード

- ファイルは`./cache/temp/user_impoert/<import_id>/`へ一時取込みし、`import_id`は暗号学的乱数で一意に発行する。辞書一致は`./assets/`へ確定し、不一致は`./cache/unknown_resouce/<import_id>/`へ保存する。未一致は描画・再生に使用しない。
- 割当レコードは`./cache/unknown_resouce/assignments.json`のUTF-8 JSONとする。`schema_version=1`、`items`は`import_id`をキーにしたObjectとする。各項目は`original_filename`（改名・Unicode正規化なし）、`content_sha256`（小文字16進64桁）、`current_path`（実体が現在存在するOPFS Root相対Path）、`category`（`BGM`/`SE`/`Voice`/`Character`/`SD Character`/`Character Icon`）、`target_id`（Character系は指定ID、その他は空文字）、`dictionary_status`（`unmatched`/`matched_pending_confirmation`/`invalid`）、`assigned_path`（未確定なら空文字）、`created_at`（UTC epoch milliseconds）を必須とする。
- 端末内の割当レコードは元ファイル名と実ファイル名を別に保持する。`target_id`やユーザーの手動区分は辞書一致を証明しない。ログイン後に辞書更新した場合は元ファイル名および必要に応じた内容SHA-256で再照合し、保存先変更/上書きはユーザー確認後に行う。
- 割当レコードは現在実体Pathを唯一の参照正本として保存する。再配置時は移動先へコピー→内容Hashの再検証→割当レコードの原子的な参照切替→旧実体削除の順で処理する。保存済み`current_path`が存在しない場合は旧一時Pathを勝手に正本化せず`invalid`の修復対象とする。割当レコードは一時ファイルへ全件書込み→読戻しValidation→参照切替の順に更新する。レコードと素材の一方が欠落した場合は一致とみなさず当該レコードを`invalid`として表示・修復対象にする。キャッシュクリアでは保留素材と割当レコードの両方を消す。

## キャラクター構成データ（端末内完結）

- ユーザーが用意した骨格・モーション（`SpriteAnimationData`）、アトラス定義（`PlistRoot`）、参照PNGを**一組の構成セット**としてClientのアセット追加画面から選択できる。Clientでのみ検証・登録・入替・削除・再起動後復元を行い、Public API/Private API/GameServer/DBへ素材を送信・保存しない。
- 各セットにClient内の`asset_set_id`を割り当て、読み込んだ構成のファイル参照・元ファイル名・元内容Hash・OPFS保存Pathを一組のManifestとして記録する。ManifestはClient内部の端末データでありServerとの同期仕様ではない。`SpriteAnimationData`が列挙するアトラス/PNGを参照先と照合し、セット外の任意Pathやディレクトリ脱出を禁止する。検証済みセット全体を一時領域から原子的に登録する。
- 構成セットの登録に必要な入力は既存のProtoBufであり、名称から骨格/Movementを自動生成しない。実データから機械的に作れない`CharacterID × 向き × Action`の全件対応表を別途必須Schemaとして要求しない。ゲーム内の表示対象と使用セットはClient側の明示選択・既存素材参照で決定し、参照不能なCharacterは代替表示を行う。
- **アセット辞書をRuntime素材使用許可の最上位規則**とする。構成セットに含まれる骨格・モーション・アトラス定義・参照PNGについても、Runtimeで使用する各ファイルの元ファイル名が有効辞書に存在し、辞書で許可されたPathに解決できなければセット全体を使用不可とする。構成セットの端末内登録だけでは使用権限を生じない。辞書登録名でのユーザー素材差替えは`config.cnf`の明示設定とClient仕様の許可Path制限に従う。セット削除時は共有PNGを他セットが参照しているか確認する。


### 構成セットManifestと世代切替

- OPFS `./character_sets/<asset_set_id>/generations/<generation_id>/`に1世代のManifestとセット管理メタデータを保持し、実行時に使用する素材ファイルは辞書が許可した`./assets/<path>`へ置く。`asset_set_id`/`generation_id`はClient生成の一意な不透明IDとし、PathにUser指定の相対文字列を連結しない。`./character_sets/index.json`を原子的なActive参照台帳とする。
- 各世代の`manifest.json`はUTF-8 JSON Objectとし、`schema_version: 1`、`asset_set_id`、`generation_id`、`files`（配列）を必須とする。各File要素は`logical_id`（セット内一意）、`kind`（`animation`/`atlas`/`image`）、`original_filename`、`current_path`（辞書が許可した`./assets/<path>`）、`sha256`（小文字16進64桁）、`references`（他の`logical_id`の配列）を必須とする。`animation`は`SpriteAnimationData`、`atlas`は`PlistRoot`、`image`は参照PNGであり、参照の存在・型・一意性・到達範囲を検証する。
- `index.json`は`schema_version: 1`、`active_sets`（`asset_set_id`から`generation_id`へのObject）を必須とする。構成セットは一時領域で全ファイルHash・ProtoBuf・画像・参照整合・辞書によるファイル名使用許可を検査し、完成世代を保存後に`index.json`を原子的に切替える。失敗時は旧Activeを維持する。再起動後はIndexから世代を復元して各実体とHashを再検証し、欠損・破損なら使用停止して旧検証済み世代へ戻す。構造不正Frameが1件でもあればセット全体を拒否する。
- 登録・差替え・削除はClientのローカル操作で完結する。GameServer/DB/Public/Private APIへManifestを送信しない。辞書未掲載ファイルをセットに含めて保存してもRuntimeでの使用は禁止する。ローカルManifest/Indexは実行用素材ではないため辞書の列挙対象にはせず、いずれのManifestも許可済み素材ファイルの代わりにならない。

## HCAループ指定と鍵探索キャッシュ

- **`./assets/sound/bgm/`**（ディレクトリ境界と大文字小文字を区別し、配下のサブディレクトリを含む）へ配置されたHCAは音源全体をループ再生する。それ以外のHCAはループしない。区分は端末の`./assets/`配下の実際の保存先フォルダによって決まり、拡張子やファイル名から推測しない。`hca_config.json`を新規生成・取り込み・参照せず、利用者によるloopチェックUIも設けない。キャッシュクリア後も`./assets/`の配置は維持するためループ判定が復元される。BGM Pathは`./assets/sound/bgm/`で固定し、`./assets/sound/bgmmusic`や`./assets/Sound/bgm/`を含めない。辞書指定保存先がこのディレクトリ境界の中にある場合のみ全曲ループする。
- `./cache/temp/decode/keys.json`は`schema_version=1`と`entries` Objectを持つ。Keyは`<UTF-8元ファイル名をBase64url化した文字列>.<内容SHA-256小文字16進64桁>`、Valueは`{"filename": "...", "sha256": "...", "key_decimal": "0以上の整数の10進文字列"}`とする。Keyを受け入れる前にfilename/Hashと復号成功を検証する。浮動小数点や先頭ゼロ・負値の鍵表現は拒否する。鍵の許容上限は採用したHCAデコーダーの鍵型と同一にする。
- キャッシュ一致時はその鍵で復号を検証し、失敗なら鍵を破棄して探索を行う。探索で復号成功を確認した時だけ、`keys.json`を一時生成・読戻しValidation・参照切替して更新する。鍵および復号結果をログへ出さない。キャッシュクリアでは鍵キャッシュも消える。鍵の探索自体が失敗した場合は無音にする。

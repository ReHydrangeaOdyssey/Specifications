# ローカルアセットの取り込み・保存契約

この文書は`design/client/client.md`のデータ規則を端末側の具体的な保存と更新に適用する。ユーザーが取り込む画像・音声の正本と、ゲームが自動取得する辞書/代替画像は区別する。パスはOPFSのRoot相対表記であり、Clientが実際のWeb Host filesystemに自由にアクセスできるという意味ではない。

## Release辞書の取得・原子的更新

1. ログイン成功後、`./config.cfg`の`update_asset_dictionary`が`true`の場合、`asset_dictionary_version=latest`なら最新Release、それ以外は指定tagのReleaseをGitHub Releases APIで取得する。Asset名は`asset_dictionary.json`に固定し、同名Assetが0個または複数個なら取得失敗とする。Release AssetのAPI返却URLからダウンロードし、任意の未知Assetを選ばない。
2. HTTPSレスポンス正常性、Content-Lengthと実受信量、最大受信量上限、UTF-8、JSON Object、すべての`path`/`paths`とハッシュキー形式、相対Path安全性、File名の重複と空値を全件検証する。取得した生バイト列のSHA-256を記録する。端末内`config.cnf`が既定の`verify_asset_dictionary_source=true`なら、信頼済み公開鍵とRelease配布物に付属する検証可能な署名を照合し、欠落・不正時は未検証Generationに切替えない。利用者が明示的にfalseとした場合だけ配布元署名検証を解除できるが、他の構造検証は省略しない。ReleaseのtagとAsset IDおよびETag、署名検証の合否を取得履歴として保存する。ETagだけを完全性の証明とはしない。
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
- PNG/HCA単体の辞書一致判定は従来どおり維持する。構成セットを登録しただけで辞書未一致のPNGを汎用アセットとして使用可能にしたり、GameServerの計算マスターデータへ昇格させたりしない。セット削除時は共有PNGを他のセットが参照しているか確認し、破損した参照が残らないようにする。


## HCAループ指定と鍵探索キャッシュ

- **BGM専用フォルダ**へ配置されたHCAは音源全体をループ再生する。それ以外のHCAはループしない。区分は端末の`./assets/`配下の実際の保存先フォルダによって決まり、拡張子やファイル名から推測しない。`hca_config.json`を新規生成・取り込み・参照せず、利用者によるloopチェックUIも設けない。キャッシュクリア後も`./assets/`の配置は維持するためループ判定が復元される。BGMフォルダの具体的なPath文字列は既存の辞書配置Path/素材区分を正本とし、異なる表記のフォルダを自動BGM扱いしない。
- `./cache/temp/decode/keys.json`は`schema_version=1`と`entries` Objectを持つ。Keyは`<UTF-8元ファイル名をBase64url化した文字列>.<内容SHA-256小文字16進64桁>`、Valueは`{"filename": "...", "sha256": "...", "key_decimal": "0以上の整数の10進文字列"}`とする。Keyを受け入れる前にfilename/Hashと復号成功を検証する。浮動小数点や先頭ゼロ・負値の鍵表現は拒否する。鍵の許容上限は採用したHCAデコーダーの鍵型と同一にする。
- キャッシュ一致時はその鍵で復号を検証し、失敗なら鍵を破棄して探索を行う。探索で復号成功を確認した時だけ、`keys.json`を一時生成・読戻しValidation・参照切替して更新する。鍵および復号結果をログへ出さない。キャッシュクリアでは鍵キャッシュも消える。鍵の探索自体が失敗した場合は無音にする。

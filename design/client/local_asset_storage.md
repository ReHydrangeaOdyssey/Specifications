# ローカルアセットの取り込み・保存契約

この文書は`design/client/client.md`のデータ規則を端末側の具体的な保存と更新に適用する。ユーザーが取り込む画像・音声の正本と、ゲームが自動取得する辞書/代替画像は区別する。パスはOPFSのRoot相対表記であり、Clientが実際のWeb Host filesystemに自由にアクセスできるという意味ではない。

代替画像は`https://github.com/ReHydrangeaOdyssey/GameAssets/releases`から取得する。Releaseで明示されたAsset名・検査値と有効辞書の有無を検証し、既知の検証済み画像へだけ参照を切り替える。代替画像は通常素材と異なるClient管理物だが、ゲーム開始には有効辞書も必須とする。実配布Asset名は提供側が公開する実体に合わせ、未提示の名称を固定しない。

## Release辞書の取得・原子的更新

1. ログイン成功後、配布`./config.cfg`とタイトル設定画面で保存した端末上書き値を統合した実効`update_asset_dictionary`が`true`の場合、`asset_dictionary_version=latest`なら最新Release、それ以外は指定tagのReleaseをGitHub Releases APIで取得する。辞書本体は`asset_dictionary.json`という名前のRelease Assetを**ちょうど1件**選び、同じReleaseから検査値を表す**小文字16進64桁のAsset名**を1件取得する（実効`verify_asset_dictionary_sha256=false`では当該Asset不在も許容する）。Assetの実URLはRelease APIの返却値から取得し、任意の未知Assetを辞書として選ばない。
2. HTTPSレスポンス正常性、Content-Lengthと実受信量、最大受信量上限、UTF-8、JSON Object、すべての`path`/`paths`とハッシュキー形式、相対Path安全性、File名の重複と空値を全件検証する。**辞書本体のRaw Bytes全体**にSHA-256を計算し、同じRelease内でファイル名がこのDigestと完全一致する検査値Assetがちょうど1件だけある場合に照合成功とする。`verify_asset_dictionary_sha256=true`（初期値）で検査値Asset欠落・曖昧・不一致なら切替えない。利用者が設定画面で明示的にfalseとしたときだけ検査値照合を省略できるが、Schema/Path検査は常に実施する。tag・辞書Asset ID・検査値Asset ID・ETag・計算Digest・検証結果を履歴へ保存する。ETagはHashの代用にならず、同一Release内のDigest名ではRelease改ざん自体を検出できない。
3. `./cache/temp/asset_dictionary/`に`generation_<id>.json`として一時書込みし、読戻し検証後に`active.json`参照（generation ID・tag・SHA-256・Size）を一時ファイルから切替える。旧Generationは新Generationの参照確定まで削除しない。再起動時はActiveのHashとJSONを検証し、不完全なら直前の検証済みGenerationへ戻す。旧辞書と新辞書で全Pathを比較し、旧辞書にのみある保存Pathの素材を`./cache/obsolete_assets/<更新ID>/`へ退避する。共通Pathの既存素材は残し、新規Pathへ旧内容を根拠なく割り当てない。退避・全件検証・有効辞書参照の切替を更新マーカーで一体化し、途中失敗/再起動時は旧辞書と元の`./assets/`状態へロールバックする。新辞書が有効になった後、退避した素材はRuntimeで使用せず、明示的なキャッシュクリアの対象とする。
4. `update_asset_dictionary=false`ならネットワーク取得しない。初回に有効辞書がない場合は空辞書として手動割当だけを使う。HTTP失敗は1回だけ再試行してから保存済み正本へ戻す。
5. `./cache/temp/`配下はプロセス再起動で自動消去しないが、ユーザーが**キャッシュクリアを明示実行した場合は辞書Generationも消去される**。次回ログインで再取得する。Version差分移行中は既存仕様に従いキャッシュクリアを拒否する。

## 取り込みと割当レコード

- ファイルは`./cache/temp/user_impoert/<import_id>/`へ一時取込みし、`import_id`は暗号学的乱数で一意に発行する。辞書一致は`./assets/`へ確定し、不一致は`./cache/unknown_resouce/<import_id>/`へ保存する。未一致は描画・再生に使用しない。
- 割当レコードは`./cache/unknown_resouce/assignments.json`のUTF-8 JSONとする。`schema_version=1`、`items`は`import_id`をキーにしたObjectとする。各項目は`original_filename`（改名・Unicode正規化なし）、`content_sha256`（小文字16進64桁）、`current_path`（実体が現在存在するOPFS Root相対Path）、`category`（`BGM`/`SE`/`Voice`/`Character`/`SD Character`/`Character Icon`）、`target_id`（Character系は指定ID、その他は空文字）、`dictionary_status`（`unmatched`/`matched_pending_confirmation`/`invalid`）、`assigned_path`（未確定なら空文字）、`created_at`（UTC epoch milliseconds）を必須とする。
- 端末内の割当レコードは元ファイル名と実ファイル名を別に保持する。`target_id`やユーザーの手動区分は辞書一致を証明しない。ログイン後に辞書更新した場合は元ファイル名および必要に応じた内容SHA-256で再照合し、保存先変更/上書きはユーザー確認後に行う。
- 割当レコードは現在実体Pathを唯一の参照正本として保存する。再配置時は移動先へコピー→内容Hashの再検証→割当レコードの原子的な参照切替→旧実体削除の順で処理する。保存済み`current_path`が存在しない場合は旧一時Pathを勝手に正本化せず`invalid`の修復対象とする。割当レコードは一時ファイルへ全件書込み→読戻しValidation→参照切替の順に更新する。レコードと素材の一方が欠落した場合は一致とみなさず当該レコードを`invalid`として表示・修復対象にする。キャッシュクリアでは保留素材と割当レコードの両方を消す。

## キャラクター構成データ（端末内完結）

- キャラクター描画の構造情報（`SpriteAnimationData`/`PlistRoot`の論理モデル）とユーザーが取り込む**画像PNG/HCAの実ファイル**は区別する。通常の`./assets/`にProtoBufファイルを取り込んだり、そこから列挙したりしない。Client側に既に提供された構造情報に従って画像参照を解決する。Clientでのみ検証・登録・入替・削除・再起動後復元を行い、Public API/Private API/GameServer/DBへ素材を送信・保存しない。
- 画像等の取込対象ファイルの元名・内容Hash・保存先Pathは取込時に検証する。Clientが保持する構造情報の参照とPNGの実体を照合し、セット外の任意Pathやディレクトリ脱出を禁止する。対象実ファイルを一時領域で検証し、既存ファイルの退避と原子的な置換手順を用いる。永続Manifestは作らない。
- ProtoBufは描画用データ型の定義であり、`./assets/`内のユーザーファイルの形式・保存対象を意味しない。名称から骨格/Movementを自動生成しない。実データから機械的に作れない`CharacterID × 向き × Action`の全件対応表を別途必須Schemaとして要求しない。ゲーム内の表示対象と使用セットはClient側の明示選択・既存素材参照で決定し、参照不能なCharacterは代替表示を行う。
- **アセット辞書をRuntime素材使用許可の最上位規則**とする。Runtimeでユーザー供給素材として読むPNG/HCAについて、各ファイルの元ファイル名が有効辞書に存在し、辞書で許可されたPathに解決できなければ使用不可とする。骨格・モーション・アトラスの内部データ構造そのものを辞書登録済みの`./assets/`ファイルだと解釈しない。構成セットの端末内登録だけでは使用権限を生じない。辞書登録名でのユーザー素材差替えは`config.cnf`の明示設定とClient仕様の許可Path制限に従う。セット削除時は共有PNGを他セットが参照しているか確認する。


### 構成セットの保存・入替

- 独立した`manifest.json`・`index.json`や`generation_id`台帳は作らない。Clientが取得した描画構造情報と参照PNGの関係を**メモリ上で**検査し、辞書一致したPNG/HCAの実体だけを辞書が許可する`./assets/`始まりの完全Pathへ保存する。ProtoBufは`./assets/`に保存しない。辞書の一致しないファイルをRuntimeには渡さない。
- 一括取込みや差替えでは、取込対象のPNG/HCAの形式・画像参照・Hash・辞書許可を検証し、変更対象の旧ファイルをOPFSの一時領域へ退避した後に新ファイルを配置する。全件成功時だけ退避を削除し、中断・失敗時には既存の旧ファイルを復元する。処理中マーカーは一時領域に保持し、起動時に未完了処理を検出したらロールバックする。構成セットの永続Manifest・世代管理は必要としない。
- 次回起動時は有効辞書の完全PathとClientが利用可能な描画構造情報の参照からPNG実体を再検証する。`./assets/`をProtoBuf探索先とせず、存在しない構造情報を推測で生成しない。壊れたFrameや参照が1件でもあれば、その読込対象の構成一式を拒否する。存在しない全件自動対応表・Movement名を推測で補わない。Client以外のAPI/DBへ素材を送信しない。

## HCAループ指定と鍵探索キャッシュ

- **`./assets/sound/bgm/`**（ディレクトリ境界と大文字小文字を区別し、配下のサブディレクトリを含む）へ配置されたHCAは音源全体をループ再生する。それ以外のHCAはループしない。区分は端末の`./assets/`配下の実際の保存先フォルダによって決まり、拡張子やファイル名から推測しない。`hca_config.json`を新規生成・取り込み・参照せず、利用者によるloopチェックUIも設けない。キャッシュクリア後も`./assets/`の配置は維持するためループ判定が復元される。BGM Pathは`./assets/sound/bgm/`で固定し、`./assets/sound/bgmmusic`や`./assets/Sound/bgm/`を含めない。辞書指定保存先がこのディレクトリ境界の中にある場合のみ全曲ループする。
- `./cache/temp/decode/keys.json`は`schema_version=1`と`entries` Objectを持つ。Keyは`<UTF-8元ファイル名をBase64url化した文字列>.<内容SHA-256小文字16進64桁>`、Valueは`{"filename": "...", "sha256": "...", "key_decimal": "0以上の整数の10進文字列"}`とする。Keyを受け入れる前にfilename/Hashと復号成功を検証する。浮動小数点や先頭ゼロ・負値の鍵表現は拒否する。鍵の許容上限は採用したHCAデコーダーの鍵型と同一にする。
- キャッシュ一致時はその鍵で復号を検証し、失敗なら鍵を破棄して探索を行う。探索で復号成功を確認した時だけ、`keys.json`を一時生成・読戻しValidation・参照切替して更新する。鍵および復号結果をログへ出さない。キャッシュクリアでは鍵キャッシュも消える。鍵の探索自体が失敗した場合は無音にする。

### 辞書の保存Pathの基準

辞書生成側が`path`または`paths`の値を`./assets/`で始まる**OPFS Root相対の完全Path**として出力する。Client側で接頭辞を追加しない（`./assets/assets/`を作らない）。`./assets/`より外への参照、`..`、空セグメント・区切り文字の置換・URL・バックスラッシュを拒否する。`./assets/sound/bgm/...`はそのままBGM判定対象であり、辞書Pathの全体を大文字小文字も含めて厳密に扱う。

保存先の重複は辞書生成側で検査するという配布前提とし、Clientで別名素材の自動統合・エイリアス解決を新設しない。辞書の安全Path検証自体は省略しない。

### 辞書更新で不要となった素材の退避

新旧辞書を`path`と`paths`の全Pathへ展開し、旧辞書で許可され、新辞書では**どのエントリからも参照されない**保存Pathを不要素材と判定する。対象となる実ファイルは`./cache/obsolete_assets/<更新ID>/`へ元のRoot相対Pathを保ったまま退避し、新辞書を有効化した後は使用しない。新旧で共通するPathは移動しない。退避中に失敗した場合は、新辞書を有効化せず旧辞書と旧素材の整合状態へ復帰させる。更新中マーカーは完了/ロールバックまで維持し、更新中はキャッシュクリア・新規素材の変更を受付けない。手動キャッシュクリアは確定済みの退避ファイルを消す操作であるとUIで示す。

### 構成素材の入替中の画面保護

構成素材の全ファイルの検証・退避・切替・完了までClientをローディング表示とし、ユーザーの画面操作・キャッシュクリア・素材削除・新たな入替を受け付けない。ローディングによる操作禁止だけではブラウザの強制終了を防げないため、既定の作業マーカー・退避・起動時ロールバックは残す。再起動後に未完了マーカーがあれば復元が済むまで同じローディング状態で操作を無効化する。永続Manifestは導入しない。

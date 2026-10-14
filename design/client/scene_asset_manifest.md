# シーン別Asset Manifest仕様

## 目的・適用範囲

- 各シーンが利用する画像・音声の**論理キーと元ファイル名**の対応を、Rust/WASMの定数表から分離し、実行時に読み込めるJSONとして配布する。JSONをWASMへ静的埋込みしないことをWASMサイズ低減の前提とする。削減効果は変更前後の非圧縮WASMサイズを同一ビルド条件で比較して測定する。
- **Scene Manifest**はシーンからの参照、**AssetDictionary**はアセット名と保存可能なPath/内容Hash条件の正本、**Asset Manager**はRuntimeでのファイル検証・読み込み・デコード・GPU/音声メモリ管理を担う。Manifestに記載しただけでは、未登録素材を許可・配布・ダウンロード・複製したことにはならない。
- 通常取込み対象は既存どおり**PNG画像とHCA音声**に限定する。拡張子別辞書に`jpg/`等が存在しても、このManifestの導入を理由にClient対応形式を拡張しない。
- 本仕様の**シーン参照JSON**は、`local_asset_storage.md`にある**キャラクター構成セットの永続Manifestを作成しない**規則とは別用途であり、キャラクター骨格・モーション・アトラス等の構造モデルを自動生成するものではない。

## 配置・バージョン・配布

- 配布ルートでは`./scene_assets/<scene_id>.json`、OPFSでは同じClient Versionの`./game/scene_assets/<scene_id>.json`に格納する。Service WorkerのVersion別Cache Storageにも同じURLのJSONを格納し、他VersionのHTML・JS・WASMやScene JSONを混用しない。
- `scene_id`はクライアントが保持する固定ID（英小文字から開始し、英小文字・数字・`_`のみ、正規表現`^[a-z][a-z0-9_]*$`）とする。各実シーンのIDと配布JSONの対応表はシーン登録側で確定する。JSONの`scene`と要求先IDを厳密に一致させる。ネットワークの任意文字列をファイルPathへ連結しない。
- Client Versionの切替時には、全配布シーンJSONをHTML・JS・WASMと**同一更新単位**で取得・検証し、`./game/`全量置換/Service Worker Cache切替の既存規則を適用する。全JSONの事前ダウンロード・保存と、各シーンでの実アセットの**遅延ロード**は両立する。`./assets/`内のユーザー素材とアセット辞書のGenerationは引き続き独立管理する。
- Manifestはログイン不要の静的Client配布物とし、GameServer/Public APIやAssetDictionaryのGitHub Releaseから取得しない。初回の配布失敗・不正JSON・同VersionのCache欠落では当該シーンを表示可能と判断しない。オフラインでは検証済みの**同一Client Version**の保存済みJSONを使用する。
- ファイルが必要ないシーンにも`"assets": {}`を含む有効なJSONを配布する。配布する実シーン全件のID・具体的な論理キー・実ファイル名・任意Hash・優先度指定は元ゲーム素材の確認後に確定する。本書の例示ファイル名を本番の確定値として使用しない。

## JSON Schema v1

次は**構造例**であり、`example_*`という元ファイルが実際に配布・登録されていることを示さない。

```json
{
  "version": 1,
  "scene": "home",
  "assets": {
    "bgm": {
      "main": { "file": "example_home.hca" }
    },
    "se": {
      "confirm": { "file": "example_confirm.hca" }
    },
    "background": {
      "main": { "file": "example_background.png" }
    },
    "ui": {
      "start_button": { "file": "example_start_button.png" }
    },
    "animation": {
      "character_idle": {
        "files": [
          { "file": "example_idle_01.png" },
          { "file": "example_idle_02.png" }
        ]
      }
    }
  },
  "critical": ["background.main", "ui.start_button"],
  "prefetch": ["bgm.main", "animation.character_idle"]
}
```

- ルート必須キーは`version`（JSON整数、現行値`1`）、`scene`（上記ID）、`assets`（Object）。任意キーは`critical`、`prefetch`（省略時は空配列）。未知キー・重複JSONキー・型違い・不正Versionは読込失敗とする。JSONはUTF-8として解析し、配布時にはファイル単位の容量制限とスキーマ検査を実施する。
- `assets`のカテゴリは`bgm`、`se`、`voice`、`background`、`ui`、`animation`だけを認める。`voice`は既存HCAボイスの参照用で任意、指定のないカテゴリは空と同義とする。カテゴリ名`back ground`ではなく**`background`**を使用する。
- カテゴリ配下は`<logical_key> → AssetReference`のObjectとする。論理キーは`^[a-z][a-z0-9_]*$`で、一カテゴリ内で一意とする。Runtimeはカテゴリとキーの組を使い、`"ui.start_button"`のように参照する。異なるカテゴリの同名キーは区別する。
- `bgm`・`se`・`voice`は単一HCA参照、`background`・`ui`は単一PNG参照（`{ "file": "<original_filename>", "sha256": "<optional_digest>" }`）とする。`animation`は`{ "files": [<PNG参照>, ...] }`とし、配列は1件以上、並び順を維持する。アニメーションの**フレーム時間、ボーン、アトラス、再生制御**は既存の`SpriteAnimationData`/`PlistRoot`とRuntimeを正とし、この配列から推測・生成しない。
- `file`には辞書の第1キーとなる**ディレクトリを含まない拡張子付き元ファイル名**を記述する。元名は通常取込ルールに従い、拡張子を除いた名前に英数字・`_`・`-`・`(`・`)`だけを許可する。拡張子は小文字`.png`/`.hca`のみ許可し、元名は完全一致で照合する。`/`、バックスラッシュ、URL、端末内Path、`..`を含む入力を禁止する。
- 任意の`sha256`は元ファイルのSHA-256小文字16進64桁とする。辞書に複数のHash候補が存在するときは`sha256`必須。辞書で候補Hashが1つのときは省略可能だが、解決したHashと実ファイルの内容照合は省略しない。`path`が非空のエントリでは、Manifestに`sha256`がある場合に追加の実内容照合を行う。Hash値を示しても辞書側にない元名・Pathを許可しない。
- `critical`と`prefetch`は`<category>.<logical_key>`形式の文字列配列で、`assets`で宣言した参照だけを指定できる。両リスト内の重複や両リスト間の重複は認めない。`animation`の配列内PNGはその論理キー単位で一括して優先度を持つ。どちらにも指定されない参照は初回利用時に読み込む。
- `critical`は**シーンの初回表示に必要なアセット**、`prefetch`は**表示を妨げず先行準備するアセット**とする。`critical`に含むHCAも再生開始ではなく読み込み・デコーダー初期化等の利用準備を待つ。ブラウザーのAudioContext再開はユーザー操作起点とする既存仕様を変えない。

## AssetDictionary Resolver（利用許可と同名ファイル）

1. `file`の拡張子からアセット辞書の配布Root相対`png/assets_dict.json`または`hca/assets_dict.json`を選択し、**ディレクトリを除く元ファイル名を完全一致**で照合する。Manifestから任意のディレクトリ・Pathを直接指定しない。
2. 辞書エントリで`path`が非空なら、その辞書が許可した単一相対Pathを`./assets/`に一度だけ連結し、存在・形式を検証して読む。Manifestの`sha256`が指定されていれば実ファイル内容とも照合する。
3. 辞書エントリで`path`が空なら、Manifest指定Hash（Hash候補が1つならその候補を使用可）に一致する`paths`グループのPath**配列**を使う。**取込時には配列の全Pathへ複製する**従来の保存契約を維持する。一方、Runtimeはその配列内の順序で存在を確認し、内容SHA-256が一致する最初の利用可能な実体を読み込む。1件読めれば同一内容を全Pathから重複デコードする必要はない。利用可能な実体が無ければ未解決とする。ユーザーが一部Pathを削除した場合も、Runtimeが自動複製・補完・再配置しない。
4. 実体の再利用キーは辞書Generation、元名、選択Hashまたは検証済み実保存Path/内容同一性に結び付ける。**論理キーだけで**異なる画像・音声を共有しない。ユーザーによる素材削除・置換、辞書Generation切替では該当実体を再検証し、失効したGPU/音声キャッシュを次の利用へ再使用しない。
5. 欠落、Hash不一致、Path不正、形式不正、デコード失敗では参照を使用不可にする。ユーザー取込対象外の代替画像は既存の別リポジトリ由来の**検証済み**データだけを用い、Manifestによって許可要件を迂回しない。HCA欠落時は音を再生せず、Server状態や戦闘計算を変更しない。
6. `bgm`/`se`/`voice`は参照の用途区分であり、**HCAの実際のループ判定は保存先`./assets/sound/bgm/`配下かどうか**という既存規則を優先する。Manifestのカテゴリからループの真偽を変更しない。

## シーン遷移・非同期処理・メモリ管理

- `SceneController`は対象シーンのManifestを解析し、参照を辞書で解決してから`critical`の読み込みを開始する。PNGは既存`createImageBitmap()`からWebGL 2テクスチャへの転送、HCAは必要なデコード準備まで終えた状態を「利用可能」とする。`critical`が満たされるまで**新シーンを確定しない**。画面・キャラクターについて既存仕様が代替表示を明示した場合に限り検証済み代替アセットを使用できる。代替のない必須背景/UI等が使えなければ旧シーンに留まりエラー/再試行を表示する。初期起動シーンの異常は既存の起動エラー表示を使用する。
- `prefetch`は非同期で事前に読み込むが**シーン遷移の成立条件にはしない**。通信、OPFS、デコード、GPUメモリに余裕がない場合は先読みをスキップまたは中止してよい。次のシーンへの先読みは実際に遷移候補が確定している場合だけ行い、無制限に全シーンの実素材をデコードしない。`critical`/`prefetch`以外は必要になった時点で読み込む。
- 遷移要求ごとに一意な要求IDを割り当てる。新しい遷移、キャンセル、辞書Generation更新、Client Version切替、素材削除/置換で以前のロード完了通知を古いものとして破棄する。遷移確定時は要求ID・Client Version・辞書Generation・対象素材の現在の検証状態を再確認する。**古い非同期結果を新シーンへ適用しない。**
- 旧シーンは新シーンの必須素材が準備できるまで描画状態を維持する。切替後に不要なWebGL Texture/`ImageBitmap`/AudioBuffer/PCMキューを解放し、複数シーンや継続再生で共有する実体は参照が残る間保持する。**OPFSのユーザー素材をメモリ節約のため自動削除しない。** キャッシュ済み実体は必要に応じて再読み込み可能であり、メモリキャッシュの解放と端末保存の削除を混同しない。
- Manifestの取得・解析失敗時、形式未対応時、オフライン時の未キャッシュJSON、必須素材欠落ではエラーを表示し、進行可能と偽装しない。これは既存の辞書と代替画像によるゲーム開始前ガード、Server認証・各シーンのAPI事前条件に**追加される表示準備条件**であり、既存条件を緩和しない。

## 実装に先立つ確定項目

- 具体的な各シーンの`scene_id`・Runtimeで参照する論理キー・実在する元名・同名素材選択Hash・`critical`/`prefetch`分類は原ゲームのアセットと画面要件を照合して確定する。試験用`example_*`のJSONを本番へ混入させない。
- 実素材データが確定していない段階では、**本仕様の形式と処理契約を実装し、実シーン用JSONの完成・検証は別の配布条件として管理する**。無いアセットをWASMに推測で埋め込んだり、辞書にない名前を強制的に解決したりしない。

## 参照

- [クライアント仕様](client.md)
- [シーン遷移](scene_transition.md)
- [ローカルアセット保存](local_asset_storage.md)
- [Web配布](../programming/client/web_delivery.md)
- [Client実装](../programming/client/client.md)
- [テスト設計](../programming/test/test_design.md)

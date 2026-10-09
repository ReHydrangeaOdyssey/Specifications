# コンポーネント別 Rust ライブラリ一覧

| コンポーネント | 使用を推奨するcrate | 用途 | 備考 |
|---|---|---|---|
| **Client（Rust/WASM）** | `wasm-bindgen` | Rust/WASMとJavaScript/ブラウザの結合 | 選定済み |
|  | `web-sys` | WebGL 2, `createImageBitmap`関連のブラウザAPI, Web Audio, OPFS等 | `default-features = false`と必要なAPI featuresを指定 |
|  | `js-sys` | `ArrayBuffer`・TypedArray・Promise等 | 選定済み |
|  | `wasm-bindgen-futures` | Browser PromiseとRust `Future`の連携 | 選定済み |
|  | `cridecoder` | HCAからPCMへのデコード | `0.3.6`, `default-features = false`を採用候補とする。Safari実機検証が最終採用条件 |
|  | `prost` | Public APIのProtocol Buffers encode/decode | 既存仕様に基づく依存を維持。`public_api.proto`共有 |
|  | `game-core` ※内部crate | 戦闘計算、PRNG | 外部crateではなくworkspace内crate |
|  | `protocol` ※内部crate | Protocol Buffers生成型 | 既存の共有crateを維持 |
|  | `serde` | ローカル設定・状態等の型変換 | 必要な場合のみ。HCA関連推移的依存との区別が必要 |
|  | `serde_json` | JSON形式のローカルデータ等 | 必要な場合のみ。HCA関連推移的依存との区別が必要 |
| **Public API Server** | `tokio` | 非同期runtime、timeout、同期処理 | 必須 |
|  | `axum` | Public HTTP API | 必須 |
|  | `axum-server` | HTTPS server | 必須 |
|  | `rustls` | TLS 1.3、mTLS | 必須 |
|  | `reqwest` | Private API / GameServerへのHTTP通信 | 必須 |
|  | `prost` | Protocol Buffers | 必須 |
|  | `serde` | JWT Claim等 | 必須 |
|  | `serde_json` | 構造化データ | 実質必要 |
|  | `jsonwebtoken` | AccessToken / DiscordAuthorizationToken検証 | 必須 |
|  | `base64` | RefreshTokenのBase64url変換 | 必須 |
|  | `time` | JWT時刻、ログ時刻等 | 必須 |
|  | `kube` | GameServer EndpointSlice watch | Kubernetes本番環境のみ |
|  | `k8s-openapi` | EndpointSlice等のKubernetes型 | Kubernetes本番環境のみ |
| **Private API Server** | `tokio` | 非同期runtime、Semaphore | 必須 |
|  | `axum` | Private API | 必須 |
|  | `axum-server` | mTLS HTTP server | 必須 |
|  | `rustls` | mTLS | 必須 |
|  | `reqwest` | 必要な内部通信 | 必要 |
|  | `prost` | Protocol Buffers | 必須 |
|  | `serde` | JWT Claim / DB JSON型等 | 必須 |
|  | `serde_json` | PostgreSQL JSONB等 | 必要 |
|  | `sqlx` | PostgreSQL | 必須 |
|  | `argon2` | Password Hash / Verify | 必須 |
|  | `sha2` | RefreshTokenのSHA-256 | 必須 |
|  | `getrandom` | Salt / RefreshToken等のCSPRNG | 必須 |
|  | `uuid` | SessionID / Operation ID等 | 必須 |
|  | `jsonwebtoken` | AccessToken生成・Ed25519署名 | 必須 |
|  | `time` | Token期限、DB timestamp | 必須 |
| **GameServer** | `tokio` | 非同期通信、Worker、Queue | 必須 |
|  | `axum` | Private HTTP API | 必須 |
|  | `axum-server` | mTLS HTTP server | 必須 |
|  | `rustls` | mTLS | 必須 |
|  | `reqwest` | Private API / Coordinator通信 | 必須 |
|  | `prost` | API・Replay Protocol Buffers | 必須 |
|  | `serde` | Recovery等の型変換 | 必要 |
|  | `serde_json` | DB障害時Recovery JSON、ログ | 必須 |
|  | `uuid` | `X-Operation-ID`生成 | 必須 |
|  | `time` | Replay/Recovery filename等 | 必須 |
|  | `game-core` ※内部crate | 戦闘ロジック、PRNG | 必須 |
| **GuildBattleCoordinator** | `tokio` | 非同期runtime | 必須 |
|  | `axum` | 内部APIを受ける場合 | 設計に応じて必要 |
|  | `axum-server` | mTLS server | APIを持つ場合 |
|  | `rustls` | mTLS | 必須 |
|  | `reqwest` | Private API / GameServer通信 | 必須 |
|  | `prost` | Protocol Buffers | 必須 |
|  | `serde` | データ変換 | 必要 |
|  | `serde_json` | ログ等 | 必要 |
|  | `uuid` | Operation ID等 | 必要 |
|  | `time` | 時刻処理 | 必要 |
|  | `kube` | GameServer EndpointSlice watch | Kubernetes本番環境のみ |
|  | `k8s-openapi` | Kubernetes型 | Kubernetes本番環境のみ |
| **Discord Bot** | `tokio` | 非同期runtime | Rust実装時 |
|  | `serenity` | Discord Gateway / REST API | Rust実装時 |
|  | `reqwest` | Private API等との通信 | Serenity外の内部通信用 |
|  | `rustls` | Private APIへのmTLS | 必須 |
|  | `jsonwebtoken` | DiscordAuthorizationToken生成 | 必須 |
|  | `getrandom` | `jti`等の生成 | 必須 |
|  | `uuid` | DiscordAuthorizationTokenID | 必須 |
|  | `serde` | JWT Claim | 必須 |
|  | `time` | JWT期限 | 必須 |

## Clientの選定に伴う注意点

- Clientの実装方式はRust/WASM（`wasm32-unknown-unknown`）であり, iPhone Safari/PWAおよびAndroid Chrome/PWAを対象とする. `reqwest`をNative Client向け推奨としてClient依存一覧に残さない.
- PNGはブラウザの`createImageBitmap()`, 描画はWebGL 2, PCM音声再生はWeb Audio API, OPFSファイル保存はブラウザAPIを使用し, これらのために追加の専用crateは採用しない.
- 汎用2Dエンジン, `image`, `png`, `pix`, `wgpu`, `glow`はClient描画用として採用しない.
- `cridecoder`はHCA以外のCRI形式も含むため推移的依存が発生する. 選定資料の「直接依存5クレート」は**新たに選定されたブラウザ連携/デコード用crateの数**であり, 既存`prost`や内部crateを含むClient全体の依存総数ではない.
- ClientとPublic API Server間の通信方式は「[ネットワーク](network.md)」を正とし, HTTP/2 over TLS 1.3とProtocol Buffersを使用する. `SubscribeGuildBattleUpdates`はHTTP/2 Response streamで受信する. 選定資料の対戦通信`WebSocket`は採用しない. この方式をブラウザで扱う具体的な通信ライブラリ/Browser APIは未確定とする.
- `Cargo.lock`によるバージョン固定と`cargo tree --target wasm32-unknown-unknown`による依存確認を行う. `cargo build --target wasm32-unknown-unknown --release --locked`の結果および端末上の動作は現時点では未検証とする.
- `web-sys`のfeature一覧とRelease設定例は選定資料にあるが, ビルド確認済みの確定`Cargo.toml`ではない. `opt-level = 3`と`opt-level = "z"`を比較し, 最終Release設定を検証で決定する.

### 選定資料に記載されたClient依存バージョン・Browser API features

下記は添付選定資料の**設計用たたき台**に記載された範囲です。検証済みのCargo設定ではありません。Cargoのバージョン条件は範囲指定であり, 実際の解決バージョンは`Cargo.lock`で固定します。

| crate | 選定資料のCargoバージョン条件 | 備考 |
|---|---|---|
| `wasm-bindgen` | `0.2` | ブラウザ連携 |
| `web-sys` | `0.3` | `default-features = false` |
| `js-sys` | `0.3` | JavaScript型 |
| `wasm-bindgen-futures` | `0.4` | PromiseとFuture |
| `cridecoder` | `0.3.6` | `default-features = false`・採用確定には実機検証が必要 |

- `web-sys`で選定資料に記載されたfeaturesのうち, 採用しない`WebSocket`を除いた候補は`Window`, `Document`, `Element`, `Navigator`, `HtmlCanvasElement`, `WebGl2RenderingContext`, `WebGlProgram`, `WebGlShader`, `WebGlBuffer`, `WebGlTexture`, `WebGlVertexArrayObject`, `Blob`, `File`, `ImageBitmap`, `AudioContext`, `BaseAudioContext`, `AudioBuffer`, `AudioBufferSourceNode`, `AudioNode`, `AudioDestinationNode`, `AudioWorklet`, `AudioWorkletNode`, `MessagePort`, `Event`, `EventTarget`, `StorageManager`, `FileSystemDirectoryHandle`, `FileSystemFileHandle`, `MessageEvent`, `Performance`です。
- これらはビルド検証前の**feature候補一覧**です。実際に呼び出すブラウザAPIに応じて追加・削除が必要です。HTTP/2のPublic API通信を行う具体的なブラウザAPI・ライブラリは未確定のため, 必要なfeaturesを推測で追加しません。
- 選定資料のRelease設定案は`opt-level = 3`, `lto = "fat"`, `codegen-units = 1`, `panic = "abort"`, `strip = "symbols"`です。圧縮後のWASMサイズ, HCAデコード時間, 初回ロード時間を`opt-level = "z"`とも比較してから最終決定します。
- `prost`と内部`protocol`/`game-core`は既存仕様からの依存であり, 上の選定資料のCargoたたき台に未記載でも除外しません。

## 共通内部crate

| 内部crate | 外部依存 | 使用するコンポーネント |
|---|---|---|
| `game-core` | 原則なし（`std`のみ） | Client / GameServer |
| `protocol` | `prost` | Client / Public API / Private API / GameServer / Coordinator |
| `common-types` | 原則`std`、必要なら`serde` | 全体 |
| `server-common` | `tokio`, `rustls`等 | 各Server |
| `auth-common` | `serde`, `jsonwebtoken`等 | Public API / Private API / Discord Bot |

## コンポーネント別の最小構成

| コンポーネント | 最小構成 |
|---|---|
| **Client** | `wasm-bindgen`, `web-sys`, `js-sys`, `wasm-bindgen-futures`, `prost`, `game-core`, `protocol`（HCAの`cridecoder`は実機検証後に最終採否を確定） |
| **Public API** | `tokio`, `axum`, `axum-server`, `rustls`, `reqwest`, `prost`, `serde`, `serde_json`, `jsonwebtoken`, `base64`, `time` |
| **Private API** | `tokio`, `axum`, `axum-server`, `rustls`, `reqwest`, `prost`, `serde`, `serde_json`, `sqlx`, `argon2`, `sha2`, `getrandom`, `uuid`, `jsonwebtoken`, `time` |
| **GameServer** | `tokio`, `axum`, `axum-server`, `rustls`, `reqwest`, `prost`, `serde`, `serde_json`, `uuid`, `time`, `game-core` |
| **GuildBattleCoordinator** | `tokio`, `axum`, `axum-server`, `rustls`, `reqwest`, `prost`, `serde`, `serde_json`, `uuid`, `time` |
| **Discord Bot** | `tokio`, `serenity`, `reqwest`, `rustls`, `serde`, `jsonwebtoken`, `getrandom`, `uuid`, `time` |
| **Public API / Coordinator 本番追加** | `kube`, `k8s-openapi` |

## 情報源

### 添付仕様書・設計書
- `design/client/client.md`
- `design/server/public_api.md`
- `design/server/private_api.md`
- `design/server/game_server.md`
- `design/server/guild_battle_coordinator.md`
- `design/server/session.md`
- `design/server/data_base.md`
- `design/system/network.md`
- `design/system/public_api.proto`
- `design/system/guild_battle_replay.proto`
- `design/game/pseudorandom.md`

### crate公式ドキュメント
- Tokio: https://docs.rs/tokio/
- Axum: https://docs.rs/axum/
- axum-server: https://docs.rs/axum-server/
- rustls: https://docs.rs/rustls/
- reqwest: https://docs.rs/reqwest/
- prost: https://docs.rs/prost/
- serde: https://docs.rs/serde/
- serde_json: https://docs.rs/serde_json/
- SQLx: https://docs.rs/sqlx/
- argon2: https://docs.rs/argon2/
- sha2: https://docs.rs/sha2/
- getrandom: https://docs.rs/getrandom/
- uuid: https://docs.rs/uuid/
- jsonwebtoken: https://docs.rs/jsonwebtoken/
- time: https://docs.rs/time/
- kube: https://docs.rs/kube/
- k8s-openapi: https://docs.rs/k8s-openapi/
- serenity: https://docs.rs/serenity/

- 添付`rust_wasm_png_hca_library_selection(1).md`（2026-10-09）, 第1～7節.

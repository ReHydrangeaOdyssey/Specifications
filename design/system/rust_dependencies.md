# コンポーネント別 Rust ライブラリ一覧

| コンポーネント | 使用を推奨するcrate | 用途 | 備考 |
|---|---|---|---|
| **Client** | `prost` | Public APIのProtocol Buffers encode/decode | `public_api.proto`共有 |
|  | `reqwest` | Public API ServerとのHTTPS通信 | Native Clientの場合。Web Clientでは別手段になる可能性あり |
|  | `serde` | ローカル設定・状態等の型変換 | 必要な場合のみ |
|  | `serde_json` | JSON形式のローカルデータ等 | 必要な場合のみ |
|  | `game-core` ※内部crate | 戦闘計算、PRNG、共通型 | 外部crateではなくworkspace内crate |
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
| **Client** | `prost` + `game-core` |
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

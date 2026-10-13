# ソースコードの公開とライセンス

## 公開方針

本プロジェクトが独自に作成する**すべてのプログラムのソースコードを公開**し、**MIT License**で提供する。公開を前提に設計・実装・テストを行う。Clientだけでなく、ネットワーク内で実行するServer側コードも非公開の例外を設けない。

| 公開対象 | 含むコード |
|---|---|
| Client | Rust/WASM、JavaScript、Service Worker、画面とローカル保存処理 |
| GameServer | Arena、GuildBattleのRuntime・Replay・Recovery・Worker |
| GuildBattleCoordinator | マッチング、割当、Lifecycle調整、Control API |
| Public API Server / Private API Server | Transport、認証・認可、Account / Guild Domain、永続化Adapter |
| 共通ライブラリ | `game-core`、`protocol`、`common-types`、`server-common`、`auth-common` |
| 付属プログラム | Discord Bot、MasterData Pipeline、ビルド・開発・テスト・配備用スクリプト等の独自コード |

上記は実行環境がインターネットに公開されるという意味ではない。GameServer、Private API、Coordinatorのネットワーク公開範囲・mTLS・認可は`network.md`のまま変更しない。

## MIT Licenseの適用

- ソースリポジトリのルートへMIT License全文を記載した`LICENSE`を配置する。複数リポジトリに分かれる場合は各リポジトリに配置し、どの独自コードが対象か判別できるようにする。著作権表記は実際の権利者情報で作成し、仮の権利者名は置かない。
- 配布物・公開ソースにMIT Licenseの著作権表示と許諾表示を付属させる。利用者に対しMIT Licenseを超える独自の利用制限を設けない。
- **第三者依存ライブラリは各権利者のライセンスに従う。** 独自コードをMITにしても第三者コード、フォント、画像、HCA、MasterData、元ゲーム由来の素材までMITに変更したことにはならない。素材の配布権限は独立して確認する。
- Client内のクレジット・依存ライセンス表示は既存契約に従って維持する。Serverのソース公開にも第三者ライセンス通知が必要な場合は同梱する。

## 公開しない情報

公開するのはプログラムのソースであり、運営中の秘密情報・個人データの公開ではない。以下をGit履歴、サンプル、テストFixture、ビルドログを含む公開リポジトリへ置かない。

- TLS/mTLS・JWT・WAL署名用秘密鍵、API Token、Cookie秘密値、DB接続資格情報、Discord Bot Token、署名・デコード等の秘密情報。
- 本番DBの行、Session、Account個人情報、非公開ログ、Replayに含まれる利用者データ。
- 配布権限を確認していないゲームアセット・MasterDataや第三者の著作物。

資格情報は実行時設定・Secret管理から渡し、必要な設定項目だけをサンプルとして公開する。公開ソースに秘密を埋め込んで隠蔽・難読化する設計は認めない。公開済みのコードを前提に、認証・認可・入力Validation・レート制限・署名照合をServer側で独立に実行する。

## テストと公開準備

- すべての独自実装crate / Applicationに単体テストを持たせ、CIで実行する。公開前に秘密情報の混入、`LICENSE`の所在と依存ライセンスの必要な通知を検査する。
- コード公開とバイナリ配布、Server稼働設定は別責務とし、公開ソースだけで接続先・鍵・個人データが確定することを要求しない。

共通コーディング規則は`../programming/implementation_rules.md`、具体的なComponent構成は`../programming/architecture.md`を正とする。

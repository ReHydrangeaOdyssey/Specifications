# 本設計で固定しない事項

## 結論

以下は添付資料で固定されていない、または明示的に未定義とされているため、本プログラミング設計では決定しない。

- ClientのNative / Web等の具体的実装方式
- Clientの具体的Framework
- Clientの具体的通信ライブラリの最終選択
- MasterData編集原本の具体的形式
- Discord Botの本番配置先
- 推奨初期値と記載された運用パラメータの最終値
- 仕様上未確定のゲーム効果・数値式
- 将来のPublic API Deployment分割
- 進行中GuildBattleをGameServer障害後に別GameServerへ自動復旧する方式

## 根拠

Client通信についてはNative Clientの場合の候補が示される一方、Web Clientでは別手段となる可能性が記載されている。

Discord Botの本番配置先は`design/system/network.md`で固定しないと明記されている。

GameServer異常終了時の進行中GuildBattleを別GameServerへ自動復旧する処理は`design/server/guild_battle_coordinator.md`で「本仕様では定義しない」とされている。

テスト方針でも、仕様未確定項目はテストで任意の挙動を固定しないと定義されている。

## 情報源

- `design/system/rust_dependencies.md`
- `design/system/network.md`
- `design/server/guild_battle_coordinator.md`
- `design/test/test_policy.md`

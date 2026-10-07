# 本設計で固定しない事項

## 結論

以下は現行仕様で固定されていない、または明示的に定義しないとされているため、プログラミング設計でも決定しません。

- ClientのNative / Web等の具体的実装方式
- Client Framework
- Web Clientを含むClient通信ライブラリの最終選択
- MasterData編集原本の具体形式
- Public APIのHTTP method / HTTP path
- `public_api.proto`にgRPC Serviceを追加すること
- Discord Botの本番配置先
- GuildBattleCoordinatorが内部APIを受信する場合のServer構成
- 推奨初期値として記載された運用値の最終運用値
- 仕様上未確定のゲーム効果・数値式
- 将来のPublic API Deployment分割
- 進行中GuildBattleをGameServer異常終了後に別GameServerへ自動復旧する方式

## 実装時の扱い

未定義事項について、既存挙動を想定したDomain Logicやテスト期待値を追加しません。必要になった時点で仕様書を更新してから実装へ反映します。

## 情報源

- `design/system/public_api.proto`
- `design/server/public_api.md`
- `design/system/rust_dependencies.md`
- `design/system/network.md`
- `design/game/master_data_pipeline.md`
- `design/server/game_server.md`
- `design/server/guild_battle_coordinator.md`
- `design/test/test_policy.md`

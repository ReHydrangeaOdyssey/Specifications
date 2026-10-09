# 本設計で固定しない事項

## 結論

以下は現行仕様で固定されていない、または明示的に定義しないとされているため、プログラミング設計でも決定しません。

- ClientのNative / Web等の具体的実装方式
- ログイン・Server未接続時に利用できる具体的なゲーム機能と必要なローカルデータ
- ログイン・Server未接続状態から接続可能状態へ戻った場合のClient側状態の扱い
- タイトル画面で追加した画像の受け入れ形式・容量制限・保存先・保持期間・再割り当てと削除の規則
- キャッシュクリアの対象範囲および追加した画像・キャラクターとの対応付けへの影響
- アセット追加操作の具体的UIフロー（独立シーンの有無を含む）
- Client Framework
- Web Clientを含むClient通信ライブラリの最終選択
- MasterData編集原本の具体形式
- Public APIのHTTP method / HTTP path
- `public_api.proto`にgRPC Serviceを追加すること
- Discord Botの本番配置先
- GuildBattleCoordinatorが内部APIを受信する場合のServer構成
- 推奨初期値として記載された運用値の最終運用値
- 仕様上未確定のゲーム効果・数値式
- 騎士団施設の武器庫・食糧庫・鍛冶屋について, レベルごとの攻撃力・最大HP・防御力補正量および計算式への適用位置
- 酒場のBP回復量・回復方法・発動条件, 最大3回の集計単位とリセット条件
- 施設レベルアップ用ゴールドの所持主体・初期値・保有量管理, 施設ごとの消費量・権限・更新API/処理方式（ゴールド獲得クエスト自体は現段階の再現対象外）
- BP50回復薬の日次10個配布を実行する契機・対象Playerの確定タイミング・未配布日の扱い, 対象ItemIDの確定方法
- 日次配布の所持数加算と騎士団戦中のGameServer所持数スナップショット・`UpdatePlayerItem`絶対所持数更新が重なった場合の同期方法
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
- `design/client/client.md`
- `design/client/scene_transition.md`

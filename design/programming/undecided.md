# 本設計で固定しない事項

## 概要

本書は実装前に確定していない仕様および, 意図的に定義しない事項を整理する。

## 未決定事項

- 対応iOS/Androidの最小OSバージョン, PWAインストール手順・配布URL・独自ドメイン（最小対応ブラウザはiOS Safari 16.3, Android Chrome 120で確定済み）
- GitHub PagesとPublic APIのSite/Origin構成（`SameSite=Strict` Cookieを維持できる構成）, HTTP/2 + TLS 1.3の対象ブラウザ実通信検証
- アセット追加シーンの戻り先・戻り操作, Safari/Chromeでのファイル/フォルダ取り込み操作, 元ファイル削除を伴う「移動」の権限と実現方式
- Server配布のファイル名SHA-256ハッシュ対応辞書の取得API・配布時期・シリアライズ形式, ファイル名をSHA-256へ入力する際の文字列表現, OPFS内の割当情報の具体形式, 同名時の上書き規則（同名ファイルは内容SHA-256で判別し, それ以外の衝突処理は設けない）
- OPFSセマンティックバージョン別ディレクトリの詳細なPath・検証基準・中断復旧手順, ブラウザ固有のquota/退避/削除, `cache`フォルダの具体的配置階層
- `cridecoder`のiPhone Safari/WASM上のビルド・再生・メモリ・ライセンス監査を経た最終採否
- 22,050Hz HCAのループ開始/終了位置とチャンネル数, 最適PCM先読み量, 実機性能・欠音検証
- GPU負荷80%, メモリ2GB, FPS30, WASMサイズ500MBの測定方法・範囲・評価端末・測定時間, 本番Release最適化設定の最終値
- `FileSystemSyncAccessHandle`の非同期API比較計測を経た最終採否
- Public APIのHTTP Method / HTTP Path, `public_api.proto`へのgRPC Service追加の採否
- Discord Botの本番配置先
- GuildBattleCoordinatorが内部APIを受信する場合のServer構成
- 推奨初期値として記載された運用値の最終運用値
- 騎士団の武器庫/食糧庫/鍛冶屋補正を既存戦闘計算へ入れる位置・順序・スナップショット反映段階（補正量自体は確定済み）
- 酒場最大3回の使用回数の集計主体（Player/Guild等）, 最大BP上限の取扱い, 酒場回復のGameServer API・RequestSequence・永続化方式（回復量・ボタン・JSTリセットは確定済み）
- 施設レベルアップ用ゴールドの所持主体・初期値・保有量管理, 施設ごとの消費量・権限・更新API/処理方式（獲得クエストは現段階の再現対象外）
- BP50回復薬の日次0:00配布の実行主体とJob/API, 対象Playerの確定タイミング, 未配布日の取扱い, 対象ItemIDの特定方式
- 日次配布と騎士団戦中のGameServer所持数スナップショット・`UpdatePlayerItem`絶対所持数更新が異常時・遅延時等に重なる場合の同期方式
- 進行中GuildBattleをGameServer異常終了後に別GameServerへ自動復旧する方式
- 状態異常付与直前の`ABILITY_EFFECT_AVOIDANCE`判定について, 被付与キャラクター側の`AbilityBattleState.activated_this_turn`確認分岐と, 発動済み時の遷移を「キャラクター行動」フローのどこへ組み込むか（発動成立時の状態更新は共通のAbility発動処理に従う）
- `ABILITY_EFFECT_AVOIDANCE_COUNTER`を通常攻撃の相手HP処理後に判定する現フローでは, 発動時の「回避」が先に適用済みの通常攻撃ダメージへ及ぼす処理が定義されていない（反撃時の味方HP処理への遷移は定義済み）

### 意図的に記載しない事項

- MasterData編集原本の具体的形式（現時点で仕様書へ記載しない方針, 未決定扱いにしない）

### 「仕様上未確定のゲーム効果・数値式」の具体箇所

- `specification/game/guild.md`「施設の効果」と`specification/game/guild_battle.md`「騎士団施設の効果」：数値補正自体は確定したが, 他補正との適用順序・計算段階は未確定.
- `specification/game/guild.md`「施設レベルアップとゴールド」：ゴールド管理とレベルアップ処理の具体仕様は未確定.
- `design/game/master_data_pipeline.md`の「具体的な数値式が仕様上未確定の効果」という包括的注意書きについて, 上記以外の具体的なゲーム効果は現在のゲーム仕様資料から特定できない. 未確認の効果を推測して列挙しない.

## 確定済みの設計事項

- ClientはRust/WASMのWeb Clientとし, iPhone Safari/PWA・Android Chrome/PWAを対象とする. 配布先はGitHub Pagesを予定する. 最小対応ブラウザはiOS Safari 16.3, Android Chrome 120とし, 最小OSバージョンは未確定とする.
- WebGL 2の独自スプライトバッチ描画とブラウザ`createImageBitmap()`によるPNGデコードを使用する.
- `wasm-bindgen`, `web-sys`, `js-sys`, `wasm-bindgen-futures`をブラウザ接続に用いる. `cridecoder`はHCAデコードの採用候補とし, 実機検証まで最終確定とはしない.
- Web Audio APIでPCM再生し, 長い音声は`AudioWorklet`と`MessagePort`によってPCMチャンクを供給する.
- PNG/HCA本体とキャラクター割当情報はOPFSへ保存し, 選択ディレクトリを再帰探索したファイル名のSHA-256ハッシュ対応辞書に基づき自動配置する. 同名ファイルはファイル内容のSHA-256で配置先を判定し, それ以上の衝突処理は設けない. Clientの自動削除は行わず, キャッシュクリアはOPFS内`cache`フォルダだけを対象とする. PNG/HCA本体はGameServerから配信しない. アセット追加はタイトルのボタンから専用シーンへ遷移する.
- ClientとPublic API Server間はHTTP/2 over TLS 1.3 + Protocol Buffersを正とし, `SubscribeGuildBattleUpdates`はHTTP/2 Response streamを使用する. ブラウザ標準Fetch API/ReadableStreamを選定済みcrateから使用する. WebSocketはPublic API通信方式に採用しない.
- ログイン・Server未接続時はタイトルからホームへの遷移だけ許可し, 復帰後は通常の全機能を利用可能にする.
- UI Frameworkは採用しない. HCAは22,050Hz・非暗号化・一部ループ・SE最大同時5.
- 性能閾値はGPU負荷80%以下, メモリ2GB以下, FPS30以上, WASMサイズ500MB以下.
- 騎士団施設の武器庫/食糧庫/鍛冶屋の補正量, 酒場の`floor(酒場レベル / 3)`BP回復とJST 0:00回数リセット, BP50回復薬の毎日JST 0:00配布時刻は確定済み.

## 未決定事項の取扱い

未定義事項について、既存挙動を想定したDomain Logicやテスト期待値を追加しません。必要になった時点で仕様書を更新してから実装へ反映します。

## 参照資料

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
- 添付`rust_wasm_png_hca_library_selection(1).md`（2026-10-09）, 第1～7節.

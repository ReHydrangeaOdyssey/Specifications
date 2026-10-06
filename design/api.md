# API仕様

APIはPublic APIとPrivate APIに分離する. 個別メソッドの仕様は以下のファイルを正とする.

* Public APIは「[Public API仕様](public_api.md)」を参照する.
* Private APIは「[Private API仕様](private_api.md)」を参照する.
* 要求およびレスポンスのデータ構造は「[API Payload](api_payload.md)」を参照する.

## Public API

Public APIはClientまたはBotからの要求を受け付ける外部向けAPIである. SessionIDやAccessToken等の認証情報を検証し, GameServerへゲーム処理を中継する. Public APIにはレート制限を適用する.

## Private API

Private APIはGameServerからのみ利用する内部APIである. Databaseへの保存・取得を仲介し, ClientまたはBotから直接呼び出さない. Private Network内へ配置し, GameServerとの通信はmTLSを必須とする. ゲームロジック上の抽選・マッチング生成はGameServerが担当する.

## 違い

| 項目 | Public API | Private API |
|---|---|---|
| 主な呼び出し元 | Client, Bot | GameServer |
| 主な役割 | 認証, 入力受付, GameServerへの中継 | Databaseへの保存・取得 |
| 配置 | Private Network外から到達可能なAPI境界 | Private Network内. GameServerとの通信はmTLS必須 |
| Session検証 | SessionIDを使用する要求で実施する | Public APIで検証済みのGameServer要求を受ける |
| レート制限 | 適用する | Public API向けレート制限は適用しない |
| 詳細仕様 | `public_api.md` | `private_api.md` |

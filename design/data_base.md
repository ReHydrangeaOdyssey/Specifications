# データベース

PostgreSQLを使用する
各カラムの論理型およびPostgreSQL物理型への対応は「[型定義](types.md)」を参照する


## テーブル設計

### 全体共通

```mermaid
erDiagram
    PLAYER {
        PlayerID id PK
        UserName name
        Count guild_battle_win_count
        Count guild_battle_lose_count
        BP max_bp
    }

    PLAYER_SESSION {
        PlayerID player_id PK, FK
        SessionID session_id UK
        SessionExpiresAt expires_at
    }

    GUILD {
        GuildID id PK
        Name name
        PlayerID leader_player_id FK
        PlayerID subleader_player_id FK
        Count castle_level
        Count armory_level
        Count food_storage_level
        Count smithy_level
        Count strategy_office_level
        Count tavern_level
    }

    GUILD_MEMBER {
        GuildID guild_id PK, FK
        PlayerID player_id PK, FK, UK
    }

    GUILD ||--o{ GUILD_MEMBER : has
    PLAYER ||--o| GUILD_MEMBER : belongs_to
    PLAYER ||--o| PLAYER_SESSION : has

    PLAYER ||--o| GUILD : leader
    PLAYER ||--o| GUILD : subleader
```

`InvalidateSession`実行時は対象`SessionID`の`PLAYER_SESSION`レコードを削除する.

## GUILD / GUILD_MEMBER 制約

* プレイヤーの初期騎士団は`GUILD.id = PLAYER.id`となるように作成する.
* 初期騎士団作成時は`castle_level`、`armory_level`、`food_storage_level`、`smithy_level`、`strategy_office_level`、`tavern_level`をすべて1で保存する.
* 初期騎士団は、その所有プレイヤーが別の騎士団へ所属している間も`GUILD`レコードを削除しない.
* 初期騎士団の`leader_player_id`は所有プレイヤーを保持する.
* 初期騎士団については、所有プレイヤーが別の騎士団へ所属している間に限り`GUILD_MEMBER`が0件となる状態を許可する.
* `player_id`には一意制約を設定し、1つのPlayerIDが同時に複数騎士団へ所属できないようにする.
* 所属変更時は、対象PlayerIDの既存`GUILD_MEMBER`行を削除してから新しいGuildIDの行を挿入する処理を同一トランザクションで行う.
* `LeaveGuild`では新しい`GUILD`レコードを作成せず、`guild_id = player_id`の既存初期騎士団へ`GUILD_MEMBER`を戻す.

`SaveSessionID`は`player_id`を競合キーとしてUPSERTする。既存レコードが存在する場合は`session_id`と`expires_at`を更新し、存在しない場合はINSERTする。`session_id`のUNIQUE制約に衝突した場合は保存失敗としてGameServerへ返し、GameServerはSessionIDを再生成する.

```mermaid
erDiagram
    CHARACTER {
        CharacterID id PK
        Title title
        Name name
        Rarity rarity
        CharacterAttribute attribute
        HP hp
        Attack attack
        Defense defense
        SpeedRank speed_rank
        BP bp
    }

    SKILL {
        SkillID id PK
        Name name
        Description description
        EffectID effect_id
        Rate activation_rate
        CorrectionValue correction_value
    }

    ABILITY {
        AbilityID id PK
        Name name
        Description description
        EffectID effect_id
        ConditionID condition_id
        ConditionValue condition_value
        Rate activation_rate
        CorrectionValue correction_value
    }

    ABILITY_ATTRIBUTE {
        AbilityID ability_id PK, FK
        CharacterAttribute attribute PK
    }

    TACTICS {
        TacticsID id PK
        Name name
        Description description
        TacticsCategory category
        TP tp_cost
        DurationSeconds duration
        Count effect_count
    }

    TACTICS_STAGE_EFFECT {
        RecordID id PK
        TacticsID tactics_id FK
        Stage stage
        CorrectionValue effect_value
    }

    TACTICS_CORRECTION {
        RecordID id PK
        TacticsID tactics_id FK
        CorrectionID correction_id
        TacticsTarget target
        CorrectionValue correction_value
    }

    CHARACTER_SKILL {
        CharacterID character_id PK, FK
        SkillID skill_id PK, FK
        SlotIndex slot_no
    }

    CHARACTER_TACTICS {
        CharacterID character_id PK, FK
        TacticsID tactics_id PK, FK
        SlotIndex slot_no
    }

    CHARACTER_ABILITY {
        CharacterID character_id PK, FK
        AbilityID ability_id PK, FK
        SlotIndex slot_no
    }

    CHARACTER ||--o{ CHARACTER_SKILL : has
    SKILL ||--o{ CHARACTER_SKILL : assigned

    CHARACTER ||--o{ CHARACTER_TACTICS : has
    TACTICS ||--o{ CHARACTER_TACTICS : assigned

    CHARACTER ||--o{ CHARACTER_ABILITY : has
    ABILITY ||--o{ CHARACTER_ABILITY : assigned
    ABILITY ||--o{ ABILITY_ATTRIBUTE : allowed_for

    TACTICS ||--o{ TACTICS_STAGE_EFFECT : has
    TACTICS ||--o{ TACTICS_CORRECTION : has

```

`SKILL.activation_rate`は基本スキル発動率`0.2`へ加算する値とする。
`SKILL.effect_id`および`ABILITY.effect_id`は個別処理IDではなく「[型定義](types.md)」の`EffectID`で定義する効果分類とする。
同一`CorrectionID`系列の補正値はすべて加算する。


```mermaid
erDiagram
    FORMATION {
        FormationID id PK
        Name name
        Description description
    }

    FORMATION_POSITION {
        RecordID id PK
        FormationID formation_id FK
        FormationSlotID position_no
        ConditionID condition_id
        CorrectionValue attack_correction
        CorrectionValue defense_correction
        CorrectionValue speed_correction
        CorrectionValue skill_correction
    }

    FORMATION ||--o{ FORMATION_POSITION : has
```


```mermaid
erDiagram
    ITEM {
        ItemID id PK
        Name name
        Description description
        ItemType item_type
        EffectID effect_id
        CorrectionValue effect_value
    }

    PLAYER_ITEM {
        PlayerID player_id PK, FK
        ItemID item_id PK, FK
        Count quantity
    }

    PLAYER ||--o{ PLAYER_ITEM : owns
    ITEM ||--o{ PLAYER_ITEM : assigned
```


### 騎士団戦専用

```mermaid
erDiagram
    GUILD_BATTLE {
        GuildBattleID id PK
        GuildID guild_a_id FK
        GuildID guild_b_id FK
        DateTime start_at
        DateTime end_at
        Seed initial_seed
        GuildBattleStatus status
    }

    GUILD_BATTLE_RESULT {
        GuildBattleID guild_battle_id PK, FK
        GuildID guild_id PK, FK
        Score score
        GuildBattleResult result
    }

    GUILD ||--o{ GUILD_BATTLE : guild_a
    GUILD ||--o{ GUILD_BATTLE : guild_b
    GUILD_BATTLE ||--|{ GUILD_BATTLE_RESULT : has
    GUILD ||--o{ GUILD_BATTLE_RESULT : receives
```

## アリーナ

```mermaid
erDiagram
    ARENA_PARTY {
        PlayerID player_id PK, FK
        FormationID formation_id FK
    }

    ARENA_PARTY_CHARACTER {
        PlayerID player_id PK, FK
        SlotIndex slot_no PK
        CharacterID character_id FK
        FormationSlotID position
        SkillID main_skill_id FK
    }

    ARENA_PARTY_FOLLOWER {
        PlayerID player_id PK, FK
        SlotIndex party_slot_no PK
        SlotIndex follower_slot_no PK
        CharacterID follower_character_id FK
    }

    ARENA_PARTY_ABILITY {
        PlayerID player_id PK, FK
        SlotIndex party_slot_no PK
        SlotIndex ability_slot_no PK
        AbilityID ability_id FK
    }

    PLAYER ||--o| ARENA_PARTY : has
    ARENA_PARTY ||--o{ ARENA_PARTY_CHARACTER : contains
    ARENA_PARTY_CHARACTER ||--o{ ARENA_PARTY_FOLLOWER : has
    ARENA_PARTY_CHARACTER ||--o{ ARENA_PARTY_ABILITY : has
```

`SaveArenaParty`は対象PlayerIDのアリーナ編成を上記テーブルへ保存する。既存編成がある場合は同一PlayerIDの編成を置換する。

## 騎士団戦編成

```mermaid
erDiagram
    GUILD_BATTLE_PARTY {
        PlayerID player_id PK, FK
        FormationID formation_id FK
    }

    GUILD_BATTLE_PARTY_CHARACTER {
        PlayerID player_id PK, FK
        SlotIndex slot_no PK
        CharacterID character_id FK
        FormationSlotID priority_position
        SkillID main_skill_id FK
    }

    GUILD_BATTLE_PARTY_FOLLOWER {
        PlayerID player_id PK, FK
        SlotIndex party_slot_no PK
        SlotIndex follower_slot_no PK
        CharacterID follower_character_id FK
    }

    GUILD_BATTLE_PARTY_ABILITY {
        PlayerID player_id PK, FK
        SlotIndex party_slot_no PK
        SlotIndex ability_slot_no PK
        AbilityID ability_id FK
    }

    PLAYER ||--o| GUILD_BATTLE_PARTY : has
    GUILD_BATTLE_PARTY ||--o{ GUILD_BATTLE_PARTY_CHARACTER : contains
    GUILD_BATTLE_PARTY_CHARACTER ||--o{ GUILD_BATTLE_PARTY_FOLLOWER : has
    GUILD_BATTLE_PARTY_CHARACTER ||--o{ GUILD_BATTLE_PARTY_ABILITY : has
```

`SaveGuildBattleParty`は対象PlayerIDの騎士団戦編成を上記テーブルへ保存する。既存編成がある場合は同一PlayerIDの編成を置換する。

## ログ

```mermaid
erDiagram
    GUILD_BATTLE_REPLAY_LOG {
        RecordID id PK
        GuildBattleID guild_battle_id FK
        GameServerTime time
        GuildBattleReplayProcessType process_type
        BinaryData payload
    }

    ERROR_LOG {
        RecordID id PK
        GuildBattleID guild_battle_id FK
        GameServerTime time
        ErrorLogMessage message
    }

    GUILD_BATTLE ||--o{ GUILD_BATTLE_REPLAY_LOG : has
    GUILD_BATTLE ||--o{ ERROR_LOG : has_error
```

`GUILD_BATTLE_REPLAY_LOG.payload`には、リプレイログファイルへ書き込むものと同じ処理種別対応構造体のバイナリデータを保存する。

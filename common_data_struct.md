# 共通データ構造

## プレイヤー関連

```proto
syntax = "proto3";

message Player {
  uint64 id = 1;
  string name = 2;
  uint64 guild_id = 3;
}
```

## キャラクター関連

```proto
syntax = "proto3";

enum Rarity {
  RARITY_N = 0;
  RARITY_R = 1;
  RARITY_SR = 2;
  RARITY_SSR = 3;
  RARITY_UR = 4;
}

enum CharacterAttribute {
  CHARACTER_ATTRIBUTE_SLASH = 0;
  CHARACTER_ATTRIBUTE_PIERCE = 1;
  CHARACTER_ATTRIBUTE_STRIKE = 2;
  CHARACTER_ATTRIBUTE_RANGED = 3;
}

enum SpeedRank {
  SPEED_RANK_SS9 = 0;
  SPEED_RANK_SS8 = 1;
  SPEED_RANK_SS7 = 2;
  SPEED_RANK_SS6 = 3;
  SPEED_RANK_SS5 = 4;
  SPEED_RANK_SS4 = 5;
  SPEED_RANK_SS3 = 6;
  SPEED_RANK_SS2 = 7;
  SPEED_RANK_SS1 = 8;
  SPEED_RANK_SS_PLUS = 9;
  SPEED_RANK_SS = 10;
  SPEED_RANK_SS_MINUS = 11;
  SPEED_RANK_S_PLUS = 12;
  SPEED_RANK_S = 13;
  SPEED_RANK_S_MINUS = 14;
  SPEED_RANK_A_PLUS = 15;
  SPEED_RANK_A = 16;
  SPEED_RANK_A_MINUS = 17;
  SPEED_RANK_B_PLUS = 18;
  SPEED_RANK_B = 19;
  SPEED_RANK_B_MINUS = 20;
  SPEED_RANK_C_PLUS = 21;
  SPEED_RANK_C = 22;
  SPEED_RANK_C_MINUS = 23;
  SPEED_RANK_D_PLUS = 24;
  SPEED_RANK_D = 25;
  SPEED_RANK_D_MINUS = 26;
  SPEED_RANK_E_PLUS = 27;
  SPEED_RANK_E = 28;
  SPEED_RANK_E_MINUS = 29;
  SPEED_RANK_F_PLUS = 30;
  SPEED_RANK_F = 31;
  SPEED_RANK_F_MINUS = 32;
}

message CharacterMasterData {
  uint64 id = 1;
  string name = 2;
  Rarity rarity = 3;
  CharacterAttribute attribute = 4;
  uint32 hp = 5;
  uint32 attack = 6;
  uint32 defense = 7;
  SpeedRank speed = 8;
  uint32 bp = 9;
}

message HitPoints {
  uint32 max_hp = 1;
  uint32 current_hp = 2;
}

```


```
message TacticsEffect {
  uint32 available_uses = 1;
  uint32 tp_cost = 2;
}


message TacticsBattleState {
  uint32 available_uses = 1;
  uint32 tp_cost = 2;
}
```
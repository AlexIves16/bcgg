enum ObjectType {
  tree,
  plant,
  ore,
  rock,
  water,
  structure,
  animal,
  artifact,
  empty
}

enum GameObjectType {
  oak_001,
  oak_002,
  pine_001,
  palm_001,
  wheat_001,
  berryBush_001,
  grass_001,
  iron_001,
  copper_001,
  gold_001,
  smallRock_001,
  largeRock_001,
  shallow_001, deep_001,
  house_001,
  fence_001,
  ruins_001,
  deer_001,
  wolf_001,
  rabbit_001,
  ancientRelic_001,
  magicCrystal_001,
  cactus_001,
  mangrove_001,
  reed_001,
  rareOre_001,
  fish_001,
  kelp_001
}

extension GameObjectTypeExtension on GameObjectType {
  String get id {
    switch (this) {
      case GameObjectType.oak_001: return 'oak-001';
      case GameObjectType.oak_002: return 'oak-002';
      case GameObjectType.pine_001: return 'pine-001';
      case GameObjectType.palm_001: return 'palm-001';
      case GameObjectType.wheat_001: return 'wheat-001';
      case GameObjectType.berryBush_001: return 'berry-bush-001';
      case GameObjectType.grass_001: return 'grass-001';
      case GameObjectType.iron_001: return 'iron-001';
      case GameObjectType.copper_001: return 'copper-001';
      case GameObjectType.gold_001: return 'gold-001';
      case GameObjectType.smallRock_001: return 'small-rock-001';
      case GameObjectType.largeRock_001: return 'large-rock-001';
      case GameObjectType.shallow_001: return 'shallow-001';
      case GameObjectType.deep_001: return 'deep-001';
      case GameObjectType.house_001: return 'house-001';
      case GameObjectType.fence_001: return 'fence-001';
      case GameObjectType.ruins_001: return 'ruins-001';
      case GameObjectType.deer_001: return 'deer-001';
      case GameObjectType.wolf_001: return 'wolf-001';
      case GameObjectType.rabbit_001: return 'rabbit-001';
      case GameObjectType.ancientRelic_001: return 'ancient-relic-001';
      case GameObjectType.magicCrystal_001: return 'magic-crystal-001';
      case GameObjectType.cactus_001: return 'cactus-001';
      case GameObjectType.mangrove_001: return 'mangrove-001';
      case GameObjectType.reed_001: return 'reed-001';
      case GameObjectType.rareOre_001: return 'rare-ore-001';
      case GameObjectType.fish_001: return 'fish-001';
      case GameObjectType.kelp_001: return 'kelp-001';
    }
  }

  String get emoji {
    switch (this) {
      case GameObjectType.oak_001:
      case GameObjectType.oak_002:
      case GameObjectType.pine_001:
      case GameObjectType.palm_001: return '🌳';
      case GameObjectType.wheat_001:
      case GameObjectType.grass_001:
      case GameObjectType.reed_001: return '🌾';
      case GameObjectType.berryBush_001: return '🫐';
      case GameObjectType.iron_001:
      case GameObjectType.copper_001:
      case GameObjectType.gold_001:
      case GameObjectType.rareOre_001: return '💎';
      case GameObjectType.smallRock_001:
      case GameObjectType.largeRock_001: return '🪨';
      case GameObjectType.shallow_001:
      case GameObjectType.deep_001: return '💧';
      case GameObjectType.house_001: return '🏠';
      case GameObjectType.fence_001: return '🚧';
      case GameObjectType.ruins_001: return '🏛️';
      case GameObjectType.deer_001: return '🦌';
      case GameObjectType.wolf_001: return '🐺';
      case GameObjectType.rabbit_001: return '🐇';
      case GameObjectType.ancientRelic_001: return '🏺';
      case GameObjectType.magicCrystal_001: return '🔮';
      case GameObjectType.cactus_001: return '🌵';
      case GameObjectType.mangrove_001: return '🌳';
      case GameObjectType.fish_001: return '🐟';
      case GameObjectType.kelp_001: return '🌿';
    }
  }
}

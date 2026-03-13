export enum GameObjectType {
  oak_001 = 'oak-001',
  oak_002 = 'oak-002',
  pine_001 = 'pine-001',
  palm_001 = 'palm-001',
  wheat_001 = 'wheat-001',
  berryBush_001 = 'berry-bush-001',
  grass_001 = 'grass-001',
  iron_001 = 'iron-001',
  copper_001 = 'copper-001',
  gold_001 = 'gold-001',
  smallRock_001 = 'small-rock-001',
  largeRock_001 = 'large-rock-001',
  shallow_001 = 'shallow-001',
  deep_001 = 'deep-001',
  house_001 = 'house-001',
  fence_001 = 'fence-001',
  ruins_001 = 'ruins-001',
  deer_001 = 'deer-001',
  wolf_001 = 'wolf-001',
  rabbit_001 = 'rabbit-001',
  ancientRelic_001 = 'ancient-relic-001',
  magicCrystal_001 = 'magic-crystal-001',
  cactus_001 = 'cactus-001',
  mangrove_001 = 'mangrove-001',
  reed_001 = 'reed-001',
  rareOre_001 = 'rare-ore-001',
  fish_001 = 'fish-001',
  kelp_001 = 'kelp-001',
  wild_bug = 'wild-bug',
  banshee = 'banshee',
  siren = 'siren',
  golem = 'golem',
  wraith = 'wraith',
  elemental = 'elemental',
  loot_bundle = 'loot-bundle',
  wall_wood = 'wall-wood',
  torch_ether = 'torch-ether',
  workbench = 'workbench',
  axe_wood = 'axe-wood',
  pickaxe_wood = 'pickaxe-wood'
}

export enum ObjectType {
  tree = 'tree',
  plant = 'plant',
  ore = 'ore',
  rock = 'rock',
  water = 'water',
  structure = 'structure',
  animal = 'animal',
  artifact = 'artifact',
  monster = 'monster',
  base = 'base',
  loot = 'loot',
  building = 'building',
  empty = 'empty'
}

export enum ResourceType {
  wood = 'wood',
  fiber = 'fiber',
  metal = 'metal',
  stone = 'stone',
  water = 'water',
  material = 'material',
  meat = 'meat',
  magic = 'magic',
  essence = 'essence',
  shard = 'shard'
}

export enum ItemType {
  RESOURCE = 'resource',
  EQUIPMENT = 'equipment',
  CONSUMABLE = 'consumable',
  TROPHY = 'trophy'
}

export enum BiomeType {
  B_OCEAN = 'B_OCEAN',
  B_COAST = 'B_COAST', // Побережье
  B_TUNDRA = 'B_TUNDRA',
  B_FOREST = 'B_FOREST',
  B_DESERT = 'B_DESERT',
  B_JUNGLE = 'B_JUNGLE',
  B_SWAMP = 'B_SWAMP',
  B_PLAINS = 'B_PLAINS',
  B_HILLS = 'B_HILLS',
  B_MOUNTAINS = 'B_MOUNTAINS',
}

export enum TerrainName {
  T_DEEP_WATER = 'T_DEEP_WATER',
  T_SHALLOW_WATER = 'T_SHALLOW_WATER',
  T_PLAIN = 'T_PLAINS',
  T_HILL = 'T_HILLS',
  T_MOUNTAIN = 'T_MOUNTAIN',
  T_SWAMP = 'T_SWAMP',
  T_ISLAND = 'T_ISLAND',
  T_FOREST = 'T_FOREST',
  T_ICE = 'T_ICE',
  T_VOLCANO = 'T_VOLCANO',
  T_SAND = 'T_SAND',
  T_ROCK = 'T_ROCK',
  T_CAVE = 'T_CAVE',
}

export enum MonsterRank {
  NORMAL = 'normal',
  STRONG = 'strong',
  ANCIENT = 'ancient',
  EPIC = 'epic',
  LEGENDARY = 'legendary'
}

export enum AttackType {
  PROXIMITY_AURA = 'proximity_aura',
  PROJECTILE = 'projectile',
  GAZE = 'gaze',
  BURST = 'burst'
}

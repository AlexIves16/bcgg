import { BiomeType, TerrainName } from './enums';
export const BIOMES = {
    [BiomeType.B_OCEAN]: {
        name: BiomeType.B_OCEAN,
        tempRange: [0, 50],
        moistureRange: [50, 100],
        terrainTypes: [
            TerrainName.T_DEEP_WATER,
            TerrainName.T_SHALLOW_WATER,
            TerrainName.T_ISLAND,
            TerrainName.T_ICE,
            TerrainName.T_VOLCANO,
            TerrainName.T_ROCK
        ],
    },
    [BiomeType.B_COAST]: {
        name: BiomeType.B_COAST,
        tempRange: [0, 50],
        moistureRange: [40, 100],
        terrainTypes: [
            TerrainName.T_SAND,
            TerrainName.T_ROCK,
            TerrainName.T_PLAIN,
            TerrainName.T_CAVE,
            TerrainName.T_SHALLOW_WATER,
            TerrainName.T_SWAMP,
            TerrainName.T_FOREST,
            TerrainName.T_VOLCANO
        ],
    },
    [BiomeType.B_TUNDRA]: {
        name: BiomeType.B_TUNDRA,
        tempRange: [-50, 0],
        moistureRange: [0, 50],
        terrainTypes: [
            TerrainName.T_PLAIN,
            TerrainName.T_ICE,
            TerrainName.T_FOREST,
            TerrainName.T_MOUNTAIN,
            TerrainName.T_HILL,
            TerrainName.T_VOLCANO,
            TerrainName.T_SWAMP,
            TerrainName.T_ROCK,
            TerrainName.T_CAVE
        ],
    },
    [BiomeType.B_FOREST]: {
        name: BiomeType.B_FOREST,
        tempRange: [-20, 40],
        moistureRange: [20, 80],
        terrainTypes: [
            TerrainName.T_FOREST,
            TerrainName.T_PLAIN,
            TerrainName.T_HILL,
            TerrainName.T_SHALLOW_WATER,
            TerrainName.T_SWAMP,
            TerrainName.T_MOUNTAIN,
            TerrainName.T_VOLCANO,
            TerrainName.T_ROCK,
            TerrainName.T_CAVE,
            TerrainName.T_VOLCANO
        ],
    },
    [BiomeType.B_DESERT]: {
        name: BiomeType.B_DESERT,
        tempRange: [10, 60],
        moistureRange: [0, 20],
        terrainTypes: [
            TerrainName.T_SAND,
            TerrainName.T_HILL,
            TerrainName.T_PLAIN,
            TerrainName.T_SHALLOW_WATER,
            TerrainName.T_ROCK,
            TerrainName.T_CAVE,
            TerrainName.T_MOUNTAIN,
        ],
    },
    [BiomeType.B_JUNGLE]: {
        name: BiomeType.B_JUNGLE,
        tempRange: [10, 40],
        moistureRange: [60, 100],
        terrainTypes: [
            TerrainName.T_FOREST,
            TerrainName.T_SHALLOW_WATER,
            TerrainName.T_SWAMP,
            TerrainName.T_HILL,
            TerrainName.T_MOUNTAIN,
            TerrainName.T_SAND,
            TerrainName.T_VOLCANO,
            TerrainName.T_ROCK,
            TerrainName.T_CAVE
        ],
    },
    [BiomeType.B_SWAMP]: {
        name: BiomeType.B_SWAMP,
        tempRange: [0, 40],
        moistureRange: [60, 80],
        terrainTypes: [
            TerrainName.T_SWAMP,
            TerrainName.T_FOREST,
            TerrainName.T_PLAIN,
            TerrainName.T_SHALLOW_WATER,
            TerrainName.T_SAND,
            TerrainName.T_ROCK,
            TerrainName.T_CAVE
        ],
    },
    [BiomeType.B_PLAINS]: {
        name: BiomeType.B_PLAINS,
        tempRange: [-10, 50],
        moistureRange: [0, 70],
        terrainTypes: [
            TerrainName.T_PLAIN,
            TerrainName.T_HILL,
            TerrainName.T_FOREST,
            TerrainName.T_SWAMP,
            TerrainName.T_ROCK,
            TerrainName.T_CAVE,
            TerrainName.T_SHALLOW_WATER,
            TerrainName.T_VOLCANO
        ],
    },
    [BiomeType.B_HILLS]: {
        name: BiomeType.B_HILLS,
        tempRange: [-30, 60],
        moistureRange: [20, 80],
        terrainTypes: [
            TerrainName.T_HILL,
            TerrainName.T_PLAIN,
            TerrainName.T_MOUNTAIN,
            TerrainName.T_SWAMP,
            TerrainName.T_ROCK,
            TerrainName.T_CAVE,
            TerrainName.T_SHALLOW_WATER,
            TerrainName.T_FOREST,
            TerrainName.T_VOLCANO,
        ],
    },
    [BiomeType.B_MOUNTAINS]: {
        name: BiomeType.B_MOUNTAINS,
        tempRange: [-50, 40],
        moistureRange: [0, 60],
        terrainTypes: [
            TerrainName.T_MOUNTAIN,
            TerrainName.T_HILL,
            TerrainName.T_ROCK,
            TerrainName.T_VOLCANO,
            TerrainName.T_CAVE,
            TerrainName.T_SHALLOW_WATER,
            TerrainName.T_FOREST,
            TerrainName.T_ICE
        ],
    },
};
//# sourceMappingURL=Biomes.js.map
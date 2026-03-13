import { ObjectType, TerrainName, BiomeType } from './enums';
export const TERRAIN_TYPES = {
    [TerrainName.T_DEEP_WATER]: { min: -1, max: -0.4, name: TerrainName.T_DEEP_WATER },
    [TerrainName.T_SHALLOW_WATER]: { min: -0.4, max: -0.2, name: TerrainName.T_SHALLOW_WATER },
    [TerrainName.T_SAND]: { min: -0.2, max: 0.1, name: TerrainName.T_SAND },
    [TerrainName.T_PLAIN]: { min: 0.1, max: 0.3, name: TerrainName.T_PLAIN },
    [TerrainName.T_FOREST]: { min: 0.3, max: 0.4, name: TerrainName.T_FOREST },
    [TerrainName.T_HILL]: { min: 0.4, max: 0.6, name: TerrainName.T_HILL },
    [TerrainName.T_MOUNTAIN]: { min: 0.6, max: 1, name: TerrainName.T_MOUNTAIN },
    [TerrainName.T_SWAMP]: { min: -0.3, max: 0.1, name: TerrainName.T_SWAMP },
    [TerrainName.T_ICE]: { min: -0.1, max: 0.1, name: TerrainName.T_ICE },
    [TerrainName.T_ISLAND]: { min: -0.1, max: 0.1, name: TerrainName.T_ISLAND },
    [TerrainName.T_VOLCANO]: { min: 0.7, max: 1, name: TerrainName.T_VOLCANO },
    [TerrainName.T_ROCK]: { min: 0.5, max: 0.8, name: TerrainName.T_ROCK },
    [TerrainName.T_CAVE]: { min: -1, max: 1, name: TerrainName.T_CAVE }
};
export const TERRAINS = {
    [TerrainName.T_DEEP_WATER]: {
        type: TERRAIN_TYPES[TerrainName.T_DEEP_WATER],
        allowedObjects: (biome, objectTypes) => {
            if (biome.name === BiomeType.B_OCEAN)
                return [ObjectType.water, ObjectType.animal];
            return [];
        },
    },
    [TerrainName.T_SHALLOW_WATER]: {
        type: TERRAIN_TYPES[TerrainName.T_SHALLOW_WATER],
        allowedObjects: (biome, objectTypes) => {
            if (biome.name === BiomeType.B_OCEAN)
                return [ObjectType.water, ObjectType.animal];
            if (biome.name === BiomeType.B_COAST)
                return [ObjectType.water, ObjectType.animal, ObjectType.plant];
            return [];
        },
    },
    [TerrainName.T_SAND]: {
        type: TERRAIN_TYPES[TerrainName.T_SAND],
        allowedObjects: (biome, objectTypes) => {
            if (biome.name === BiomeType.B_COAST)
                return [ObjectType.plant, ObjectType.rock, ObjectType.animal, ObjectType.structure];
            if (biome.name === BiomeType.B_DESERT)
                return [ObjectType.plant, ObjectType.rock, ObjectType.animal, ObjectType.structure, ObjectType.artifact];
            return [];
        },
    },
    [TerrainName.T_PLAIN]: {
        type: TERRAIN_TYPES[TerrainName.T_PLAIN],
        allowedObjects: (biome, objectTypes) => {
            if (biome.name === BiomeType.B_TUNDRA)
                return [ObjectType.tree, ObjectType.plant, ObjectType.rock, ObjectType.animal, ObjectType.structure, ObjectType.artifact];
            if (biome.name === BiomeType.B_FOREST)
                return [ObjectType.tree, ObjectType.plant, ObjectType.rock, ObjectType.animal, ObjectType.structure, ObjectType.artifact];
            if (biome.name === BiomeType.B_DESERT)
                return [ObjectType.plant, ObjectType.rock, ObjectType.animal, ObjectType.structure, ObjectType.artifact];
            if (biome.name === BiomeType.B_COAST)
                return [ObjectType.plant, ObjectType.rock, ObjectType.animal, ObjectType.structure, ObjectType.artifact];
            if (biome.name === BiomeType.B_JUNGLE)
                return [ObjectType.plant, ObjectType.rock, ObjectType.animal, ObjectType.structure, ObjectType.artifact];
            if (biome.name === BiomeType.B_SWAMP)
                return [ObjectType.plant, ObjectType.rock, ObjectType.animal, ObjectType.structure, ObjectType.artifact];
            if (biome.name === BiomeType.B_PLAINS)
                return [ObjectType.tree, ObjectType.plant, ObjectType.rock, ObjectType.animal, ObjectType.structure, ObjectType.artifact];
            return [ObjectType.tree, ObjectType.plant, ObjectType.rock, ObjectType.animal, ObjectType.structure, ObjectType.artifact];
        },
    },
    [TerrainName.T_FOREST]: {
        type: TERRAIN_TYPES[TerrainName.T_FOREST],
        allowedObjects: (biome, objectTypes) => {
            if (biome.name === BiomeType.B_FOREST)
                return [ObjectType.tree, ObjectType.plant, ObjectType.animal, ObjectType.rock, ObjectType.artifact, ObjectType.structure];
            if (biome.name === BiomeType.B_JUNGLE)
                return [ObjectType.tree, ObjectType.plant, ObjectType.animal, ObjectType.rock, ObjectType.artifact, ObjectType.structure];
            if (biome.name === BiomeType.B_SWAMP)
                return [ObjectType.tree, ObjectType.plant, ObjectType.animal, ObjectType.rock, ObjectType.artifact, ObjectType.structure];
            if (biome.name === BiomeType.B_PLAINS)
                return [ObjectType.tree, ObjectType.plant, ObjectType.animal, ObjectType.rock, ObjectType.artifact, ObjectType.structure];
            return [];
        },
    },
    [TerrainName.T_HILL]: {
        type: TERRAIN_TYPES[TerrainName.T_HILL],
        allowedObjects: (biome, objectTypes) => {
            if (biome.name === BiomeType.B_TUNDRA)
                return [ObjectType.tree, ObjectType.plant, ObjectType.rock, ObjectType.ore, ObjectType.animal, ObjectType.artifact];
            if (biome.name === BiomeType.B_FOREST)
                return [ObjectType.tree, ObjectType.plant, ObjectType.rock, ObjectType.ore, ObjectType.animal, ObjectType.artifact];
            if (biome.name === BiomeType.B_DESERT)
                return [ObjectType.plant, ObjectType.rock, ObjectType.ore, ObjectType.animal, ObjectType.artifact];
            if (biome.name === BiomeType.B_COAST)
                return [ObjectType.plant, ObjectType.rock, ObjectType.ore, ObjectType.animal, ObjectType.artifact];
            if (biome.name === BiomeType.B_JUNGLE)
                return [ObjectType.plant, ObjectType.tree, ObjectType.rock, ObjectType.ore, ObjectType.animal, ObjectType.artifact];
            if (biome.name === BiomeType.B_SWAMP)
                return [ObjectType.plant, ObjectType.rock, ObjectType.ore, ObjectType.animal, ObjectType.artifact];
            if (biome.name === BiomeType.B_PLAINS)
                return [ObjectType.tree, ObjectType.plant, ObjectType.rock, ObjectType.ore, ObjectType.animal, ObjectType.artifact];
            if (biome.name === BiomeType.B_HILLS)
                return [ObjectType.tree, ObjectType.plant, ObjectType.rock, ObjectType.ore, ObjectType.animal, ObjectType.artifact];
            return [ObjectType.tree, ObjectType.plant, ObjectType.rock, ObjectType.ore, ObjectType.animal, ObjectType.artifact];
        },
    },
    [TerrainName.T_SWAMP]: {
        type: TERRAIN_TYPES[TerrainName.T_SWAMP],
        allowedObjects: (biome, objectTypes) => {
            if (biome.name === BiomeType.B_SWAMP)
                return [ObjectType.tree, ObjectType.plant, ObjectType.animal, ObjectType.rock, ObjectType.water, ObjectType.artifact];
            return [];
        },
    },
    [TerrainName.T_ICE]: {
        type: TERRAIN_TYPES[TerrainName.T_ICE],
        allowedObjects: (biome, objectTypes) => {
            if (biome.name === BiomeType.B_TUNDRA)
                return [ObjectType.plant, ObjectType.rock, ObjectType.animal, ObjectType.artifact];
            if (biome.name === BiomeType.B_OCEAN)
                return [ObjectType.plant, ObjectType.rock, ObjectType.animal, ObjectType.artifact];
            if (biome.name === BiomeType.B_MOUNTAINS)
                return [ObjectType.plant, ObjectType.rock, ObjectType.animal, ObjectType.artifact];
            return [];
        },
    },
    [TerrainName.T_MOUNTAIN]: {
        type: TERRAIN_TYPES[TerrainName.T_MOUNTAIN],
        allowedObjects: (biome, objectTypes) => {
            if (biome.name === BiomeType.B_MOUNTAINS)
                return [ObjectType.ore, ObjectType.rock, ObjectType.animal, ObjectType.artifact];
            return [];
        },
    },
    [TerrainName.T_ROCK]: {
        type: TERRAIN_TYPES[TerrainName.T_ROCK],
        allowedObjects: (biome, objectTypes) => {
            return [ObjectType.rock, ObjectType.ore, ObjectType.animal, ObjectType.plant, ObjectType.artifact];
        },
    },
    [TerrainName.T_CAVE]: {
        type: TERRAIN_TYPES[TerrainName.T_CAVE],
        allowedObjects: (biome, objectTypes) => {
            return [ObjectType.rock, ObjectType.ore, ObjectType.animal, ObjectType.artifact];
        },
    },
    [TerrainName.T_ISLAND]: {
        type: TERRAIN_TYPES[TerrainName.T_ISLAND],
        allowedObjects: (biome, objectTypes) => {
            return [ObjectType.rock, ObjectType.plant, ObjectType.animal, ObjectType.tree, ObjectType.artifact];
        },
    },
    [TerrainName.T_VOLCANO]: {
        type: TERRAIN_TYPES[TerrainName.T_VOLCANO],
        allowedObjects: (biome, objectTypes) => {
            return [ObjectType.rock, ObjectType.ore, ObjectType.animal, ObjectType.artifact];
        },
    },
};
//# sourceMappingURL=Terrains.js.map
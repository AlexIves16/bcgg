import { ObjectType, TerrainName, BiomeType } from './enums';
import { OVHC, OHC, OMC, OLC, OVLC, OVVLC } from './GenerationChances';
export class TerrainRules {
    rules = [];
    addRule(rule) {
        this.rules.push(rule);
    }
    getAllowedObjects(terrainName) {
        const rule = this.rules.find((r) => r.terrainName === terrainName);
        return rule?.allowedObjects || [];
    }
    generateObjectForTerrain(biome, terrain) {
        const rule = this.rules.find((r) => r.terrainName === terrain);
        if (!rule)
            return null;
        const objectType = rule.generateObject(biome, terrain); // Получаем ObjectType
        if (objectType) {
            return objectType;
        }
        return null;
    }
}
// Правило для глубокой воды
const deepWaterRule = {
    terrainName: TerrainName.T_DEEP_WATER,
    allowedObjects: [ObjectType.water, ObjectType.animal],
    generateObject: (biome, terrain) => {
        const roll = Math.random();
        if (roll < OHC)
            return ObjectType.water;
        if (roll < OMC)
            return ObjectType.animal;
        return null;
    },
};
// Правило для мелкой воды
const shallowWaterRule = {
    terrainName: TerrainName.T_SHALLOW_WATER,
    allowedObjects: [ObjectType.water, ObjectType.animal, ObjectType.plant],
    generateObject: (biome, terrain) => {
        const roll = Math.random();
        if (roll < OVHC)
            return ObjectType.water;
        if (roll < OMC)
            return ObjectType.animal;
        if (roll < OLC)
            return ObjectType.plant;
        return null;
    },
};
// Правило для песка
const sandRule = {
    terrainName: TerrainName.T_SAND,
    allowedObjects: [ObjectType.plant, ObjectType.rock, ObjectType.animal, ObjectType.structure],
    generateObject: (biome, terrain) => {
        const roll = Math.random();
        if (roll < OMC)
            return ObjectType.plant;
        if (roll < OLC)
            return ObjectType.rock;
        if (roll < OVLC)
            return ObjectType.animal;
        if (roll < OVLC)
            return ObjectType.structure;
        return null;
    },
};
// Правило для равнин
const plainsRule = {
    terrainName: TerrainName.T_PLAIN,
    allowedObjects: [ObjectType.tree, ObjectType.plant, ObjectType.rock, ObjectType.animal, ObjectType.structure, ObjectType.artifact],
    generateObject: (biome, terrain) => {
        const roll = Math.random();
        if (biome.name === BiomeType.B_TUNDRA) {
            if (roll < OHC)
                return ObjectType.plant;
            if (roll < OMC)
                return ObjectType.rock;
            if (roll < OLC)
                return ObjectType.tree;
            if (roll < OVLC)
                return ObjectType.animal;
            if (roll < OVLC)
                return ObjectType.structure;
        }
        if (biome.name === BiomeType.B_FOREST) {
            if (roll < OMC)
                return ObjectType.tree;
            if (roll < OLC)
                return ObjectType.plant;
            if (roll < OVLC)
                return ObjectType.rock;
            if (roll < OVLC)
                return ObjectType.animal;
            if (roll < OVLC)
                return ObjectType.structure;
        }
        if (biome.name === BiomeType.B_DESERT) {
            if (roll < OMC)
                return ObjectType.plant;
            if (roll < OLC)
                return ObjectType.rock;
            if (roll < OVLC)
                return ObjectType.animal;
            if (roll < OVLC)
                return ObjectType.structure;
        }
        if (biome.name === BiomeType.B_COAST) {
            if (roll < OMC)
                return ObjectType.plant;
            if (roll < OLC)
                return ObjectType.rock;
            if (roll < OVLC)
                return ObjectType.animal;
            if (roll < OVLC)
                return ObjectType.structure;
        }
        if (biome.name === BiomeType.B_JUNGLE) {
            if (roll < OMC)
                return ObjectType.plant;
            if (roll < OLC)
                return ObjectType.tree;
            if (roll < OVLC)
                return ObjectType.animal;
            if (roll < OVLC)
                return ObjectType.structure;
        }
        if (biome.name === BiomeType.B_SWAMP) {
            if (roll < OMC)
                return ObjectType.plant;
            if (roll < OLC)
                return ObjectType.rock;
            if (roll < OVLC)
                return ObjectType.animal;
            if (roll < OVLC)
                return ObjectType.structure;
        }
        if (biome.name === BiomeType.B_PLAINS) {
            if (roll < OHC)
                return ObjectType.plant;
            if (roll < OMC)
                return ObjectType.rock;
            if (roll < OLC)
                return ObjectType.tree;
            if (roll < OVLC)
                return ObjectType.animal;
            if (roll < OVLC)
                return ObjectType.structure;
        }
        if (roll < OVVLC)
            return ObjectType.artifact;
        return null;
    },
};
// Правило для леса
const forestRule = {
    terrainName: TerrainName.T_FOREST,
    allowedObjects: [ObjectType.tree, ObjectType.plant, ObjectType.animal, ObjectType.rock, ObjectType.artifact, ObjectType.structure],
    generateObject: (biome, terrain) => {
        const roll = Math.random();
        if (roll < OHC)
            return ObjectType.tree;
        if (roll < OMC)
            return ObjectType.plant;
        if (roll < OLC)
            return ObjectType.animal;
        if (roll < OVLC)
            return ObjectType.rock;
        if (roll < OVLC)
            return ObjectType.artifact;
        return null;
    },
};
// Правило для холмов
const hillsRule = {
    terrainName: TerrainName.T_HILL,
    allowedObjects: [ObjectType.tree, ObjectType.plant, ObjectType.rock, ObjectType.ore, ObjectType.animal, ObjectType.artifact],
    generateObject: (biome, terrain) => {
        const roll = Math.random();
        if (biome.name === BiomeType.B_TUNDRA) {
            if (roll < OHC)
                return ObjectType.plant;
            if (roll < OMC)
                return ObjectType.rock;
            if (roll < OLC)
                return ObjectType.tree;
            if (roll < OVLC)
                return ObjectType.animal;
            if (roll < OVLC)
                return ObjectType.structure;
        }
        if (biome.name === BiomeType.B_FOREST) {
            if (roll < OMC)
                return ObjectType.tree;
            if (roll < OLC)
                return ObjectType.plant;
            if (roll < OVLC)
                return ObjectType.rock;
            if (roll < OVLC)
                return ObjectType.animal;
            if (roll < OVLC)
                return ObjectType.structure;
        }
        if (biome.name === BiomeType.B_DESERT) {
            if (roll < OMC)
                return ObjectType.plant;
            if (roll < OLC)
                return ObjectType.rock;
            if (roll < OVLC)
                return ObjectType.animal;
            if (roll < OVLC)
                return ObjectType.structure;
        }
        if (biome.name === BiomeType.B_COAST) {
            if (roll < OMC)
                return ObjectType.plant;
            if (roll < OLC)
                return ObjectType.rock;
            if (roll < OVLC)
                return ObjectType.animal;
            if (roll < OVLC)
                return ObjectType.structure;
        }
        if (biome.name === BiomeType.B_JUNGLE) {
            if (roll < OMC)
                return ObjectType.plant;
            if (roll < OLC)
                return ObjectType.tree;
            if (roll < OVLC)
                return ObjectType.animal;
            if (roll < OVLC)
                return ObjectType.structure;
        }
        if (biome.name === BiomeType.B_SWAMP) {
            if (roll < OMC)
                return ObjectType.plant;
            if (roll < OLC)
                return ObjectType.rock;
            if (roll < OVLC)
                return ObjectType.animal;
            if (roll < OVLC)
                return ObjectType.structure;
        }
        if (biome.name === BiomeType.B_PLAINS) {
            if (roll < OHC)
                return ObjectType.plant;
            if (roll < OMC)
                return ObjectType.rock;
            if (roll < OLC)
                return ObjectType.tree;
            if (roll < OVLC)
                return ObjectType.animal;
            if (roll < OVLC)
                return ObjectType.structure;
        }
        if (roll < OVVLC)
            return ObjectType.artifact;
        return null;
    },
};
// Правило для болот
const swampRule = {
    terrainName: TerrainName.T_SWAMP,
    allowedObjects: [ObjectType.tree, ObjectType.plant, ObjectType.animal, ObjectType.rock, ObjectType.water],
    generateObject: (biome, terrain) => {
        const roll = Math.random();
        if (roll < OHC)
            return ObjectType.tree;
        if (roll < OMC)
            return ObjectType.plant;
        return null;
    },
};
// Правило для льда
const iceRule = {
    terrainName: TerrainName.T_ICE,
    allowedObjects: [ObjectType.rock, ObjectType.animal, ObjectType.artifact],
    generateObject: (biome, terrain) => {
        const roll = Math.random();
        if (roll < OMC)
            return ObjectType.animal;
        if (roll < OLC)
            return ObjectType.rock;
        if (roll < OVLC)
            return ObjectType.artifact;
        return null;
    },
};
// Правило для гор
const mountainsRule = {
    terrainName: TerrainName.T_MOUNTAIN,
    allowedObjects: [ObjectType.ore, ObjectType.rock, ObjectType.animal, ObjectType.artifact],
    generateObject: (biome, terrain) => {
        const roll = Math.random();
        if (roll < OHC)
            return ObjectType.ore;
        if (roll < OMC)
            return ObjectType.rock;
        if (roll < OVLC)
            return ObjectType.artifact;
        if (roll < OVVLC)
            return ObjectType.artifact;
        return null;
    },
};
// Правило для скалы
const rockRule = {
    terrainName: TerrainName.T_ROCK,
    allowedObjects: [ObjectType.rock, ObjectType.ore, ObjectType.animal, ObjectType.plant, ObjectType.artifact],
    generateObject: (biome, terrain) => {
        const roll = Math.random();
        if (roll < OHC)
            return ObjectType.rock;
        if (roll < OMC)
            return ObjectType.rock;
        if (roll < OVLC)
            return ObjectType.plant;
        if (roll < OVLC)
            return ObjectType.animal;
        if (roll < OVVLC)
            return ObjectType.artifact;
        return null;
    },
};
// Правило для пещеры
const caveRule = {
    terrainName: TerrainName.T_CAVE,
    allowedObjects: [ObjectType.ore, ObjectType.rock, ObjectType.animal, ObjectType.artifact],
    generateObject: (biome, terrain) => {
        const roll = Math.random();
        if (roll < OHC)
            return ObjectType.rock;
        if (roll < OMC)
            return ObjectType.ore;
        if (roll < OMC)
            return ObjectType.animal;
        if (roll < OVVLC)
            return ObjectType.artifact;
        return null;
    },
};
// Правило для вулкана
const volcanoRule = {
    terrainName: TerrainName.T_VOLCANO,
    allowedObjects: [ObjectType.ore, ObjectType.rock, ObjectType.animal, ObjectType.artifact],
    generateObject: (biome, terrain) => {
        const roll = Math.random();
        if (roll < OHC)
            return ObjectType.rock;
        if (roll < OMC)
            return ObjectType.ore;
        if (roll < OVLC)
            return ObjectType.animal;
        if (roll < OVVLC)
            return ObjectType.artifact;
        return null;
    },
};
// Правило для острова
const islandRule = {
    terrainName: TerrainName.T_ISLAND,
    allowedObjects: [ObjectType.rock, ObjectType.plant, ObjectType.animal, ObjectType.tree, ObjectType.artifact],
    generateObject: (biome, terrain) => {
        const roll = Math.random();
        if (roll < OHC)
            return ObjectType.rock;
        if (roll < OMC)
            return ObjectType.tree;
        if (roll < OMC)
            return ObjectType.plant;
        if (roll < OMC)
            return ObjectType.animal;
        if (roll < OVVLC)
            return ObjectType.artifact;
        return null;
    },
};
// ======================================================================
export const terrainRules = new TerrainRules();
terrainRules.addRule(deepWaterRule);
terrainRules.addRule(shallowWaterRule);
terrainRules.addRule(sandRule);
terrainRules.addRule(plainsRule);
terrainRules.addRule(forestRule);
terrainRules.addRule(hillsRule);
terrainRules.addRule(swampRule);
terrainRules.addRule(iceRule);
terrainRules.addRule(mountainsRule);
terrainRules.addRule(rockRule);
terrainRules.addRule(caveRule);
terrainRules.addRule(volcanoRule);
terrainRules.addRule(islandRule);
//# sourceMappingURL=TerrainRules.js.map
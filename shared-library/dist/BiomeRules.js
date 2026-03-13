// c:\DFNNBCG\Project\shared-library\src\BiomeRules.ts
import { BiomeType, TerrainName } from './enums';
import { TVVHC, TVHC, TMC, TLC, TVLC, TVVLC } from './GenerationChances';
// Класс для управления правилами генерации террейнов в биомах
export class BiomeChanceRules {
    rules = [];
    addRule(rule) {
        this.rules.push(rule);
    }
    //Выбирает террейн по биому с учетом вероятностей
    getTerrainForBiome(biomeName) {
        const rule = this.rules.find((r) => r.biome === biomeName);
        if (!rule) {
            return null;
        }
        const roll = Math.random();
        let accumulatedChance = 0;
        for (const terrainChance of rule.terrains) {
            accumulatedChance += terrainChance.chance;
            if (roll <= accumulatedChance) {
                return terrainChance.terrain;
            }
        }
        // Если не нашли подходящий террейн, возвращаем первый из списка
        if (rule.terrains.length > 0) {
            return rule.terrains[0].terrain;
        }
        return null;
    }
    //Выбирает террейн из биома
    getTerrainFromBiome(biome, terrains) {
        if (terrains.length === 0) {
            return null;
        }
        const terrainChances = this.rules.find((r) => r.biome === biome);
        if (!terrainChances)
            return null;
        // Фильтруем террейны, оставляя только те, что есть в biome.terrainTypes
        const filteredTerrains = terrainChances.terrains.filter((terrainChance) => terrains.includes(terrainChance.terrain));
        if (filteredTerrains.length === 0) {
            return null;
        }
        const roll = Math.random();
        let accumulatedChance = 0;
        for (const terrainChance of filteredTerrains) {
            accumulatedChance += terrainChance.chance;
            if (roll <= accumulatedChance) {
                return terrainChance.terrain;
            }
        }
        return filteredTerrains[filteredTerrains.length - 1].terrain;
    }
}
// Создаем экземпляр класса BiomeChanceRules
export const biomeChanceRules = new BiomeChanceRules();
// Правила для океана
biomeChanceRules.addRule({
    biome: BiomeType.B_OCEAN,
    terrains: [
        { terrain: TerrainName.T_DEEP_WATER, chance: TVVHC },
        { terrain: TerrainName.T_SHALLOW_WATER, chance: TVHC },
        { terrain: TerrainName.T_ISLAND, chance: TLC },
        { terrain: TerrainName.T_ICE, chance: TVLC },
        { terrain: TerrainName.T_VOLCANO, chance: TVVLC },
        { terrain: TerrainName.T_ROCK, chance: TVVLC },
    ],
});
// Правила для побережья
biomeChanceRules.addRule({
    biome: BiomeType.B_COAST,
    terrains: [
        { terrain: TerrainName.T_SAND, chance: TVVHC },
        { terrain: TerrainName.T_ROCK, chance: TMC },
        { terrain: TerrainName.T_PLAIN, chance: TLC },
        { terrain: TerrainName.T_SHALLOW_WATER, chance: TMC },
        { terrain: TerrainName.T_CAVE, chance: TVVLC },
        { terrain: TerrainName.T_SWAMP, chance: TVLC },
        { terrain: TerrainName.T_FOREST, chance: TVVLC },
        { terrain: TerrainName.T_VOLCANO, chance: TVVLC }
    ],
});
// Правила для тундры
biomeChanceRules.addRule({
    biome: BiomeType.B_TUNDRA,
    terrains: [
        { terrain: TerrainName.T_PLAIN, chance: TVVHC },
        { terrain: TerrainName.T_ICE, chance: TVHC },
        { terrain: TerrainName.T_FOREST, chance: TMC },
        { terrain: TerrainName.T_MOUNTAIN, chance: TMC },
        { terrain: TerrainName.T_HILL, chance: TMC },
        { terrain: TerrainName.T_VOLCANO, chance: TVVLC },
        { terrain: TerrainName.T_SWAMP, chance: TVVLC },
        { terrain: TerrainName.T_ROCK, chance: TVLC },
        { terrain: TerrainName.T_CAVE, chance: TVVLC },
    ],
});
// Правила для леса
biomeChanceRules.addRule({
    biome: BiomeType.B_FOREST,
    terrains: [
        { terrain: TerrainName.T_FOREST, chance: TVVHC },
        { terrain: TerrainName.T_PLAIN, chance: TMC },
        { terrain: TerrainName.T_HILL, chance: TLC },
        { terrain: TerrainName.T_SHALLOW_WATER, chance: TLC },
        { terrain: TerrainName.T_SWAMP, chance: TLC },
        { terrain: TerrainName.T_MOUNTAIN, chance: TLC },
        { terrain: TerrainName.T_VOLCANO, chance: TVLC },
        { terrain: TerrainName.T_ROCK, chance: TVLC },
        { terrain: TerrainName.T_CAVE, chance: TVLC },
    ],
});
// Правила для пустыни
biomeChanceRules.addRule({
    biome: BiomeType.B_DESERT,
    terrains: [
        { terrain: TerrainName.T_SAND, chance: TVVHC },
        { terrain: TerrainName.T_HILL, chance: TMC },
        { terrain: TerrainName.T_PLAIN, chance: TLC },
        { terrain: TerrainName.T_SHALLOW_WATER, chance: TVLC },
        { terrain: TerrainName.T_ROCK, chance: TVLC },
        { terrain: TerrainName.T_CAVE, chance: TVLC },
        { terrain: TerrainName.T_MOUNTAIN, chance: TVLC },
    ],
});
// Правила для джунглей
biomeChanceRules.addRule({
    biome: BiomeType.B_JUNGLE,
    terrains: [
        { terrain: TerrainName.T_FOREST, chance: TVVHC },
        { terrain: TerrainName.T_SHALLOW_WATER, chance: TMC },
        { terrain: TerrainName.T_SWAMP, chance: TMC },
        { terrain: TerrainName.T_HILL, chance: TLC },
        { terrain: TerrainName.T_MOUNTAIN, chance: TVLC },
        { terrain: TerrainName.T_VOLCANO, chance: TVLC },
        { terrain: TerrainName.T_SAND, chance: TVLC },
        { terrain: TerrainName.T_ROCK, chance: TVLC },
        { terrain: TerrainName.T_CAVE, chance: TVLC },
    ],
});
// Правила для болота
biomeChanceRules.addRule({
    biome: BiomeType.B_SWAMP,
    terrains: [
        { terrain: TerrainName.T_SWAMP, chance: TVVHC },
        { terrain: TerrainName.T_FOREST, chance: TMC },
        { terrain: TerrainName.T_PLAIN, chance: TLC },
        { terrain: TerrainName.T_SHALLOW_WATER, chance: TLC },
        { terrain: TerrainName.T_SAND, chance: TVLC },
        { terrain: TerrainName.T_ROCK, chance: TVLC },
        { terrain: TerrainName.T_CAVE, chance: TVLC },
    ],
});
// Правила для равнин
biomeChanceRules.addRule({
    biome: BiomeType.B_PLAINS,
    terrains: [
        { terrain: TerrainName.T_PLAIN, chance: TVVHC },
        { terrain: TerrainName.T_HILL, chance: TMC },
        { terrain: TerrainName.T_FOREST, chance: TLC },
        { terrain: TerrainName.T_SWAMP, chance: TLC },
        { terrain: TerrainName.T_ROCK, chance: TVLC },
        { terrain: TerrainName.T_CAVE, chance: TVLC },
        { terrain: TerrainName.T_SHALLOW_WATER, chance: TVLC },
        { terrain: TerrainName.T_VOLCANO, chance: TVLC },
    ],
});
// Правила для холмов
biomeChanceRules.addRule({
    biome: BiomeType.B_HILLS,
    terrains: [
        { terrain: TerrainName.T_HILL, chance: TVVHC },
        { terrain: TerrainName.T_PLAIN, chance: TMC },
        { terrain: TerrainName.T_MOUNTAIN, chance: TLC },
        { terrain: TerrainName.T_SWAMP, chance: TLC },
        { terrain: TerrainName.T_ROCK, chance: TVLC },
        { terrain: TerrainName.T_CAVE, chance: TVLC },
        { terrain: TerrainName.T_SHALLOW_WATER, chance: TVLC },
        { terrain: TerrainName.T_FOREST, chance: TVLC },
        { terrain: TerrainName.T_VOLCANO, chance: TVLC },
    ],
});
// Правила для гор
biomeChanceRules.addRule({
    biome: BiomeType.B_MOUNTAINS,
    terrains: [
        { terrain: TerrainName.T_MOUNTAIN, chance: TVVHC },
        { terrain: TerrainName.T_HILL, chance: TMC },
        { terrain: TerrainName.T_ROCK, chance: TLC },
        { terrain: TerrainName.T_VOLCANO, chance: TVLC },
        { terrain: TerrainName.T_CAVE, chance: TVLC },
        { terrain: TerrainName.T_SHALLOW_WATER, chance: TVLC },
        { terrain: TerrainName.T_FOREST, chance: TVLC },
        { terrain: TerrainName.T_ICE, chance: TVLC },
    ],
});
//# sourceMappingURL=BiomeRules.js.map
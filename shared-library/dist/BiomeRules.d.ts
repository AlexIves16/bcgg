import { BiomeType, TerrainName } from './enums';
import { BiomeTerrainRule } from './interfaces';
export declare class BiomeChanceRules {
    private rules;
    addRule(rule: BiomeTerrainRule): void;
    getTerrainForBiome(biomeName: BiomeType): TerrainName | null;
    getTerrainFromBiome(biome: BiomeType, terrains: TerrainName[]): TerrainName | null;
}
export declare const biomeChanceRules: BiomeChanceRules;

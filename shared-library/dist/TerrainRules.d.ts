import { ObjectType, TerrainName } from './enums';
import { Biome, TerrainRule } from './interfaces';
export declare class TerrainRules {
    private rules;
    addRule(rule: TerrainRule): void;
    getAllowedObjects(terrainName: TerrainName): ObjectType[];
    generateObjectForTerrain(biome: Biome, terrain: TerrainName): ObjectType | null;
}
export declare const terrainRules: TerrainRules;

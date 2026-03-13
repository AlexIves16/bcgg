import { BiomeType, TerrainName } from './enums';
import { Biome } from './interfaces';
export declare const BIOMES: {
    [key in BiomeType]: Biome & {
        terrainTypes: TerrainName[];
    };
};

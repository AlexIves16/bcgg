import { ObjectType, TerrainName } from './enums';
import { Biome } from './interfaces';
export declare const TERRAIN_TYPES: {
    [key in TerrainName]: {
        min: number;
        max: number;
        name: TerrainName;
    };
};
export declare const TERRAINS: {
    [key in TerrainName]: {
        type: {
            min: number;
            max: number;
            name: TerrainName;
        };
        allowedObjects: (biome: Biome, objectTypes: {
            [objectType in ObjectType]?: number;
        }) => ObjectType[];
    };
};

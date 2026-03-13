import { TerrainName, BiomeType, ObjectType, GameObjectType, ResourceType } from "./enums";
export interface Position {
    x: number;
    y: number;
}
export interface Metadata {
    height: number;
    temperature: number;
    moisture: number;
}

export interface Biome {
    name: BiomeType;
    tempRange: [number, number];
    moistureRange: [number, number];
    terrainTypes: TerrainName[];
}

// Интерфейс для хранения вероятностей генерации террейнов в биоме
export interface TerrainChance {
    terrain: TerrainName;
    chance: number;
}

// Интерфейс для хранения правил генерации террейнов для биома
export interface BiomeTerrainRule {
    biome: BiomeType;
    terrains: TerrainChance[];
}

export interface TerrainRule {
    terrainName: TerrainName;
    allowedObjects: ObjectType[];
    generateObject: (biome: Biome, terrain: TerrainName) => ObjectType | null;
}

export interface IGameObject {
    id: GameObjectType;
    name: string;
    type: ObjectType;
    health: number;
    durability: number;
    resources: { type: ResourceType; amount: number };
    relationId: GameObjectType | null;
    getData(): any;
  }
  export interface ObjectRegistryType {
    [key: string]: {
      [key in GameObjectType]?: any;
    };
  }
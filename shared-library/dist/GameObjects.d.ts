import { ResourceType, ObjectType, GameObjectType, ItemType } from './enums';
import type { IGameObject } from './interfaces';
export declare class GameObject implements IGameObject {
    id: GameObjectType;
    name: string;
    type: ObjectType;
    health: number;
    durability: number;
    resources: {
        type: ResourceType;
        amount: number;
    };
    relationId: GameObjectType | null;
    constructor(id: GameObjectType, name: string, type: ObjectType, health: number, durability: number, resources: {
        type: ResourceType;
        amount: number;
    }, relationId?: GameObjectType | null);
    getData(): any;
    getType(): ObjectType;
}
export declare class Tree extends GameObject {
    growthStage: number;
    constructor(id: GameObjectType, name: string, growthStage: number, relationId?: GameObjectType | null);
    getData(): any;
}
export declare class Plant extends GameObject {
    harvestable: boolean;
    constructor(id: GameObjectType, name: string, harvestable: boolean, relationId?: GameObjectType | null);
    getData(): any;
}
export declare class Ore extends GameObject {
    hardness: number;
    constructor(id: GameObjectType, name: string, hardness: number, relationId?: GameObjectType | null);
    getData(): any;
}
export declare class Rock extends GameObject {
    size: string;
    constructor(id: GameObjectType, name: string, size: string, relationId?: GameObjectType | null);
    getData(): any;
}
export declare class Structure extends GameObject {
    buildTime: number;
    isComplete: boolean;
    constructor(id: GameObjectType, name: string, buildTime: number, isComplete: boolean, relationId?: GameObjectType | null);
    getData(): any;
}
export declare class Water extends GameObject {
    depth: number;
    constructor(id: GameObjectType, name: string, depth: number, relationId?: GameObjectType | null);
    getData(): any;
}
export declare class Animal extends GameObject {
    species: string;
    isHostile: boolean;
    constructor(id: GameObjectType, name: string, species: string, isHostile: boolean, relationId?: GameObjectType | null);
    getData(): any;
}
export declare class Artifact extends GameObject {
    rarity: string;
    constructor(id: GameObjectType, name: string, rarity: string, relationId?: GameObjectType | null);
    getData(): any;
}
export declare class Monster extends GameObject {
    rank: string;
    isSound: boolean;
    hp: number;
    requiredShape: string;
    attackType: string;
    attackInterval: number;
    attackPower: number;
    aggressiveness: number;
    aggroRadius: number;
    constructor(id: GameObjectType, name: string, rank: string, isSound: boolean, hp: number, requiredShape: string, attackType: string, attackInterval: number, attackPower: number, aggressiveness?: number, aggroRadius?: number, relationId?: GameObjectType | null);
    getData(): any;
}
export declare class Base extends GameObject {
    ownerId: string;
    ownerEmail: string;
    safeRadius: number;
    allowedPlayers: string[];
    constructor(id: GameObjectType, name: string, ownerId: string, ownerEmail: string, relationId?: GameObjectType | null);
    getData(): any;
}
export declare class Item {
    id: string;
    name: string;
    type: ItemType;
    description: string;
    icon: string;
    rarity: string;
    constructor(id: string, name: string, type: ItemType, description: string, icon: string, rarity?: string);
    getData(): any;
}
export declare class LootBundle extends GameObject {
    items: {
        itemId: string;
        amount: number;
    }[];
    constructor(id: GameObjectType, name: string, items: {
        itemId: string;
        amount: number;
    }[], relationId?: GameObjectType | null);
    getData(): any;
}
export declare class Building extends GameObject {
    ownerId: string;
    constructor(id: GameObjectType, name: string, ownerId: string, health: number, relationId?: GameObjectType | null);
    getData(): any;
}
export declare class Workbench extends Building {
    constructor(id: GameObjectType, name: string, ownerId: string, relationId?: GameObjectType | null);
}
export interface IRecipe {
    id: string;
    name: string;
    ingredients: {
        itemId: string;
        amount: number;
    }[];
    outputType: GameObjectType;
    outputName: string;
    isBuilding: boolean;
    requiresWorkbench?: boolean;
}
export declare const Recipes: IRecipe[];

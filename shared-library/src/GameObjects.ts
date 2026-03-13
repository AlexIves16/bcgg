import { ResourceType, ObjectType, GameObjectType, ItemType } from './enums'; //импортируем GameObjectType
import type { IGameObject } from './interfaces';
// Группа: Базовый игровой объект
export class GameObject implements IGameObject {
  public id: GameObjectType; 
  public name: string;
  public type: ObjectType;
  public health: number;
  public durability: number;
  public resources: { type: ResourceType; amount: number };
  public relationId: GameObjectType | null; //изменили тип

  constructor(id: GameObjectType, name: string, type: ObjectType, health: number, durability: number, resources: { type: ResourceType; amount: number }, relationId: GameObjectType | null = null) { //изменили тип
    this.id = id;
    this.name = name;
    this.type = type;
    this.health = health;
    this.durability = durability;
    this.resources = resources;
    this.relationId = relationId;
  }

  getData(): any {
    return {
      health: this.health,
      durability: this.durability,
      resources: this.resources,
      type: this.type,
    };
  }
  getType(): ObjectType {
    return this.type;
  }
}

// Группа: Деревья
export class Tree extends GameObject {
  public growthStage: number;

  constructor(id: GameObjectType, name: string, growthStage: number, relationId: GameObjectType | null = null) { //Изменили тип
    super(id, name, ObjectType.tree, 100, 50, { type: ResourceType.wood, amount: 20 }, relationId);
    this.growthStage = growthStage;
  }

  getData(): any {
    return {
      ...super.getData(),
      growthStage: this.growthStage,
    };
  }
}

// Группа: Растения
export class Plant extends GameObject {
  public harvestable: boolean;

  constructor(id: GameObjectType, name: string, harvestable: boolean, relationId: GameObjectType | null = null) { //Изменили тип
    super(id, name, ObjectType.plant, 50, 10, { type: ResourceType.fiber, amount: 5 }, relationId);
    this.harvestable = harvestable;
  }

  getData(): any {
    return {
      ...super.getData(),
      harvestable: this.harvestable,
    };
  }
}

// Группа: Руды
export class Ore extends GameObject {
  public hardness: number;

  constructor(id: GameObjectType, name: string, hardness: number, relationId: GameObjectType | null = null) { //Изменили тип
    super(id, name, ObjectType.ore, 200, 100, { type: ResourceType.metal, amount: 15 }, relationId);
    this.hardness = hardness;
  }

  getData(): any {
    return {
      ...super.getData(),
      hardness: this.hardness,
    };
  }
}

// Группа: Камни
export class Rock extends GameObject {
  public size: string;

  constructor(id: GameObjectType, name: string, size: string, relationId: GameObjectType | null = null) { //Изменили тип
    super(id, name, ObjectType.rock, 150, 80, { type: ResourceType.stone, amount: 10 }, relationId);
    this.size = size;
  }

  getData(): any {
    return {
      ...super.getData(),
      size: this.size,
    };
  }
}

// Группа: Строения
export class Structure extends GameObject {
  public buildTime: number;
  public isComplete: boolean;

  constructor(id: GameObjectType, name: string, buildTime: number, isComplete: boolean, relationId: GameObjectType | null = null) { //Изменили тип
    super(id, name, ObjectType.structure, 300, 200, { type: ResourceType.material, amount: 0 }, relationId);
    this.buildTime = buildTime;
    this.isComplete = isComplete;
  }

  getData(): any {
    return {
      ...super.getData(),
      buildTime: this.buildTime,
      isComplete: this.isComplete,
    };
  }
}

// Группа: Вода
export class Water extends GameObject {
  public depth: number;

  constructor(id: GameObjectType, name: string, depth: number, relationId: GameObjectType | null = null) { //Изменили тип
    super(id, name, ObjectType.water, 0, 0, { type: ResourceType.water, amount: 100 }, relationId);
    this.depth = depth;
  }

  getData(): any {
    return {
      ...super.getData(),
      depth: this.depth,
    };
  }
}

// Группа: Животные
export class Animal extends GameObject {
  public species: string;
  public isHostile: boolean;

  constructor(id: GameObjectType, name: string, species: string, isHostile: boolean, relationId: GameObjectType | null = null) { //Изменили тип
    super(id, name, ObjectType.animal, 100, 50, { type: ResourceType.meat, amount: 10 }, relationId);
    this.species = species;
    this.isHostile = isHostile;
  }

  getData(): any {
    return {
      ...super.getData(),
      species: this.species,
      isHostile: this.isHostile,
    };
  }
}

// Группа: Артефакты
export class Artifact extends GameObject {
  public rarity: string;

  constructor(id: GameObjectType, name: string, rarity: string, relationId: GameObjectType | null = null) { //Изменили тип
    super(id, name, ObjectType.artifact, 500, 500, { type: ResourceType.magic, amount: 1 }, relationId);
    this.rarity = rarity;
  }

  getData(): any {
    return {
      ...super.getData(),
      rarity: this.rarity,
    };
  }
}
// Группа: Монстры
export class Monster extends GameObject {
  public rank: string;
  public isSound: boolean;
  public hp: number;
  public requiredShape: string;
  public attackType: string;
  public attackInterval: number;
  public attackPower: number;
  public aggressiveness: number; // 0.0 to 1.0
  public aggroRadius: number;     // meters

  constructor(id: GameObjectType, name: string, rank: string, isSound: boolean, hp: number, requiredShape: string, attackType: string, attackInterval: number, attackPower: number, aggressiveness: number = 0, aggroRadius: number = 20, relationId: GameObjectType | null = null) {
    super(id, name, ObjectType.monster, hp, 0, { type: ResourceType.meat, amount: 15 }, relationId);
    this.rank = rank;
    this.isSound = isSound;
    this.hp = hp;
    this.requiredShape = requiredShape;
    this.attackType = attackType;
    this.attackInterval = attackInterval;
    this.attackPower = attackPower;
    this.aggressiveness = aggressiveness;
    this.aggroRadius = aggroRadius;
  }

  getData(): any {
    return {
      ...super.getData(),
      rank: this.rank,
      isSound: this.isSound,
      hp: this.hp,
      requiredShape: this.requiredShape,
      attackType: this.attackType,
      attackInterval: this.attackInterval,
      attackPower: this.attackPower,
      aggressiveness: this.aggressiveness,
      aggroRadius: this.aggroRadius,
    };
  }
}

export class Base extends GameObject {
  public ownerId: string;
  public ownerEmail: string;
  public safeRadius: number = 50;
  public allowedPlayers: string[] = []; // List of UIDs

  constructor(id: GameObjectType, name: string, ownerId: string, ownerEmail: string, relationId: GameObjectType | null = null) {
    super(id, name, ObjectType.base, 1000, 0, { type: ResourceType.material, amount: 0 }, relationId);
    this.ownerId = ownerId;
    this.ownerEmail = ownerEmail;
  }

  getData(): any {
    return {
      ...super.getData(),
      ownerId: this.ownerId,
      ownerEmail: this.ownerEmail,
      safeRadius: this.safeRadius,
      allowedPlayers: this.allowedPlayers,
    };
  }
}

export class Item {
  public id: string;
  public name: string;
  public type: ItemType;
  public description: string;
  public icon: string;
  public rarity: string;

  constructor(id: string, name: string, type: ItemType, description: string, icon: string, rarity: string = 'common') {
    this.id = id;
    this.name = name;
    this.type = type;
    this.description = description;
    this.icon = icon;
    this.rarity = rarity;
  }

  getData(): any {
    return {
      id: this.id,
      name: this.name,
      type: this.type,
      description: this.description,
      icon: this.icon,
      rarity: this.rarity,
    };
  }
}

export class LootBundle extends GameObject {
  public items: { itemId: string; amount: number }[];

  constructor(id: GameObjectType, name: string, items: { itemId: string; amount: number }[], relationId: GameObjectType | null = null) {
    super(id, name, ObjectType.loot, 1, 0, { type: ResourceType.material, amount: 0 }, relationId);
    this.items = items;
  }

  getData(): any {
    return {
      ...super.getData(),
      items: this.items,
    };
  }
}

export class Building extends GameObject {
  public ownerId: string;

  constructor(id: GameObjectType, name: string, ownerId: string, health: number, relationId: GameObjectType | null = null) {
    super(id, name, ObjectType.building, health, 100, { type: ResourceType.material, amount: 0 }, relationId);
    this.ownerId = ownerId;
  }

  getData(): any {
    return {
      ...super.getData(),
      ownerId: this.ownerId,
    };
  }
}

export class Workbench extends Building {
  constructor(id: GameObjectType, name: string, ownerId: string, relationId: GameObjectType | null = null) {
    super(id, name, ownerId, 500, relationId);
  }
}

export interface IRecipe {
  id: string;
  name: string;
  ingredients: { itemId: string; amount: number }[];
  outputType: GameObjectType;
  outputName: string;
  isBuilding: boolean;
  requiresWorkbench?: boolean;
}

export const Recipes: IRecipe[] = [
  {
    id: 'craft_wall_wood',
    name: 'Wooden Wall',
    ingredients: [
      { itemId: 'fiber', amount: 5 },
      { itemId: 'shard', amount: 2 }
    ],
    outputType: GameObjectType.wall_wood,
    outputName: 'Wooden Wall',
    isBuilding: true
  },
  {
    id: 'craft_torch',
    name: 'Ether Torch',
    ingredients: [
      { itemId: 'essence', amount: 3 },
      { itemId: 'shard', amount: 1 }
    ],
    outputType: GameObjectType.torch_ether,
    outputName: 'Ether Torch',
    isBuilding: true
  },
  {
    id: 'craft_workbench',
    name: 'Workbench',
    ingredients: [
      { itemId: 'fiber', amount: 10 },
      { itemId: 'shard', amount: 5 },
      { itemId: 'meat', amount: 2 }
    ],
    outputType: GameObjectType.workbench,
    outputName: 'Workbench',
    isBuilding: true
  },
  {
    id: 'craft_axe_wood',
    name: 'Wooden Axe',
    ingredients: [
      { itemId: 'fiber', amount: 5 },
      { itemId: 'shard', amount: 3 }
    ],
    outputType: GameObjectType.axe_wood,
    outputName: 'Wooden Axe',
    isBuilding: false,
    requiresWorkbench: true
  },
  {
    id: 'craft_pickaxe_wood',
    name: 'Wooden Pickaxe',
    ingredients: [
      { itemId: 'fiber', amount: 5 },
      { itemId: 'shard', amount: 3 }
    ],
    outputType: GameObjectType.pickaxe_wood,
    outputName: 'Wooden Pickaxe',
    isBuilding: false,
    requiresWorkbench: true
  }
];

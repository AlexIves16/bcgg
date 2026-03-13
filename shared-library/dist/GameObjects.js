import { ResourceType, ObjectType, GameObjectType } from './enums'; //импортируем GameObjectType
// Группа: Базовый игровой объект
export class GameObject {
    id;
    name;
    type;
    health;
    durability;
    resources;
    relationId; //изменили тип
    constructor(id, name, type, health, durability, resources, relationId = null) {
        this.id = id;
        this.name = name;
        this.type = type;
        this.health = health;
        this.durability = durability;
        this.resources = resources;
        this.relationId = relationId;
    }
    getData() {
        return {
            health: this.health,
            durability: this.durability,
            resources: this.resources,
            type: this.type,
        };
    }
    getType() {
        return this.type;
    }
}
// Группа: Деревья
export class Tree extends GameObject {
    growthStage;
    constructor(id, name, growthStage, relationId = null) {
        super(id, name, ObjectType.tree, 100, 50, { type: ResourceType.wood, amount: 20 }, relationId);
        this.growthStage = growthStage;
    }
    getData() {
        return {
            ...super.getData(),
            growthStage: this.growthStage,
        };
    }
}
// Группа: Растения
export class Plant extends GameObject {
    harvestable;
    constructor(id, name, harvestable, relationId = null) {
        super(id, name, ObjectType.plant, 50, 10, { type: ResourceType.fiber, amount: 5 }, relationId);
        this.harvestable = harvestable;
    }
    getData() {
        return {
            ...super.getData(),
            harvestable: this.harvestable,
        };
    }
}
// Группа: Руды
export class Ore extends GameObject {
    hardness;
    constructor(id, name, hardness, relationId = null) {
        super(id, name, ObjectType.ore, 200, 100, { type: ResourceType.metal, amount: 15 }, relationId);
        this.hardness = hardness;
    }
    getData() {
        return {
            ...super.getData(),
            hardness: this.hardness,
        };
    }
}
// Группа: Камни
export class Rock extends GameObject {
    size;
    constructor(id, name, size, relationId = null) {
        super(id, name, ObjectType.rock, 150, 80, { type: ResourceType.stone, amount: 10 }, relationId);
        this.size = size;
    }
    getData() {
        return {
            ...super.getData(),
            size: this.size,
        };
    }
}
// Группа: Строения
export class Structure extends GameObject {
    buildTime;
    isComplete;
    constructor(id, name, buildTime, isComplete, relationId = null) {
        super(id, name, ObjectType.structure, 300, 200, { type: ResourceType.material, amount: 0 }, relationId);
        this.buildTime = buildTime;
        this.isComplete = isComplete;
    }
    getData() {
        return {
            ...super.getData(),
            buildTime: this.buildTime,
            isComplete: this.isComplete,
        };
    }
}
// Группа: Вода
export class Water extends GameObject {
    depth;
    constructor(id, name, depth, relationId = null) {
        super(id, name, ObjectType.water, 0, 0, { type: ResourceType.water, amount: 100 }, relationId);
        this.depth = depth;
    }
    getData() {
        return {
            ...super.getData(),
            depth: this.depth,
        };
    }
}
// Группа: Животные
export class Animal extends GameObject {
    species;
    isHostile;
    constructor(id, name, species, isHostile, relationId = null) {
        super(id, name, ObjectType.animal, 100, 50, { type: ResourceType.meat, amount: 10 }, relationId);
        this.species = species;
        this.isHostile = isHostile;
    }
    getData() {
        return {
            ...super.getData(),
            species: this.species,
            isHostile: this.isHostile,
        };
    }
}
// Группа: Артефакты
export class Artifact extends GameObject {
    rarity;
    constructor(id, name, rarity, relationId = null) {
        super(id, name, ObjectType.artifact, 500, 500, { type: ResourceType.magic, amount: 1 }, relationId);
        this.rarity = rarity;
    }
    getData() {
        return {
            ...super.getData(),
            rarity: this.rarity,
        };
    }
}
// Группа: Монстры
export class Monster extends GameObject {
    rank;
    isSound;
    hp;
    requiredShape;
    attackType;
    attackInterval;
    attackPower;
    aggressiveness; // 0.0 to 1.0
    aggroRadius; // meters
    constructor(id, name, rank, isSound, hp, requiredShape, attackType, attackInterval, attackPower, aggressiveness = 0, aggroRadius = 20, relationId = null) {
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
    getData() {
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
    ownerId;
    ownerEmail;
    safeRadius = 50;
    allowedPlayers = []; // List of UIDs
    constructor(id, name, ownerId, ownerEmail, relationId = null) {
        super(id, name, ObjectType.base, 1000, 0, { type: ResourceType.material, amount: 0 }, relationId);
        this.ownerId = ownerId;
        this.ownerEmail = ownerEmail;
    }
    getData() {
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
    id;
    name;
    type;
    description;
    icon;
    rarity;
    constructor(id, name, type, description, icon, rarity = 'common') {
        this.id = id;
        this.name = name;
        this.type = type;
        this.description = description;
        this.icon = icon;
        this.rarity = rarity;
    }
    getData() {
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
    items;
    constructor(id, name, items, relationId = null) {
        super(id, name, ObjectType.loot, 1, 0, { type: ResourceType.material, amount: 0 }, relationId);
        this.items = items;
    }
    getData() {
        return {
            ...super.getData(),
            items: this.items,
        };
    }
}
export class Building extends GameObject {
    ownerId;
    constructor(id, name, ownerId, health, relationId = null) {
        super(id, name, ObjectType.building, health, 100, { type: ResourceType.material, amount: 0 }, relationId);
        this.ownerId = ownerId;
    }
    getData() {
        return {
            ...super.getData(),
            ownerId: this.ownerId,
        };
    }
}
export class Workbench extends Building {
    constructor(id, name, ownerId, relationId = null) {
        super(id, name, ownerId, 500, relationId);
    }
}
export const Recipes = [
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
//# sourceMappingURL=GameObjects.js.map
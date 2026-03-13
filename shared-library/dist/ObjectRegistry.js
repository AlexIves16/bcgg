import { Tree, Rock, Ore, Plant, Water, Structure, Animal, Artifact } from './GameObjects';
import { ObjectType, GameObjectType } from './enums';
// Реестр объектов
export const ObjectRegistry = {
    // Деревья
    [ObjectType.tree]: {
        [GameObjectType.oak_001]: new Tree(GameObjectType.oak_001, 'Oak Tree Variant 1', 3, null),
        [GameObjectType.oak_002]: new Tree(GameObjectType.oak_002, 'Oak Tree Variant 2', 4, null),
        [GameObjectType.pine_001]: new Tree(GameObjectType.pine_001, 'Pine Tree Variant 1', 5, null),
        [GameObjectType.palm_001]: new Tree(GameObjectType.palm_001, 'Palm Tree Variant 1', 2, null),
        [GameObjectType.mangrove_001]: new Tree(GameObjectType.mangrove_001, 'Mangrove Tree Variant 1', 3, null),
    },
    // Растения
    [ObjectType.plant]: {
        [GameObjectType.wheat_001]: new Plant(GameObjectType.wheat_001, 'Wheat Variant 1', true, null),
        [GameObjectType.berryBush_001]: new Plant(GameObjectType.berryBush_001, 'Berry Bush Variant 1', true, null),
        [GameObjectType.grass_001]: new Plant(GameObjectType.grass_001, 'Grass Variant 1', false, null),
        [GameObjectType.cactus_001]: new Plant(GameObjectType.cactus_001, 'Cactus Variant 1', false, null),
        [GameObjectType.reed_001]: new Plant(GameObjectType.reed_001, 'Reed Variant 1', false, null),
        [GameObjectType.kelp_001]: new Plant(GameObjectType.kelp_001, 'Kelp Variant 1', false, null),
    },
    // Руды
    [ObjectType.ore]: {
        [GameObjectType.iron_001]: new Ore(GameObjectType.iron_001, 'Iron Ore Variant 1', 5, null),
        [GameObjectType.copper_001]: new Ore(GameObjectType.copper_001, 'Copper Ore Variant 1', 4, null),
        [GameObjectType.gold_001]: new Ore(GameObjectType.gold_001, 'Gold Ore Variant 1', 8, null),
        [GameObjectType.rareOre_001]: new Ore(GameObjectType.rareOre_001, 'Rare Ore Variant 1', 10, null),
    },
    // Камни
    [ObjectType.rock]: {
        [GameObjectType.smallRock_001]: new Rock(GameObjectType.smallRock_001, 'Small Rock Variant 1', 'small', null),
        [GameObjectType.largeRock_001]: new Rock(GameObjectType.largeRock_001, 'Large Rock Variant 1', 'large', null),
    },
    // Вода
    [ObjectType.water]: {
        [GameObjectType.shallow_001]: new Water(GameObjectType.shallow_001, 'Shallow Water Variant 1', 1, null),
        [GameObjectType.deep_001]: new Water(GameObjectType.deep_001, 'Deep Water Variant 1', 5, null),
        [GameObjectType.fish_001]: new Animal(GameObjectType.fish_001, 'Fish Variant 1', 'fish', false, null),
    },
    // Строения
    [ObjectType.structure]: {
        [GameObjectType.house_001]: new Structure(GameObjectType.house_001, 'House Variant 1', 100, true, null),
        [GameObjectType.fence_001]: new Structure(GameObjectType.fence_001, 'Fence Variant 1', 50, true, null),
        [GameObjectType.ruins_001]: new Structure(GameObjectType.ruins_001, 'Ruins Variant 1', 0, false, null),
    },
    // Животные
    [ObjectType.animal]: {
        [GameObjectType.deer_001]: new Animal(GameObjectType.deer_001, 'Deer Variant 1', 'herbivore', false, null),
        [GameObjectType.wolf_001]: new Animal(GameObjectType.wolf_001, 'Wolf Variant 1', 'carnivore', true, null),
        [GameObjectType.rabbit_001]: new Animal(GameObjectType.rabbit_001, 'Rabbit Variant 1', 'herbivore', false, null),
    },
    // Артефакты
    [ObjectType.artifact]: {
        [GameObjectType.ancientRelic_001]: new Artifact(GameObjectType.ancientRelic_001, 'Ancient Relic Variant 1', 'rare', null),
        [GameObjectType.magicCrystal_001]: new Artifact(GameObjectType.magicCrystal_001, 'Magic Crystal Variant 1', 'epic', null),
    },
};
// Метод для получения обьекта по id
export function getObjectById(objectId) {
    for (const objectType in ObjectRegistry) {
        if (ObjectRegistry[objectType][objectId]) {
            return ObjectRegistry[objectType][objectId];
        }
    }
    return null;
}
//# sourceMappingURL=ObjectRegistry.js.map
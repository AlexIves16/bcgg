import { createNoise2D, NoiseFunction2D } from 'simplex-noise';
import {
    BIOMES,
    Biome,
    GameObjectType,
    Hex,
    Rhombus,
    TERRAIN_TYPES,
    TerrainName,
    biomeChanceRules,
    getObjectById,
    GameObject,
    ObjectType,
    terrainRules,
    BiomeType,
    ObjectRegistry
} from 'shared-library';

// Константы для смещения
const HEIGHT_OFFSET = 1000;
const TEMP_OFFSET = 2000;
const MOISTURE_OFFSET = 3000;
const DIRECTIONS = [[0, 1], [1, 0], [0, -1], [-1, 0]]; // Возможные направления движения
const MAX_MOUNTAIN_ATTEMPTS = 1000;

// Функция нормализации значений
function normalize(value: number, min: number, max: number): number {
    return Math.min(max, Math.max(min, value));
}

// Функция округления до 3 знаков после запятой
function roundToThreeDecimals(value: number): number {
    return Math.round(value * 1000) / 1000;
}

// Функция генерации шума Перлина
function generateNoise(noise: NoiseFunction2D, x: number, y: number, scale: number = 3): number {
    let height = 0;
    let frequency = 1;
    let amplitude = 1;

    for (let i = 0; i < 4; i++) {
        height += noise(x * frequency, y * frequency) * amplitude;
        frequency *= 2;
        amplitude *= 0.5;
    }

    return height / 2;
}

// Функция для определения типа местности
function getTerrain(height: number): TerrainName | null {
    for (const terrainType of Object.keys(TERRAIN_TYPES) as TerrainName[]) {
        const type = TERRAIN_TYPES[terrainType];
        if (height >= type.min && height <= type.max) {
            return type.name;
        }
    }
    // Если ни один террейн не подошел
    return null;
}

// Функция для создания гряды гор
function createMountainRange(hexagons: { [key: string]: Hex }, startHexId: string, rangeLength: number) {
    const rangeHexIds: string[] = [];
    let currentHex = hexagons[startHexId];
    rangeHexIds.push(startHexId);
    for (let i = 1; i < rangeLength; i++) {
        let nextHex: Hex | null = null;
        let attempts = 0;
        let startHex = currentHex;
        while (!nextHex) { // Попытки найти следующий гекс
            if (attempts > MAX_MOUNTAIN_ATTEMPTS) break;
            const directionIndex = Math.floor(Math.random() * DIRECTIONS.length);
            const [dx, dy] = DIRECTIONS[directionIndex];
            const nextX = currentHex.position.x + dx;
            const nextY = currentHex.position.y + dy;
            const nextHexId = `hex_${nextY}_${nextX}`;
            nextHex = hexagons[nextHexId];
            if (!nextHex) {
                // Если гекс не найден, пробуем снова с другого гекса
                currentHex = startHex;
            }
            attempts++;
        }
        if (nextHex) {
            currentHex = nextHex;
            rangeHexIds.push(currentHex.id)
        }
    }
    return rangeHexIds;
}
// Функция для создания кольца холмов
function createHillsRing(hexagons: { [key: string]: Hex }, centerHexIds: string[]) {
    const hillsHexIds: string[] = [];
    const ringCount = Math.floor(Math.random() * 2) + 1;
    for (let i = 0; i < ringCount; i++) {
        for (const centerHexId of centerHexIds) {
            const currentHex = hexagons[centerHexId];
            const allowedBiomes = centerHexIds.map((hexId) => hexagons[hexId].biome);
            for (const [dx, dy] of DIRECTIONS) {
                const nextX = currentHex.position.x + dx;
                const nextY = currentHex.position.y + dy;
                const nextHexId = `hex_${nextY}_${nextX}`;
                const nextHex = hexagons[nextHexId];
                if (nextHex && !allowedBiomes.includes(nextHex.biome) && !hillsHexIds.includes(nextHexId)) { // Дополнительная проверка на наличие nextHex
                    hillsHexIds.push(nextHexId)

                }
            }

        }
    }
    return hillsHexIds;
}

// Функция для создания кольца пляжей
function createCoastRing(hexagons: { [key: string]: Hex }, centerHexIds: string[]) {
    const coastHexIds: string[] = [];
    const ringCount = Math.floor(Math.random() * 2) + 1;
    for (let i = 0; i < ringCount; i++) {
        for (const centerHexId of centerHexIds) {
            const currentHex = hexagons[centerHexId];
            const allowedBiomes = centerHexIds.map((hexId) => hexagons[hexId].biome);
            for (const [dx, dy] of DIRECTIONS) {
                const nextX = currentHex.position.x + dx;
                const nextY = currentHex.position.y + dy;
                const nextHexId = `hex_${nextY}_${nextX}`;
                const nextHex = hexagons[nextHexId];
                if (nextHex && !allowedBiomes.includes(nextHex.biome) && !coastHexIds.includes(nextHexId)) { // Дополнительная проверка на наличие nextHex
                    coastHexIds.push(nextHexId)
                }
            }

        }
    }
    return coastHexIds;
}

// Функция для определения подходящих биомов
function getSuitableBiomes(temp: number, moisture: number): Biome[] {
    const suitableBiomes: Biome[] = [];
    for (const biome of Object.values(BIOMES) as Biome[]) {
        if (temp >= biome.tempRange[0] && temp <= biome.tempRange[1] && moisture >= biome.moistureRange[0] && moisture <= biome.moistureRange[1]) {
            suitableBiomes.push(biome);
        }
    }
    return suitableBiomes;
}

// Функция для выбора биома с учетом вероятностей
function getRandomBiome(suitableBiomes: Biome[]): Biome | null {
    if (suitableBiomes.length === 0) {
        return null;
    }
    return suitableBiomes[Math.floor(Math.random() * suitableBiomes.length)]; // Выбираем случайный биом
}

// Функция для генерации ромбов в гексе
function generateRhombuses(biome: Biome, hexId: string, terrain: TerrainName): { [key in "top" | "bottomLeft" | "bottomRight"]: Rhombus } {
    const rhombuses: { [key in "top" | "bottomLeft" | "bottomRight"]: Rhombus } = {
        top: new Rhombus(`${hexId}-top`, 'top'),
        bottomLeft: new Rhombus(`${hexId}-bottomLeft`, 'bottomLeft'),
        bottomRight: new Rhombus(`${hexId}-bottomRight`, 'bottomRight'),
    };

    for (const position of ['top', 'bottomLeft', 'bottomRight'] as const) {
        //Получаем массив разрешенных типов объектов для данного террейна
        const allowedObjectsForTerrain = terrainRules.getAllowedObjects(terrain);
        //Проверяем если объектов нет, то ромб должен быть пустым
        if (allowedObjectsForTerrain.length === 0) {
            rhombuses[position].setObject("empty")
            continue;
        }
        // Получаем тип объекта для данного биома и террейна
        const objectType: ObjectType | null = terrainRules.generateObjectForTerrain(biome, terrain);

        // Если тип объекта не определен, то ромб пустой
        if (!objectType) {
            rhombuses[position].setObject("empty")
            continue;
        }
        //проверяем разрешен ли объект для данного террейна
        if (!allowedObjectsForTerrain.includes(objectType)) {
            rhombuses[position].setObject("empty")
            continue;
        }

        const availableObjects = Object.keys(ObjectRegistry[objectType]) as GameObjectType[];
        if (availableObjects.length === 0) {
            rhombuses[position].setObject("empty")
            continue;
        }
        const randomIndex = Math.floor(Math.random() * availableObjects.length);
        const gameObjectType = availableObjects[randomIndex];
        const gameObject: GameObject | null = getObjectById(gameObjectType);
        // Если объект не найден, устанавливаем empty
        if(!gameObject){
             rhombuses[position].setObject("empty")
            continue;
        }
        rhombuses[position].setObject(gameObjectType); // Устанавливаем GameObjectType в ромб

        if (gameObject && gameObject.relationId) { // Если GameObject есть и он имеет relationId
            const otherPositions = ['top', 'bottomLeft', 'bottomRight'].filter((pos) => pos !== position) as ["top", "bottomLeft", "bottomRight"];
            const otherPosition = otherPositions[Math.floor(Math.random() * otherPositions.length)];
            const otherRhombus = rhombuses[otherPosition];
            const relatedObject = getObjectById(gameObject.relationId);
            if (relatedObject) {
                otherRhombus.setObject(gameObject.relationId);
            }
            otherRhombus.relationId = rhombuses[position].id;
            rhombuses[position].relationId = otherRhombus.id;
        }
    }

    return rhombuses;
}


// Основная функция генерации карты
export function generateMap(size: number = 9, seed: number = Date.now()): any {
    const biomeGroupCounter = { count: 0 }; // Создаем счетчик для групп биомов
    const hexagons: { [key: string]: Hex } = {}; // Добавляем объявление hexagons здесь
    const MIN_SIZE = 5;
    const MAX_SIZE = 12;
    size = Math.max(MIN_SIZE, Math.min(size, MAX_SIZE));
    if (size % 2 === 0) size--;

    const cols = size * 2;
    const rows = Math.ceil(size * 2.3);

    const heightNoise = createNoise2D(() => seed);
    const tempNoise = createNoise2D(() => seed + 100);
    const moistureNoise = createNoise2D(() => seed + 200);


    for (let y = 0; y < rows; y++) {
        for (let x = 0; x < cols; x++) {
            const id = `hex_${y}_${x}`;

            // Генерация значений с уникальными смещениями
            const rawHeight = generateNoise(heightNoise, x * 0.1 + HEIGHT_OFFSET, y * 0.1 + HEIGHT_OFFSET); // Только height
            const rawTemp = generateNoise(tempNoise, x * 0.2 + TEMP_OFFSET, y * 0.2 + TEMP_OFFSET);
            const rawMoisture = generateNoise(moistureNoise, x * 0.3 + MOISTURE_OFFSET, y * 0.3 + MOISTURE_OFFSET);

            // Округление height до 3 знаков
            const height = roundToThreeDecimals(rawHeight);
            const terrain = getTerrain(height);

            //Проверка на Null
            if(!terrain) continue;
            // Определение биома по необработанным данным
            const unscaledTemp = (rawTemp + 1) * 50;
            const unscaledMoisture = (rawMoisture + 1) * 50;
            const suitableBiomes = getSuitableBiomes(unscaledTemp, unscaledMoisture);
            const biome = getRandomBiome(suitableBiomes); // Теперь biome имеет тип Biome | null
            if (!biome) continue; // Проверяем, не равен ли biome null

            // Выбираем случайный террейн
            const randomTerrain = biomeChanceRules.getTerrainForBiome(biome.name);
            if (!randomTerrain) continue;

            // Масштабирование в диапазоны биома
            // Блок if гарантирует, что biome точно не null
            if (biome) {
                const temperature = normalize(
                    Math.floor(
                        ((rawTemp + 1) * (biome.tempRange[1] - biome.tempRange[0]) / 2) + biome.tempRange[0]
                    ),
                    biome.tempRange[0],
                    biome.tempRange[1]
                );

                const moisture = normalize(
                    Math.floor(
                        ((rawMoisture + 1) * (biome.moistureRange[1] - biome.moistureRange[0]) / 2) + biome.moistureRange[0]
                    ),
                    biome.moistureRange[0],
                    biome.moistureRange[1]
                );
                // Создание гекса
                const hex = new Hex(id, { x, y }, height, randomTerrain, biome.name, { //Изменили terrain на randomTerrain
                    height: height,
                    temperature: temperature,
                    moisture: moisture,
                });
                hexagons[id] = hex; // Сохраняем гекс в hexagons
            }
        }
    }
    // После генерации всех гексов, создаем горную гряду
    for (const hexId in hexagons) {
        if (hexagons[hexId].biome === BiomeType.B_MOUNTAINS && !hexagons[hexId].biomeGroup) {
            biomeGroupCounter.count++;
            const rangeLength = Math.floor(Math.random() * 3) + 2; // 2-4
            const mountainRangeIds = createMountainRange(hexagons, hexId, rangeLength);
            for (const rangeId of mountainRangeIds) {
                hexagons[rangeId].biomeGroup = `mountains-range-${biomeGroupCounter.count}`
                hexagons[rangeId].biome = BiomeType.B_MOUNTAINS;

            }
            const hillsRingIds = createHillsRing(hexagons, mountainRangeIds);
            for (const hillId of hillsRingIds) {
                hexagons[hillId].biomeGroup = `hills-ring-for-mountains-range-${biomeGroupCounter.count}`
                hexagons[hillId].biome = BiomeType.B_HILLS;
            }
        }

    }
    // После генерации всех гексов, создаем океан и побережье
    for (const hexId in hexagons) {
        if (hexagons[hexId].biome === BiomeType.B_OCEAN && !hexagons[hexId].biomeGroup) {
            biomeGroupCounter.count++;
            hexagons[hexId].biomeGroup = `ocean-spot-${biomeGroupCounter.count}`;
            const coastRingIds = createCoastRing(hexagons, [hexId]);
            for (const coastId of coastRingIds) {
                hexagons[coastId].biomeGroup = `coast-ring-for-ocean-spot-${biomeGroupCounter.count}`
                hexagons[coastId].biome = BiomeType.B_COAST;
            }
        }

    }

    // Генерация ромбов
    for (const hexId in hexagons) {
        const hex = hexagons[hexId];
        const rhombuses = generateRhombuses(BIOMES[hex.biome], hexId, hex.terrain as TerrainName);
        hex.rhombuses = rhombuses;
    }

    return {
        metadata: {
            seed: seed,
            size: { width: cols, height: rows },
            generationTime: new Date().toISOString(),
        },
        hexagons: hexagons,
    };
}

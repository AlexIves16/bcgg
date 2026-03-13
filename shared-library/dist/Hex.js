// c:\DFNNBCG\Project\shared-library\src\Hex.ts
import { Rhombus } from './Rhombus';
// Типы позиций ромбов
export class Hex {
    id; // Уникальный идентификатор гекса
    position; // Позиция гекса на карте
    height; // Высота гекса (определяется шумом)
    biome; // Название биома (например, 'forest', 'desert') Изменил тип на BiomeType
    terrain; // Тип местности (например, 'grass', 'sand')
    metadata; // Дополнительные метаданные
    rhombuses; // Ромбы внутри гекса
    biomeGroup = null;
    /**
     * Конструктор класса Hex
     * @param id - Уникальный идентификатор гекса
     * @param position - Позиция гекса на карте
     * @param height - Высота гекса
     * @param biome - Название биома
     * @param terrain - Тип местности
     * @param metadata - Метаданные гекса
     */
    constructor(id, position, height, terrain, biome, metadata) {
        this.id = id;
        this.position = position;
        this.height = height;
        this.biome = biome;
        this.terrain = terrain;
        this.metadata = metadata;
        this.rhombuses = {
            top: new Rhombus(`${id}-top`, 'top'),
            bottomLeft: new Rhombus(`${id}-bottomLeft`, 'bottomLeft'),
            bottomRight: new Rhombus(`${id}-bottomRight`, 'bottomRight'),
        };
    }
}
//# sourceMappingURL=Hex.js.map
import { Rhombus } from './Rhombus';
import { Metadata } from './interfaces';
import { BiomeType } from './enums';
import { RhombusPosition } from './Rhombus';
export declare class Hex {
    id: string;
    position: {
        x: number;
        y: number;
    };
    height: number;
    biome: BiomeType;
    terrain: string;
    metadata: Metadata;
    rhombuses: {
        [key in RhombusPosition]: Rhombus;
    };
    biomeGroup: string | null;
    /**
     * Конструктор класса Hex
     * @param id - Уникальный идентификатор гекса
     * @param position - Позиция гекса на карте
     * @param height - Высота гекса
     * @param biome - Название биома
     * @param terrain - Тип местности
     * @param metadata - Метаданные гекса
     */
    constructor(id: string, position: {
        x: number;
        y: number;
    }, height: number, terrain: string, biome: BiomeType, metadata: Metadata);
}

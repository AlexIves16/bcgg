// c:\DFNNBCG\Project\shared-library\src\Hex.ts
import { Rhombus } from './Rhombus';
import { Metadata } from './interfaces'; 
import { BiomeType } from './enums'; 
import { RhombusPosition } from './Rhombus'; 
// Типы позиций ромбов

export class Hex {
  public id: string; // Уникальный идентификатор гекса
  public position: { x: number; y: number }; // Позиция гекса на карте
  public height: number; // Высота гекса (определяется шумом)
  public biome: BiomeType; // Название биома (например, 'forest', 'desert') Изменил тип на BiomeType
  public terrain: string; // Тип местности (например, 'grass', 'sand')
  public metadata: Metadata; // Дополнительные метаданные
  public rhombuses: { [key in RhombusPosition]: Rhombus }; // Ромбы внутри гекса
  public biomeGroup: string | null = null;

  /**
   * Конструктор класса Hex
   * @param id - Уникальный идентификатор гекса
   * @param position - Позиция гекса на карте
   * @param height - Высота гекса
   * @param biome - Название биома
   * @param terrain - Тип местности
   * @param metadata - Метаданные гекса
   */
  constructor(
    id: string,
    position: { x: number; y: number },
    height: number,
    terrain: string,
    biome: BiomeType,
    metadata: Metadata
  ) {
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
    } as { [key in RhombusPosition]: Rhombus };
  }
}

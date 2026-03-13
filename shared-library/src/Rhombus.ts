import { GameObjectType, ObjectType } from './enums'; // Импортируем ObjectType
import { getObjectById, ObjectRegistry, } from './ObjectRegistry';
import { GameObject } from './GameObjects';

// Типы позиций ромбов
export type RhombusPosition = 'top' | 'bottomLeft' | 'bottomRight';

export class Rhombus {
  public id: string; // Уникальный идентификатор ромба
  public position: RhombusPosition; // Позиция ромба ('top', 'bottomLeft', 'bottomRight')
  public objectId: GameObjectType | ObjectType | "empty"; // Идентификатор объекта в ромбе (например, 'tree', 'rock') или "empty"
  public relationId?: string; // Идентификатор связанного ромба

  /**
   * Конструктор класса Rhombus
   * @param id - Уникальный идентификатор ромба
   * @param position - Позиция ромба
   */
  constructor(id: string, position: RhombusPosition) {
    this.id = id;
    this.position = position;
    this.objectId = "empty"; // Изначально ромб пустой, но поле objectId всегда определено
  }

  /**
   * Установка объекта в ромбе
   * @param objectId - Идентификатор объекта или "empty"
   */
  setObject(objectId: GameObjectType | ObjectType | "empty"): void { // Добавил ObjectType
    this.objectId = objectId;
  }

  /**
   * Очистка ромба (удаление объекта)
   */
  clear(): void {
    this.objectId = "empty"; // Устанавливаем "empty" вместо undefined
    this.relationId = undefined;
  }

  /**
   * Получение объекта в ромбе
   */
  getObject(): GameObject | null {
    if (this.objectId && this.objectId !== "empty") {
        const object = getObjectById(this.objectId as GameObjectType); // Так как теперь может быть и ObjectType, то приводим его к GameObjectType
      // Если объекта больше нет, удаляем его из ромба
      if (!object) {
        this.clear();
        return null;
      }
      return object;
    }
    return null;
  }

  /**
   * Проверка наличия объекта в ромбе
   */
  hasObject(): boolean {
    return this.objectId !== "empty";
  }
}

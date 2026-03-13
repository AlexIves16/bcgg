import { GameObjectType, ObjectType } from './enums';
import { GameObject } from './GameObjects';
export type RhombusPosition = 'top' | 'bottomLeft' | 'bottomRight';
export declare class Rhombus {
    id: string;
    position: RhombusPosition;
    objectId: GameObjectType | ObjectType | "empty";
    relationId?: string;
    /**
     * Конструктор класса Rhombus
     * @param id - Уникальный идентификатор ромба
     * @param position - Позиция ромба
     */
    constructor(id: string, position: RhombusPosition);
    /**
     * Установка объекта в ромбе
     * @param objectId - Идентификатор объекта или "empty"
     */
    setObject(objectId: GameObjectType | ObjectType | "empty"): void;
    /**
     * Очистка ромба (удаление объекта)
     */
    clear(): void;
    /**
     * Получение объекта в ромбе
     */
    getObject(): GameObject | null;
    /**
     * Проверка наличия объекта в ромбе
     */
    hasObject(): boolean;
}

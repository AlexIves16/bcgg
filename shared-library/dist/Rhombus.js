import { getObjectById, } from './ObjectRegistry';
export class Rhombus {
    id; // Уникальный идентификатор ромба
    position; // Позиция ромба ('top', 'bottomLeft', 'bottomRight')
    objectId; // Идентификатор объекта в ромбе (например, 'tree', 'rock') или "empty"
    relationId; // Идентификатор связанного ромба
    /**
     * Конструктор класса Rhombus
     * @param id - Уникальный идентификатор ромба
     * @param position - Позиция ромба
     */
    constructor(id, position) {
        this.id = id;
        this.position = position;
        this.objectId = "empty"; // Изначально ромб пустой, но поле objectId всегда определено
    }
    /**
     * Установка объекта в ромбе
     * @param objectId - Идентификатор объекта или "empty"
     */
    setObject(objectId) {
        this.objectId = objectId;
    }
    /**
     * Очистка ромба (удаление объекта)
     */
    clear() {
        this.objectId = "empty"; // Устанавливаем "empty" вместо undefined
        this.relationId = undefined;
    }
    /**
     * Получение объекта в ромбе
     */
    getObject() {
        if (this.objectId && this.objectId !== "empty") {
            const object = getObjectById(this.objectId); // Так как теперь может быть и ObjectType, то приводим его к GameObjectType
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
    hasObject() {
        return this.objectId !== "empty";
    }
}
//# sourceMappingURL=Rhombus.js.map
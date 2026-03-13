import 'package:flutter/material.dart';
import 'models/entity.dart';

/// Callback types for entity interactions
typedef OnEntityTapCallback = void Function(Entity entity);
typedef OnPlayerTapCallback = void Function(PlayerEntity player);
typedef OnMonsterTapCallback = void Function(MonsterEntity monster);
typedef OnCloudTapCallback = void Function(CloudEntity cloud);
typedef OnBaseTapCallback = void Function(BaseEntity base);
typedef OnObjectTapCallback = void Function(ObjectEntity obj);
typedef OnLootTapCallback = void Function(LootEntity loot);

/// Service handling all map entity interactions
class MapInteractions {
  // Callbacks for different entity types
  final OnEntityTapCallback? onEntityTap;
  final OnPlayerTapCallback? onPlayerTap;
  final OnMonsterTapCallback? onMonsterTap;
  final OnCloudTapCallback? onCloudTap;
  final OnBaseTapCallback? onBaseTap;
  final OnObjectTapCallback? onObjectTap;
  final OnLootTapCallback? onLootTap;

  const MapInteractions({
    this.onEntityTap,
    this.onPlayerTap,
    this.onMonsterTap,
    this.onCloudTap,
    this.onBaseTap,
    this.onObjectTap,
    this.onLootTap,
  });

  /// Handle tap on any entity
  void handleEntityTap(Entity entity) {
    // Call general callback
    onEntityTap?.call(entity);

    // Call type-specific callback
    switch (entity.type) {
      case EntityType.player:
        if (entity is PlayerEntity) {
          onPlayerTap?.call(entity);
        }
        break;
      case EntityType.monster:
        if (entity is MonsterEntity) {
          onMonsterTap?.call(entity);
        }
        break;
      case EntityType.cloud:
        if (entity is CloudEntity) {
          onCloudTap?.call(entity);
        }
        break;
      case EntityType.base:
        if (entity is BaseEntity) {
          onBaseTap?.call(entity);
        }
        break;
      case EntityType.object:
        if (entity is ObjectEntity) {
          onObjectTap?.call(entity);
        }
        break;
      case EntityType.loot:
        if (entity is LootEntity) {
          onLootTap?.call(entity);
        }
        break;
    }
  }

  /// Show dialog with entity information
  static void showEntityInfoDialog(BuildContext context, Entity entity) {
    String title;
    String description;
    IconData icon;
    Color color;

    switch (entity.type) {
      case EntityType.player:
        final player = entity as PlayerEntity;
        title = player.username ?? 'Игрок';
        description = 'ID: ${player.uid}';
        icon = Icons.person;
        color = Colors.purple;
        break;
      case EntityType.monster:
        final monster = entity as MonsterEntity;
        title = monster.monsterType ?? 'Монстр';
        description = 'Тип: ${monster.monsterType}';
        icon = Icons.bug_report;
        color = Colors.red[700]!;
        break;
      case EntityType.cloud:
        final cloud = entity as CloudEntity;
        title = 'Облако энергии';
        description = 'Тип: ${cloud.cloudType ?? "Неизвестно"}';
        icon = Icons.cloud;
        color = Colors.lightBlue[300]!;
        break;
      case EntityType.base:
        final base = entity as BaseEntity;
        title = base.baseId;
        description = 'ID базы';
        icon = Icons.castle;
        color = Colors.amber[700]!;
        break;
      case EntityType.object:
        final obj = entity as ObjectEntity;
        title = obj.objectType ?? 'Объект';
        description = 'ID: ${obj.id}';
        icon = Icons.work;
        color = Colors.green[700]!;
        break;
      case EntityType.loot:
        final loot = entity as LootEntity;
        title = loot.itemName ?? 'Предмет';
        description = 'Редкость: ${loot.rarity ?? "Обычный"}';
        icon = Icons.shopping_bag;
        color = Colors.orange[700]!;
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  /// Create default interactions that show info dialogs
  factory MapInteractions.createDefault(BuildContext context) {
    return MapInteractions(
      onEntityTap: (entity) => showEntityInfoDialog(context, entity),
      onPlayerTap: (player) {
        debugPrint('Tap on player: ${player.username}');
      },
      onMonsterTap: (monster) {
        debugPrint('Tap on monster: ${monster.monsterType}');
      },
      onCloudTap: (cloud) {
        debugPrint('Tap on cloud: ${cloud.cloudType}');
      },
      onBaseTap: (base) {
        debugPrint('Tap on base: ${base.baseId}');
      },
      onObjectTap: (obj) {
        debugPrint('Tap on object: ${obj.name}');
      },
      onLootTap: (loot) {
        debugPrint('Tap on loot: ${loot.itemName}');
      },
    );
  }
}

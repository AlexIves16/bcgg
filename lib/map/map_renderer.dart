import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'models/entity.dart';
import 'services/visibility_service.dart';

/// Service for rendering map entities as markers
class MapRenderer {
  final VisibilityService _visibilityService = VisibilityService();

  /// Render all visible entities as markers
  List<Marker> renderEntities({
    required List<Entity> entities,
    required Position currentPosition,
    required double visibilityRadius,
    Function(Entity)? onEntityTap,
  }) {
    // Filter by visibility
    final visibleEntities = _visibilityService.filterVisible(
      entities: entities,
      center: currentPosition,
      radius: visibilityRadius,
    );

    // Sort by distance (nearest first)
    final sortedEntities = _visibilityService.sortEntitiesByDistance(
      entities: visibleEntities,
      center: currentPosition,
    );

    // Create markers
    return sortedEntities.map((entity) {
      return _createMarker(entity, onEntityTap);
    }).toList();
  }

  Marker _createMarker(Entity entity, Function(Entity)? onTap) {
    Widget widget;

    switch (entity.type) {
      case EntityType.player:
        widget = _createPlayerMarker(entity as PlayerEntity);
        break;
      case EntityType.monster:
        widget = _createMonsterMarker(entity as MonsterEntity);
        break;
      case EntityType.cloud:
        widget = _createCloudMarker(entity as CloudEntity);
        break;
      case EntityType.base:
        widget = _createBaseMarker(entity as BaseEntity);
        break;
      case EntityType.object:
        widget = _createObjectMarker(entity as ObjectEntity);
        break;
      case EntityType.loot:
        widget = _createLootMarker(entity as LootEntity);
        break;
    }

    return Marker(
      point: entity.position,
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => onTap?.call(entity),
        child: widget,
      ),
    );
  }

  Widget _createPlayerMarker(PlayerEntity player) {
    if (player.avatarBase64 != null && player.avatarBase64!.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: MemoryImage(
          base64Decode(player.avatarBase64!),
        ),
        backgroundColor: Colors.white,
        radius: 20,
      );
    } else if (player.username != null && player.username!.trim().isNotEmpty) {
      final seed = Uri.encodeComponent(player.username!);
      return CircleAvatar(
        backgroundImage: NetworkImage(
          'https://api.dicebear.com/8.x/pixel-art/png?seed=$seed',
        ),
        backgroundColor: Colors.grey[200],
        radius: 20,
      );
    } else {
      return const Icon(
        Icons.person_pin_circle,
        color: Colors.purple,
        size: 40.0,
      );
    }
  }

  Widget _createMonsterMarker(MonsterEntity monster) {
    return Icon(
      Icons.bug_report,
      color: Colors.red[700],
      size: 35.0,
    );
  }

  Widget _createCloudMarker(CloudEntity cloud) {
    return Icon(
      Icons.cloud,
      color: Colors.lightBlue[300],
      size: 40.0,
    );
  }

  Widget _createBaseMarker(BaseEntity base) {
    return Icon(
      Icons.castle,
      color: Colors.amber[700],
      size: 35.0,
    );
  }

  Widget _createObjectMarker(ObjectEntity obj) {
    return Icon(
      Icons.work,
      color: Colors.green[700],
      size: 35.0,
    );
  }

  Widget _createLootMarker(LootEntity loot) {
    return Icon(
      Icons.shopping_bag,
      color: Colors.orange[700],
      size: 30.0,
    );
  }

  /// Create a marker for current user position
  Marker createCurrentPlayerMarker(Position position) {
    return Marker(
      point: LatLng(position.latitude, position.longitude),
      width: 40,
      height: 40,
      child: const Icon(
        Icons.my_location,
        color: Colors.blue,
        size: 40.0,
      ),
    );
  }

  /// Get icon for entity type
  IconData getIconForEntityType(EntityType type) {
    switch (type) {
      case EntityType.player:
        return Icons.person;
      case EntityType.monster:
        return Icons.bug_report;
      case EntityType.cloud:
        return Icons.cloud;
      case EntityType.base:
        return Icons.castle;
      case EntityType.object:
        return Icons.work;
      case EntityType.loot:
        return Icons.shopping_bag;
    }
  }

  /// Get color for entity type
  Color getColorForEntityType(EntityType type) {
    switch (type) {
      case EntityType.player:
        return Colors.purple;
      case EntityType.monster:
        return Colors.red[700]!;
      case EntityType.cloud:
        return Colors.lightBlue[300]!;
      case EntityType.base:
        return Colors.amber[700]!;
      case EntityType.object:
        return Colors.green[700]!;
      case EntityType.loot:
        return Colors.orange[700]!;
    }
  }
}

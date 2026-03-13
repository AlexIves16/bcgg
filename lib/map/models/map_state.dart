import 'package:geolocator/geolocator.dart';
import 'entity.dart';

/// Immutable state container for map screen
class MapState {
  final Position? currentPosition;
  final List<Entity> entities;
  final int userXp;
  final int userEnergy;
  final double visibilityRadius;
  final bool isCombatOpen;

  const MapState({
    this.currentPosition,
    this.entities = const [],
    this.userXp = 0,
    this.userEnergy = 0,
    this.visibilityRadius = 300.0,
    this.isCombatOpen = false,
  });

  /// Create a copy with updated fields
  MapState copyWith({
    Position? currentPosition,
    List<Entity>? entities,
    int? userXp,
    int? userEnergy,
    double? visibilityRadius,
    bool? isCombatOpen,
  }) {
    return MapState(
      currentPosition: currentPosition ?? this.currentPosition,
      entities: entities ?? this.entities,
      userXp: userXp ?? this.userXp,
      userEnergy: userEnergy ?? this.userEnergy,
      visibilityRadius: visibilityRadius ?? this.visibilityRadius,
      isCombatOpen: isCombatOpen ?? this.isCombatOpen,
    );
  }

  /// Get entities by type
  List<T> getEntitiesByType<T extends Entity>() {
    return entities.whereType<T>().toList();
  }

  /// Get entity by ID
  Entity? getEntityById(String id) {
    try {
      return entities.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Check if position is valid
  bool get hasValidPosition => currentPosition != null;

  /// Get player entity for current user
  PlayerEntity? get currentPlayer {
    // This would need the current user's UID to filter properly
    // For now, returns first player entity
    return getEntitiesByType<PlayerEntity>().firstOrNull;
  }
}

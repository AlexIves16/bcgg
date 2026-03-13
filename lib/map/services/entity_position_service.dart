import 'package:latlong2/latlong.dart';

/// Animation data for smooth entity movement
class EntityAnimationData {
  final LatLng from;
  final LatLng to;
  final DateTime startTime;
  final Duration duration;

  const EntityAnimationData({
    required this.from,
    required this.to,
    required this.startTime,
    required this.duration,
  });

  /// Get current interpolation factor (0.0 to 1.0)
  double getInterpolationFactor(DateTime currentTime) {
    final elapsed = currentTime.difference(startTime);
    return (elapsed.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Check if animation is complete
  bool isComplete(DateTime currentTime) {
    return currentTime.difference(startTime) >= duration;
  }

  /// Get current position based on time
  LatLng getCurrentPosition(DateTime currentTime) {
    final t = getInterpolationFactor(currentTime);
    // Smooth ease-in-out interpolation
    final easedT = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
    
    final newLat = from.latitude + (to.latitude - from.latitude) * easedT;
    final newLng = from.longitude + (to.longitude - from.longitude) * easedT;
    return LatLng(newLat, newLng);
  }
}

/// Service for managing smooth entity position interpolation
class EntityPositionService {
  final Map<String, EntityAnimationData> _animations = {};
  
  /// Start animation for entity from one position to another
  void startAnimation(
    String entityId,
    LatLng from,
    LatLng to, {
    Duration duration = const Duration(seconds: 5),
  }) {
    _animations[entityId] = EntityAnimationData(
      from: from,
      to: to,
      startTime: DateTime.now(),
      duration: duration,
    );
  }

  /// Get current interpolated position for entity
  LatLng? getCurrentPosition(String entityId) {
    final animation = _animations[entityId];
    if (animation == null) return null;
    
    final currentPosition = animation.getCurrentPosition(DateTime.now());
    
    // Remove completed animations
    if (animation.isComplete(DateTime.now())) {
      _animations.remove(entityId);
    }
    
    return currentPosition;
  }

  /// Update all animations and return IDs of changed entities
  Set<String> update() {
    final now = DateTime.now();
    final changedIds = <String>{};
    final completedIds = <String>{};
    
    _animations.forEach((id, animation) {
      if (animation.isComplete(now)) {
        completedIds.add(id);
      } else {
        changedIds.add(id);
      }
    });
    
    // Remove completed animations
    for (final id in completedIds) {
      _animations.remove(id);
    }
    
    return changedIds;
  }

  /// Check if entity has active animation
  bool hasAnimation(String entityId) {
    return _animations.containsKey(entityId);
  }

  /// Clear all animations
  void clearAll() {
    _animations.clear();
  }

  /// Get animation data for entity
  EntityAnimationData? getAnimation(String entityId) {
    return _animations[entityId];
  }

  /// Get count of active animations
  int get activeAnimationCount => _animations.length;
}

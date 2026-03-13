import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/entity.dart';

/// Service for calculating visibility and distance between entities
class VisibilityService {
  /// Calculate distance between two positions in meters
  double calculateDistance(Position a, Position b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  /// Calculate distance between two LatLng points in meters
  double calculateLatLngDistance(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  /// Check if entity is visible from center position within radius
  bool isVisible({
    required Position center,
    required Entity entity,
    required double radius,
  }) {
    final entityPosition = entity.position;
    final distance = calculateLatLngDistance(
      LatLng(center.latitude, center.longitude),
      entityPosition,
    );
    return distance <= radius;
  }

  /// Filter entities by visibility
  List<Entity> filterVisible({
    required List<Entity> entities,
    required Position center,
    required double radius,
  }) {
    return entities.where((entity) {
      return isVisible(
        center: center,
        entity: entity,
        radius: radius,
      );
    }).toList();
  }

  /// Get distances to all entities from center
  Map<String, double> getDistancesToEntities({
    required List<Entity> entities,
    required Position center,
  }) {
    final distances = <String, double>{};
    
    for (final entity in entities) {
      final distance = calculateLatLngDistance(
        LatLng(center.latitude, center.longitude),
        entity.position,
      );
      distances[entity.id] = distance;
    }
    
    return distances;
  }

  /// Find nearest entity of specific type
  T? findNearestEntity<T extends Entity>({
    required List<Entity> entities,
    required Position center,
  }) {
    T? nearest;
    double minDistance = double.infinity;
    
    for (final entity in entities.whereType<T>()) {
      final distance = calculateLatLngDistance(
        LatLng(center.latitude, center.longitude),
        entity.position,
      );
      
      if (distance < minDistance) {
        minDistance = distance;
        nearest = entity;
      }
    }
    
    return nearest;
  }

  /// Sort entities by distance from center (nearest first)
  List<T> sortEntitiesByDistance<T extends Entity>({
    required List<Entity> entities,
    required Position center,
  }) {
    final typedEntities = entities.whereType<T>().toList();
    
    typedEntities.sort((a, b) {
      final distanceA = calculateLatLngDistance(
        LatLng(center.latitude, center.longitude),
        a.position,
      );
      final distanceB = calculateLatLngDistance(
        LatLng(center.latitude, center.longitude),
        b.position,
      );
      return distanceA.compareTo(distanceB);
    });
    
    return typedEntities;
  }

  /// Check if point is within polygon (for advanced visibility checks)
  bool isPointInPolygon({
    required LatLng point,
    required List<LatLng> polygon,
  }) {
    // Ray casting algorithm
    bool inside = false;
    
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      if (((polygon[i].latitude > point.latitude) != 
           (polygon[j].latitude > point.latitude)) &&
          (point.longitude < (polygon[j].longitude - polygon[i].longitude) * 
           (point.latitude - polygon[i].latitude) / 
           (polygon[j].latitude - polygon[i].latitude) + 
           polygon[i].longitude)) {
        inside = !inside;
      }
    }
    
    return inside;
  }
}

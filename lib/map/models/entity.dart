import 'package:latlong2/latlong.dart';

/// Base type for all map entities
enum EntityType {
  player,
  monster,
  cloud,
  base,
  object,
  loot,
}

/// Abstract base class for all entities on the map
abstract class Entity {
  final String id;
  final LatLng position;
  final EntityType type;

  const Entity({
    required this.id,
    required this.position,
    required this.type,
  });

  /// Copy with new position (for interpolation)
  Entity copyWithPosition(LatLng newPosition);
}

/// Player entity (other players or self)
class PlayerEntity extends Entity {
  final String uid;
  final String? username;
  final String? email;
  final String? avatarBase64;
  final double? lat;
  final double? lng;

  const PlayerEntity({
    required String id,
    required LatLng position,
    required this.uid,
    this.username,
    this.email,
    this.avatarBase64,
    this.lat,
    this.lng,
  }) : super(id: id, position: position, type: EntityType.player);

  @override
  PlayerEntity copyWithPosition(LatLng newPosition) {
    return PlayerEntity(
      id: id,
      position: newPosition,
      uid: uid,
      username: username,
      email: email,
      avatarBase64: avatarBase64,
      lat: newPosition.latitude,
      lng: newPosition.longitude,
    );
  }

  factory PlayerEntity.fromMap(String id, Map data) {
    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;
    return PlayerEntity(
      id: id,
      position: lat != null && lng != null ? LatLng(lat, lng) : const LatLng(0, 0),
      uid: data['uid'] ?? id,
      username: data['username'],
      email: data['email'],
      avatarBase64: data['avatarBase64'],
      lat: lat,
      lng: lng,
    );
  }
}

/// Monster entity (enemy NPC)
class MonsterEntity extends Entity {
  final String monsterId;
  final String? name;
  final int? hp;
  final int? maxHp;
  final String? monsterType;

  const MonsterEntity({
    required String id,
    required LatLng position,
    required this.monsterId,
    this.name,
    this.hp,
    this.maxHp,
    this.monsterType,
  }) : super(id: id, position: position, type: EntityType.monster);

  @override
  MonsterEntity copyWithPosition(LatLng newPosition) {
    return MonsterEntity(
      id: id,
      position: newPosition,
      monsterId: monsterId,
      name: name,
      hp: hp,
      maxHp: maxHp,
      monsterType: monsterType,
    );
  }

  factory MonsterEntity.fromMap(String id, Map data) {
    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;
    return MonsterEntity(
      id: id,
      position: lat != null && lng != null ? LatLng(lat, lng) : const LatLng(0, 0),
      monsterId: data['monsterId'] ?? id,
      name: data['name'],
      hp: data['hp'] as int?,
      maxHp: data['maxHp'] as int?,
      monsterType: data['monsterType'] ?? data['type'],
    );
  }
}

/// Cloud entity (energy mining target)
class CloudEntity extends Entity {
  final String cloudId;
  final int? energyAmount;
  final String? cloudType;

  const CloudEntity({
    required String id,
    required LatLng position,
    required this.cloudId,
    this.energyAmount,
    this.cloudType,
  }) : super(id: id, position: position, type: EntityType.cloud);

  @override
  CloudEntity copyWithPosition(LatLng newPosition) {
    return CloudEntity(
      id: id,
      position: newPosition,
      cloudId: cloudId,
      energyAmount: energyAmount,
      cloudType: cloudType,
    );
  }

  factory CloudEntity.fromMap(String id, Map data) {
    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;
    return CloudEntity(
      id: id,
      position: lat != null && lng != null ? LatLng(lat, lng) : const LatLng(0, 0),
      cloudId: data['cloudId'] ?? id,
      energyAmount: data['energyAmount'] as int?,
      cloudType: data['cloudType'] ?? data['type'],
    );
  }
}

/// Base entity (player-established base)
class BaseEntity extends Entity {
  final String baseId;
  final String? ownerUid;
  final String? ownerName;
  final String? ownerEmail;
  final int? level;

  const BaseEntity({
    required String id,
    required LatLng position,
    required this.baseId,
    this.ownerUid,
    this.ownerName,
    this.ownerEmail,
    this.level,
  }) : super(id: id, position: position, type: EntityType.base);

  @override
  BaseEntity copyWithPosition(LatLng newPosition) {
    return BaseEntity(
      id: id,
      position: newPosition,
      baseId: baseId,
      ownerUid: ownerUid,
      ownerName: ownerName,
      ownerEmail: ownerEmail,
      level: level,
    );
  }

  factory BaseEntity.fromMap(String id, Map data) {
    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;
    return BaseEntity(
      id: id,
      position: lat != null && lng != null ? LatLng(lat, lng) : const LatLng(0, 0),
      baseId: data['baseId'] ?? id,
      ownerUid: data['ownerUid'],
      ownerName: data['ownerName'],
      ownerEmail: data['ownerEmail'],
      level: data['level'] as int?,
    );
  }
}

/// Object entity (interactive objects like workbenches, trees, etc.)
class ObjectEntity extends Entity {
  final String objectId;
  final String? name;
  final String? objectType;
  final Map<String, dynamic>? properties;

  const ObjectEntity({
    required String id,
    required LatLng position,
    required this.objectId,
    this.name,
    this.objectType,
    this.properties,
  }) : super(id: id, position: position, type: EntityType.object);

  @override
  ObjectEntity copyWithPosition(LatLng newPosition) {
    return ObjectEntity(
      id: id,
      position: newPosition,
      objectId: objectId,
      name: name,
      objectType: objectType,
      properties: properties,
    );
  }

  factory ObjectEntity.fromMap(String id, Map data) {
    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;
    return ObjectEntity(
      id: id,
      position: lat != null && lng != null ? LatLng(lat, lng) : const LatLng(0, 0),
      objectId: data['objectId'] ?? id,
      name: data['name'],
      objectType: data['objectType'],
      properties: data['properties'] as Map<String, dynamic>?,
    );
  }
}

/// Loot entity (collectible items)
class LootEntity extends Entity {
  final String lootId;
  final String? itemName;
  final int? quantity;
  final String? rarity;

  const LootEntity({
    required String id,
    required LatLng position,
    required this.lootId,
    this.itemName,
    this.quantity,
    this.rarity,
  }) : super(id: id, position: position, type: EntityType.loot);

  @override
  LootEntity copyWithPosition(LatLng newPosition) {
    return LootEntity(
      id: id,
      position: newPosition,
      lootId: lootId,
      itemName: itemName,
      quantity: quantity,
      rarity: rarity,
    );
  }

  factory LootEntity.fromMap(String id, Map data) {
    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;
    return LootEntity(
      id: id,
      position: lat != null && lng != null ? LatLng(lat, lng) : const LatLng(0, 0),
      lootId: data['lootId'] ?? id,
      itemName: data['itemName'],
      quantity: data['quantity'] as int?,
      rarity: data['rarity'],
    );
  }
}

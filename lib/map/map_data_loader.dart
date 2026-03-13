import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/entity.dart';
import 'services/entity_position_service.dart';

/// Service for loading map data from Firebase Realtime Database
class MapDataLoader {
  final DatabaseReference _dbRef;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Stream controllers
  final _playersController = StreamController<List<PlayerEntity>>.broadcast();
  final _monstersController = StreamController<List<MonsterEntity>>.broadcast();
  final _objectsController = StreamController<List<ObjectEntity>>.broadcast();
  final _basesController = StreamController<List<BaseEntity>>.broadcast();
  
  // Subscriptions
  StreamSubscription? _playersSubscription;
  StreamSubscription? _monstersSubscription;
  StreamSubscription? _objectsSubscription;
  StreamSubscription? _basesSubscription;
  
  // Position service for interpolation
  final EntityPositionService _positionService = EntityPositionService();

  /// Get stream of player entities (excluding current user)
  Stream<List<PlayerEntity>> get playersStream => _playersController.stream;
  
  /// Get stream of monster entities
  Stream<List<MonsterEntity>> get monstersStream => _monstersController.stream;
  
  /// Get stream of object entities
  Stream<List<ObjectEntity>> get objectsStream => _objectsController.stream;
  
  /// Get stream of base entities
  Stream<List<BaseEntity>> get basesStream => _basesController.stream;

  MapDataLoader({FirebaseDatabase? db})
      : _dbRef = (db ?? FirebaseDatabase.instanceFor(
          app: FirebaseDatabase.instance.app,
          databaseURL: 'https://game26-base-default-rtdb.europe-west1.firebasedatabase.app',
        )).ref();

  /// Start listening to all Firebase streams
  void startListening() {
    _startListeningToPlayers();
    _startListeningToMonsters();
    _startListeningToObjects();
    _startListeningToBases();
  }

  /// Stop all subscriptions
  void stopListening() {
    _playersSubscription?.cancel();
    _monstersSubscription?.cancel();
    _objectsSubscription?.cancel();
    _basesSubscription?.cancel();
    _playersController.close();
    _monstersController.close();
    _objectsController.close();
    _basesController.close();
  }

  void _startListeningToPlayers() {
    _playersSubscription = _dbRef.child('players').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value == null) {
        _playersController.add([]);
        return;
      }

      Map? data;
      if (value is Map) {
        data = value;
      } else if (value is List) {
        data = {
          for (int i = 0; i < value.length; i++)
            if (value[i] != null) i.toString(): value[i]
        };
      }

      if (data == null) {
        _playersController.add([]);
        return;
      }

      final currentUser = _auth.currentUser;
      final players = <PlayerEntity>[];

      data.forEach((key, value) {
        if (value == null) return;
        
        final playerData = Map<String, dynamic>.from(value);
        
        // Skip current user's own player data
        if (playerData['uid'] == currentUser?.uid) return;
        
        try {
          final player = PlayerEntity.fromMap(key, playerData);
          players.add(player);
          
          // Start position animation if player moved
          if (_positionService.hasAnimation(key)) {
            final currentPos = _positionService.getCurrentPosition(key);
            if (currentPos != null) {
              _positionService.startAnimation(
                key,
                currentPos,
                player.position,
              );
            }
          } else {
            _positionService.startAnimation(key, player.position, player.position);
          }
        } catch (e) {
          print('[MapDataLoader] Error parsing player $key: $e');
        }
      });

      _playersController.add(players);
    });
  }

  void _startListeningToMonsters() {
    _monstersSubscription = _dbRef.child('map/monsters').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value == null) {
        _monstersController.add([]);
        return;
      }

      Map? data;
      if (value is Map) {
        data = value;
      } else if (value is List) {
        data = {
          for (int i = 0; i < value.length; i++)
            if (value[i] != null) i.toString(): value[i]
        };
      }

      if (data == null) {
        _monstersController.add([]);
        return;
      }

      final monsters = <MonsterEntity>[];
      data.forEach((key, value) {
        if (value == null) return;
        try {
          final monster = MonsterEntity.fromMap(key, Map<String, dynamic>.from(value));
          monsters.add(monster);
        } catch (e) {
          print('[MapDataLoader] Error parsing monster $key: $e');
        }
      });

      _monstersController.add(monsters);
    });
  }

  void _startListeningToObjects() {
    _objectsSubscription = _dbRef.child('map/objects').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value == null) {
        _objectsController.add([]);
        return;
      }

      Map? data;
      if (value is Map) {
        data = value;
      } else if (value is List) {
        data = {
          for (int i = 0; i < value.length; i++)
            if (value[i] != null) i.toString(): value[i]
        };
      }

      if (data == null) {
        _objectsController.add([]);
        return;
      }

      final objects = <ObjectEntity>[];
      data.forEach((key, value) {
        if (value == null) return;
        try {
          final obj = ObjectEntity.fromMap(key, Map<String, dynamic>.from(value));
          objects.add(obj);
        } catch (e) {
          print('[MapDataLoader] Error parsing object $key: $e');
        }
      });

      _objectsController.add(objects);
    });
  }

  void _startListeningToBases() {
    _basesSubscription = _dbRef.child('map/bases').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value == null) {
        _basesController.add([]);
        return;
      }

      Map? data;
      if (value is Map) {
        data = value;
      } else if (value is List) {
        data = {
          for (int i = 0; i < value.length; i++)
            if (value[i] != null) i.toString(): value[i]
        };
      }

      if (data == null) {
        _basesController.add([]);
        return;
      }

      final bases = <BaseEntity>[];
      data.forEach((key, value) {
        if (value == null) return;
        try {
          final base = BaseEntity.fromMap(key, Map<String, dynamic>.from(value));
          bases.add(base);
        } catch (e) {
          print('[MapDataLoader] Error parsing base $key: $e');
        }
      });

      _basesController.add(bases);
    });
  }

  /// Get combined stream of all entities
  /// Note: This is a simple implementation. For production, use rxdart's combineLatest
  Stream<List<Entity>> get combinedEntitiesStream async* {
    // Listen to all streams and yield combined results
    await for (final players in _playersController.stream) {
      yield players;
    }
    await for (final monsters in _monstersController.stream) {
      yield monsters;
    }
    await for (final objects in _objectsController.stream) {
      yield objects;
    }
    await for (final bases in _basesController.stream) {
      yield bases;
    }
  }

  /// Get entity position service for interpolation
  EntityPositionService get positionService => _positionService;
}

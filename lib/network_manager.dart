import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../network_manager.dart';
import 'package:bcgame/location_manager.dart';
import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  static const _rtdbUrl = 'https://game26-base-default-rtdb.europe-west1.firebasedatabase.app';
  late DatabaseReference _db;
  bool _dbInitialized = false;
  StreamSubscription? _mapSubscription;
  StreamSubscription? _playersSubscription;

  double? _lastLat;
  double? _lastLng;
  String? _username;
  String? _avatarBase64;
  String _appVersion = "Unknown";
  String get appVersion => _appVersion;

  List<dynamic> _lastPlayers = [];
  List<dynamic> get lastPlayers => _lastPlayers;

  final _playersController = StreamController<List<dynamic>>.broadcast();
  Stream<List<dynamic>> get playersStream => _playersController.stream;

  final _monstersController = StreamController<List<dynamic>>.broadcast();
  Stream<List<dynamic>> get monstersStream => _monstersController.stream;

  final _objectsController = StreamController<List<dynamic>>.broadcast();
  Stream<List<dynamic>> get objectsStream => _objectsController.stream;

  final _basesController = StreamController<List<dynamic>>.broadcast();
  Stream<List<dynamic>> get basesStream => _basesController.stream;

  Future<void> connect() async {
    debugPrint('[RTDB] Connecting to Firebase Realtime Database...');
    debugPrint('[RTDB] Using regional URL: $_rtdbUrl');
    
    // Initialize DB reference with explicit regional URL
    if (!_dbInitialized) {
      _db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _rtdbUrl,
      ).ref();
      _dbInitialized = true;
    }
    
    // Fetch version
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = "${info.version}+${info.buildNumber}";
      debugPrint('[RTDB] App Version: $_appVersion');
    } catch (e) {
      debugPrint('[RTDB] Failed to get app version: $e');
    }

    final user = FirebaseAuth.instance.currentUser;
    debugPrint('[RTDB] Current User: ${user?.email} (UID: ${user?.uid})');

    // 1. Listen to Map Elements (Monsters and Clouds)
    _mapSubscription?.cancel();
    _mapSubscription = _db.child('map').onValue.listen((event) {
      final value = event.snapshot.value;
      // debugPrint('[RTDB] RAW MAP DATA: $value');
      if (value == null) {
        debugPrint('[RTDB] Map data is NULL');
        return;
      }
      
      Map? data;
      if (value is Map) {
        data = value;
      } else if (value is List) {
        // Handle case where Firebase returns a list if keys are integers
        data = { for (int i = 0; i < value.length; i++) if (value[i] != null) i.toString(): value[i] };
      }

      if (data == null) return;

      final monstersMap = data['monsters'] as Map?;
      final cloudsMap = data['clouds'] as Map?;
      final objectsMap = data['objects'] as Map?;
      
      final monsterElements = [];
      if (monstersMap != null) {
        monsterElements.addAll(monstersMap.values.where((v) => v != null));
      } else if (data['monsters'] is List) {
        monsterElements.addAll((data['monsters'] as List).where((v) => v != null));
      }

      if (cloudsMap != null) {
        monsterElements.addAll(cloudsMap.values.where((v) => v != null));
      } else if (data['clouds'] is List) {
        monsterElements.addAll((data['clouds'] as List).where((v) => v != null));
      }
      
      _monstersController.add(monsterElements);

      final objectElements = [];
      if (objectsMap != null) {
        objectElements.addAll(objectsMap.values.where((v) => v != null));
      } else if (data['objects'] is List) {
        objectElements.addAll((data['objects'] as List).where((v) => v != null));
      }
      _objectsController.add(objectElements);

      final baseElements = [];
      final basesMap = data['bases'] as Map?;
      if (basesMap != null) {
        baseElements.addAll(basesMap.values.where((v) => v != null));
      } else if (data['bases'] is List) {
        baseElements.addAll((data['bases'] as List).where((v) => v != null));
      }
      _basesController.add(baseElements);
    });

    // 2. Listen to Players
    _playersSubscription?.cancel();
    _playersSubscription = _db.child('players').onValue.listen((event) {
      final value = event.snapshot.value;
      // debugPrint('[RTDB] RAW PLAYERS DATA: $value');
      if (value == null) {
        debugPrint('[RTDB] Player data is NULL');
        _playersController.add([]);
        _lastPlayers = []; // Store last known
        return;
      }
      
      List playerList = [];
      if (value is Map) {
        playerList = value.values.toList();
      } else if (value is List) {
        playerList = value.where((v) => v != null).toList();
      }
      
      // debugPrint('[RTDB] Received ${playerList.length} players');
      _lastPlayers = playerList; // Store last known
      _playersController.add(playerList);
    });

    // 3. Sync User Info from Firestore
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((doc) {
        if (doc.exists) {
          _username = doc.data()?['username'];
          _avatarBase64 = doc.data()?['avatarBase64'];
          // Keep RTDB player record updated if we have location
          if (_lastLat != null && _lastLng != null) {
            sendLocation(_lastLat!, _lastLng!);
          }
        }
      });
    }

    // Auto-create Firestore profile if it doesn't exist
    _ensureFirestoreProfile();
  }

  DateTime? _lastProfileSync;

  Future<void> _ensureFirestoreProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      // Throttle: Only sync once every 10 minutes to avoid spam
      if (_lastProfileSync != null && 
          DateTime.now().difference(_lastProfileSync!).inMinutes < 10) {
        return;
      }
      _lastProfileSync = DateTime.now();

      try {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final doc = await userDoc.get();
        
        final Map<String, dynamic> initialData = {
          'email': user.email!.toLowerCase(),
          'lastActive': FieldValue.serverTimestamp(),
          'appVersion': _appVersion,
        };

        if (!doc.exists) {
          debugPrint("[FIRESTORE] Auto-creating NEW user profile for ${user.email}");
          initialData['username'] = user.displayName ?? user.email!.split('@')[0];
          initialData['createdAt'] = FieldValue.serverTimestamp();
          await userDoc.set(initialData, SetOptions(merge: true));
        } else {
          // Silent update for existing profiles
          await userDoc.set(initialData, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint("[FIRESTORE] !!! Profile sync error: $e");
      }
    } else {
      debugPrint("[FIRESTORE] No user or email found to sync profile.");
    }
  }

  void stop() {
    _mapSubscription?.cancel();
    _playersSubscription?.cancel();
  }

  DateTime? _lastLocationSent;

  void sendLocation(double latitude, double longitude) {
    if (!_dbInitialized) return;

    // Throttle: Don't send location more than once every 3 seconds
    if (_lastLocationSent != null && 
        DateTime.now().difference(_lastLocationSent!).inSeconds < 3) {
      return;
    }
    _lastLocationSent = DateTime.now();

    _lastLat = latitude;
    _lastLng = longitude;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Write to RTDB
    _db.child('players').child(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'username': _username,
      'avatarBase64': _avatarBase64,
      'lat': latitude,
      'lng': longitude,
      'lastUpdated': ServerValue.timestamp,
    }).then((_) {
       debugPrint('[RTDB] Location synced for ${user.email} -> $latitude, $longitude');
       _ensureFirestoreProfile();
    }).catchError((err) {
      debugPrint('[RTDB] Error sending location for ${user.email}: $err');
    });
  }

  void mineEnergy(String cloudId, int amount) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Push action to queue for server processing
    _db.child('actions').push().set({
      'type': 'mineEnergy',
      'uid': user.uid,
      'cloudId': cloudId,
      'amount': amount,
      'timestamp': ServerValue.timestamp,
    });
  }

  void logActivity(String action, int value) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Logs are still fine in console/Cloud Functions if needed, 
    // but here we just push to a log node for observability
    _db.child('activity_logs').push().set({
      'uid': user.uid,
      'email': user.email,
      'action': action,
      'value': value,
      'timestamp': ServerValue.timestamp,
    });
  }

  void killMonster(String monsterId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Push action to queue for server processing
    _db.child('actions').push().set({
      'type': 'killMonster',
      'uid': user.uid,
      'monsterId': monsterId,
      'timestamp': ServerValue.timestamp,
    });
  }

  void establishBase(double latitude, double longitude) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _db.child('actions').push().set({
      'type': 'establishBase',
      'uid': user.uid,
      'email': user.email,
      'username': _username ?? user.email?.split('@')[0] ?? 'Explorer',
      'lat': latitude,
      'lng': longitude,
      'timestamp': ServerValue.timestamp,
    });
  }
  void collectLoot(String lootId, double lat, double lng) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _db.child('actions').push().set({
      'type': 'collectLoot',
      'uid': user.uid,
      'lootId': lootId,
      'lat': lat,
      'lng': lng,
      'timestamp': ServerValue.timestamp,
    });
  }

  void craftItem(String recipeId, double lat, double lng) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _db.child('actions').push().set({
      'type': 'craftItem',
      'uid': user.uid,
      'recipeId': recipeId,
      'lat': lat,
      'lng': lng,
      'timestamp': ServerValue.timestamp,
    });
  }

  void equipTool(String itemId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _db.child('actions').push().set({
      'type': 'equipTool',
      'uid': user.uid,
      'itemId': itemId,
      'timestamp': ServerValue.timestamp,
    });
  }

  void harvest(String targetType, double targetLat, double targetLng) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _db.child('actions').push().set({
      'type': 'harvest',
      'uid': user.uid,
      'targetType': targetType,
      'targetLat': targetLat,
      'targetLng': targetLng,
      'lat': LocationManager().lastPosition?.latitude,
      'lng': LocationManager().lastPosition?.longitude,
      'timestamp': ServerValue.timestamp,
    });
  }

  void upgradeBase() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _db.child('actions').push().set({
      'type': 'upgradeBase',
      'uid': user.uid,
      'timestamp': ServerValue.timestamp,
    });
  }

  void inviteToBase(String targetIdentifier) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _db.child('actions').push().set({
      'type': 'inviteToBase',
      'uid': user.uid,
      'targetIdentifier': targetIdentifier,
      'timestamp': ServerValue.timestamp,
    });
  }

  void getSpawnSettings() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _db.child('actions').push().set({
      'type': 'getSpawnSettings',
      'uid': user.uid,
      'timestamp': ServerValue.timestamp,
    });
  }

  void updateSpawnSettings(Map<String, dynamic> settings) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _db.child('actions').push().set({
      'type': 'updateSpawnSettings',
      'uid': user.uid,
      'settings': settings,
      'timestamp': ServerValue.timestamp,
    });
  }

  void regenerateObjects() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _db.child('actions').push().set({
      'type': 'regenerateObjects',
      'uid': user.uid,
      'timestamp': ServerValue.timestamp,
    });
  }
}

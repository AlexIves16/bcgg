import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      
      final elements = [];
      if (monstersMap != null) {
        elements.addAll(monstersMap.values.where((v) => v != null));
      } else if (data['monsters'] is List) {
        elements.addAll((data['monsters'] as List).where((v) => v != null));
      }

      if (cloudsMap != null) {
        elements.addAll(cloudsMap.values.where((v) => v != null));
      } else if (data['clouds'] is List) {
        elements.addAll((data['clouds'] as List).where((v) => v != null));
      }
      
      // debugPrint('[RTDB] Received ${elements.length} map elements');
      _monstersController.add(elements);
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
}

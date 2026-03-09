import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  final _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://game26-base-default-rtdb.europe-west1.firebasedatabase.app/',
  ).ref();
  StreamSubscription? _mapSubscription;
  StreamSubscription? _playersSubscription;

  double? _lastLat;
  double? _lastLng;
  String? _username;
  String? _avatarBase64;
  String _appVersion = "Unknown";
  String get appVersion => _appVersion;

  final _playersController = StreamController<List<dynamic>>.broadcast();
  Stream<List<dynamic>> get playersStream => _playersController.stream;

  final _monstersController = StreamController<List<dynamic>>.broadcast();
  Stream<List<dynamic>> get monstersStream => _monstersController.stream;

  static String get serverUrl => "Firebase Realtime Database";

  void setServerUrl(String url) {}

  Future<void> connect() async {
    debugPrint('[RTDB] Connecting to Firebase Realtime Database...');
    
    // Fetch version
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = "${info.version}+${info.buildNumber}";
    } catch (e) {
      debugPrint('[RTDB] Failed to get app version: $e');
    }

    // 1. Listen to Map Elements (Monsters and Clouds)
    _mapSubscription?.cancel();
    _mapSubscription = _db.child('map').onValue.listen((event) {
      final value = event.snapshot.value;
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
      
      debugPrint('[RTDB] Received ${elements.length} map elements');
      _monstersController.add(elements);
    });

    // 2. Listen to Players
    _playersSubscription?.cancel();
    _playersSubscription = _db.child('players').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value == null) {
        debugPrint('[RTDB] Player data is NULL');
        _playersController.add([]);
        return;
      }
      
      List playerList = [];
      if (value is Map) {
        playerList = value.values.toList();
      } else if (value is List) {
        playerList = value.where((v) => v != null).toList();
      }
      
      debugPrint('[RTDB] Received ${playerList.length} players');
      _playersController.add(playerList);
    });

    // 3. Sync User Info from Firestore
    final user = FirebaseAuth.instance.currentUser;
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
  }

  void stop() {
    _mapSubscription?.cancel();
    _playersSubscription?.cancel();
  }

  void sendLocation(double latitude, double longitude) {
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
       // Success log
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

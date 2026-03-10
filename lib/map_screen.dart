import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'location_manager.dart';
import 'sensor_manager.dart';
import 'ble_manager.dart';
import 'network_manager.dart';
import 'gesture_combat_screen.dart';
import 'gesture_calibration_screen.dart';
import 'combat/sound_combat_overlay.dart';
import 'profile/voice_calibration_screen.dart';
import 'energy_mining_dialog.dart';
import 'update_manager.dart';
import 'profile/profile_drawer.dart';
import 'admin_screen.dart';
import 'package:firebase_database/firebase_database.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  List<Marker> _markers = [];
  
  // Per-entity position interpolation
  final Map<String, dynamic> _entityDataById = {};
  final Map<String, LatLng> _entityFromPos = {};
  final Map<String, LatLng> _entityToPos = {};
  final Map<String, DateTime> _entityAnimStart = {};
  final Map<String, LatLng> _entityCurrentPos = {};
  static const Duration _tickDuration = Duration(seconds: 5);
  Ticker? _ticker;
  
  StreamSubscription<List<dynamic>>? _playersSubscription;
  StreamSubscription<List<dynamic>>? _monstersSubscription;
  StreamSubscription<Position>? _positionSubscription;
  
  int _userXp = 0;
  int _userEnergy = 0;
  double _visibilityRadius = 300;

  @override
  void initState() {
    super.initState();
    _initServices();
    _startAdminSettingsListener();
    // Ticker drives per-frame updates for entity position interpolation
    _ticker = createTicker((_) => _updateEntityPositions())..start();
  }

  void _startAdminSettingsListener() {
    FirebaseDatabase.instanceFor(
      app: FirebaseDatabase.instance.app,
      databaseURL: 'https://game26-base-default-rtdb.europe-west1.firebasedatabase.app',
    ).ref('admin_settings/visibilityRadius').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val != null && mounted) {
        setState(() => _visibilityRadius = (val as num).toDouble());
        debugPrint("[CONFIG] Visibility Radius updated: $_visibilityRadius");
      }
    });
  }

  void _updateEntityPositions() {
    if (!mounted || _entityDataById.isEmpty) return;
    final now = DateTime.now();
    bool changed = false;
    for (final id in _entityDataById.keys) {
      final from = _entityFromPos[id];
      final to = _entityToPos[id];
      final start = _entityAnimStart[id];
      if (from == null || to == null || start == null) continue;
      final elapsed = now.difference(start);
      final t = (elapsed.inMilliseconds / _tickDuration.inMilliseconds).clamp(0.0, 1.0);
      // Smooth ease-in-out interpolation
      final easedT = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
      final newLat = from.latitude + (to.latitude - from.latitude) * easedT;
      final newLng = from.longitude + (to.longitude - from.longitude) * easedT;
      _entityCurrentPos[id] = LatLng(newLat, newLng);
      changed = true;
    }
    if (changed && mounted) setState(() {});
  }

  Future<void> _initServices() async {
    debugPrint("=== STARTING _initServices ===");

    // Grab cached synchronous payload before the async streams start
    if (mounted) {
      setState(() {
        _userXp = SensorManager().userXp;
        _userEnergy = SensorManager().userEnergy;
      });
    }

    try {
      debugPrint("0. Connecting to Network Manager...");
      await NetworkManager().connect();
      
      debugPrint("1. Requesting location permissions...");
      await LocationManager().requestPermissions();
      debugPrint("2. Starting location tracking stream...");
      LocationManager().startTracking();
    } catch (e) {
      debugPrint("!!! Location Permission Error: $e");
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Location Required'),
            content: Text('Error: $e\n\nTo play Digital Ether, you must enable GPS and grant Location Permissions in your device settings.'),
            actions: [
              TextButton(
                onPressed: () {
                  Geolocator.openLocationSettings();
                  Geolocator.openAppSettings();
                  Navigator.pop(context);
                },
                child: const Text('Open Settings'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      }
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
      NetworkManager().sendLocation(position.latitude, position.longitude);
    } catch (e) {
      debugPrint("!!! Error getting initial position: $e");
      // Fallback location - Moscow
      final fallbackPos = Position(
        longitude: 37.6173,
        latitude: 55.7558,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      if (mounted) {
        setState(() {
          _currentPosition = fallbackPos;
        });
        NetworkManager().sendLocation(fallbackPos.latitude, fallbackPos.longitude);
      }
    }

    debugPrint("7. Starting to listen to active Nearby Players and Monsters...");
    _startListeningToNearbyPlayers();
    _startListeningToMonsters();
    
    debugPrint("8. Listening to SensorManager for Local XP and Energy updates...");
    SensorManager().xpStream.listen((xp) {
      if (mounted) {
        setState(() {
          _userXp = xp;
        });
      }
    });
    SensorManager().energyStream.listen((energy) {
      if (mounted) {
        setState(() {
          _userEnergy = energy;
        });
      }
    });

    debugPrint("9. Listening to precise GPS changes...");
    _positionSubscription = LocationManager().positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          _currentPosition = pos;
        });
      }
    });
    
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint("10. Checking for OTA updates...");
      UpdateManager().checkForUpdates(context);
    });
    
    debugPrint("=== FINISHED _initServices ===");
  }

  void _startListeningToNearbyPlayers() {
    _playersSubscription = NetworkManager().playersStream.listen((List<dynamic> playersData) {
      List<Marker> newMarkers = [];
      final currentUser = FirebaseAuth.instance.currentUser;
      
      for (var data in playersData) {
        if (data == null) continue;
        
        // data looks like { uid: userUid, lat: number, lng: number, lastUpdated: number, email: string }
        if (data['uid'] == currentUser?.uid) continue; // Не показываем себя маркером как других
        
        // Calculate distance from current location
        double distanceStr = 0;
        if (_currentPosition != null) {
          distanceStr = Geolocator.distanceBetween(
              _currentPosition!.latitude, _currentPosition!.longitude,
              data['lat'], data['lng']);
        }

        // Only render players within visibility radius
        if (distanceStr > _visibilityRadius) continue;
        
        Widget playerAvatar;
        String playerLabel = data['username'] ?? data['email']?.split('@')?[0] ?? 'Explorer';

        if (data['avatarBase64'] != null) {
          playerAvatar = CircleAvatar(
            backgroundImage: MemoryImage(base64Decode(data['avatarBase64'])),
            backgroundColor: Colors.white,
            radius: 20,
          );
        } else if (data['username'] != null && data['username'].toString().trim().isNotEmpty) {
          final seed = Uri.encodeComponent(data['username']);
          playerAvatar = CircleAvatar(
            backgroundImage: NetworkImage('https://api.dicebear.com/8.x/pixel-art/png?seed=$seed'),
            backgroundColor: Colors.grey[200],
            radius: 20,
          );
        } else {
          playerAvatar = const Icon(Icons.person_pin_circle, color: Colors.purple, size: 40.0);
        }

        newMarkers.add(
          Marker(
            width: 80.0,
            height: 60.0,
            point: LatLng(data['lat'], data['lng']),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                playerAvatar,
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    playerLabel, 
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold), 
                    overflow: TextOverflow.ellipsis
                  ),
                )
              ],
            ),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _markers = newMarkers;
        });
      }
    });
  }

  void _startListeningToMonsters() {
    _monstersSubscription = NetworkManager().monstersStream.listen((List<dynamic> elementsData) {
      if (!mounted) return;
      // debugPrint('[MAP] Received ${elementsData.length} elements for rendering');
      final now = DateTime.now();
      final incomingIds = <String>{};

      for (final element in elementsData) {
        if (element == null) continue;
        final id = element['id']?.toString();
        if (id == null) continue;

        // Proximity Filtering
        if (_currentPosition != null) {
          final dist = Geolocator.distanceBetween(
            _currentPosition!.latitude, _currentPosition!.longitude,
            (element['lat'] as num).toDouble(), (element['lng'] as num).toDouble()
          );
          if (dist > _visibilityRadius) continue;
        }

        incomingIds.add(id);
        
        // Use more robust parsing for coordinates
        final double? lat = (element['lat'] as num?)?.toDouble();
        final double? lng = (element['lng'] as num?)?.toDouble();
        
        if (lat == null || lng == null) {
          debugPrint('[MAP] Element $id has invalid coords: lat=$lat, lng=$lng');
          continue;
        }

        final newPos = LatLng(lat, lng);
        
        if (!_entityDataById.containsKey(id)) {
          _entityFromPos[id] = newPos;
          _entityToPos[id] = newPos;
          _entityCurrentPos[id] = newPos;
          _entityAnimStart[id] = now;
        } else {
          _entityFromPos[id] = _entityCurrentPos[id] ?? newPos;
          _entityToPos[id] = newPos;
          _entityAnimStart[id] = now;
        }
        _entityDataById[id] = element;
      }

      // Remove entities that are no longer on the server
      final toRemove = _entityDataById.keys.where((id) => !incomingIds.contains(id)).toList();
      for (final id in toRemove) {
        _entityDataById.remove(id);
        _entityFromPos.remove(id);
        _entityToPos.remove(id);
        _entityCurrentPos.remove(id);
        _entityAnimStart.remove(id);
      }
      
      // Explicitly trigger a rebuild when new data arrives
      setState(() {});
    });
  }

  void _handleCloudTap(dynamic cloud) {
    if (_currentPosition == null) return;

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude, 
      _currentPosition!.longitude, 
      cloud['lat'], 
      cloud['lng']
    );

    if (distance > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Too far! (Distance: ${distance.round()}m. Need <= 5m)'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else {
      double efficiency = distance > 3 ? 0.3 : 1.0;
      showDialog(
        context: context,
        builder: (context) => EnergyMiningDialog(cloud: cloud, efficiency: efficiency),
      );
    }
  }

  void _handleMonsterTap(dynamic monster) {
    if (_currentPosition == null) return;

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude, 
      _currentPosition!.longitude, 
      monster['lat'], 
      monster['lng']
    );

    if (distance > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Too far to fight! (Distance: ${distance.round()}m. Need <= 10m)'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    int cost = monster['energyCost'] ?? 20; // Fallback to 20 if server doesn't send it

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Wild Monster Appeared!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A wild ${monster['type'] ?? 'bug'} with ${monster['hp']} HP blocks your path.'),
              const SizedBox(height: 12),
              Text(
                'Cost to fight: $cost ⚡', 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Flee
              child: const Text('Flee'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_userEnergy < cost) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Not enough energy! You need $cost ⚡'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                } else {
                  Navigator.of(context).pop();
                  
                  // Consume energy as entry fee
                  bool success = await SensorManager().consumeEnergy(cost);
                  if (success) {
                    if (mounted) {
                      final bool isSoundMonster = 
                          monster['type'] == 'banshee' || 
                          monster['type'] == 'siren' || 
                          monster['isSound'] == true;

                      if (isSoundMonster) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SoundCombatOverlay(
                              monster: monster,
                              onWin: () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Victory! The resonance purified the soul.'), backgroundColor: Colors.green),
                                );
                              },
                              onLose: () => Navigator.pop(context),
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => GestureCombatScreen(monster: monster)),
                        );
                      }
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Fight!'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _playersSubscription?.cancel();
    _monstersSubscription?.cancel();
    _positionSubscription?.cancel();
    NetworkManager().stop();
    LocationManager().stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      drawer: const ProfileDrawer(),
      appBar: AppBar(
        title: const Text('Digital Ether'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                   const Icon(Icons.flash_on, color: Colors.orange, size: 20),
                  Text(
                    ' $_userEnergy/100', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.star, color: Colors.blueAccent, size: 20),
                  Text(
                    ' $_userXp', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)
                  ),
                ],
              )
            ),
          ),
        ],
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                initialZoom: 16.0,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.bcgame',
                ),
                MarkerLayer(
                  markers: [
                    // Добавляем маркер для самого пользователя
                    Marker(
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      width: 80,
                      height: 70,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.my_location, color: Colors.blue, size: 40),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                            child: const Text('You', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                    ..._markers,
                  ],
                ),
                // Animated Entity Markers - position taken from interpolated state
                MarkerLayer(
                  markers: _entityDataById.entries.map((entry) {
                    final id = entry.key;
                    final element = entry.value;
                    final pos = _entityCurrentPos[id];
                    if (pos == null) return null;
                    
                    final type = element['type']?.toString() ?? '';
                    final bool isMonster = type == 'wild_bug' || type == 'banshee' || type == 'siren' || element['isSound'] == true;
                    
                    String emoji;
                    String label;
                    
                    if (type == 'energy_cloud') {
                      emoji = '☁️';
                      label = 'Energy';
                    } else if (type == 'banshee') {
                      emoji = '👻';
                      label = 'Banshee';
                    } else if (type == 'siren') {
                      emoji = '🧜‍♀️';
                      label = 'Siren';
                    } else {
                      emoji = '🐞';
                      label = 'Wild Bug';
                    }

                    return Marker(
                      width: 80.0,
                      height: 85.0,
                      point: pos, 
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => isMonster ? _handleMonsterTap(element) : _handleCloudTap(element),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              emoji,
                              style: const TextStyle(fontSize: 40),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).whereType<Marker>().toList(),
                ),
                // Version Display Overlay
                Positioned(
                  bottom: 120,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'v${NetworkManager().appVersion}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentPosition != null) {
            _mapController.move(
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 
              16.0
            );
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

class AnimatedEntityWidget extends StatefulWidget {
  final dynamic elementData;
  final VoidCallback onTapBug;
  final VoidCallback onTapCloud;

  const AnimatedEntityWidget({
    super.key,
    required this.elementData,
    required this.onTapBug,
    required this.onTapCloud,
  });

  @override
  State<AnimatedEntityWidget> createState() => _AnimatedEntityWidgetState();
}

class _AnimatedEntityWidgetState extends State<AnimatedEntityWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Tween<double> _bounceTween;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    // Simulate drifting/bobbing motion
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _bounceTween = Tween(begin: 0.0, end: 6.0);
    _bounceAnimation = _bounceTween.animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isBug = widget.elementData['type'] == 'wild_bug';
    
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_bounceAnimation.value),
          child: child,
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isBug ? widget.onTapBug : widget.onTapCloud,
        child: Container(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isBug ? Icons.bug_report : Icons.cloud, 
                color: isBug ? Colors.red : Colors.blueAccent, 
                size: 40.0
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  isBug ? 'Wild Bug' : 'Energy', 
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

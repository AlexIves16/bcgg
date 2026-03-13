import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'location_manager.dart';
import 'sensor_manager.dart';
import 'network_manager.dart';
import 'gesture_combat_screen.dart';
import 'combat/sound_combat_overlay.dart';
import 'energy_mining_dialog.dart';
import 'update_manager.dart';
import 'profile/profile_drawer.dart';
import 'profile/crafting_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'map/widgets/animated_entity_widget.dart';
import 'map/dialogs/physical_action_dialog.dart';
import 'map/dialogs/base_management_dialog.dart';
import 'map/menus/interaction_menu.dart';
import 'map/dialogs/build_menu_dialog.dart';

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
  StreamSubscription<List<dynamic>>? _objectsSubscription;
  StreamSubscription<List<dynamic>>? _basesSubscription;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription? _ambushSubscription;
  bool _isCombatOpen = false;
  
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
    _startListeningToObjects();
    _startListeningToBases();
    
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
    
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _ambushSubscription = FirebaseDatabase.instanceFor(
        app: FirebaseDatabase.instance.app,
        databaseURL: 'https://game26-base-default-rtdb.europe-west1.firebasedatabase.app',
      ).ref('players/${user.uid}/ambush').onValue.listen((event) {
        if (!mounted) return;
        if (event.snapshot.exists && !_isCombatOpen) {
          final data = event.snapshot.value as Map;
          final monster = Map<String, dynamic>.from(data['monster'] as Map);
          _handleAmbush(monster);
          event.snapshot.ref.remove();
        }
      });
    }

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

  void _startListeningToObjects() {
    _objectsSubscription = NetworkManager().objectsStream.listen((List<dynamic> elementsData) {
      if (!mounted) return;
      final now = DateTime.now();
      final incomingIds = <String>{};

      for (final element in elementsData) {
        if (element == null) continue;
        final id = element['id']?.toString();
        if (id == null) continue;

        if (_currentPosition != null) {
          final dist = Geolocator.distanceBetween(
            _currentPosition!.latitude, _currentPosition!.longitude,
            (element['lat'] as num).toDouble(), (element['lng'] as num).toDouble()
          );
          if (dist > _visibilityRadius) continue;
        }

        incomingIds.add(id);
        final double? lat = (element['lat'] as num?)?.toDouble();
        final double? lng = (element['lng'] as num?)?.toDouble();
        
        if (lat == null || lng == null) continue;

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

      final toRemove = _entityDataById.keys.where((id) => id.startsWith('obj_') && !incomingIds.contains(id)).toList();
      for (final id in toRemove) {
        _entityDataById.remove(id);
        _entityFromPos.remove(id);
        _entityToPos.remove(id);
        _entityCurrentPos.remove(id);
        _entityAnimStart.remove(id);
      }
      setState(() {});
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

  List<dynamic> _currentBases = [];

  void _startListeningToBases() {
    _basesSubscription = NetworkManager().basesStream.listen((List<dynamic> elementsData) {
      if (mounted) {
        setState(() {
          _currentBases = elementsData;
        });
      }
    });
  }

  void _handleAmbush(dynamic monster) {
    if (!mounted) return;
    setState(() => _isCombatOpen = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('WATCH OUT! A ${monster['rank']} ${monster['name']} is attacking!'),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );

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
              if (mounted) setState(() => _isCombatOpen = false);
              Navigator.pop(context);
            },
            onLose: () {
              if (mounted) setState(() => _isCombatOpen = false);
              Navigator.pop(context);
            },
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GestureCombatScreen(monster: monster)),
      ).then((_) {
        if (mounted) setState(() => _isCombatOpen = false);
      });
    }
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

  void _showInteractionMenu() {
    // Show menu button actions - not tied to a specific element
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'MENU',
              style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const Divider(color: Colors.white24, height: 24),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.white),
              title: const Text('Profile', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Scaffold.of(context).openDrawer();
              },
            ),
            ListTile(
              leading: const Icon(Icons.build, color: Colors.white),
              title: const Text('Crafting', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CraftingScreen(isNearWorkbench: false)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleObjectTap(dynamic element) {
    // Handle null element
    if (element == null) {
      debugPrint('[MAP] Cannot tap on null element');
      return;
    }
    
    showInteractionMenu(
      context: context,
      element: element,
      onMonsterTap: _handleMonsterTap,
      onCloudTap: _handleCloudTap,
      onWorkbenchTap: _showWorkbenchCrafting,
      onLootTap: _handleLootTap,
      onBaseTap: (base) => showBaseManagementDialog(context, base, FirebaseAuth.instance.currentUser?.uid),
      onHarvestTap: _handleHarvest,
    );
  }

  void _handleHarvest(dynamic element) async {
    final String type = element['type']?.toString() ?? '';
    final double lat = (element['lat'] as num?)?.toDouble() ?? 0.0;
    final double lng = (element['lng'] as num?)?.toDouble() ?? 0.0;
    
    // Check distance before starting physical action
    if (_currentPosition != null) {
      final double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude, _currentPosition!.longitude,
        lat, lng
      );
      if (distance > 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Too far to harvest! (Distance: ${distance.round()}m)'), backgroundColor: Colors.redAccent),
        );
        return;
      }
    }

    final String actionDesc = type == 'tree' ? 'Swing phone to chop wood!' 
                            : type == 'rock' || type == 'ore' ? 'Swing phone to mine stone/ore!' 
                            : 'Swing phone to harvest!';
    
    final bool? success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PhysicalActionDialog(
        title: 'Harvesting',
        actionDescription: actionDesc,
        requiredShakes: 10,
      ),
    );

    if (success == true) {
      NetworkManager().harvest(type, lat, lng);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resource harvested!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  void _showWorkbenchCrafting(dynamic workbench) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CraftingScreen(isNearWorkbench: true),
      ),
    );
  }

  void _handleLootTap(dynamic loot) {
    if (_currentPosition == null) return;

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude, 
      _currentPosition!.longitude, 
      loot['lat'], 
      loot['lng']
    );

    if (distance > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Too far to collect! (Distance: ${distance.round()}m. Need <= 10m)'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // List items in loot
    final List<dynamic> items = (loot['items'] as List?) ?? [];
    String itemsList = items.map((i) => '${i['amount']}x ${i['itemId']}').join(', ');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Found Loot!'),
        content: Text('This bundle contains: $itemsList'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Leave')),
          ElevatedButton(
            onPressed: () {
              NetworkManager().collectLoot(loot['id'], _currentPosition!.latitude, _currentPosition!.longitude);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Collecting loot...')),
              );
            },
            child: const Text('Collect'),
          ),
        ],
      ),
    );
  }


  @override
  void dispose() {
    _ticker?.dispose();
    _playersSubscription?.cancel();
    _monstersSubscription?.cancel();
    _objectsSubscription?.cancel();
    _positionSubscription?.cancel();
    _ambushSubscription?.cancel();
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
          : Stack(
              children: [
                FlutterMap(
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
                  ],
                ),
                
                // Safe Zone Circles for Bases
                CircleLayer(
                  circles: _currentBases.map((base) {
                    final lat = (base['lat'] as num?)?.toDouble() ?? 0.0;
                    final lng = (base['lng'] as num?)?.toDouble() ?? 0.0;
                    return CircleMarker(
                      point: LatLng(lat, lng),
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderStrokeWidth: 2,
                      borderColor: Colors.blueAccent.withOpacity(0.3),
                      useRadiusInMeter: true,
                      radius: ((base['level'] ?? 1) * 10.0 + 40.0).toDouble(), // Level 1: 50, Level 2: 60, Level 3: 70
                    );
                  }).toList(),
                ),

                MarkerLayer(
                  markers: _currentBases.map((base) {
                    final lat = (base['lat'] as num?)?.toDouble() ?? 0.0;
                    final lng = (base['lng'] as num?)?.toDouble() ?? 0.0;
                    final int level = base['level'] ?? 1;
                    String iconStr = '🏕️';
                    if (level == 2) iconStr = '🛖';
                    if (level == 3) iconStr = '🏠';

                    return Marker(
                      width: 60.0,
                      height: 60.0,
                      point: LatLng(lat, lng),
                      child: GestureDetector(
                        child: Column(
                          children: [
                            Text(iconStr, style: const TextStyle(fontSize: 32.0)),
                            const Text('HOME', style: TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        onTap: () {
                          if (base['ownerId'] == user?.uid) {
                            showBaseManagementDialog(context, base, user?.uid);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Welcome to ${base['name']}')),
                            );
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
                MarkerLayer(markers: _markers),
                 MarkerLayer(
                  markers: _entityDataById.entries.map((entry) {
                    final id = entry.key;
                    final element = entry.value;
                    final pos = _entityCurrentPos[id];
                    if (pos == null || element == null) return null;
                    
                    final type = element['type']?.toString() ?? '';
                    final bool isMonster = type == 'wild-bug' || type == 'banshee' || type == 'siren' || element['isSound'] == true;

                    return Marker(
                        width: 80.0,
                        height: 85.0,
                        point: pos, 
                        child: AnimatedEntityWidget(
                          elementData: element,
                          onTap: () {
                            if (isMonster) {
                              _handleMonsterTap(element);
                            } else if (type == 'energy_cloud') {
                              _handleCloudTap(element);
                            } else {
                              _handleObjectTap(element);
                            }
                          },
                        ),
                      );
                  }).whereType<Marker>().toList(),
                ),
              ],
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'locationBtn',
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
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'baseBtn',
            backgroundColor: Colors.blueAccent,
            child: const Icon(Icons.add_home),
            onPressed: () {
              if (_currentPosition == null) return;
              
              final user = FirebaseAuth.instance.currentUser;
              dynamic userBase;
              if (user != null) {
                try {
                   userBase = _currentBases.firstWhere((b) => b['ownerId'] == user.uid);
                } catch(_) {}
              }

              showBuildMenuDialog(context, userBase, _currentPosition!.latitude, _currentPosition!.longitude);
            },
          ),
        ],
      ),
    );
  }
}


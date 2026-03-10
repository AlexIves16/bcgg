import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'network_manager.dart';

class LocationManager {
  static final LocationManager _instance = LocationManager._internal();
  factory LocationManager() => _instance;
  LocationManager._internal();

  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  Position? get lastPosition => _lastPosition;

  final _positionController = StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  Future<void> requestPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }
  }

  void startTracking() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, 
        distanceFilter: 5, // Reduced from 20m for smoother updates
      ),
    ).listen((Position position) {
      _lastPosition = position; // Update cache
      _positionController.add(position); // Broadcast to UI
      _updateUserLocation(position);
    });
  }

  void stopTracking() {
    _positionSubscription?.cancel();
  }

  Future<void> _updateUserLocation(Position position) async {
    try {
      NetworkManager().sendLocation(position.latitude, position.longitude);
    } catch (e) {
      // Slient error
    }
  }
}

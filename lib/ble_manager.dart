import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleManager {
  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;
  BleManager._internal();

  bool _isScanning = false;
  List<ScanResult> nearbyPlayers = [];

  Future<void> startScanning() async {
    try {
      if (await FlutterBluePlus.isSupported == false) {
        print("Bluetooth not supported by this device");
        return;
      }

      var subscription = FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
        if (state == BluetoothAdapterState.on && !_isScanning) {
          _scanForPlayers();
        }
      });
      // Note: Remember to cancel the subscription when done
    } catch (e) {
      print('BLE Setup Error: $e');
    }
  }

  void _scanForPlayers() async {
    _isScanning = true;
    
    // Listen to scan results
    var scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      if (results.isNotEmpty) {
        nearbyPlayers = results;
        // Logic to track players for Team Raids goes here based on specific MAC or service UUIDs
      }
    }, onError: (e) => print(e));

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    await FlutterBluePlus.isScanning.where((val) => val == false).first;
    _isScanning = false;
  }
}

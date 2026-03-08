import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'network_manager.dart';
import 'sensor_manager.dart';

class EnergyMiningDialog extends StatefulWidget {
  final dynamic cloud;
  final double efficiency; // 1.0 for close, 0.3 for far

  const EnergyMiningDialog({
    super.key, 
    required this.cloud, 
    required this.efficiency
  });

  @override
  State<EnergyMiningDialog> createState() => _EnergyMiningDialogState();
}

class _EnergyMiningDialogState extends State<EnergyMiningDialog> {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  
  int _cloudCapacity = 0;
  int _shakesCount = 0;
  DateTime? _lastShake;
  final double _shakeThreshold = 20.0;
  
  @override
  void initState() {
    super.initState();
    _cloudCapacity = widget.cloud['capacity'] ?? 0;
    _startListening();
  }

  void _startListening() {
    _accelSub = accelerometerEventStream().listen((AccelerometerEvent event) {
      if (_cloudCapacity <= 0) return;
      
      double accel = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
      if (accel > _shakeThreshold) {
        final now = DateTime.now();
        if (_lastShake != null && now.difference(_lastShake!).inMilliseconds < 400) {
          return; // Debounce
        }
        _lastShake = now;
        
        setState(() {
          _shakesCount++;
        });

        if (_shakesCount >= 3) {
          _mineEnergy();
        }
      }
    });
  }

  void _mineEnergy() {
    if (_cloudCapacity <= 0) return;

    // Base yield is 10, reduced by efficiency (e.g. 10 * 0.3 = 3)
    int amountToMine = (10 * widget.efficiency).round();
    
    // Prevent over-mining the cloud
    if (amountToMine > _cloudCapacity) {
      amountToMine = _cloudCapacity;
    }

    setState(() {
      _shakesCount = 0;
      _cloudCapacity -= amountToMine;
    });

    // Award to player profile
    SensorManager().addEnergy(amountToMine);
    // Notify server to deplete cloud
    NetworkManager().mineEnergy(widget.cloud['id'], amountToMine);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mined +$amountToMine Energy! ⚡'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isEmpty = _cloudCapacity <= 0;
    
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.cloud, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Text(isEmpty ? 'Depleted Cloud' : 'Energy Cloud'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isEmpty 
              ? 'This cloud has been fully drained.'
              : 'Shake your phone hard to extract energy!',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (!isEmpty) ...[
            Text('Cloud Capacity: $_cloudCapacity ⚡', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            Text('Efficiency: ${(widget.efficiency * 100).round()}%', 
              style: TextStyle(
                color: widget.efficiency >= 1.0 ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: _shakesCount / 3.0, // 3 shakes = 1 mine cycle
              backgroundColor: Colors.grey[300],
              color: Colors.orange,
              minHeight: 15,
            ),
            const SizedBox(height: 8),
            Text('Shakes: $_shakesCount / 3'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

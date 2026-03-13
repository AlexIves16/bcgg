import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class PhysicalActionDialog extends StatefulWidget {
  final String title;
  final String actionDescription;
  final int requiredShakes;

  const PhysicalActionDialog({
    super.key, 
    required this.title, 
    required this.actionDescription,
    this.requiredShakes = 10,
  });

  @override
  State<PhysicalActionDialog> createState() => _PhysicalActionDialogState();
}

class _PhysicalActionDialogState extends State<PhysicalActionDialog> {
  int _currentShakes = 0;
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  
  // Shake detection thresholds
  static const double shakeThresholdGravity = 2.0;
  static const int shakeSlopTimeMs = 300;
  int _lastShakeTime = 0;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _accelSubscription = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      // Calculate acceleration magnitude
      double gX = event.x / 9.80665;
      double gY = event.y / 9.80665;
      double gZ = event.z / 9.80665;

      double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

      if (gForce > shakeThresholdGravity) {
        final now = DateTime.now().millisecondsSinceEpoch;
        
        // Ignore shakes that are too close together
        if (_lastShakeTime + shakeSlopTimeMs > now) {
          return;
        }

        _lastShakeTime = now;
        
        if (mounted) {
          setState(() {
            _currentShakes++;
          });
          
          if (_currentShakes >= widget.requiredShakes) {
            _completeAction();
          }
        }
      }
    });
  }

  void _completeAction() {
    _accelSubscription?.cancel();
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double progress = (_currentShakes / widget.requiredShakes).clamp(0.0, 1.0);
    
    return PopScope(
      canPop: false, // Prevent dismissing by swiping/back button
      child: AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.vibration, size: 60, color: Colors.orangeAccent),
            const SizedBox(height: 16),
            Text(
              widget.actionDescription,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: progress,
              minHeight: 20,
              backgroundColor: Colors.grey[800],
              color: progress >= 1.0 ? Colors.green : Colors.blueAccent,
            ),
            const SizedBox(height: 8),
            Text('${(progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../network_manager.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  
  Map<String, double> _spawnSettings = {
    'tree': 50.0,
    'rock': 30.0,
    'plant': 40.0,
    'ore': 10.0,
    'animal': 20.0,
    'artifact': 5.0,
    'structure': 15.0,
  };

  @override
  void initState() {
    super.initState();
    // Listen for incoming spawn settings payload from global admin node
    _db.child('admin/spawnSettings').onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        if (mounted) {
          setState(() {
            data.forEach((key, value) {
              _spawnSettings[key.toString()] = (value as num).toDouble();
            });
          });
        }
      }
    });
    
    // Fallback: If node empty, request it
    if (_uid != null) {
      NetworkManager().getSpawnSettings();
    }
  }

  void _saveSettings() {
    if (_uid == null) return;
    
    // Convert back to int/num for the server payload
    Map<String, dynamic> payload = {};
    _spawnSettings.forEach((key, value) {
      payload[key] = value.toInt();
    });
    
    NetworkManager().updateSpawnSettings(payload);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved!'), backgroundColor: Colors.green),
    );
  }

  void _regenerateObjects() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Warning'),
        content: const Text('Are you sure you want to regenerate all map objects using the new settings? This will clear all existing non-loot/non-base objects.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              NetworkManager().regenerateObjects();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Regenerating Map Objects...'), backgroundColor: Colors.orangeAccent),
              );
            },
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_spawnSettings[key]!.toInt().toString(), style: const TextStyle(color: Colors.blueAccent)),
            ],
          ),
          Slider(
            value: _spawnSettings[key]!,
            min: 0,
            max: 100,
            divisions: 100,
            label: _spawnSettings[key]!.toInt().toString(),
            onChanged: (value) {
              setState(() {
                _spawnSettings[key] = value;
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spawn Settings'),
        backgroundColor: Colors.indigoAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Adjust the relative spawn weights of map objects. These take effect on the next client-side heartbeat or force-regeneration.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            const Divider(),
            _buildSlider('🌳 Tree Gen Probability', 'tree'),
            _buildSlider('🪨 Rock Gen Probability', 'rock'),
            _buildSlider('🌿 Grass/Plant Gen Probability', 'plant'),
            _buildSlider('💎 Ore Gen Probability', 'ore'),
            _buildSlider('🐇 Animal Gen Probability', 'animal'),
            _buildSlider('🏺 Ancient Relic Gen Probability', 'artifact'),
            _buildSlider('🏛️ Old Ruins Gen Probability', 'structure'),
            
            const SizedBox(height: 30),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Regenerate All Map Objects', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _regenerateObjects,
              ),
            ),
            
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

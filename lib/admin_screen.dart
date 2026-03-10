import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'network_manager.dart';
import 'combat/sound_combat_overlay.dart';
import 'gesture_combat_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final DatabaseReference _adminRef = FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
    databaseURL: 'https://game26-base-default-rtdb.europe-west1.firebasedatabase.app',
  ).ref('admin_settings');

  double _maxMonsters = 20;
  double _maxClouds = 10;
  double _visibilityRadius = 300;
  bool _sonicMobsEnabled = true;
  bool _vocalMobsEnabled = true;
  bool _basicMobsEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
    _loadSettings();
  }

  Future<void> _checkAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("[ADMIN] No user logged in");
      if (mounted) Navigator.pop(context);
      return;
    }
    
    debugPrint("[ADMIN] Checking access for UID: ${user.uid}");
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      
      if (!doc.exists) {
        debugPrint("[ADMIN] Document does NOT exist for UID: ${user.uid}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: User profile not found in Firestore (${user.uid.substring(0,6)})')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final data = doc.data();
      final bool isAdmin = data?['isAdmin'] == true;
      debugPrint("[ADMIN] Document data: $data");
      debugPrint("[ADMIN] isAdmin flag: $isAdmin");

      if (!isAdmin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Access Denied: Not an Admin')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint("[ADMIN] Firestore Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firestore Error: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadSettings() async {
    try {
      final snapshot = await _adminRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        setState(() {
          _maxMonsters = (data['maxMonsters'] ?? 20).toDouble();
          _maxClouds = (data['maxClouds'] ?? 10).toDouble();
          _visibilityRadius = (data['visibilityRadius'] ?? 300).toDouble();
          _sonicMobsEnabled = data['sonicMobsEnabled'] ?? true;
          _vocalMobsEnabled = data['vocalMobsEnabled'] ?? true;
          _basicMobsEnabled = data['basicMobsEnabled'] ?? true;
        });
      }
    } catch (e) {
      debugPrint("Error loading admin settings: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    await _adminRef.update({key: value});
  }

  void _triggerMockBattle(String type) {
    final mockMonster = {
      'id': 'mock_${type}_${DateTime.now().millisecondsSinceEpoch}',
      'type': type,
      'hp': 100,
      'energyCost': 0,
      'name': 'Training ${type.toUpperCase()}',
      'isSound': type != 'wild_bug',
    };

    if (type == 'banshee' || type == 'siren') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SoundCombatOverlay(
            monster: mockMonster,
            onWin: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mock Victory!'), backgroundColor: Colors.green),
              );
            },
            onLose: () => Navigator.pop(context),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GestureCombatScreen(monster: mockMonster),
        ),
      );
    }
  }

  Future<void> _triggerReset() async {
    await _adminRef.update({'resetTrigger': true});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Respawn triggered! Map will be cleared soon.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Management'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple, Colors.deepPurple],
            ),
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildCategoryTile(
                title: 'World Entities & Spawning',
                icon: Icons.public,
                color: Colors.blueAccent,
                children: [
                  _buildSliderTile(
                    'Max Basic Monsters', 
                    _maxMonsters, 
                    5, 100, 
                    (val) {
                      setState(() => _maxMonsters = val);
                      _updateSetting('maxMonsters', val.toInt());
                    }
                  ),
                  _buildSliderTile(
                    'Max Energy Clouds', 
                    _maxClouds, 
                    2, 50, 
                    (val) {
                      setState(() => _maxClouds = val);
                      _updateSetting('maxClouds', val.toInt());
                    }
                  ),
                  _buildSliderTile(
                    'Visibility Radius (meters)', 
                    _visibilityRadius, 
                    50, 2000, 
                    (val) {
                      setState(() => _visibilityRadius = val);
                      _updateSetting('visibilityRadius', val.toInt());
                    }
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _triggerReset,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Force Global Respawn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _buildCategoryTile(
                title: 'Combat & Mob Types',
                icon: Icons.security,
                color: Colors.orangeAccent,
                children: [
                  _buildSwitchTile(
                    'Basic Mobs (Physical)', 
                    _basicMobsEnabled, 
                    (val) {
                      setState(() => _basicMobsEnabled = val);
                      _updateSetting('basicMobsEnabled', val);
                    }
                  ),
                  _buildSwitchTile(
                    'Sonic Mobs (Note Singing)', 
                    _sonicMobsEnabled, 
                    (val) {
                      setState(() => _sonicMobsEnabled = val);
                      _updateSetting('sonicMobsEnabled', val);
                    }
                  ),
                  _buildSwitchTile(
                    'Vocal Mobs (Vowel Singing)', 
                    _vocalMobsEnabled, 
                    (val) {
                      setState(() => _vocalMobsEnabled = val);
                      _updateSetting('vocalMobsEnabled', val);
                    }
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Sonic and Vocal mobs require FFT analysis. Basic mobs use the standard gesture system.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _buildCategoryTile(
                title: 'Database & Sync Status',
                icon: Icons.storage,
                color: Colors.greenAccent,
                children: [
                   _buildUserList(),
                ],
              ),
              const SizedBox(height: 16),

              _buildCategoryTile(
                title: 'Combat Emulation (DEBUG)',
                icon: Icons.bug_report,
                color: Colors.redAccent,
                children: [
                  const Text(
                    'Instantly start a mock battle for testing. No energy cost, no XP gain.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _triggerMockBattle('banshee'),
                          icon: const Text('👻', style: TextStyle(fontSize: 18)),
                          label: const Text('Test Banshee'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan[700], foregroundColor: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _triggerMockBattle('siren'),
                          icon: const Text('🧜‍♀️', style: TextStyle(fontSize: 18)),
                          label: const Text('Test Siren'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.pink[700], foregroundColor: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _triggerMockBattle('wild_bug'),
                      icon: const Text('🐞', style: TextStyle(fontSize: 18)),
                      label: const Text('Test Basic Bug (Gestures)'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
    );
  }

  Widget _buildCategoryTile({required String title, required IconData icon, required Color color, required List<Widget> children}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.purpleAccent,
    );
  }

  Widget _buildUserList() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        
        final users = snapshot.data?.docs ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Registered Explorers:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${users.length}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                itemCount: users.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = users[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    dense: true,
                    title: Text(data['email'] ?? 'Unknown Email'),
                    subtitle: Text('ID: ${doc.id}', style: const TextStyle(fontSize: 10)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(data['username'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('v${data['appVersion'] ?? 'old'}', style: const TextStyle(fontSize: 9, color: Colors.blueGrey)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Registry of all players synchronized from RTDB.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
      ),
    );
  }

  Widget _buildSliderTile(String title, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            Text(value.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          activeColor: Colors.orangeAccent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../network_manager.dart';
import '../location_manager.dart';
import '../sensor_manager.dart';
import 'friends_screen.dart';
import 'edit_profile_dialog.dart';
import 'voice_calibration_screen.dart';
import 'inventory_screen.dart';
import 'crafting_screen.dart';
import '../admin_screen.dart';
import 'admin_settings_screen.dart';

class ProfileDrawer extends StatefulWidget {
  const ProfileDrawer({super.key});

  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  int _userXp = 0;
  int _userEnergy = 0;
  StreamSubscription? _xpSubscription;
  StreamSubscription? _energySubscription;

  @override
  void initState() {
    super.initState();
    // Fetch initial cached values
    _userXp = SensorManager().userXp;
    _userEnergy = SensorManager().userEnergy;

    // Listen to changes while drawer is open
    _xpSubscription = SensorManager().xpStream.listen((xp) {
      if (mounted) setState(() => _userXp = xp);
    });
    _energySubscription = SensorManager().energyStream.listen((energy) {
      if (mounted) setState(() => _userEnergy = energy);
    });
  }

  Future<void> _logout(BuildContext context) async {
    // Stop background services before logging out
    NetworkManager().stop();
    LocationManager().stopTracking();
    
    // Sign out from both Firebase and Google
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _xpSubscription?.cancel();
    _energySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String email = user?.email ?? 'Unknown Explorer';
    final String? photoUrl = user?.photoURL;

    return Drawer(
      child: StreamBuilder<DocumentSnapshot>(
        stream: user != null
            ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots()
            : const Stream.empty(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint("[PROFILE] Firestore stream error: ${snapshot.error}");
          }
          
          final data = (snapshot.hasData && snapshot.data!.exists)
              ? snapshot.data!.data() as Map<String, dynamic>
              : <String, dynamic>{};

          final bool isAdmin = data['isAdmin'] == true;
          if (snapshot.hasData) {
             debugPrint("[PROFILE] data loaded, isAdmin: $isAdmin");
          }
          
          String displayEmail = email;
          String displayName = 'Level ${(_userXp / 100).floor() + 1}';
          Widget? avatar;

          if (data['username'] != null && data['username'].toString().isNotEmpty) {
            displayName = '${data['username']} (Lv ${(_userXp / 100).floor() + 1})';
          }
          
          if (data['avatarBase64'] != null) {
            avatar = CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: MemoryImage(base64Decode(data['avatarBase64'])),
            );
          } else if (data['username'] != null && data['username'].toString().isNotEmpty) {
            final seed = Uri.encodeComponent(data['username']);
            avatar = CircleAvatar(
              backgroundColor: Colors.grey[200],
              backgroundImage: NetworkImage('https://api.dicebear.com/8.x/pixel-art/png?seed=$seed'),
            );
          }

          avatar ??= CircleAvatar(
            backgroundColor: Colors.white,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null ? const Icon(Icons.person, size: 40, color: Colors.grey) : null,
          );

          return Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blueAccent, Colors.purpleAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                currentAccountPicture: GestureDetector(
                  onTap: () => showDialog(context: context, builder: (c) => const EditProfileDialog()),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      avatar,
                      Container(
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.edit, size: 14, color: Colors.blueAccent),
                      ),
                    ],
                  ),
                ),
                accountName: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                accountEmail: Text(displayEmail),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn('Energy', '$_userEnergy', Colors.orange, Icons.flash_on),
                        _buildStatColumn('XP', '$_userXp', Colors.blue, Icons.star),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (data['stats'] != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.military_tech, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            'Kills: ${data['stats']['totalKills'] ?? 0}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const Divider(),

              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Friends'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('Voice Calibration'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const VoiceCalibrationScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2),
                title: const Text('Inventory'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.build),
                title: const Text('Crafting & Building'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CraftingScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.military_tech, color: Colors.orange),
                title: const Text('Achievements'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  _showAchievementsDialog(context, data['achievements'] ?? []);
                },
              ),
              if (isAdmin) ...[
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Colors.orangeAccent),
                  title: const Text('Admin Panel', style: TextStyle(color: Colors.orangeAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.indigoAccent),
                  title: const Text('Generation Settings', style: TextStyle(color: Colors.indigoAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSettingsScreen()));
                  },
                ),
              ],
              
              const Spacer(),
              const Divider(),
              
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
                onTap: () => _logout(context),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
  void _showAchievementsDialog(BuildContext context, List<dynamic> achievements) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.military_tech, color: Colors.orange),
            SizedBox(width: 8),
            Text('Your Achievements'),
          ],
        ),
        content: achievements.isEmpty 
          ? const Text('Defeat monsters to earn badges!')
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: achievements.map((a) => ListTile(
                leading: const Icon(Icons.workspace_premium, color: Colors.amber),
                title: Text(a.toString()),
              )).toList(),
            ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}

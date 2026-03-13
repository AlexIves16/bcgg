import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../network_manager.dart';

class CraftingScreen extends StatefulWidget {
  final bool isNearWorkbench;
  const CraftingScreen({super.key, this.isNearWorkbench = false});

  @override
  State<CraftingScreen> createState() => _CraftingScreenState();
}

class _CraftingScreenState extends State<CraftingScreen> {
  Position? _currentPos;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _currentPos = pos);
    } catch (e) {
      debugPrint("Error getting location for crafting: $e");
    }
  }

  final List<Map<String, dynamic>> recipes = [
    {
      'id': 'craft_wall_wood',
      'name': 'Wooden Wall',
      'description': 'A basic defensive structure for your base.',
      'icon': Icons.grid_view,
      'color': Colors.brown,
      'ingredients': {'fiber': 5, 'shard': 2},
    },
    {
      'id': 'craft_torch',
      'name': 'Ether Torch',
      'description': 'Illuminate your territory with ethereal light.',
      'icon': Icons.lightbulb,
      'color': Colors.amber,
      'ingredients': {'essence': 3, 'shard': 1},
    },
    {
      'id': 'craft_workbench',
      'name': 'Workbench',
      'description': 'Required for advanced crafting (Tools).',
      'icon': Icons.build_circle,
      'color': Colors.blueAccent,
      'ingredients': {'fiber': 10, 'shard': 5, 'meat': 2},
    },
    {
      'id': 'craft_axe_wood',
      'name': 'Wooden Axe',
      'description': 'Efficiently chop trees for wood.',
      'icon': Icons.handyman,
      'color': Colors.greenAccent,
      'ingredients': {'fiber': 5, 'shard': 3},
      'requiresWorkbench': true,
    },
    {
      'id': 'craft_pickaxe_wood',
      'name': 'Wooden Pickaxe',
      'description': 'Mine rocks and ores for stone.',
      'icon': Icons.gavel,
      'color': Colors.orangeAccent,
      'ingredients': {'fiber': 5, 'shard': 3},
      'requiresWorkbench': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Please log in')));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Crafting & Building', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final inventory = data?['inventory'] as Map<String, dynamic>? ?? {};

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              final isLocked = (recipe['requiresWorkbench'] == true && !widget.isNearWorkbench);
              return _buildRecipeCard(recipe, inventory, isLocked);
            },
          );
        },
      ),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe, Map<String, dynamic> inventory, bool isLocked) {
    final ingredients = recipe['ingredients'] as Map<String, dynamic>; // Changed to dynamic for safety
    bool hasAll = true;
    
    List<Widget> ingredientWidgets = [];
    ingredients.forEach((id, amount) {
      final count = inventory[id] ?? 0;
      final hasEnough = count >= amount;
      if (!hasEnough) hasAll = false;
      
      ingredientWidgets.add(
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _getItemIcon(id, 16),
              const SizedBox(width: 4),
              Text(
                '$count/$amount',
                style: TextStyle(
                  color: hasEnough ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold
                ),
              ),
            ],
          ),
        ),
      );
    });

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: recipe['color'].withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: recipe['color'].withOpacity(0.2),
                  child: Icon(recipe['icon'] as IconData, color: recipe['color']),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipe['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(recipe['description'] as String, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Requirements:', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(children: ingredientWidgets),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (hasAll && _currentPos != null && !isLocked) 
                  ? () {
                      NetworkManager().craftItem(recipe['id'] as String, _currentPos!.latitude, _currentPos!.longitude);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Building ${recipe['name']}...'), backgroundColor: Colors.blueAccent),
                      );
                      Navigator.pop(context);
                    }
                  : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: recipe['color'],
                  disabledBackgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  isLocked ? 'Workbench Required' : (hasAll ? 'Craft Now' : 'Missing Materials'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_currentPos == null)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Waiting for GPS...', style: TextStyle(color: Colors.orangeAccent, fontSize: 10)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _getItemIcon(String id, double size) {
    if (id == 'shard') return Icon(Icons.diamond, color: Colors.purpleAccent, size: size);
    if (id == 'fiber') return Icon(Icons.gesture, color: Colors.greenAccent, size: size);
    if (id == 'essence') return Icon(Icons.wb_sunny, color: Colors.cyanAccent, size: size);
    if (id == 'meat') return Icon(Icons.restaurant, color: Colors.redAccent, size: size);
    return Icon(Icons.category, color: Colors.grey, size: size);
  }
}

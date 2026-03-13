import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../network_manager.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Please log in')));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Inventory', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final inventory = data?['inventory'] as Map<String, dynamic>? ?? {};
          final equipment = data?['equipment'] as Map<String, dynamic>? ?? {};
          final String? equippedTool = equipment['tool']?.toString();

          final items = inventory.entries.toList();

          return Column(
            children: [
              if (equippedTool != null)
                _buildEquippedSection(equippedTool),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75, // Adjusted for button
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final entry = items[index];
                    final String name = entry.key;
                    final int count = entry.value as int;

                    return _buildItemCard(name, count, isEquipped: name == equippedTool);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemCard(String id, int count, {bool isEquipped = false}) {
    String label = id.toUpperCase();
    IconData icon = Icons.category;
    Color color = Colors.grey;
    bool isTool = false;

    // Item definitions
    if (id == 'shard') { label = 'Shadow Shard'; icon = Icons.diamond; color = Colors.purpleAccent; }
    else if (id == 'meat') { label = 'Monster Meat'; icon = Icons.restaurant; color = Colors.redAccent; }
    else if (id == 'fiber') { label = 'Woven Fiber'; icon = Icons.gesture; color = Colors.greenAccent; }
    else if (id == 'essence') { label = 'Ethereal Essence'; icon = Icons.wb_sunny; color = Colors.cyanAccent; }
    else if (id == 'magic') { label = 'Magic Dust'; icon = Icons.auto_awesome; color = Colors.amberAccent; }
    else if (id == 'axe-wood') { label = 'Wooden Axe'; icon = Icons.handyman; color = Colors.greenAccent; isTool = true; }
    else if (id == 'pickaxe-wood') { label = 'Wooden Pickaxe'; icon = Icons.gavel; color = Colors.orangeAccent; isTool = true; }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isEquipped ? Colors.cyanAccent : color.withOpacity(0.3), width: isEquipped ? 2 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('x$count', style: TextStyle(color: color, fontSize: 11)),
          if (isTool)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SizedBox(
                height: 24,
                child: ElevatedButton(
                  onPressed: isEquipped ? null : () => NetworkManager().equipTool(id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: Text(isEquipped ? 'Active' : 'Equip', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEquippedSection(String toolId) {
    String label = toolId.replaceFirst('-', ' ').toUpperCase();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.cyanAccent.withOpacity(0.2), Colors.transparent]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.flash_on, color: Colors.cyanAccent),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('EQUIPPED TOOL', style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

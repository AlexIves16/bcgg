import 'package:flutter/material.dart';

void showInteractionMenu({
  required BuildContext context,
  required dynamic element,
  required Function(dynamic) onMonsterTap,
  required Function(dynamic) onCloudTap,
  required Function(dynamic) onWorkbenchTap,
  required Function(dynamic) onLootTap,
  required Function(dynamic) onBaseTap,
  required Function(dynamic) onHarvestTap,
}) {
  // Handle null element - should not happen but just in case
  if (element == null) {
    debugPrint('[InteractionMenu] ERROR: element is null, this should not happen!');
    return;
  }
  
  final String type = element['type']?.toString() ?? '';
  final String objectTypeId = element['objectTypeId']?.toString() ?? '';
  final String name = element['name'] ?? 'Object';

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
          Text(
            name.toUpperCase(),
            style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const Divider(color: Colors.white24, height: 24),
          
          if (type == 'wild-bug' || type == 'banshee' || type == 'siren')
            _buildInteractionTile(
              icon: Icons.flash_on,
              label: 'BATTLE',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                onMonsterTap(element);
              },
            ),
            
          if (type == 'energy_cloud')
            _buildInteractionTile(
              icon: Icons.bolt,
              label: 'HARVEST ENERGY',
              color: Colors.cyanAccent,
              onTap: () {
                Navigator.pop(context);
                onCloudTap(element);
              },
            ),

          if (objectTypeId == 'workbench')
            _buildInteractionTile(
              icon: Icons.build,
              label: 'USE WORKBENCH',
              color: Colors.brown,
              onTap: () {
                Navigator.pop(context);
                onWorkbenchTap(element);
              },
            ),

          if (type == 'tree' || type == 'plant' || type == 'rock' || type == 'ore')
             _buildInteractionTile(
              icon: Icons.pan_tool,
              label: 'HARVEST RESOURCE',
              color: Colors.greenAccent,
              onTap: () {
                Navigator.pop(context);
                onHarvestTap(element);
              },
            ),

          if (type == 'loot')
            _buildInteractionTile(
              icon: Icons.inventory_2,
              label: 'COLLECT LOOT',
              color: Colors.amberAccent,
              onTap: () {
                Navigator.pop(context);
                onLootTap(element);
              },
            ),

          if (type == 'base')
            _buildInteractionTile(
              icon: Icons.settings,
              label: 'MANAGE BASE',
              color: Colors.blueAccent,
              onTap: () {
                Navigator.pop(context);
                onBaseTap(element);
              },
            ),
            
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    ),
  );
}

Widget _buildInteractionTile({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
  return ListTile(
    leading: Icon(icon, color: color),
    title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
    trailing: const Icon(Icons.chevron_right, color: Colors.white30),
    onTap: onTap,
  );
}

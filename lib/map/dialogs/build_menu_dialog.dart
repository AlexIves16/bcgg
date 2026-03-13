import 'package:flutter/material.dart';
import '../../network_manager.dart';
import 'physical_action_dialog.dart';

void showBuildMenuDialog(BuildContext context, dynamic baseInfo, double lat, double lng) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => BuildMenuSheet(baseInfo: baseInfo, lat: lat, lng: lng),
  );
}

class BuildMenuSheet extends StatelessWidget {
  final dynamic baseInfo;
  final double lat;
  final double lng;

  const BuildMenuSheet({super.key, required this.baseInfo, required this.lat, required this.lng});

  void _performActionWithPhysicalCheck(BuildContext context, String title, String description, int shakes, VoidCallback onComplete) async {
    final bool? success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PhysicalActionDialog(
        title: title,
        actionDescription: description,
        requiredShakes: shakes,
      ),
    );

    if (success == true) {
      onComplete();
      if (context.mounted) {
        Navigator.pop(context); // Close the build menu
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasBase = baseInfo != null;
    int currentLevel = hasBase ? (baseInfo['level'] ?? 1) : 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E), // Dark theme
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
             width: 40, height: 5,
             decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 16),
          const Text('Build Menu', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 20),
          
          if (!hasBase) ...[
            _buildOption(
              context,
              icon: '🏕️',
              title: 'Primary Camp (Первичный лагерь)',
              subtitle: 'Safe Radius: 50m. Protects from monsters.',
              buttonText: 'Establish',
              onPressed: () {
                _performActionWithPhysicalCheck(
                  context, 
                  'Chopping Wood & Clearing Area', 
                  'Shake your device to establish the camp!', 
                  15, 
                  () => NetworkManager().establishBase(lat, lng)
                );
              },
            ),
          ] else ...[
            if (currentLevel < 3)
              _buildOption(
                context,
                icon: currentLevel == 1 ? '🛖' : '🏠',
                title: currentLevel == 1 ? 'Upgrade to Hut' : 'Upgrade to House',
                subtitle: 'Expands Safe Radius by 10m. Costs Wood & Stone.',
                buttonText: 'Upgrade',
                onPressed: () {
                  _performActionWithPhysicalCheck(
                    context, 
                    'Upgrading Base', 
                    'Shake your device to build the upgrade!', 
                    20, 
                    () => NetworkManager().upgradeBase()
                  );
                },
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Base is at Maximum Level (🏠 House)', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ),
              
            const Divider(color: Colors.white24, height: 30),
            
            _buildOption(
              context,
              icon: '🪚',
              title: 'Workbench (Верстак)',
              subtitle: 'Allows crafting of advanced tools and items.',
              buttonText: 'Build',
              onPressed: () {
                _performActionWithPhysicalCheck(
                  context, 
                  'Crafting Workbench', 
                  'Shake to assemble the workbench!', 
                  15, 
                  () => NetworkManager().craftItem('craft_workbench', lat, lng)
                );
              },
            ),
             _buildOption(
              context,
              icon: '🌱',
              title: 'Garden Bed (Грядка)',
              subtitle: 'Grow herbs and healing plants.',
              buttonText: 'Build',
              onPressed: () {
                _performActionWithPhysicalCheck(
                  context, 
                  'Digging the Soil', 
                  'Shake to prepare the garden bed!', 
                  10, 
                  // Assuming we will add garden bed recipe later, for now simulate:
                  () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Garden Bed blueprint unlocked!'))); }
                );
              },
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, {required String icon, required String title, required String subtitle, required String buttonText, required VoidCallback onPressed}) {
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Text(icon, style: const TextStyle(fontSize: 32)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          child: Text(buttonText),
        ),
      ),
    );
  }
}

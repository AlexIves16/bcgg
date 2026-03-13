import 'package:flutter/material.dart';
import '../../network_manager.dart';

void showBaseManagementDialog(BuildContext context, dynamic element, String? userId) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text(element['name'] ?? 'Base Management', style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Safe Zone: ${element['safeRadius'] ?? 50}m', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          const Text('Allowed Players:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ...(element['allowedPlayers'] as List? ?? []).map((p) => 
            Text('• $p', style: const TextStyle(color: Colors.white70))
          ),
        ],
      ),
      actions: [
        if (element['ownerId'] == userId)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showInviteDialog(context, element['id']);
            },
            child: const Text('Invite Player', style: TextStyle(color: Colors.blueAccent)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.white54)),
        ),
      ],
    ),
  );
}

void _showInviteDialog(BuildContext context, String baseId) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('Invite to Base', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Enter Player Email or Username',
          hintStyle: TextStyle(color: Colors.white38),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (controller.text.isNotEmpty) {
              NetworkManager().inviteToBase(controller.text);
              Navigator.pop(context);
            }
          },
          child: const Text('Invite'),
        ),
      ],
    ),
  );
}

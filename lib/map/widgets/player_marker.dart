import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/entity.dart';

/// Widget for displaying player markers on the map
class PlayerMarker extends StatelessWidget {
  final PlayerEntity player;
  final bool isMe;
  final VoidCallback? onTap;

  const PlayerMarker({
    super.key,
    required this.player,
    this.isMe = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar;

    if (player.avatarBase64 != null && player.avatarBase64!.isNotEmpty) {
      avatar = CircleAvatar(
        backgroundImage: MemoryImage(base64Decode(player.avatarBase64!)),
        backgroundColor: Colors.white,
        radius: 20,
      );
    } else if (player.username != null && player.username!.trim().isNotEmpty) {
      final seed = Uri.encodeComponent(player.username!);
      avatar = CircleAvatar(
        backgroundImage: NetworkImage(
          'https://api.dicebear.com/8.x/pixel-art/png?seed=$seed',
        ),
        backgroundColor: Colors.grey[200],
        radius: 20,
      );
    } else {
      avatar = const Icon(
        Icons.person_pin_circle,
        color: Colors.purple,
        size: 40.0,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: avatar,
    );
  }
}

import 'package:flutter/material.dart';
import '../models/entity.dart';

/// Widget for displaying loot markers on the map
class LootMarker extends StatelessWidget {
  final LootEntity loot;
  final VoidCallback? onTap;

  const LootMarker({
    super.key,
    required this.loot,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        Icons.shopping_bag,
        color: Colors.orange[700],
        size: 30.0,
      ),
    );
  }
}

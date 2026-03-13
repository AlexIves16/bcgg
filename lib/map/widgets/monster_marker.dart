import 'package:flutter/material.dart';
import '../models/entity.dart';

/// Widget for displaying monster markers on the map
class MonsterMarker extends StatelessWidget {
  final MonsterEntity monster;
  final VoidCallback? onTap;

  const MonsterMarker({
    super.key,
    required this.monster,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        Icons.bug_report,
        color: Colors.red[700],
        size: 35.0,
      ),
    );
  }
}

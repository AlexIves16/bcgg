import 'package:flutter/material.dart';
import '../models/entity.dart';

/// Widget for displaying base markers on the map
class BaseMarker extends StatelessWidget {
  final BaseEntity base;
  final VoidCallback? onTap;

  const BaseMarker({
    super.key,
    required this.base,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        Icons.castle,
        color: Colors.amber[700],
        size: 35.0,
      ),
    );
  }
}

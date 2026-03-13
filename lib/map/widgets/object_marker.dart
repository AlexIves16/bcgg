import 'package:flutter/material.dart';
import '../models/entity.dart';

/// Widget for displaying interactive object markers on the map
class ObjectMarker extends StatelessWidget {
  final ObjectEntity object;
  final VoidCallback? onTap;

  const ObjectMarker({
    super.key,
    required this.object,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        Icons.work,
        color: Colors.green[700],
        size: 35.0,
      ),
    );
  }
}

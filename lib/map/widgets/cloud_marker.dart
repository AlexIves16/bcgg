import 'package:flutter/material.dart';
import '../models/entity.dart';

/// Widget for displaying energy cloud markers on the map
class CloudMarker extends StatelessWidget {
  final CloudEntity cloud;
  final VoidCallback? onTap;

  const CloudMarker({
    super.key,
    required this.cloud,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        Icons.cloud,
        color: Colors.lightBlue[300],
        size: 40.0,
      ),
    );
  }
}

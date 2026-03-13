import 'package:flutter/material.dart';

class AnimatedEntityWidget extends StatefulWidget {
  final dynamic elementData;
  final VoidCallback? onTap;

  const AnimatedEntityWidget({
    super.key,
    required this.elementData,
    this.onTap,
  });

  @override
  State<AnimatedEntityWidget> createState() => _AnimatedEntityWidgetState();
}

class _AnimatedEntityWidgetState extends State<AnimatedEntityWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _bounceAnimation = Tween(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut)
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Handle null elementData
    if (widget.elementData == null) {
      return const Text('❓', style: TextStyle(fontSize: 40));
    }
    
    final type = widget.elementData['type']?.toString() ?? '';
    final objectTypeId = widget.elementData['objectTypeId']?.toString() ?? '';
    
    String emoji = '❓';
    String label = 'Unknown';

    // Expanded Mappings
    if (type == 'energy_cloud') {
      emoji = '☁️';
      label = 'Energy';
    } else if (type == 'banshee') {
      emoji = '👻';
      label = 'Banshee';
    } else if (type == 'siren') {
      emoji = '🧜‍♀️';
      label = 'Siren';
    } else if (type == 'golem') {
      emoji = '🗿';
      label = 'Golem';
    } else if (type == 'wraith') {
      emoji = '🧟';
      label = 'Wraith';
    } else if (type == 'elemental') {
      emoji = '🌪️';
      label = 'Elemental';
    } else if (type == 'loot') {
      emoji = '🎁';
      label = 'Loot';
    } else if (type == 'building') {
      emoji = objectTypeId == 'wall-wood' ? '🧱' : '🏮';
      label = widget.elementData['name'] ?? 'Building';
    } else if (objectTypeId.contains('ancient-relic')) {
      emoji = '🏺';
      label = 'Ancient Relic';
    } else if (objectTypeId.contains('grass')) {
      emoji = '🌿';
      label = 'Wild Grass';
    } else if (objectTypeId.contains('ruins')) {
      emoji = '🏛️';
      label = 'Old Ruins';
    } else if (objectTypeId.contains('oak') || objectTypeId.contains('pine') || objectTypeId.contains('palm')) {
      emoji = '🌳';
      label = 'Tree';
    } else if (objectTypeId == 'workbench') {
      emoji = '⚒️';
      label = 'Workbench';
    } else if (type == 'wild-bug') {
      emoji = '🐞';
      label = '${widget.elementData['rank'] != null ? '${widget.elementData['rank']} ' : ''}Wild Bug';
    }

    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_bounceAnimation.value),
          child: child,
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 40),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              constraints: const BoxConstraints(maxWidth: 90),
              child: Text(
                label,
                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

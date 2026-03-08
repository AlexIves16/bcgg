import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'network_manager.dart';
import 'sensor_manager.dart';
import 'gesture_recognizer.dart';

class GestureCombatScreen extends StatefulWidget {
  final dynamic monster;

  const GestureCombatScreen({super.key, required this.monster});

  @override
  State<GestureCombatScreen> createState() => _GestureCombatScreenState();
}

class _GestureCombatScreenState extends State<GestureCombatScreen> {
  int _timeLeft = 15;
  Timer? _timer;
  
  bool _isDrawing = false;
  List<Offset> _points = [];
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  
  // Smoothing and position tracking
  double _px = 0, _py = 0;
  double _filteredX = 0, _filteredY = 0;
  
  // Base calibration values (tuned by user)
  final double _alpha = 1.0; // 1.0 = Pure raw sensor data, no smoothing delay
  final double _deadzone = 0.5;
  final double _scale = 20.0;

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.monster['timeLimit'] ?? 15;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _failCombat();
        }
      });
    });
  }

  void _failCombat() {
    _timer?.cancel();
    _stopSensors();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time is up! The monster escaped!'), backgroundColor: Colors.orange),
      );
      Navigator.of(context).pop(); // Return to map
    }
  }

  void _winCombat() {
    _timer?.cancel();
    _stopSensors();
    NetworkManager().killMonster(widget.monster['id']);
    NetworkManager().logActivity('kill_monster', 50);
    SensorManager().addXP(50);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You drew a ${widget.monster['requiredShape']}! +50 XP'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(); // Return to map
    }
  }

  void _startDrawing() {
    setState(() {
      _isDrawing = true;
      _points.clear();
      _px = 0; _py = 0;
      _filteredX = 0; _filteredY = 0;
    });

    _gyroSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      // 1. ПРИМЕНЯЕМ LOW-PASS FILTER (Сглаживание шума)
      // Rot X (pitch) moves phone Up/Down (Y axis on screen)
      // Rot Y (yaw) moves phone Left/Right (X axis on screen, inverted)
      _filteredX = _alpha * (-event.y) + (1 - _alpha) * _filteredX;
      _filteredY = _alpha * (-event.x) + (1 - _alpha) * _filteredY;

      // 2. Игнорируем микро-движения (мертвая зона)
      double dx = _filteredX;
      double dy = _filteredY;
      if (dx.abs() < _deadzone) dx = 0;
      if (dy.abs() < _deadzone) dy = 0;

      // 3. ОБНОВЛЯЕМ ПОЗИЦИЮ (интеграция вращения в перемещение кисти)
      _px += dx * _scale;
      _py += dy * _scale;
      
      if (mounted) {
        setState(() {
          _points.add(Offset(_px, _py));
        });
      }
    });
  }

  void _stopDrawing() {
    _stopSensors();
    setState(() {
      _isDrawing = false;
    });
    _analyzeShape();
  }

  void _stopSensors() {
    _gyroSubscription?.cancel();
  }

  void _analyzeShape() {
    if (_points.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drawing too short! Try again.')),
      );
      return;
    }

    String requiredShape = widget.monster['requiredShape'];

    double bestScore = GestureRecognizer.traceScore(_points, requiredShape, 120.0);
    
    // Check Result
    bool success = (bestScore > 0.6); // 60% match threshold
    
    if (success) {
      _winCombat();
    } else {
      if (mounted) {
        String msg = 'Match: ${(bestScore * 100).toStringAsFixed(1)}%. Trace the $requiredShape closer!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg), 
            backgroundColor: Colors.red
          ),
        );
        setState(() {
           _points.clear();
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopSensors();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String shape = widget.monster['requiredShape'] ?? 'unknown';
    IconData shapeIcon = Icons.help_outline;
    if (shape == 'circle') shapeIcon = Icons.circle_outlined;
    if (shape == 'square') shapeIcon = Icons.crop_square;
    if (shape == 'triangle') shapeIcon = Icons.change_history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Combat!'),
        backgroundColor: Colors.red[900],
        automaticallyImplyLeading: false, // Prevent simple back button escape
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Monster: ${widget.monster['type']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('HP: ${widget.monster['hp']}', style: const TextStyle(fontSize: 16)),
                  ],
                ),
                Text('$_timeLeft s', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange)),
              ],
            ),
          ),
          const Divider(),
          const SizedBox(height: 20),
          const Text('Draw this shape with your phone:', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 10),
          Icon(shapeIcon, size: 80, color: Colors.white),
          const SizedBox(height: 20),
          
          // Drawing Canvas
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white30),
                color: Colors.black26,
                borderRadius: BorderRadius.circular(16)
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: TrajectoryPainter(
                    points: _points, 
                    templateShape: widget.monster['requiredShape'] ?? 'circle',
                    radius: 120.0
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _startDrawing(),
              onTapUp: (_) => _stopDrawing(),
              onTapCancel: () => _stopDrawing(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 240,
                height: 80,
                decoration: BoxDecoration(
                  color: _isDrawing ? Colors.redAccent : Colors.blueAccent,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    if (!_isDrawing)
                       BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
                  ]
                ),
                child: Center(
                  child: Text(
                    _isDrawing ? 'DRAWING...' : 'HOLD TO DRAW',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TrajectoryPainter extends CustomPainter {
  final List<Offset> points;
  final String templateShape;
  final double radius;

  TrajectoryPainter({required this.points, required this.templateShape, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    Offset canvasCenter = Offset(size.width / 2, size.height / 2);

    // 1. Отрисовка шаблона (полупрозрачного)
    final templatePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    List<Offset> templatePoints = [];
    if (templateShape == 'circle') templatePoints = GestureRecognizer.generateCircleTemplate();
    if (templateShape == 'square') templatePoints = GestureRecognizer.generateSquareTemplate();
    if (templateShape == 'triangle') templatePoints = GestureRecognizer.generateTriangleTemplate();

    if (templatePoints.isNotEmpty) {
      Path templatePath = Path();
      templatePath.moveTo(
        canvasCenter.dx + templatePoints[0].dx * radius,
        canvasCenter.dy + templatePoints[0].dy * radius,
      );
      for (int i = 1; i < templatePoints.length; i++) {
        templatePath.lineTo(
          canvasCenter.dx + templatePoints[i].dx * radius,
          canvasCenter.dy + templatePoints[i].dy * radius,
        );
      }
      canvas.drawPath(templatePath, templatePaint);
    }

    // Если нет точек, только рисуем курсор по центру
    if (points.isEmpty) {
       canvas.drawCircle(canvasCenter, 6.0, Paint()..color = Colors.redAccent);
       return;
    }

    // 2. Отрисовка пути игрока без автомасштабирования
    final paint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    Path path = Path();
    var p0 = Offset(canvasCenter.dx + points[0].dx, canvasCenter.dy + points[0].dy);
    path.moveTo(p0.dx, p0.dy);

    if (points.length == 2) {
       var p1 = Offset(canvasCenter.dx + points[1].dx, canvasCenter.dy + points[1].dy);
       path.lineTo(p1.dx, p1.dy);
    } else if (points.length > 2) {
      var pPrev = p0;
      for (int i = 1; i < points.length - 1; i++) {
          var p1 = Offset(canvasCenter.dx + points[i].dx, canvasCenter.dy + points[i].dy);
          var p2 = Offset(canvasCenter.dx + points[i+1].dx, canvasCenter.dy + points[i+1].dy);
          
          var xc = (p1.dx + p2.dx) / 2;
          var yc = (p1.dy + p2.dy) / 2;
          path.quadraticBezierTo(p1.dx, p1.dy, xc, yc);
      }
      var pLast = Offset(canvasCenter.dx + points.last.dx, canvasCenter.dy + points.last.dy);
      path.lineTo(pLast.dx, pLast.dy);
    }
    canvas.drawPath(path, paint);

    // 3. Выделяем последнюю точку как "Кисть/Курсор"
    canvas.drawCircle(
      Offset(canvasCenter.dx + points.last.dx, canvasCenter.dy + points.last.dy), 
      6.0, 
      Paint()..color = Colors.redAccent
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

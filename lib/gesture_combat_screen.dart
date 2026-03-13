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
  bool _isDodging = false;
  DateTime? _lastDodgeTime;
  String? _incomingAttackWarning;

  // Combat State
  int _timeLeft = 15;
  int _playerHp = 100;
  int _maxPlayerHp = 100;
  List<String> _sequence = [];
  int _currentSequenceIndex = 0;
  Timer? _timer;
  Timer? _combatTickTimer;

  // Drawing/Gyro State
  bool _isDrawing = false;
  final List<Offset> _points = [];
  double _px = 0, _py = 0;
  double _filteredX = 0, _filteredY = 0;
  final double _alpha = 0.2;
  final double _deadzone = 0.1;
  final double _scale = 300.0;
  StreamSubscription? _gyroSubscription;

  void _stopSensors() {
    _gyroSubscription?.cancel();
  }

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.monster['timeLimit'] ?? 15;
    _playerHp = SensorManager().userHp;
    _maxPlayerHp = SensorManager().maxHp;
    _sequence = widget.monster['combatSequence'] ?? [widget.monster['requiredShape']];
    
    _startTimer();
    _startCombatLoop();
    _startAccelerometerMonitor();
  }

  void _startAccelerometerMonitor() {
    userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      if (!mounted) return;
      // Detect a sharp movement (shake)
      if (event.x.abs() > 15 || event.y.abs() > 15 || event.z.abs() > 15) {
        if (_lastDodgeTime == null || DateTime.now().difference(_lastDodgeTime!) > const Duration(seconds: 1)) {
          _performDodge();
        }
      }
    });
  }

  void _performDodge() {
    setState(() {
      _isDodging = true;
      _lastDodgeTime = DateTime.now();
      _incomingAttackWarning = null; // Clear warning on dodge
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isDodging = false);
    });
  }

  void _startCombatLoop() {
    _combatTickTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) return;
      
      // 1. Aura Damage (Always hits, but reduced if dodging?)
      if (widget.monster['attackType'] == 'proximity_aura') {
        _takeDamage(_isDodging ? 1 : 2);
      }

      // 2. Scheduled Attacks
      final int interval = widget.monster['attackInterval'] ?? 3000;
      final int tickMs = timer.tick * 500;
      
      // Warning 1 second before attack
      if ((tickMs + 1000) % interval == 0) {
        setState(() => _incomingAttackWarning = "MONSTER ATTACKING!");
      }

      if (tickMs % interval == 0) {
        if (!_isDodging) {
          _takeDamage(widget.monster['attackPower'] ?? 10);
        } else {
          setState(() => _incomingAttackWarning = "DODGED!");
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) setState(() => _incomingAttackWarning = null);
          });
        }
      }
    });
  }

  void _takeDamage(int amount) {
    setState(() {
      _playerHp = (_playerHp - amount).clamp(0, _maxPlayerHp);
      if (_playerHp <= 0) {
        _failCombat('You were defeated!');
      }
    });
    SensorManager().takeDamage(amount);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _failCombat('Time is up! The monster escaped!');
        }
      });
    });
  }

  void _failCombat(String message) {
    _timer?.cancel();
    _combatTickTimer?.cancel();
    _stopSensors();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.orange),
      );
      Navigator.of(context).pop(); // Return to map
    }
  }

  void _winCombat() {
    if (_currentSequenceIndex < _sequence.length - 1) {
      setState(() {
        _currentSequenceIndex++;
        _points.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Next shape: ${_sequence[_currentSequenceIndex]}!'), duration: const Duration(milliseconds: 800)),
      );
      return;
    }

    _timer?.cancel();
    _combatTickTimer?.cancel();
    _stopSensors();
    NetworkManager().killMonster(widget.monster['id']);
    NetworkManager().logActivity('kill_monster', 50);
    SensorManager().addXP(50);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Victory! Monster defeated! +50 XP'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(); // Return to map
    }
  }

  void _startDrawing() {
    // SAME as before
    setState(() {
      _isDrawing = true;
      _points.clear();
      _px = 0; _py = 0;
      _filteredX = 0; _filteredY = 0;
    });

    _gyroSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      _filteredX = _alpha * (-event.y) + (1 - _alpha) * _filteredX;
      _filteredY = _alpha * (-event.x) + (1 - _alpha) * _filteredY;

      double dx = _filteredX;
      double dy = _filteredY;
      if (dx.abs() < _deadzone) dx = 0;
      if (dy.abs() < _deadzone) dy = 0;

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
    _gyroSubscription?.cancel();
    setState(() {
      _isDrawing = false;
    });
    _analyzeShape();
  }

  void _analyzeShape() {
    if (_points.length < 20) return;

    String requiredShape = _sequence[_currentSequenceIndex];
    double bestScore = GestureRecognizer.traceScore(_points, requiredShape, 120.0);
    
    if (bestScore > 0.6) {
      _winCombat();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Keep tracing the $requiredShape!'), duration: const Duration(seconds: 1)),
        );
        setState(() => _points.clear());
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _combatTickTimer?.cancel();
    _stopSensors();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String shape = _sequence[_currentSequenceIndex];
    IconData shapeIcon = shape == 'circle' ? Icons.circle_outlined : (shape == 'square' ? Icons.crop_square : Icons.change_history);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Monster Info & Player HP
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$_timeLeft s', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
                      Text('Seq: ${_currentSequenceIndex + 1}/${_sequence.length}', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Monster HP Bar
                  const LinearProgressIndicator(value: 1.0, color: Colors.red, backgroundColor: Colors.white10, minHeight: 8),
                  const SizedBox(height: 12),
                  // Player HP Bar
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.greenAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _playerHp / _maxPlayerHp,
                            minHeight: 12,
                            color: Colors.greenAccent,
                            backgroundColor: Colors.white10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    painter: TrajectoryPainter(
                      points: _points, 
                      templateShape: shape,
                      radius: 120.0
                    ),
                    size: Size.infinite,
                  ),
                  Positioned(
                    top: 40,
                    child: Column(
                      children: [
                        Text(widget.monster['name'] ?? 'Monster', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('RANK: ${widget.monster['rank']?.toString().toUpperCase()}', style: const TextStyle(color: Colors.orangeAccent)),
                        if (_incomingAttackWarning != null)
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                            child: Text(_incomingAttackWarning!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                  if (_isDodging)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueAccent, width: 4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(child: Text('DODGING!', style: TextStyle(color: Colors.blueAccent, fontSize: 40, fontWeight: FontWeight.bold))),
                    ),
                  Icon(shapeIcon, size: 100, color: Colors.white10),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(32.0),
              child: GestureDetector(
                onLongPressStart: (_) => _startDrawing(),
                onLongPressEnd: (_) => _stopDrawing(),
                child: Container(
                  width: double.infinity,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _isDrawing ? Colors.redAccent.withOpacity(0.8) : Colors.blueAccent.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Center(
                    child: Text(_isDrawing ? 'TRACING...' : 'HOLD TO START TRACING', 
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ],
        ),
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'gesture_recognizer.dart';

class GestureCalibrationScreen extends StatefulWidget {
  const GestureCalibrationScreen({super.key});

  @override
  State<GestureCalibrationScreen> createState() => _GestureCalibrationScreenState();
}

class _GestureCalibrationScreenState extends State<GestureCalibrationScreen> {
  // Calibration Variables
  double _alpha = 0.2; // Low-pass filter constant
  double _deadzone = 0.5; // Ignore movements below this
  double _damping = 0.85; // Air friction / velocity decay
  double _scale = 20.0; // Movement scale multiplier

  // Drawing state
  bool _isDrawing = false;
  List<Offset> _points = [];
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  // Gyroscope tracking
  double _px = 0, _py = 0;
  double _filteredX = 0, _filteredY = 0;
  
  String _lastShapeScores = "Draw over the template to see your score!";
  String _selectedShape = 'circle';

  void _startDrawing() {
    setState(() {
      _isDrawing = true;
      _points.clear();
      _px = 0; _py = 0;
      _filteredX = 0; _filteredY = 0;
    });

    _gyroSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      // Gyroscope provides rotation rate (rad/s)
      // Rot X (pitch) moves phone Up/Down (Y axis on screen)
      // Rot Y (yaw) moves phone Left/Right (X axis on screen, inverted)
      
      _filteredX = _alpha * (-event.y) + (1 - _alpha) * _filteredX;
      _filteredY = _alpha * (-event.x) + (1 - _alpha) * _filteredY;

      // Мертвая зона, чтобы кисть стояла ровно, пока рука покоится
      double dx = _filteredX;
      double dy = _filteredY;
      if (dx.abs() < _deadzone) dx = 0;
      if (dy.abs() < _deadzone) dy = 0;
      
      // В гироскопе мы не имитируем инерцию/скорость (velocity), мы берем чистое вращение
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
    
    // Analyze shape
    double score = GestureRecognizer.traceScore(_points, _selectedShape, 120.0);
    setState(() {
      _lastShapeScores = "Match Score: ${(score * 100).toStringAsFixed(1)}%";
    });
  }

  @override
  void dispose() {
    _gyroSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Calibration'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Column(
        children: [
          // Sliders panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white10,
            child: Column(
              children: [
                _buildSlider('Low-Pass Alpha (Smoothness)', _alpha, 0.01, 1.0, (val) => setState(() => _alpha = val)),
                _buildSlider('Deadzone (Ignore small shakes)', _deadzone, 0.0, 3.0, (val) => setState(() => _deadzone = val)),
                _buildSlider('Velocity Damping (Friction)', _damping, 0.5, 0.99, (val) => setState(() => _damping = val)),
                _buildSlider('Movement Scale (Speed)', _scale, 1.0, 100.0, (val) => setState(() => _scale = val)),
              ],
            ),
          ),
          
          // Debug values shown to the user so they can copy-paste them
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Template: ', style: TextStyle(color: Colors.white)),
                    DropdownButton<String>(
                      value: _selectedShape,
                      dropdownColor: Colors.black87,
                      style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(value: 'circle', child: Text('Circle')),
                        DropdownMenuItem(value: 'square', child: Text('Square')),
                        DropdownMenuItem(value: 'triangle', child: Text('Triangle')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedShape = val;
                            _points.clear();
                            _lastShapeScores = "Draw over the template!";
                          });
                        }
                      },
                    ),
                  ],
                ),
                SelectableText(
                  'Alpha: ${_alpha.toStringAsFixed(2)} | Deadzone: ${_deadzone.toStringAsFixed(2)} | Damping: ${_damping.toStringAsFixed(2)} | Scale: ${_scale.toStringAsFixed(1)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.yellowAccent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _lastShapeScores,
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: _lastShapeScores.contains('9') ? Colors.green : Colors.orangeAccent, 
                    fontSize: 20
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
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
                  painter: CalibrationTrajectoryPainter(
                    points: _points, 
                    templateShape: _selectedShape,
                    radius: 120.0
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _points.clear();
                    });
                  },
                  child: const Text('Clear'),
                ),
                GestureDetector(
                  onTapDown: (_) => _startDrawing(),
                  onTapUp: (_) => _stopDrawing(),
                  onTapCancel: () => _stopDrawing(),
                  child: Container(
                    width: 150,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _isDrawing ? Colors.redAccent : Colors.blueAccent,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        _isDrawing ? 'DRAWING...' : 'HOLD TO DRAW',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Expanded(flex: 3, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          flex: 4,
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 40, child: Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}

class CalibrationTrajectoryPainter extends CustomPainter {
  final List<Offset> points;
  final String templateShape;
  final double radius;

  CalibrationTrajectoryPainter({required this.points, required this.templateShape, required this.radius});

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

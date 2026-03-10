import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../audio/audio_analyzer.dart';

class VoiceCalibrationScreen extends StatefulWidget {
  const VoiceCalibrationScreen({super.key});

  @override
  State<VoiceCalibrationScreen> createState() => _VoiceCalibrationScreenState();
}

class _VoiceCalibrationScreenState extends State<VoiceCalibrationScreen> {
  final AudioAnalyzer _analyzer = AudioAnalyzer();
  final List<CalibrationTarget> _targets = [
    CalibrationTarget(name: 'А (Vowel)', type: 'vowel'),
    CalibrationTarget(name: 'Е (Vowel)', type: 'vowel'),
    CalibrationTarget(name: 'И (Vowel)', type: 'vowel'),
    CalibrationTarget(name: 'О (Vowel)', type: 'vowel'),
    CalibrationTarget(name: 'У (Vowel)', type: 'vowel'),
    CalibrationTarget(name: 'До (Note C)', type: 'note'),
    CalibrationTarget(name: 'Ре (Note D)', type: 'note'),
    CalibrationTarget(name: 'Ми (Note E)', type: 'note'),
    CalibrationTarget(name: 'Фа (Note F)', type: 'note'),
    CalibrationTarget(name: 'Соль (Note G)', type: 'note'),
    CalibrationTarget(name: 'Ля (Note A)', type: 'note'),
    CalibrationTarget(name: 'Си (Note B)', type: 'note'),
  ];

  int _currentIndex = 0;
  bool _isRecording = false;
  bool _isVerifying = false;
  
  double _realtimeSuitability = 0; // 0.0 to 1.0
  double _holdProgress = 0; // 0.0 to 1.0 (2 seconds total)
  String _stepFeedback = "Wait for stable sound...";
  
  List<double> _currentSamples = [];
  List<List<double>> _currentFftSamples = [];
  List<double> _latestFft = []; // For real visualizer
  
  // Sliding windows for stability check
  final List<double> _stabilityWindow = [];

  StreamSubscription? _pitchSub;
  StreamSubscription? _fftSub;
  Timer? _holdTimer;

  @override
  void dispose() {
    _pitchSub?.cancel();
    _fftSub?.cancel();
    _holdTimer?.cancel();
    _analyzer.stopAnalysis();
    super.dispose();
  }

  Future<void> _startStep() async {
    // print("[CALIB] _startStep called.");
    final success = await _analyzer.startAnalysis();
    // print("[CALIB] _startStep success: $success");
    if (!success) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Audio Error"),
            content: const Text("Could not start microphone. Please check permissions."),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
          ),
        );
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _isVerifying = false;
      _realtimeSuitability = 0;
      _holdProgress = 0;
      _currentSamples = [];
      _currentFftSamples = [];
      _stabilityWindow.clear();
      _stepFeedback = "Start singing...";
    });

    _pitchSub = _analyzer.pitchStream.listen((pitch) {
      if (!_isRecording) return;
      
      if (pitch != null && _targets[_currentIndex].type == 'note') {
        _currentSamples.add(pitch);
        _updateStability(pitch);
        if (math.Random().nextInt(20) == 0) {
          // debugPrint("[CALIB] Pitch: $pitch Hz, Suitability: $_realtimeSuitability");
        }
      } else if (pitch == null) {
        _decaySuitability();
      }
    });

    _fftSub = _analyzer.fftStream.listen((fft) {
      if (!_isRecording) return;
      
      if (math.Random().nextInt(10) == 0) { // Log every ~10th FFT
        // print("[CALIB] FFT received! Array length: ${fft.length}");
      }
      
      setState(() => _latestFft = fft);

      if (_targets[_currentIndex].type == 'vowel') {
        _currentFftSamples.add(fft);
        _updateFftClarity(fft);
        if (math.Random().nextInt(20) == 0) {
          // debugPrint("[CALIB] FFT Clarity Suitability: $_realtimeSuitability");
        }
      }
    });

    // Main logic timer (tick every 100ms)
    _holdTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_isRecording) {
        timer.cancel();
        return;
      }

      if (_realtimeSuitability > 0.7) {
        // High quality sound detected!
        setState(() {
          _holdProgress += 0.1 / 2.0; // 2 seconds to fill
          _stepFeedback = "Perfect! Hold it... (${(100 - _holdProgress * 100).round()}ms left)";
        });

        if (_holdProgress >= 1.0) {
          timer.cancel();
          _finishStep();
        }
      } else {
        // Quality dropped
        setState(() {
          _holdProgress = math.max(0, _holdProgress - 0.05); // Rapid decay if lost
          if (_realtimeSuitability < 0.2) {
            _stepFeedback = "No sound detected or too much noise.";
          } else {
            _stepFeedback = "Try to keep the sound steady and clear.";
          }
        });
      }
    });
  }

  void _updateStability(double pitch) {
    _stabilityWindow.add(pitch);
    if (_stabilityWindow.length > 10) _stabilityWindow.removeAt(0);

    if (_stabilityWindow.length >= 5) {
      double avg = _stabilityWindow.reduce((a, b) => a + b) / _stabilityWindow.length;
      double variance = _stabilityWindow.map((s) => math.pow(s - avg, 2)).reduce((a, b) => a + b) / _stabilityWindow.length;
      double stdDev = math.sqrt(variance);
      
      // StdDev < 25Hz is a reasonable stability for human voice
      double suitability = (1.0 - (stdDev / 25.0)).clamp(0.0, 1.0);
      setState(() => _realtimeSuitability = suitability);
    }
  }

  void _updateFftClarity(List<double> fft) {
    // Ignore low-frequency noise for suitability check too
    final int startBin = (150 * AudioAnalyzer.bufferSize / AudioAnalyzer.sampleRate).floor();
    final List<double> cleanFft = fft.sublist(math.min(fft.length, startBin));
    
    if (cleanFft.isEmpty) return;

    double mean = cleanFft.reduce((a, b) => a + b) / cleanFft.length;
    double maxPeak = cleanFft.reduce((a, b) => math.max(a, b));
    
    // Peak should be at least 6x higher than background noise (down from 8x)
    double suitability = (maxPeak / (mean * 6)).clamp(0.0, 1.0);
    setState(() => _realtimeSuitability = suitability);
  }

  void _decaySuitability() {
    setState(() {
      _realtimeSuitability = math.max(0, _realtimeSuitability - 0.1);
    });
  }

  void _finishStep() {
    _pitchSub?.cancel();
    _fftSub?.cancel();
    _holdTimer?.cancel();
    _analyzer.stopAnalysis();

    final target = _targets[_currentIndex];

    if (target.type == 'note') {
      if (_currentSamples.length > 5) {
        target.value = _currentSamples.reduce((a, b) => a + b) / _currentSamples.length;
      }
    } else {
      if (_currentFftSamples.isNotEmpty) {
        List<double> avgFft = List.filled(_currentFftSamples[0].length, 0.0);
        for (var sample in _currentFftSamples) {
          for (int i = 0; i < sample.length; i++) {
            avgFft[i] += sample[i];
          }
        }
        for (int i = 0; i < avgFft.length; i++) avgFft[i] /= _currentFftSamples.length;
        target.formants = _analyzer.getDominantFrequencies(avgFft, 3);
      }
    }

    setState(() {
      _isRecording = false;
      _isVerifying = true;
      _stepFeedback = "Step Complete! Resonance captured.";
    });
  }

  void _confirmStep() {
    setState(() {
      _isVerifying = false;
      _currentIndex++;
    });

    if (_currentIndex >= _targets.length) {
      _saveCalibration();
    }
  }

  void _retryStep() {
    setState(() {
      _isVerifying = false;
      _holdProgress = 0;
    });
  }

  Future<void> _saveCalibration() async {
    debugPrint("[AUDIO] Saving voice calibration to Firestore...");
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("[AUDIO] Error: User is null during save!");
      _showError("You must be logged in to save calibration.");
      return;
    }

    try {
      final data = {
        'timestamp': FieldValue.serverTimestamp(),
        'vowels': {
          for (var t in _targets.where((t) => t.type == 'vowel'))
            t.name.split(' ')[0]: t.formants ?? []
        },
        'notes': {
          for (var t in _targets.where((t) => t.type == 'note'))
            t.name.split(' ')[0]: t.value ?? 0.0
        }
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'voiceCalibration': data}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      debugPrint("[AUDIO] Calibration saved successfully!");

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Calibration Complete!'),
            content: const Text('Your voice profile has been saved. You are ready for sonic combat!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Pop dialog
                  Navigator.of(context).pop(); // Pop screen
                },
                child: const Text('Awesome'),
              )
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("[AUDIO] Error saving calibration: $e");
      _showError("Failed to save calibration: $e");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error Saving'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              setState(() {
                _currentIndex = 0; // Reset to allow retry or exit
              });
            },
            child: const Text('Go Back'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), // Exit
            child: const Text('Exit Anyway'),
          )
        ],
      ),
    ).then((exit) {
      if (exit == true && mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= _targets.length) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final target = _targets[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Calibration')),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Step ${_currentIndex + 1} of ${_targets.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              'Please Sing:',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              target.name,
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            if (_isRecording) ...[
              // Real-time Suitability Meter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 50),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Sound Quality", style: TextStyle(color: Colors.white38, fontSize: 12)),
                        Text("${(_realtimeSuitability * 100).round()}%", style: TextStyle(color: _realtimeSuitability > 0.7 ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _realtimeSuitability,
                        backgroundColor: Colors.white10,
                        color: _realtimeSuitability > 0.7 ? Colors.greenAccent : Colors.orangeAccent,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    // Resonance Lock (Hold Progress)
                    const Text("RESONANCE LOCK", style: TextStyle(color: Colors.cyanAccent, fontSize: 10, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 60,
                          width: 60,
                          child: CircularProgressIndicator(
                            value: _holdProgress,
                            strokeWidth: 6,
                            backgroundColor: Colors.white10,
                            color: Colors.cyanAccent,
                          ),
                        ),
                        if (_holdProgress > 0)
                          const Icon(Icons.lock_open, color: Colors.cyanAccent)
                        else
                          const Icon(Icons.mic, color: Colors.white24),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Text(_stepFeedback, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ] else if (_isVerifying) ...[
               // Verification UI
               Container(
                 margin: const EdgeInsets.symmetric(horizontal: 40),
                 padding: const EdgeInsets.all(20),
                 decoration: BoxDecoration(
                   color: Colors.white.withOpacity(0.05),
                   borderRadius: BorderRadius.circular(16),
                   border: Border.all(color: Colors.greenAccent, width: 1),
                 ),
                 child: Column(
                   children: [
                     const Text(
                       "Quality Locked!",
                       style: TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold),
                     ),
                     const SizedBox(height: 10),
                     Text(_stepFeedback, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                     const SizedBox(height: 20),
                     Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         ElevatedButton.icon(
                           onPressed: _retryStep,
                           icon: const Icon(Icons.refresh),
                           label: const Text("Retry"),
                           style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white),
                         ),
                         const SizedBox(width: 16),
                         ElevatedButton.icon(
                           onPressed: _confirmStep,
                           icon: const Icon(Icons.check),
                           label: const Text("Next Step"),
                           style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                         ),
                       ],
                     )
                   ],
                 ),
               ),
            ] else ...[
              ElevatedButton(
                onPressed: _startStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: const Text('Start Recording'),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Hold the note or vowel steady for 3 seconds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            ],
            const SizedBox(height: 60),
            // Placeholder for real-time visualization
            _buildVisualizer(),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualizer() {
    return Container(
      height: 100,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(20, (index) {
          // Use real FFT data (buckets)
          double magnitude = 0;
          if (_latestFft.isNotEmpty) {
            int bucket = (index * (_latestFft.length / 40)).floor(); // Show first half of FFT
            magnitude = _latestFft[bucket % _latestFft.length];
          }
          
          double h = (magnitude * 500).clamp(5.0, 100.0);
          
          return Container(
            width: 8,
            height: h,
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}

class CalibrationTarget {
  final String name;
  final String type; // 'vowel' or 'note'
  double? value; // For notes (Hz)
  List<double>? formants; // For vowels (List of Hz)

  CalibrationTarget({required this.name, required this.type});
}

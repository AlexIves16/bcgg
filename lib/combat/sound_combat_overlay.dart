import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../audio/audio_analyzer.dart';
import '../profile/voice_calibration_screen.dart';
import '../sensor_manager.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SoundCombatOverlay extends StatefulWidget {
  final dynamic monster;
  final VoidCallback onWin;
  final VoidCallback onLose;

  const SoundCombatOverlay({
    super.key,
    required this.monster,
    required this.onWin,
    required this.onLose,
  });

  @override
  State<SoundCombatOverlay> createState() => _SoundCombatOverlayState();
}

class _SoundCombatOverlayState extends State<SoundCombatOverlay> {
  final AudioAnalyzer _analyzer = AudioAnalyzer();
  dynamic _fingerprint;
  bool _isLoading = true;
  bool _needsCalibration = false;
  
  String _targetName = "";
  dynamic _targetValue; // List<double> for vowels, double for notes
  String _combatType = "vowel"; // 'vowel' or 'note'

  double _matchPercentage = 0;
  bool _isMatching = false;
  String _feedback = "Prepare to sing...";

  // New combat state
  int _playerHp = 100;
  int _maxPlayerHp = 100;
  int _currentSequenceIndex = 0;
  int _totalSequenceLength = 1;
  List<String> _sequenceTargets = [];

  bool _isDodging = false;
  DateTime? _lastDodgeTime;
  String? _incomingAttackWarning;
  Timer? _combatTickTimer;
  Timer? _gameTimer;
  int _timeLeft = 30;

  StreamSubscription? _pitchSub;
  StreamSubscription? _fftSub;
  StreamSubscription? _accelSub;

  @override
  void initState() {
    super.initState();
    _playerHp = SensorManager().userHp;
    _maxPlayerHp = SensorManager().maxHp;
    _timeLeft = widget.monster['timeLimit'] ?? 30;
    _loadFingerprint();
    _startAccelerometerMonitor();
  }

  @override
  void dispose() {
    _pitchSub?.cancel();
    _fftSub?.cancel();
    _accelSub?.cancel();
    _combatTickTimer?.cancel();
    _gameTimer?.cancel();
    _analyzer.stopAnalysis();
    super.dispose();
  }

  void _startAccelerometerMonitor() {
    _accelSub = userAccelerometerEvents.listen((event) {
      if (!mounted) return;
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
      _incomingAttackWarning = null;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isDodging = false);
    });
  }

  Future<void> _loadFingerprint() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists || doc.data()?['voiceCalibration'] == null) {
      setState(() {
        _isLoading = false;
        _needsCalibration = true;
      });
      return;
    }

    _fingerprint = doc.data()?['voiceCalibration'];
    _setupBattle();
  }

  void _setupBattle() {
    final rand = Random();
    final String monsterType = widget.monster['type'] ?? '';
    
    if (monsterType == 'banshee' || widget.monster['subtype'] == 'sonic') {
      _combatType = 'note';
    } else {
      _combatType = 'vowel';
    }
    
    // Determine sequence length from monster rank
    final String rank = widget.monster['rank'] ?? 'normal';
    _totalSequenceLength = rank == 'epic' ? 3 : (rank == 'ancient' ? 2 : 1);
    
    // Pre-generate targets from calibration
    final pool = _fingerprint![_combatType == 'note' ? 'notes' : 'vowels'] as Map;
    final keys = pool.keys.toList();
    if (keys.isEmpty) {
        setState(() => _needsCalibration = true);
        return;
    }

    for (int i = 0; i < _totalSequenceLength; i++) {
        _sequenceTargets.add(keys[rand.nextInt(keys.length)]);
    }

    _targetName = _sequenceTargets[0];
    _targetValue = pool[_targetName];

    setState(() {
      _isLoading = false;
      _feedback = "Sing the ${_combatType == 'note' ? 'note' : 'vowel'}: $_targetName";
    });

    _startListening();
    _startCombatTimers();
  }

  void _startCombatTimers() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) _timeLeft--;
        else _fail("Time is up!");
      });
    });

    _combatTickTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) return;
      
      // 1. Aura Damage
      if (widget.monster['attackType'] == 'proximity_aura') {
        _takeDamage(_isDodging ? 1 : 2);
      }

      // 2. Scheduled Attacks
      final int interval = widget.monster['attackInterval'] ?? 3000;
      final int tickMs = timer.tick * 500;
      
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
        _fail("You were defeated!");
      }
    });
    SensorManager().takeDamage(amount);
  }

  void _fail(String msg) {
    _analyzer.stopAnalysis();
    _combatTickTimer?.cancel();
    _gameTimer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
    widget.onLose();
  }

  Future<void> _startListening() async {
    final success = await _analyzer.startAnalysis();
    if (!success) {
      setState(() => _feedback = "Microphone Error!");
      return;
    }

    if (_combatType == 'note') {
      _pitchSub = _analyzer.pitchStream.listen(_handlePitch);
    } else {
      _fftSub = _analyzer.fftStream.listen(_handleFft);
    }
  }

  void _handlePitch(double? pitch) {
    if (pitch == null) {
      _updateMatch(false);
      return;
    }

    final double diff = (pitch - (_targetValue as num)).abs();
    final bool match = diff < 30.0;
    _updateMatch(match);
  }

  void _handleFft(List<double> magnitudes) {
    final liveFormants = _analyzer.getDominantFrequencies(magnitudes, 3);
    if (liveFormants.isEmpty) {
      _updateMatch(false);
      return;
    }

    final List<dynamic> fingerFormants = _targetValue;
    double distance = 0;
    for (int i = 0; i < min(liveFormants.length, fingerFormants.length); i++) {
      distance += pow(liveFormants[i] - (fingerFormants[i] as num), 2);
    }
    distance = sqrt(distance);

    final bool match = distance < 450.0;
    _updateMatch(match);
  }

  void _updateMatch(bool match) {
    if (!mounted) return;
    setState(() {
      _isMatching = match;
      if (match) {
        _matchPercentage += 0.025; // Slightly faster to win for sound
        if (_matchPercentage >= 1.0) {
          _nextOrWin();
        }
      } else {
        _matchPercentage = max(0, _matchPercentage - 0.008);
      }
    });
  }

  void _nextOrWin() {
    if (_currentSequenceIndex < _totalSequenceLength - 1) {
      setState(() {
        _currentSequenceIndex++;
        _matchPercentage = 0;
        _targetName = _sequenceTargets[_currentSequenceIndex];
        _targetValue = (_fingerprint![_combatType == 'note' ? 'notes' : 'vowels'] as Map)[_targetName];
        _feedback = "Next target: $_targetName!";
      });
      return;
    }
    _win();
  }

  void _win() {
    _analyzer.stopAnalysis();
    widget.onWin();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Colors.black87, body: Center(child: CircularProgressIndicator()));
    }

    if (_needsCalibration) {
      return Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mic_off, size: 80, color: Colors.redAccent),
                const SizedBox(height: 20),
                const Text(
                  'Voice Calibration Required!',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'To fight this monster, you must first calibrate your voice in the Profile menu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const VoiceCalibrationScreen()));
                  },
                  child: const Text('Go to Calibration'),
                ),
                TextButton(
                  onPressed: widget.onLose,
                  child: const Text('Flee Battle', style: TextStyle(color: Colors.white38)),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.9),
      body: Stack(
        children: [
          _buildAura(),
          
          SafeArea(
            child: Column(
              children: [
                // Top Header (Time and Sequence)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$_timeLeft s', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
                      Text('Seq: ${_currentSequenceIndex + 1}/$_totalSequenceLength', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),

                // Player HP Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.greenAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _playerHp / _maxPlayerHp,
                            minHeight: 10,
                            color: Colors.greenAccent,
                            backgroundColor: Colors.white10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                const Text("SONIC COMBAT", style: TextStyle(color: Colors.cyanAccent, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4)),
                
                const Spacer(),
                
                // The Target
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _isMatching ? Colors.greenAccent : Colors.white24, width: 4),
                        boxShadow: [
                          if (_isMatching)
                            BoxShadow(color: Colors.greenAccent.withOpacity(0.3), blurRadius: 40, spreadRadius: 10),
                        ],
                      ),
                      child: Text(
                        _targetName,
                        style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_incomingAttackWarning != null)
                      Positioned(
                        top: -20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                          child: Text(_incomingAttackWarning!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 20),
                Text(_feedback, style: const TextStyle(color: Colors.white70, fontSize: 18)),
                
                const Spacer(),
                
                // Progress Bar (Mob Health / Match Strength)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      Text(_isDodging ? "DODGING!" : "PURIFYING RESONANCE", style: TextStyle(color: _isDodging ? Colors.blueAccent : Colors.white30, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _matchPercentage,
                        backgroundColor: Colors.white10,
                        color: _isMatching ? Colors.greenAccent : Colors.white24,
                        minHeight: 15,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                const Text("Shake phone to DODGE", style: TextStyle(color: Colors.white24, fontSize: 12)),
                const SizedBox(height: 20),
                
                TextButton(
                  onPressed: widget.onLose,
                  child: const Text("Flee (Lose XP)", style: TextStyle(color: Colors.redAccent)),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          
          if (_isDodging)
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 10)),
            ),
        ],
      ),
    );
  }

  Widget _buildAura() {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: _isMatching ? 300 : 200,
        height: _isMatching ? 300 : 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              (_isMatching ? Colors.cyanAccent : Colors.purpleAccent).withOpacity(0.3),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../audio/audio_analyzer.dart';
import '../profile/voice_calibration_screen.dart';

class SoundCombatOverlay extends StatefulWidget {
  final Map<String, dynamic> monster;
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
  Map<String, dynamic>? _fingerprint;
  bool _isLoading = true;
  bool _needsCalibration = false;
  
  String _targetName = "";
  dynamic _targetValue; // List<double> for vowels, double for notes
  String _combatType = "vowel"; // 'vowel' or 'note'

  double _matchPercentage = 0;
  bool _isMatching = false;
  String _feedback = "Prepare to sing...";

  StreamSubscription? _pitchSub;
  StreamSubscription? _fftSub;

  @override
  void initState() {
    super.initState();
    _loadFingerprint();
  }

  @override
  void dispose() {
    _pitchSub?.cancel();
    _fftSub?.cancel();
    _analyzer.stopAnalysis();
    super.dispose();
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
    
    // Choose battle type based on monster type
    final String monsterType = widget.monster['type'] ?? '';
    
    if (monsterType == 'banshee') {
      _combatType = 'note';
    } else if (monsterType == 'siren') {
      _combatType = 'vowel';
    } else {
      // Fallback or subtype logic
      _combatType = widget.monster['subtype'] == 'sonic' ? 'note' : 'vowel';
    }
    
    if (_combatType == 'note') {
      final notes = (_fingerprint!['notes'] as Map).keys.toList();
      _targetName = notes[rand.nextInt(notes.length)];
      _targetValue = _fingerprint!['notes'][_targetName];
    } else {
      _combatType = 'vowel';
      final vowels = (_fingerprint!['vowels'] as Map).keys.toList();
      _targetName = vowels[rand.nextInt(vowels.length)];
      _targetValue = _fingerprint!['vowels'][_targetName];
    }

    setState(() {
      _isLoading = false;
      _feedback = "Sing the ${_combatType == 'note' ? 'note' : 'vowel'}: $_targetName";
    });

    _startListening();
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
    // Tolerance: roughly 30Hz (wider for easier gameplay)
    final bool match = diff < 30.0;
    _updateMatch(match);
  }

  void _handleFft(List<double> magnitudes) {
    final liveFormants = _analyzer.getDominantFrequencies(magnitudes, 3);
    if (liveFormants.isEmpty) {
      _updateMatch(false);
      return;
    }

    // Euclidean distance between formant vectors
    final List<dynamic> fingerFormants = _targetValue;
    double distance = 0;
    for (int i = 0; i < min(liveFormants.length, fingerFormants.length); i++) {
      distance += pow(liveFormants[i] - (fingerFormants[i] as num), 2);
    }
    distance = sqrt(distance);

    // Vowel matching is harder, higher tolerance needed (especially for O and U)
    final bool match = distance < 450.0;
    _updateMatch(match);
  }

  void _updateMatch(bool match) {
    if (!mounted) return;
    setState(() {
      _isMatching = match;
      if (match) {
        _matchPercentage += 0.02; // Take ~2-3 seconds to win
        if (_matchPercentage >= 1.0) {
          _win();
        }
      } else {
        _matchPercentage = max(0, _matchPercentage - 0.005);
      }
    });
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
          // Visualizers and Background FX
          _buildAura(),
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text("SONIC COMBAT", style: TextStyle(color: Colors.cyanAccent, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4)),
                const Spacer(),
                
                // The Target
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _isMatching ? Colors.greenAccent : Colors.white24, width: 4),
                    boxShadow: [
                      if (_isMatching)
                        BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 40, spreadRadius: 10),
                    ],
                  ),
                  child: Text(
                    _targetName,
                    style: const TextStyle(color: Colors.white, fontSize: 70, fontWeight: FontWeight.bold),
                  ),
                ),
                
                const SizedBox(height: 20),
                Text(_feedback, style: const TextStyle(color: Colors.white70, fontSize: 18)),
                
                const Spacer(),
                
                // Progress Bar (Mob Health / Match Strength)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      const Text("PURIFYING RESONANCE", style: TextStyle(color: Colors.white30, fontSize: 10)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _matchPercentage,
                        backgroundColor: Colors.white10,
                        color: Colors.greenAccent,
                        minHeight: 15,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                TextButton(
                  onPressed: widget.onLose,
                  child: const Text("Flee (Lose XP)", style: TextStyle(color: Colors.redAccent)),
                ),
                const SizedBox(height: 20),
              ],
            ),
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

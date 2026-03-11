import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'network_manager.dart';

class SensorManager {
  static final SensorManager _instance = SensorManager._internal();
  factory SensorManager() => _instance;
  SensorManager._internal();

  // Local XP tracking, synced with Realtime Database
  int _xp = 0;
  final _xpController = StreamController<int>.broadcast();
  Stream<int> get xpStream => _xpController.stream;
  int get userXp => _xp;
  
  // Local Energy tracking, synced with Realtime Database
  int _energy = 0;
  final _energyController = StreamController<int>.broadcast();
  Stream<int> get energyStream => _energyController.stream;
  int get currentEnergy => _energy;
  int get userEnergy => _energy;
  
  // Realtime Database reference
  static const _rtdbUrl = 'https://game26-base-default-rtdb.europe-west1.firebasedatabase.app';
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL: _rtdbUrl,
  ).ref();
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Load local cache immediately so UI doesn't flash 0/100
    _xp = _prefs?.getInt('cached_xp') ?? 0;
    _xpController.add(_xp);
    
    _energy = _prefs?.getInt('cached_energy') ?? 100;
    _energyController.add(_energy);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Listen to XP
      _dbRef.child("users/${user.uid}/xp").onValue.listen((event) {
        if (event.snapshot.value != null) {
          _xp = (event.snapshot.value as num).toInt();
          _prefs?.setInt('cached_xp', _xp);
          _xpController.add(_xp);
        }
      });
      
      // Listen to Energy
      _dbRef.child("users/${user.uid}/energy").onValue.listen((event) {
        if (event.snapshot.value != null) {
          _energy = (event.snapshot.value as num).toInt();
          _prefs?.setInt('cached_energy', _energy);
        } else {
          // Default starting energy if not set in DB
          if (_energy != 0 && _energy != 100) {
            // Keep cached if we have it, else 100
          } else {
             _energy = 100;
             _prefs?.setInt('cached_energy', 100);
          }
          _dbRef.child("users/${user.uid}/energy").set(_energy);
        }
        _energyController.add(_energy);
      });
    }
  }

  // NOTE: Passive background shaking (startListening) has been removed.
  // Shaking is now actively monitored only while the Energy Mining dialog is open.

  Future<bool> consumeEnergy(int amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (_energy >= amount) {
        _energy -= amount;
        _energyController.add(_energy);
        _prefs?.setInt('cached_energy', _energy);
        await _dbRef.child("users/${user.uid}/energy").set(ServerValue.increment(-amount));
        print('Consumed $amount Energy. Remaining: $_energy');
        return true;
      } else {
        print('Not enough energy to consume $amount. Current: $_energy');
        return false;
      }
    }
    return false;
  }

  Future<void> addEnergy(int amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      int newEnergy = _energy + amount;
      if (newEnergy > 100) newEnergy = 100; // Cap at 100
      
      _energy = newEnergy;
      _energyController.add(_energy);
      _prefs?.setInt('cached_energy', _energy);
      await _dbRef.child("users/${user.uid}/energy").set(_energy);
      print('Awarded $amount Energy. Total: $_energy');
    }
  }

  Future<void> addXP(int amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        _xp += amount;
        _xpController.add(_xp);
        _prefs?.setInt('cached_xp', _xp);
        await _dbRef.child("users/${user.uid}/xp").set(ServerValue.increment(amount));
        print('Awarded $amount XP locally and saved to DB. Total XP: $_xp');
      } catch (e) {
        print('Error saving XP to Realtime Database: $e');
      }
    }
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

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

  // Local HP tracking
  int _hp = 100;
  final int _maxHp = 100;
  final _hpController = StreamController<int>.broadcast();
  Stream<int> get hpStream => _hpController.stream;
  int get userHp => _hp;
  int get maxHp => _maxHp;
  
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

    _hp = _prefs?.getInt('cached_hp') ?? 100;
    _hpController.add(_hp);

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
          _energy = 100;
          _prefs?.setInt('cached_energy', 100);
          _dbRef.child("users/${user.uid}/energy").set(_energy);
        }
        _energyController.add(_energy);
      });

      // Listen to HP
      _dbRef.child("users/${user.uid}/hp").onValue.listen((event) {
        if (event.snapshot.value != null) {
          _hp = (event.snapshot.value as num).toInt();
          _prefs?.setInt('cached_hp', _hp);
          _hpController.add(_hp);
        }
      });
    }
  }

  void takeDamage(int amount) {
    _hp = max(0, _hp - amount);
    _hpController.add(_hp);
    _prefs?.setInt('cached_hp', _hp);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _dbRef.child("users/${user.uid}/hp").set(_hp);
    }
  }

  void heal(int amount) {
    _hp = min(_maxHp, _hp + amount);
    _hpController.add(_hp);
    _prefs?.setInt('cached_hp', _hp);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _dbRef.child("users/${user.uid}/hp").set(_hp);
    }
  }

  // NOTE: Passive background shaking (startListening) has been removed.
  // Shaking is now actively monitored only while the Energy Mining dialog is open.

  Future<bool> consumeEnergy(int amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Anti-cheat: Validate amount
      if (amount <= 0 || amount > 100) {
        debugPrint('[SensorManager] Invalid energy amount: $amount');
        return false;
      }
      
      if (_energy >= amount) {
        _energy -= amount;
        _energyController.add(_energy);
        _prefs?.setInt('cached_energy', _energy);
        try {
          await _dbRef.child("users/${user.uid}/energy").set(ServerValue.increment(-amount));
          print('Consumed $amount Energy. Remaining: $_energy');
          return true;
        } on FirebaseException catch (e) {
          debugPrint('[SensorManager] Firebase error consuming energy: $e');
          // Rollback on error
          _energy += amount;
          _energyController.add(_energy);
          return false;
        }
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
      // Anti-cheat: Validate amount
      if (amount <= 0) {
        debugPrint('[SensorManager] Invalid energy amount: $amount');
        return;
      }
      
      int newEnergy = _energy + amount;
      if (newEnergy > 100) newEnergy = 100; // Cap at 100
      
      _energy = newEnergy;
      _energyController.add(_energy);
      _prefs?.setInt('cached_energy', _energy);
      try {
        await _dbRef.child("users/${user.uid}/energy").set(_energy);
        print('Awarded $amount Energy. Total: $_energy');
      } on FirebaseException catch (e) {
        debugPrint('[SensorManager] Firebase error adding energy: $e');
      }
    }
  }

  Future<void> addXP(int amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Anti-cheat: Validate XP amount
      if (amount <= 0) {
        debugPrint('[SensorManager] Invalid XP amount: $amount');
        return;
      }
      
      // Anti-cheat: Cap maximum XP gain per action
      if (amount > 1000) {
        debugPrint('[SensorManager] XP cap exceeded ($amount), capping to 1000');
        amount = 1000;
      }
      
      try {
        _xp += amount;
        _xpController.add(_xp);
        _prefs?.setInt('cached_xp', _xp);
        await _dbRef.child("users/${user.uid}/xp").set(ServerValue.increment(amount));
        print('Awarded $amount XP locally and saved to DB. Total XP: $_xp');
      } on FirebaseException catch (e) {
        debugPrint('[SensorManager] Firebase error adding XP: $e');
        // Rollback local XP on Firebase error
        _xp -= amount;
        _xpController.add(_xp);
      } catch (e) {
        debugPrint('[SensorManager] Error saving XP to Realtime Database: $e');
      }
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  late IO.Socket _socket;
  
  double? _lastLat;
  double? _lastLng;
  String? _username;
  String? _avatarBase64;
  
  // Static Ngrok URL
  String _serverUrl = "https://interequinoctial-sulcate-vanna.ngrok-free.dev"; 
  static String get serverUrl => _instance._serverUrl;
  
  // Stream to broadcast player updates to the UI
  final _playersController = StreamController<List<dynamic>>.broadcast();
  Stream<List<dynamic>> get playersStream => _playersController.stream;

  // Stream to broadcast map elements (monsters, loot) to the UI
  final _monstersController = StreamController<List<dynamic>>.broadcast();
  Stream<List<dynamic>> get monstersStream => _monstersController.stream;

  void setServerUrl(String url) {
    _serverUrl = url;
  }

  void connect() {
    _socket = IO.io(_serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket.connect();

    _socket.onConnect((_) {
      debugPrint('[SOCKET] 🟢 Connected to Game Server (Socket ID: ${_socket.id})');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((doc) {
          if (doc.exists) {
            _username = doc.data()?['username'];
            _avatarBase64 = doc.data()?['avatarBase64'];
          }
        });
      }

      // Auto-resend location upon reconnection so the server knows where to spawn monsters
      if (_lastLat != null && _lastLng != null) {
        sendLocation(_lastLat!, _lastLng!);
      }
    });

    _socket.on('playersUpdate', (data) {
      if (data != null && data is List) {
        _playersController.add(data);
      }
    });

    _socket.on('mapElementsUpdate', (data) {
      if (data != null && data is List) {
        _monstersController.add(data);
      }
    });

    _socket.onDisconnect((_) {
      debugPrint('[SOCKET] 🔴 Disconnected from Game Server');
    });

    _socket.onConnectError((err) {
      debugPrint('[SOCKET ERROR] ⚠️ Connection Error: $err');
    });

    _socket.onError((err) {
      debugPrint('[SOCKET ERROR] ⚠️ Error: $err');
    });

    _socket.on('connect_timeout', (data) => debugPrint('[SOCKET] ⏱️ Connection Timeout'));
    _socket.on('reconnect', (data) => debugPrint('[SOCKET] 🔄 Reconnected successfully'));
    _socket.on('reconnect_attempt', (attempt) => debugPrint('[SOCKET] 🔄 Reconnect attempt: $attempt'));
    _socket.on('reconnecting', (attempt) => debugPrint('[SOCKET] 🔄 Reconnecting (Attempt $attempt)'));
    _socket.on('reconnect_error', (error) => debugPrint('[SOCKET ERROR] ⚠️ Reconnect error: $error'));
    _socket.on('reconnect_failed', (_) => debugPrint('[SOCKET ERROR] ❌ Reconnect failed completely'));

  }

  void stop() {
    _socket.disconnect();
    _socket.dispose();
  }

  void sendLocation(double latitude, double longitude) {
    _lastLat = latitude;
    _lastLng = longitude;
    
    if (_socket.connected) {
      final user = FirebaseAuth.instance.currentUser;
      _socket.emit('updateLocation', {
        'uid': user?.uid ?? _socket.id,
        'email': user?.email ?? 'anonymous',
        'username': _username,
        'avatarBase64': _avatarBase64,
        'lat': latitude,
        'lng': longitude,
      });
    }
  }

  void mineEnergy(String cloudId, int amount) {
    if (_socket.connected) {
      _socket.emit('mineEnergy', {
        'cloudId': cloudId,
        'amount': amount,
      });
    }
  }

  void logActivity(String action, int value) {
    if (_socket.connected) {
      final user = FirebaseAuth.instance.currentUser;
      _socket.emit('logActivity', {
        'uid': user?.uid ?? _socket.id,
        'email': user?.email ?? 'anonymous',
        'action': action,
        'value': value,
      });
    }
  }

  void killMonster(String monsterId) {
    if (_socket.connected) {
      _socket.emit('killMonster', {
        'monsterId': monsterId,
      });
    }
  }
}

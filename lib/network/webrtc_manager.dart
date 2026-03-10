import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupMessage {
  final String text;
  final String senderId;
  final String senderName;
  final int timestamp;

  GroupMessage({
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'senderId': senderId,
    'senderName': senderName,
    'timestamp': timestamp,
  };

  factory GroupMessage.fromJson(Map<String, dynamic> json) => GroupMessage(
    text: json['text'],
    senderId: json['senderId'],
    senderName: json['senderName'],
    timestamp: json['timestamp'],
  );
}

class WebRtcManager {
  static final WebRtcManager _instance = WebRtcManager._internal();
  factory WebRtcManager() => _instance;
  WebRtcManager._internal();

  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCDataChannel> _dataChannels = {};
  
  final _db = FirebaseDatabase.instance.ref();
  final auth = FirebaseAuth.instance;
  
  String? _currentGroupId;
  StreamSubscription? _peersSubscription;
  StreamSubscription? _signalingSubscription;

  // Stream for UI to listen for incoming messages
  final _messageController = StreamController<GroupMessage>.broadcast();
  Stream<GroupMessage> get messageStream => _messageController.stream;

  // Stream for UI to track connection status
  final _connectionController = StreamController<Map<String, bool>>.broadcast();
  Stream<Map<String, bool>> get connectionStream => _connectionController.stream;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  final Map<String, dynamic> _dcConstraints = {
    'ordered': true,
  };

  Future<void> joinGroup(String groupId) async {
    if (_currentGroupId != null) await leaveGroup();
    
    _currentGroupId = groupId;
    final myUid = auth.currentUser?.uid;
    if (myUid == null) return;

    debugPrint('[WebRTC] Joining group: $groupId');

    // 1. Register myself in the group
    await _db.child('groups/$groupId/peers/$myUid').set({
      'joinedAt': ServerValue.timestamp,
      'name': auth.currentUser?.displayName ?? auth.currentUser?.email?.split('@')[0] ?? 'Explorer',
    });

    // 2. Listen for other peers in the group
    _peersSubscription = _db.child('groups/$groupId/peers').onValue.listen((event) {
      final peers = event.snapshot.value as Map?;
      if (peers == null) return;

      peers.forEach((peerUid, data) {
        if (peerUid == myUid) return;
        
        // If we don't have a connection, initiate one if we are the "initiator"
        // Rule: Higher UID initiates to lower UID for determinism
        if (!_peerConnections.containsKey(peerUid)) {
          if (myUid.compareTo(peerUid) > 0) {
            _createPeerConnection(peerUid, true);
          }
        }
      });
    });

    // 3. Listen for incoming signaling messages (offers, answers, ice)
    _signalingSubscription = _db.child('signaling/$myUid').onChildAdded.listen((event) {
      final peerUid = event.snapshot.key; // Who sent this
      if (peerUid == null) return;

      final data = event.snapshot.value as Map?;
      if (data == null) return;

      _handleSignalingData(peerUid, data);
      
      // Clear processed signaling
      _db.child('signaling/$myUid/$peerUid').remove();
    });
  }

  Future<void> _createPeerConnection(String peerUid, bool isInitiator) async {
    if (_peerConnections.containsKey(peerUid)) return;

    debugPrint('[WebRTC] Creating connection to $peerUid (Initiator: $isInitiator)');
    
    RTCPeerConnection pc = await createPeerConnection(_configuration);
    _peerConnections[peerUid] = pc;

    pc.onIceCandidate = (candidate) {
      _sendSignaling(peerUid, {'ice': candidate.toMap()});
    };

    pc.onConnectionState = (state) {
      debugPrint('[WebRTC] Connection state to $peerUid: $state');
      _updateConnectionStatus();
    };

    if (isInitiator) {
      RTCDataChannel dc = await pc.createDataChannel('chat', RTCDataChannelInit()..ordered = true);
      _setupDataChannel(peerUid, dc);

      RTCSessionDescription offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      _sendSignaling(peerUid, {'offer': offer.toMap()});
    } else {
      pc.onDataChannel = (dc) {
        _setupDataChannel(peerUid, dc);
      };
    }
  }

  void _setupDataChannel(String peerUid, RTCDataChannel dc) {
    _dataChannels[peerUid] = dc;
    dc.onMessage = (RTCDataChannelMessage message) {
      if (message.isBinary) return;
      try {
        final json = jsonDecode(message.text);
        _messageController.add(GroupMessage.fromJson(json));
      } catch (e) {
        debugPrint('[WebRTC] Error decoding message: $e');
      }
    };
    
    dc.onDataChannelState = (state) {
      debugPrint('[WebRTC] DataChannel state for $peerUid: $state');
      _updateConnectionStatus();
    };
  }

  Future<void> _handleSignalingData(String peerUid, Map data) async {
    // If we don't have a PC yet, create one as responder
    if (!_peerConnections.containsKey(peerUid)) {
      await _createPeerConnection(peerUid, false);
    }
    
    final pc = _peerConnections[peerUid]!;

    if (data.containsKey('offer')) {
      final offerMap = Map<String, dynamic>.from(data['offer']);
      await pc.setRemoteDescription(RTCSessionDescription(offerMap['sdp'], offerMap['type']));
      
      RTCSessionDescription answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      _sendSignaling(peerUid, {'answer': answer.toMap()});
    } else if (data.containsKey('answer')) {
      final answerMap = Map<String, dynamic>.from(data['answer']);
      await pc.setRemoteDescription(RTCSessionDescription(answerMap['sdp'], answerMap['type']));
    } else if (data.containsKey('ice')) {
      final iceMap = Map<String, dynamic>.from(data['ice']);
      await pc.addCandidate(RTCIceCandidate(iceMap['candidate'], iceMap['sdpMid'], iceMap['sdpMLineIndex']));
    }
  }

  void _sendSignaling(String peerUid, Map<String, dynamic> data) {
    final myUid = auth.currentUser?.uid;
    if (myUid == null) return;
    _db.child('signaling/$peerUid/$myUid').update(data);
  }

  void _updateConnectionStatus() {
    final status = <String, bool>{};
    _dataChannels.forEach((uid, dc) {
      status[uid] = dc.state == RTCDataChannelState.RTCDataChannelOpen;
    });
    _connectionController.add(status);
  }

  void broadcastMessage(String text) {
    final myUid = auth.currentUser?.uid;
    final myName = auth.currentUser?.displayName ?? auth.currentUser?.email?.split('@')[0] ?? 'Explorer';
    
    final msg = GroupMessage(
      text: text,
      senderId: myUid ?? 'unknown',
      senderName: myName,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    final json = jsonEncode(msg.toJson());
    
    _dataChannels.values.forEach((dc) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(json));
      }
    });

    // Also add to local stream so sender sees it
    _messageController.add(msg);
  }

  Future<void> leaveGroup() async {
    final myUid = auth.currentUser?.uid;
    if (myUid != null && _currentGroupId != null) {
      await _db.child('groups/$_currentGroupId/peers/$myUid').remove();
    }

    _peersSubscription?.cancel();
    _signalingSubscription?.cancel();
    
    for (var dc in _dataChannels.values) {
      await dc.close();
    }
    for (var pc in _peerConnections.values) {
      await pc.close();
    }
    
    _dataChannels.clear();
    _peerConnections.clear();
    _currentGroupId = null;
    _updateConnectionStatus();
  }
}

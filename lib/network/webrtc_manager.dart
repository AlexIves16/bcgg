import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_cache.dart';

class GroupMessage {
  final String text;
  final String senderId;
  final String senderName;
  final int timestamp;
  final String messageId; // Unique message ID for deduplication

  GroupMessage({
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    String? messageId,
  }) : messageId = messageId ?? '${senderId}_$timestamp';

  Map<String, dynamic> toJson() => {
    'text': text,
    'senderId': senderId,
    'senderName': senderName,
    'timestamp': timestamp,
    'messageId': messageId,
  };

  factory GroupMessage.fromJson(Map<String, dynamic> json) => GroupMessage(
    text: json['text'],
    senderId: json['senderId'],
    senderName: json['senderName'],
    timestamp: json['timestamp'],
    messageId: json['messageId'],
  );
}

class WebRtcManager {
  static final WebRtcManager _instance = WebRtcManager._internal();
  factory WebRtcManager() => _instance;
  WebRtcManager._internal();

  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCDataChannel> _dataChannels = {};
  
  static const _rtdbUrl = 'https://game26-base-default-rtdb.europe-west1.firebasedatabase.app';
  final _db = FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL: _rtdbUrl,
  ).ref();
  final auth = FirebaseAuth.instance;
  
  String? _currentGroupId;
  StreamSubscription? _peersSubscription;
  StreamSubscription? _signalingSubscription;
  StreamSubscription? _groupSubscription;
  StreamSubscription? _inviteSubscription;

  // --- Streams ---
  final _messageController = StreamController<GroupMessage>.broadcast();
  Stream<GroupMessage> get messageStream => _messageController.stream;

  final _connectionController = StreamController<Map<String, bool>>.broadcast();
  Stream<Map<String, bool>> get connectionStream => _connectionController.stream;

  final _invitationController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get invitationStream => _invitationController.stream;

  // TURN server configuration for better P2P connectivity on mobile networks
  // Free public TURN servers (for testing) + instructions for production
  // Production: Register at https://www.metered.ca/tools/ for free credentials
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      // Google STUN servers (always available)
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
      // TURN servers for NAT traversal (mobile networks)
      // OpenTURN public servers (limited, for testing only)
      {'urls': 'turn:openrelay.metered.ca:80', 'username': 'openrelayproject', 'credential': 'openrelayproject'},
      {'urls': 'turn:openrelay.metered.ca:443', 'username': 'openrelayproject', 'credential': 'openrelayproject'},
      {'urls': 'turn:openrelay.metered.ca:443?transport=tcp', 'username': 'openrelayproject', 'credential': 'openrelayproject'},
      // Metered.ca free tier (register for your own credentials)
      // {
      //   'urls': ['turn:ca.turn.metered.ca:443', 'turns:ca.turn.metered.ca:443'],
      //   'username': 'your-username',
      //   'credential': 'your-password'
      // },
    ],
    'iceTransportPolicy': 'all', // Uses both STUN and TURN automatically
  };

  Future<void> startListeningForInvites() async {
    final myUid = auth.currentUser?.uid;
    if (myUid == null) return;

    _inviteSubscription?.cancel();
    _inviteSubscription = _db.child('invitations/$myUid').onChildAdded.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      
      debugPrint('[WebRTC] Received INVITATION from ${event.snapshot.key}');
      _invitationController.add({
        'senderUid': event.snapshot.key,
        'groupId': data['groupId'],
        'groupName': data['groupName'],
      });
      
      // Auto-clear after reporting to UI
      event.snapshot.ref.remove();
    });
  }

  Future<void> joinGroup(String groupId) async {
    if (_currentGroupId != null) await leaveGroup();
    
    _currentGroupId = groupId;
    final myUid = auth.currentUser?.uid;
    if (myUid == null) return;

    debugPrint('[WebRTC] Joining group: $groupId');

    // 1. Register myself in the group.
    // We intentionally DO NOT clear signaling/$myUid here anymore to avoid wiping incoming handshakes!

    await _db.child('groups/$groupId/peers/$myUid').set({
      'joinedAt': ServerValue.timestamp,
      'name': auth.currentUser?.displayName ?? auth.currentUser?.email?.split('@')[0] ?? 'Explorer',
    });

    // 2. Listen for other peers in the group
    _peersSubscription = _db.child('groups/$groupId/peers').onValue.listen((event) {
      final peers = event.snapshot.value as Map?;
      if (peers == null) {
        debugPrint('[WebRTC] No peers in group $groupId');
        return;
      }

      debugPrint('[WebRTC] Peers update in group: ${peers.keys.toList()}');

      peers.forEach((peerUid, data) {
        if (peerUid == myUid) return;
        
        // If we don't have a connection, initiate one if we are the "initiator"
        if (!_peerConnections.containsKey(peerUid)) {
          // Rule: Higher UID initiates to lower UID for determinism
          if (myUid.compareTo(peerUid) > 0) {
            debugPrint('[WebRTC] I ($myUid) am initiator for $peerUid. Starting connection...');
            _createPeerConnection(peerUid, true);
          } else {
            debugPrint('[WebRTC] I ($myUid) wait for $peerUid to initiate...');
          }
        }
      });
    });

    // 3. Listen for incoming signaling messages (offers, answers, ice)
    // We listen to the shared signaling node where others push messages for ME
    final List<StreamSubscription> innerSubscriptions = [];
    _signalingSubscription = _db.child('signaling/$myUid').onChildAdded.listen((peerEvent) {
      final peerUid = peerEvent.snapshot.key;
      if (peerUid == null) return;

      debugPrint('[WebRTC] Found signaling folder from peer: $peerUid');

      // Now listen to the messages PUSHED by this specific peer
      var sub = _db.child('signaling/$myUid/$peerUid').onChildAdded.listen((msgEvent) {
        final data = msgEvent.snapshot.value as Map?;
        if (data == null) return;

        debugPrint('[WebRTC] Incoming signal from $peerUid: ${data.keys.first}');
        _handleSignalingData(peerUid, data);
        
        // Clear this specific message AFTER processing
        msgEvent.snapshot.ref.remove();
      });
      innerSubscriptions.add(sub);
    });

    // Store inner subs to cancel them later
    _peersSubscription?.onDone(() {
      for (var s in innerSubscriptions) {
        s.cancel();
      }
    });
  }

  Future<void> sendInvite(String targetUid, String groupId, String groupName) async {
    final myUid = auth.currentUser?.uid;
    if (myUid == null) return;

    debugPrint('[WebRTC] Sending invite to $targetUid for group $groupId');
    await _db.child('invitations/$targetUid/$myUid').set({
      'groupId': groupId,
      'groupName': groupName,
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Groups players by a grid (roughly 500m) to allow discovery within ~300m radius
  Future<void> joinLocalMesh(double lat, double lng) async {
    // 0.005 degrees is ~500m
    final gridLat = (lat / 0.005).floor();
    final gridLng = (lng / 0.005).floor();
    final localGroupId = 'local_mesh_${gridLat}_$gridLng';
    
    debugPrint('[WebRTC] Joining Local Mesh: $localGroupId (Lat: $lat, Lng: $lng)');
    await joinGroup(localGroupId);
  }

  Future<void> _createPeerConnection(String peerUid, bool isInitiator) async {
    if (_peerConnections.containsKey(peerUid)) return;

    debugPrint('[WebRTC] Creating connection to $peerUid (Initiator: $isInitiator)');
    
    RTCPeerConnection pc = await createPeerConnection(_configuration);
    _peerConnections[peerUid] = pc;

    pc.onIceCandidate = (candidate) {
      debugPrint('[WebRTC] Local ICE Candidate gathered: ${candidate.candidate?.split(" ")[0]}');
      _sendSignaling(peerUid, {'ice': candidate.toMap()});
    };

    pc.onIceConnectionState = (state) {
      debugPrint('[WebRTC] ICE Connection state to $peerUid: $state');
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
        final msg = GroupMessage.fromJson(json);
        
        // Save incoming message to cache
        if (_currentGroupId != null) {
          ChatCache().saveMessage(_currentGroupId!, msg);
        }
        
        _messageController.add(msg);
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
      debugPrint('[WebRTC] Received OFFER from $peerUid');
      final offerMap = Map<String, dynamic>.from(data['offer']);
      
      // Check connection state before setting remote description
      if (pc.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        debugPrint('[WebRTC] Connection already ${pc.connectionState}, ignoring duplicate offer');
        return;
      }
      
      await pc.setRemoteDescription(RTCSessionDescription(offerMap['sdp'], offerMap['type']));
      
      RTCSessionDescription answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      _sendSignaling(peerUid, {'answer': answer.toMap()});
    } else if (data.containsKey('answer')) {
      debugPrint('[WebRTC] Received ANSWER from $peerUid');
      final answerMap = Map<String, dynamic>.from(data['answer']);
      
      // Check connection state before setting remote description
      if (pc.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        debugPrint('[WebRTC] Connection already ${pc.connectionState}, ignoring duplicate answer');
        return;
      }
      
      await pc.setRemoteDescription(RTCSessionDescription(answerMap['sdp'], answerMap['type']));
    } else if (data.containsKey('ice')) {
      final iceMap = Map<String, dynamic>.from(data['ice']);
      debugPrint('[WebRTC] Received ICE CANDIDATE from $peerUid: ${iceMap['candidate']?.split(" ")[0]}');
      await pc.addCandidate(RTCIceCandidate(iceMap['candidate'], iceMap['sdpMid'], iceMap['sdpMLineIndex']));
    }
  }

  void _sendSignaling(String peerUid, Map<String, dynamic> data) {
    final myUid = auth.currentUser?.uid;
    if (myUid == null) return;
    debugPrint('[WebRTC] Pushing signaling to $peerUid: ${data.keys.first}');
    _db.child('signaling/$peerUid/$myUid').push().set(data);
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
    
    for (var dc in _dataChannels.values) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(json));
      }
    }

    // Save to cache immediately (for sender)
    if (_currentGroupId != null) {
      ChatCache().saveMessage(_currentGroupId!, msg);
    }

    // Also add to local stream so sender sees it
    _messageController.add(msg);
  }

  Future<void> leaveGroup() async {
    _peersSubscription?.cancel();
    _signalingSubscription?.cancel();
    _groupSubscription?.cancel();
    
    final myUid = auth.currentUser?.uid;
    if (myUid == null) return;

    if (_currentGroupId != null) {
      debugPrint('[WebRTC] Leaving group: $_currentGroupId');
      await _db.child('groups/$_currentGroupId/peers/$myUid').remove();
    }
    
    _currentGroupId = null;
    
    for (var dc in _dataChannels.values) {
      await dc.close();
    }
    for (var pc in _peerConnections.values) {
      await pc.close();
    }
    
    _dataChannels.clear();
    _peerConnections.clear();
    _currentGroupId = null;
    
    // Clear signaling *after* leaving the group to clean up
    await _db.child('signaling/$myUid').remove();
    debugPrint('[WebRTC] Cleared stale signaling on leave for $myUid');
    
    _updateConnectionStatus();
  }
}

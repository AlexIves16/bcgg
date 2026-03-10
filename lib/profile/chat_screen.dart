import 'package:flutter/material.dart';
import 'dart:async';
import '../network/webrtc_manager.dart';

class ChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final bool isLocalMesh;
  final double? lat;
  final double? lng;

  const ChatScreen({
    super.key,
    required this.groupId,
    this.groupName = 'Group Chat',
    this.isLocalMesh = false,
    this.lat,
    this.lng,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<GroupMessage> _messages = [];
  Map<String, bool> _peerStatus = {};
  
  StreamSubscription? _msgSub;
  StreamSubscription? _statusSub;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  void _initChat() {
    if (widget.isLocalMesh && widget.lat != null && widget.lng != null) {
      WebRtcManager().joinLocalMesh(widget.lat!, widget.lng!);
    } else {
      WebRtcManager().joinGroup(widget.groupId);
    }
    
    _msgSub = WebRtcManager().messageStream.listen((msg) {
      if (mounted) {
        setState(() {
          _messages.add(msg);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
        _scrollToBottom();
      }
    });

    _statusSub = WebRtcManager().connectionStream.listen((status) {
      if (mounted) {
        setState(() => _peerStatus = status);
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _statusSub?.cancel();
    WebRtcManager().leaveGroup();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    
    WebRtcManager().broadcastMessage(text);
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    int onlinePeers = _peerStatus.values.where((v) => v).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.groupName),
            Text(
              'P2P Mesh: $onlinePeers connected',
              style: const TextStyle(fontSize: 12, color: Colors.greenAccent),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Invite Friends',
            onPressed: () => _inviteMoreFriends(),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showStatusDialog(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2027), Color(0xFF203A43)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final myUid = WebRtcManager().auth.currentUser?.uid;
                  bool isMe = msg.senderId == myUid;
                  return _buildMessageBubble(msg, isMe);
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(GroupMessage msg, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Text(
              msg.senderName,
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe ? Colors.cyanAccent.withOpacity(0.2) : Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isMe ? Colors.cyanAccent.withOpacity(0.5) : Colors.white24, width: 0.5),
            ),
            child: Text(
              msg.text,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.black26,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Direct P2P Message...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  fillColor: Colors.white.withOpacity(0.05),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: _sendMessage,
              backgroundColor: Colors.cyanAccent,
              child: const Icon(Icons.send, color: Colors.black, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  void _inviteMoreFriends() {
    // Show a dialog to pick a friend to invite to this specific groupId
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Invite Friends to P2P Session', style: TextStyle(color: Colors.white, fontSize: 18)),
            const Divider(color: Colors.white24),
            // We can reuse a list of online friends or just a simple input
            const Text('Feature coming soon: Picker list', style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Friend Email',
                hintStyle: TextStyle(color: Colors.white30),
              ),
              style: const TextStyle(color: Colors.white),
              onSubmitted: (email) {
                // In a real app, we'd lookup the UID. For now, we assume simple email or UID input
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inviting...')));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Peer Connections', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _peerStatus.length,
            itemBuilder: (context, index) {
              final uid = _peerStatus.keys.elementAt(index);
              final isOnline = _peerStatus[uid]!;
              return ListTile(
                leading: Icon(Icons.person, color: isOnline ? Colors.greenAccent : Colors.grey),
                title: Text(uid.substring(0, 8), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                trailing: Text(isOnline ? 'Active' : 'Handshake...', style: TextStyle(color: isOnline ? Colors.green : Colors.orange, fontSize: 10)),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}

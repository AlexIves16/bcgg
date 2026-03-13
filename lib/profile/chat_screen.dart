import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../network/webrtc_manager.dart';
import '../network/chat_cache.dart';

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
  static String? _currentlyOpenGroupId; // Track open chat globally

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  void _initChat() {
    // Prevent opening duplicate chats
    if (_currentlyOpenGroupId == widget.groupId) {
      debugPrint('[ChatScreen] Group ${widget.groupId} is already open!');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chat "${widget.groupName}" is already open')),
          );
        }
      });
      return;
    }
    
    _currentlyOpenGroupId = widget.groupId;
    
    // 1. Load cached history
    _loadCachedMessages();

    if (widget.isLocalMesh && widget.lat != null && widget.lng != null) {
      WebRtcManager().joinLocalMesh(widget.lat!, widget.lng!);
    } else {
      WebRtcManager().joinGroup(widget.groupId);
    }
    
    _msgSub = WebRtcManager().messageStream.listen((msg) {
      if (mounted) {
        setState(() {
          // Deduplication using unique messageId
          if (!_messages.any((m) => m.messageId == msg.messageId)) {
            _messages.add(msg);
            _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            // Save incoming msg to cache
            ChatCache().saveMessage(widget.groupId, msg);
          }
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

  Future<void> _loadCachedMessages() async {
    final cached = await ChatCache().loadMessages(widget.groupId);
    if (!mounted) return;
    setState(() {
      _messages.addAll(cached);
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
    _scrollToBottom();
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
    _currentlyOpenGroupId = null; // Reset when chat closes
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    
    // Broadcast via WebRTC
    WebRtcManager().broadcastMessage(text);
    _msgController.clear();
  }

  void _clearMessages() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text('Are you sure you want to clear all messages? This will only clear your local view.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _messages.clear();
              });
              // Clear from cache
              ChatCache().clearMessages(widget.groupId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat history cleared')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
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
          // Clear messages button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Messages',
            onPressed: () => _clearMessages(),
          ),
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
            _buildInputArea(onlinePeers),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(GroupMessage msg, bool isMe) {
    // Format timestamp
    final DateTime dt = DateTime.fromMillisecondsSinceEpoch(msg.timestamp);
    final String timeString = DateFormat('HH:mm').format(dt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe)
                Text(
                  msg.senderName,
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              if (!isMe) const SizedBox(width: 6),
              Text(
                timeString,
                style: const TextStyle(color: Colors.white54, fontSize: 8),
              ),
            ],
          ),
          const SizedBox(height: 2),
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

  Widget _buildInputArea(int onlinePeers) {
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
                  hintText: onlinePeers > 0 ? 'Direct P2P Message...' : 'Connecting to P2P Mesh...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  enabled: onlinePeers > 0,
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
              onPressed: onlinePeers > 0 ? _sendMessage : null,
              backgroundColor: onlinePeers > 0 ? Colors.cyanAccent : Colors.grey,
              child: Icon(
                onlinePeers > 0 ? Icons.send : Icons.sync,
                color: Colors.black, 
                size: 20
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _inviteMoreFriends() {
    final myUid = WebRtcManager().auth.currentUser?.uid;
    if (myUid == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 400,
        child: Column(
          children: [
            const Text('Invite Friends to Session', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('They will receive a notification to join this P2P channel.', style: TextStyle(color: Colors.white60, fontSize: 12)),
            const Divider(color: Colors.white24, height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(myUid)
                    .collection('friends')
                    .where('status', isEqualTo: 'friends')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No friends found to invite.', style: TextStyle(color: Colors.grey)));
                  }

                  final friendDocs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: friendDocs.length,
                    itemBuilder: (context, index) {
                      final friendData = friendDocs[index].data() as Map<String, dynamic>;
                      final friendUid = friendDocs[index].id;
                      final email = friendData['email'] ?? 'Unknown';

                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(email, style: const TextStyle(color: Colors.white)),
                        trailing: ElevatedButton(
                          onPressed: () {
                            WebRtcManager().sendInvite(friendUid, widget.groupId, widget.groupName);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Invitation sent to $email'), backgroundColor: Colors.green),
                            );
                          },
                          child: const Text('Invite'),
                        ),
                      );
                    },
                  );
                },
              ),
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../network_manager.dart';
import '../location_manager.dart';
import 'add_friend_dialog.dart';
import 'chat_screen.dart';
import '../network/webrtc_manager.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  String _currentOpenChatId = ''; // Track currently open chat to prevent duplicates
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
  }



  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Friends')),
        body: const Center(child: Text('Please log in to see friends.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.radar),
            tooltip: 'Join Nearby Mesh',
            onPressed: () async {
              // Prevent opening duplicate chats
              if (_currentOpenChatId == 'local_mesh') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Local Mesh chat is already open')),
                );
                return;
              }
              
              final pos = await LocationManager().getCurrentPosition();
              if (!mounted) return;
              _currentOpenChatId = 'local_mesh';
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    groupId: 'local_mesh', // Logic handled in ChatScreen init or WebRtcManager
                    groupName: 'Nearby Mesh (300m)',
                    isLocalMesh: true,
                    lat: pos.latitude,
                    lng: pos.longitude,
                  ),
                ),
              ).then((_) {
                _currentOpenChatId = ''; // Reset when chat closes
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.groups_outlined),
            tooltip: 'Join Global Chat',
            onPressed: () {
              // Prevent opening duplicate chats
              if (_currentOpenChatId == 'global_mesh') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Global Mesh chat is already open')),
                );
                return;
              }
              
              _currentOpenChatId = 'global_mesh';
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatScreen(groupId: 'global_mesh', groupName: 'Global Mesh Chat'),
                ),
              ).then((_) {
                _currentOpenChatId = ''; // Reset when chat closes
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(color: Colors.white24, height: 4.0),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('friends')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final friendDocs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: friendDocs.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
            itemBuilder: (context, index) {
              final friendData = friendDocs[index].data() as Map<String, dynamic>;
              return FriendListTile(
                friendUid: friendDocs[index].id,
                friendEmail: friendData['email'] ?? 'Unknown Explorer',
                status: friendData['status'] ?? 'pending',
                onAccept: () => _acceptFriendRequest(friendDocs[index].id, friendData['email'] ?? ''),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddFriendDialog(context),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group_off, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No friends yet.', style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _openAddFriendDialog(context),
            icon: const Icon(Icons.person_add),
            label: const Text('Add a Friend'),
          )
        ],
      ),
    );
  }

  Future<void> _acceptFriendRequest(String friendUid, String friendEmail) async {
    if (currentUser == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final myFriendRef = FirebaseFirestore.instance
          .collection('users').doc(currentUser!.uid)
          .collection('friends').doc(friendUid);
      batch.update(myFriendRef, {'status': 'friends'});

      final theirFriendRef = FirebaseFirestore.instance
          .collection('users').doc(friendUid)
          .collection('friends').doc(currentUser!.uid);
      batch.update(theirFriendRef, {'status': 'friends'});

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are now friends with $friendEmail!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openAddFriendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddFriendDialog(),
    );
  }
}

class FriendListTile extends StatefulWidget {
  final String friendUid;
  final String friendEmail;
  final String status;
  final VoidCallback onAccept;

  const FriendListTile({
    super.key,
    required this.friendUid,
    required this.friendEmail,
    required this.status,
    required this.onAccept,
  });

  @override
  State<FriendListTile> createState() => _FriendListTileState();
}

class _FriendListTileState extends State<FriendListTile> {
  StreamSubscription? _playersSub;
  StreamSubscription? _locationSub;
  Timer? _refreshTimer;

  Position? _currentPosition;
  Map<String, dynamic>? _friendActiveData;
  bool get _isOnline => _friendActiveData != null;

  @override
  void initState() {
    super.initState();
    
    _currentPosition = LocationManager().lastPosition;
    _updateFriendData(NetworkManager().lastPlayers);

    _playersSub = NetworkManager().playersStream.listen((players) {
      if (mounted) setState(() => _updateFriendData(players));
    });

    _locationSub = LocationManager().positionStream.listen((pos) {
      if (mounted) setState(() => _currentPosition = pos);
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _isOnline) setState(() {});
    });
  }

  void _updateFriendData(List<dynamic> players) {
    try {
      final found = players.firstWhere(
        (p) => p['uid'] == widget.friendUid,
        orElse: () => null,
      );
      
      if (found != null) {
        _friendActiveData = Map<String, dynamic>.from(found as Map);
        // debugPrint('[FRIENDS] Found friend ${widget.friendEmail} online! UID: ${widget.friendUid}');
      } else {
        _friendActiveData = null;
        // debugPrint('[FRIENDS] Friend ${widget.friendEmail} (UID: ${widget.friendUid}) is not in players list.');
      }
    } catch (e) {
      debugPrint('[FRIENDS] Error updating friend data: $e');
      _friendActiveData = null;
    }
  }

  @override
  void dispose() {
    _playersSub?.cancel();
    _locationSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String proximityText = "";
    if (_isOnline && widget.status == 'friends') {
      proximityText = " • Online";
      if (_currentPosition != null && _friendActiveData!['lat'] != null && _friendActiveData!['lng'] != null) {
        try {
          double distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            (_friendActiveData!['lat'] as num).toDouble(),
            (_friendActiveData!['lng'] as num).toDouble(),
          );
          proximityText = " • ${distance.toInt()}m away";
        } catch (e) {
          debugPrint('[FRIENDS] Distance calc error: $e');
        }
      }
    }

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: widget.status == 'friends' ? Colors.green : Colors.orange,
            child: const Icon(Icons.person, color: Colors.white),
          ),
          if (_isOnline && widget.status == 'friends')
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(widget.friendEmail, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('Status: ${widget.status.replaceAll('_', ' ')}$proximityText'),
      trailing: _buildTrailing(),
    );
  }

  Widget? _buildTrailing() {
    if (widget.status == 'request_received') {
      return ElevatedButton(
        onPressed: widget.onAccept,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
        child: const Text('Accept'),
      );
    }
    if (widget.status == 'pending') {
      return const Text('Pending...', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));
    }
    if (widget.status == 'friends') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isOnline)
            IconButton(
              icon: const Icon(Icons.add_comment_outlined, color: Colors.greenAccent, size: 24),
              tooltip: 'Private P2P Chat',
              onPressed: () {
                final myUid = FirebaseAuth.instance.currentUser?.uid;
                if (myUid == null) return;
                // Use a DETERMINISTIC group ID for 1-to-1 P2P invitation to avoid split-brain
                final uids = [myUid, widget.friendUid]..sort();
                final groupId = 'p2p_invite_${uids[0]}_${uids[1]}';
                
                WebRtcManager().sendInvite(widget.friendUid, groupId, 'Private Chat');
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      groupId: groupId,
                      groupName: 'Private Chat',
                    ),
                  ),
                );
              },
            ),
          if (!_isOnline)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.wifi_off, color: Colors.grey, size: 20),
            ),
        ],
      );
    }
    return null;
  }
}

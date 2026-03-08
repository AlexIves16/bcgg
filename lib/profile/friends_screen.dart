import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_friend_dialog.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(
            color: Colors.white24,
            height: 4.0,
          ),
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
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  )
                ],
              ),
            );
          }

          final friendDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: friendDocs.length,
            itemBuilder: (context, index) {
              final friendData = friendDocs[index].data() as Map<String, dynamic>;
              final String friendEmail = friendData['email'] ?? 'Unknown Explorer';
              final String status = friendData['status'] ?? 'pending';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: status == 'accepted' ? Colors.green : Colors.orange,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: Text(friendEmail, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Status: $status'),
                trailing: status == 'pending'
                    ? const Icon(Icons.hourglass_empty, color: Colors.orange)
                    : const Icon(Icons.check_circle, color: Colors.green),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddFriendDialog(context),
        tooltip: 'Add Friend',
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _openAddFriendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddFriendDialog(),
    );
  }
}

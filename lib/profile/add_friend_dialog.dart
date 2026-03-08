import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddFriendDialog extends StatefulWidget {
  const AddFriendDialog({super.key});

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  final TextEditingController _emailController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;
  String _message = '';

  Future<void> _searchAndAddFriend() async {
    final String targetEmail = _emailController.text.trim().toLowerCase();
    
    if (targetEmail.isEmpty || !targetEmail.contains('@')) {
      setState(() => _message = 'Please enter a valid email.');
      return;
    }

    if (targetEmail == currentUser?.email?.toLowerCase()) {
      setState(() => _message = "You can't add yourself as a friend!");
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      // 1. Find the target user by email
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: targetEmail)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() => _message = 'No explorer found with this email.');
        return;
      }

      final targetUserDoc = querySnapshot.docs.first;
      final String targetUid = targetUserDoc.id;

      // 2. Add to CURRENT USER's friend list (Pending)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('friends')
          .doc(targetUid)
          .set({
        'friendUid': targetUid,
        'email': targetEmail,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3. Add to TARGET USER's friend list (Request Received)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('friends')
          .doc(currentUser!.uid)
          .set({
        'friendUid': currentUser!.uid,
        'email': currentUser!.email ?? 'Unknown Explorer',
        'status': 'request_received', // In the future, target user can accept this
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend request sent to $targetEmail!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _message = 'Error adding friend: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a Friend'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter your friend\'s Ethereum registered email:'),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Friend Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _searchAndAddFriend(),
          ),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_message, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        _isLoading
            ? const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : ElevatedButton(
                onPressed: _searchAndAddFriend,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text('Send Request', style: TextStyle(color: Colors.white)),
              ),
      ],
    );
  }
}

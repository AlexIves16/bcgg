import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({super.key});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final TextEditingController _usernameController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  bool _isLoading = false;
  String? _avatarBase64;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    if (currentUser == null) return;
    
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _usernameController.text = data['username'] ?? '';
        _avatarBase64 = data['avatarBase64'];
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // Use low quality and tiny resolution to ensure the Base64 string is small (< 1MB Firestore limit)
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 150,
      maxHeight: 150,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final base64String = base64Encode(bytes);
      
      setState(() {
        _avatarBase64 = base64String;
      });
    }
  }

  Future<void> _saveProfile() async {
    final String username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).set({
        'username': username,
        'avatarBase64': _avatarBase64,
        'email': currentUser!.email,
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Widget _buildAvatarPreview() {
    if (_avatarBase64 != null) {
      return CircleAvatar(
        radius: 40,
        backgroundImage: MemoryImage(base64Decode(_avatarBase64!)),
      );
    }

    if (_usernameController.text.trim().isNotEmpty) {
      // Auto-generate Pixel Art via DiceBear if no custom image
      final String seed = Uri.encodeComponent(_usernameController.text.trim());
      return CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey[200],
        backgroundImage: NetworkImage('https://api.dicebear.com/8.x/pixel-art/png?seed=$seed'),
      );
    }

    return const CircleAvatar(
      radius: 40,
      backgroundColor: Colors.grey,
      child: Icon(Icons.person, size: 40, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: _isLoading 
        ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
        : SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      _buildAvatarPreview(),
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Tap to upload photo', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 24),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  onChanged: (_) => setState(() {}), // Trigger avatar redraw if using DiceBear
                ),
              ],
            ),
          ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveProfile,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

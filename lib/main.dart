import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'map_screen.dart';
import 'sensor_manager.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'network/webrtc_manager.dart';
import 'profile/chat_screen.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Initialize SensorManager here as requested
    await SensorManager().init();
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }
  
  runApp(const DigitalEtherApp());
}

class DigitalEtherApp extends StatelessWidget {
  const DigitalEtherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalNavigatorKey,
      title: 'Digital Ether',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = false;
  bool _isInitCalled = false;
  StreamSubscription? _globalInviteSub;

  @override
  void initState() {
    super.initState();
    _checkInit();
    _listenForGlobalInvites();
  }

  void _listenForGlobalInvites() {
    _globalInviteSub = WebRtcManager().invitationStream.listen((invite) {
      if (!mounted) return;
      
      final ctx = globalNavigatorKey.currentContext;
      if (ctx == null) return;
      
      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: const Text('P2P Chat Invite', style: TextStyle(color: Colors.white)),
          content: Text('Friend ${invite['senderUid']} invites you to join "${invite['groupName']}"', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Decline', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(groupId: invite['groupId'], groupName: invite['groupName']),
                  ),
                );
              },
              child: const Text('Join'),
            ),
          ],
        ),
      );
    });
  }
  
  @override
  void dispose() {
    _globalInviteSub?.cancel();
    super.dispose();
  }

  void _checkInit() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && !_isInitCalled) {
        _isInitCalled = true;
        SensorManager().init();
        WebRtcManager().startListeningForInvites();
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() { _isLoading = false; });
        return; // User canceled
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Google Sign-In failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (snapshot.hasData) {
          // User is logged in, initialization is handled by auth listener
          return const MapScreen();
        }
        
        // User is NOT logged in, show login screen
        return Scaffold(
          body: Center(
            child: _isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
          ),
        );
      },
    );
  }
}

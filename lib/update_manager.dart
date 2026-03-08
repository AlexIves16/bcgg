import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'network_manager.dart'; // To get the Ngrok SERVER_URL

class UpdateManager {
  static final UpdateManager _instance = UpdateManager._internal();
  factory UpdateManager() => _instance;
  UpdateManager._internal();

  /// Checks the server for a new APK version. If found, shows a non-dismissible dialog.
  Future<void> checkForUpdates(BuildContext context) async {
    try {
      // 1. Get current installed version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      // packageInfo.buildNumber is usually a string like "1"
      int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;

      // 2. Fetch latest version from Game Server
      final String versionUrl = '${NetworkManager.serverUrl.replaceFirst("ws://", "http://").replaceFirst("wss://", "https://")}/api/version';
      
      final response = await http.get(Uri.parse(versionUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        int serverVersion = data['version'] ?? 1;
        String downloadUrl = data['url'] ?? '';

        // 3. Compare and Show Dialog
        if (serverVersion > currentBuildNumber) {
          _showUpdateDialog(context, serverVersion, downloadUrl);
        }
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
      // Silently fail if server is down or no internet
    }
  }

  void _showUpdateDialog(BuildContext context, int serverVersion, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false, // Must update
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.system_update, color: Colors.blue),
                SizedBox(width: 8),
                Text('Update Available!'),
              ],
            ),
            content: Text(
              'A new version (v$serverVersion) of Digital Ether is available. '
              'Please download and install the latest APK to continue playing.'
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: () async {
                  final Uri url = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    debugPrint('Could not launch $url');
                  }
                },
                child: const Text('Download APK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }
}

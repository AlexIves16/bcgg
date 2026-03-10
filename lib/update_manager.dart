import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// GitHub Releases OTA — no server or ngrok needed!
const String _githubOwner = 'AlexIves16';  // Your GitHub username
const String _githubRepo  = 'bcgg';         // Your GitHub repo name

class UpdateManager {
  static final UpdateManager _instance = UpdateManager._internal();
  factory UpdateManager() => _instance;
  UpdateManager._internal();

  /// Checks GitHub Releases for a new APK version.
  /// If found, shows a non-dismissible dialog.
  Future<void> checkForUpdates(BuildContext context) async {
    try {
      // 1. Get current installed build number
      final packageInfo = await PackageInfo.fromPlatform();
      final int currentBuild = int.tryParse(packageInfo.buildNumber) ?? 1;

      // 2. Fetch latest release from GitHub API (no auth needed for public repos)
      final uri = Uri.parse(
        'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest',
      );
      final response = await http.get(uri, headers: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // tag_name can be "v25" or "0.25"
        final tagName = data['tag_name'] as String? ?? '0';
        
        // Extract the last numeric part (e.g., "0.25" -> "25", "v25" -> "25")
        final String numericPart = tagName.split('.').last.replaceAll(RegExp(r'[^0-9]'), '');
        final serverVersion = int.tryParse(numericPart) ?? 0;

        // Find the APK asset download URL
        final assets = (data['assets'] as List?)?.cast<Map<String, dynamic>>();
        final apkAsset = assets?.firstWhere(
          (a) => (a['name'] as String).endsWith('.apk'),
          orElse: () => <String, dynamic>{},
        );
        final downloadUrl = apkAsset?['browser_download_url'] as String? ?? '';

        debugPrint('[Update] Current: $currentBuild, Server: $serverVersion');
        if (serverVersion > currentBuild && downloadUrl.isNotEmpty) {
          if (context.mounted) {
            _showUpdateDialog(context, serverVersion, downloadUrl);
          }
        }
      }
    } catch (e) {
      debugPrint('[Update] Check failed (offline?): $e');
    }
  }

  void _showUpdateDialog(BuildContext context, int version, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.system_update, color: Colors.blue),
              SizedBox(width: 8),
              Text('Update Available!'),
            ],
          ),
          content: Text(
            'New version v$version of Digital Ether is available.\n'
            'Please install it to continue playing.',
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () async {
                final uri = Uri.parse(downloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.download, color: Colors.white),
              label: const Text('Download APK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

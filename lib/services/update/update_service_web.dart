import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:web/web.dart' as web;
import 'update_service.dart';

UpdateService getUpdateService() => UpdateServiceWeb();

class UpdateServiceWeb implements UpdateService {
  Timer? _timer;
  String? _currentVersion;
  bool _isUpdateAvailable = false;

  // Poll every 15 minutes
  static const Duration _pollInterval = Duration(minutes: 15);

  @override
  void init(BuildContext context) {
    debugPrint('[UpdateService] Initializing auto-update check (Web)...');
    _checkVersion(context); // Check immediately on startup

    _timer = Timer.periodic(_pollInterval, (_) {
      _checkVersion(context);
    });
  }

  Future<void> _checkVersion(BuildContext context) async {
    try {
      // 1. Get current running version
      if (_currentVersion == null) {
        final packageInfo = await PackageInfo.fromPlatform();
        _currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
        debugPrint('[UpdateService] Current version: $_currentVersion');
      }

      // 2. Fetch latest version from server
      // Add timestamp to prevent caching
      final uri = Uri.parse(
        '/version.json?t=${DateTime.now().millisecondsSinceEpoch}',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String latestVersion = data['version'];

        if (_isNewerVersion(latestVersion, _currentVersion!)) {
          debugPrint('[UpdateService] New version available: $latestVersion');
          if (!_isUpdateAvailable && context.mounted) {
            _isUpdateAvailable = true;
            _showUpdatePrompt(context);
          }
        } else {
          debugPrint('[UpdateService] Client is up to date.');
        }
      }
    } catch (e) {
      debugPrint('[UpdateService] Error checking for updates: $e');
    }
  }

  bool _isNewerVersion(String latest, String current) {
    return latest != current;
  }

  void _showUpdatePrompt(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'A new version of TopScore AI is available!',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
        duration: const Duration(days: 1), // Persistent
        action: SnackBarAction(
          label: 'Reload',
          textColor: Colors.amber,
          onPressed: () {
            web.window.location.reload();
          },
        ),
      ),
    );
  }

  void dispose() {
    _timer?.cancel();
  }
}

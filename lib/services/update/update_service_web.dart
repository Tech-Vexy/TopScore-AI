import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'update_service.dart';

UpdateService getUpdateService() => UpdateServiceWeb();

class UpdateServiceWeb implements UpdateService {
  Timer? _timer;
  String? _currentVersion;
  bool _isUpdateAvailable = false;

  // Poll every 5 minutes (service worker handles auto-updates at 60 seconds)
  static const Duration _pollInterval = Duration(minutes: 5);

  @override
  void init(BuildContext context) {
    debugPrint('[UpdateService] Initializing version monitoring (Web)...');
    debugPrint('[UpdateService] Auto-updates handled by Service Worker');
    _checkVersion(context); // Check immediately on startup

    _timer = Timer.periodic(_pollInterval, (_) {
      _checkVersion(context);
    });
  }

  Future<void> _checkVersion(BuildContext context) async {
    try {
      // Don't check if update already detected
      if (_isUpdateAvailable) {
        return;
      }

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
          debugPrint('[UpdateService] Service Worker will auto-update within 60 seconds');
          if (!_isUpdateAvailable) {
            _isUpdateAvailable = true;
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

  void dispose() {
    _timer?.cancel();
  }
}

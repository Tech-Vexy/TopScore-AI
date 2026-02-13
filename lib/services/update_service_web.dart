import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:web/web.dart' as web;

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  bool _isChecking = false;
  Timer? _timer;

  void startAutoCheck() {
    // Initial check
    checkForUpdate();
    // Periodic check every 60 seconds
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => checkForUpdate(),
    );
  }

  Future<void> checkForUpdate() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final localVersion = await _getLocalVersion();
      final serverVersion = await _getServerVersion();

      if (localVersion == null || serverVersion == null) return;

      final cleanLocal = _cleanVersion(localVersion);
      final cleanServer = _cleanVersion(serverVersion);

      debugPrint('[UpdateService] Current version: $localVersion');
      debugPrint('[UpdateService] New version available: $serverVersion');
      debugPrint('[UpdateService] Clean compare: $cleanLocal vs $cleanServer');

      if (cleanLocal != cleanServer) {
        debugPrint('[UpdateService] Real update found. Reloading...');
        _reloadApp();
      } else {
        debugPrint(
          '[UpdateService] Versions match (ignoring trailing metadata).',
        );
      }
    } catch (e) {
      debugPrint('[UpdateService] Update check failed: $e');
    } finally {
      _isChecking = false;
    }
  }

  Future<String?> _getLocalVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (info.buildNumber.trim().isEmpty) return info.version.trim();
    return '${info.version.trim()}+${info.buildNumber.trim()}';
  }

  Future<String?> _getServerVersion() async {
    final cacheBust = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.parse('/version.json?v=$cacheBust');
    final response = await http.get(
      uri,
      headers: const {'cache-control': 'no-cache'},
    );

    if (response.statusCode != 200) {
      debugPrint(
        '[UpdateService] version.json not available (${response.statusCode}).',
      );
      return null;
    }

    final body = response.body.trim();
    if (body.isEmpty) return null;

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['version'] != null) {
        return decoded['version'].toString().trim();
      }
    } catch (_) {
      // If not JSON, fall through to return raw body.
    }

    return body;
  }

  String _cleanVersion(String version) {
    return version.trim();
  }

  void _reloadApp() {
    web.window.location.reload();
  }
}

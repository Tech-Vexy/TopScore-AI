import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

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
        await _reloadApp();
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
    // Use relative path or origin-aware URI to avoid ERR_NAME_NOT_RESOLVED
    final currentUri = Uri.base;
    final uri = Uri(
      scheme: currentUri.scheme,
      host: currentUri.host,
      port: currentUri.port,
      path: '/version.json',
      queryParameters: {'v': cacheBust.toString()},
    );
    final response = await http.get(
      uri,
      headers: const {'cache-control': 'no-cache'},
    );

    if (response.statusCode != 200) {
      debugPrint('[UpdateService] Server returned ${response.statusCode}');
      return null;
    }

    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('application/json') &&
        !response.body.trim().startsWith('{')) {
      debugPrint(
          '[UpdateService] Invalid content type: $contentType. Likely HTML error page.');
      return null;
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['version'] != null) {
        return decoded['version'].toString().trim();
      }
    } catch (e) {
      debugPrint('[UpdateService] JSON Decode failed: $e');
    }

    final body = response.body.trim();
    return body;
  }

  String _cleanVersion(String version) {
    return version.trim();
  }

  Future<void> _reloadApp() async {
    try {
      // 1. Unregister Service Workers
      final registrations =
          (await web.window.navigator.serviceWorker.getRegistrations().toDart)
              .toDart;
      for (final reg in registrations) {
        await reg.unregister().toDart;
        debugPrint('[UpdateService] Unregistered service worker');
      }

      // 2. Clear Cache Storage
      final cacheKeys = (await web.window.caches.keys().toDart).toDart;
      for (final key in cacheKeys) {
        final keyString = key.toDart;
        await web.window.caches.delete(keyString).toDart;
        debugPrint('[UpdateService] Deleted cache: $keyString');
      }
    } catch (e) {
      debugPrint('[UpdateService] Cache clearing failed: $e');
    }

    // 3. Final Reload
    web.window.location.reload();
  }
}

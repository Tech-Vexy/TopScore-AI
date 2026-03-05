import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

/// Polls /version.json and auto-reloads when a newer build is detected.
///
/// The build script writes both `version` (semver) and `buildTimestamp`
/// (ISO-8601 UTC) into version.json on every `flutter build web`.  This
/// service caches the first-seen timestamp in memory and compares it on
/// every poll.  Any change triggers a service-worker purge + hard reload.
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  bool _isChecking = false;
  Timer? _timer;

  /// The buildTimestamp captured when the app first loaded.
  /// A mismatch means a newer build has been deployed.
  String? _initialBuildTimestamp;

  void startAutoCheck() {
    // Capture initial version immediately
    _captureInitialVersion();
    // Periodic check every 30 seconds
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => checkForUpdate(),
    );
  }

  /// Fetch the server version once at startup to establish the baseline.
  Future<void> _captureInitialVersion() async {
    try {
      final serverData = await _fetchVersionJson();
      if (serverData != null) {
        _initialBuildTimestamp = serverData['buildTimestamp'] as String?;
        debugPrint(
          '[UpdateService] Baseline: v${serverData['version']} '
          '@ $_initialBuildTimestamp',
        );
      }
    } catch (e) {
      debugPrint('[UpdateService] Initial version capture failed: $e');
    }
  }

  Future<void> checkForUpdate() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final serverData = await _fetchVersionJson();
      if (serverData == null) return;

      final serverVersion = serverData['version'] as String? ?? '';
      final serverTimestamp = serverData['buildTimestamp'] as String? ?? '';

      debugPrint(
        '[UpdateService] Poll: v$serverVersion @ $serverTimestamp '
        '(baseline: $_initialBuildTimestamp)',
      );

      // If we haven't captured a baseline yet, store it now
      if (_initialBuildTimestamp == null) {
        _initialBuildTimestamp = serverTimestamp;
        return;
      }

      // Compare timestamps — any change means a new build
      if (serverTimestamp.isNotEmpty &&
          serverTimestamp != _initialBuildTimestamp) {
        debugPrint(
          '[UpdateService] New build detected! '
          '$_initialBuildTimestamp -> $serverTimestamp. Reloading...',
        );
        await _reloadApp();
      }
    } catch (e) {
      debugPrint('[UpdateService] Update check failed: $e');
    } finally {
      _isChecking = false;
    }
  }

  /// Fetches and parses /version.json with cache-busting.
  Future<Map<String, dynamic>?> _fetchVersionJson() async {
    final cacheBust = DateTime.now().millisecondsSinceEpoch;
    final currentUri = Uri.base;
    final uri = Uri(
      scheme: currentUri.scheme,
      host: currentUri.host,
      port: currentUri.port,
      path: '/version.json',
      queryParameters: {'_': cacheBust.toString()},
    );

    final response = await http.get(
      uri,
      headers: const {
        'cache-control': 'no-cache, no-store',
        'pragma': 'no-cache',
      },
    );

    if (response.statusCode != 200) {
      debugPrint('[UpdateService] Server returned ${response.statusCode}');
      return null;
    }

    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('application/json') &&
        !response.body.trim().startsWith('{')) {
      debugPrint(
        '[UpdateService] Invalid content type: $contentType. '
        'Likely HTML error page.',
      );
      return null;
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      debugPrint('[UpdateService] JSON decode failed: $e');
    }

    return null;
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

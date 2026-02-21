import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Exposes real-time network connectivity status to the widget tree.
/// Use [isOnline] to guard Firestore/API calls and show offline UI.
class ConnectivityProvider with ChangeNotifier {
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityProvider() {
    _init();
  }

  Future<void> _init() async {
    // Get initial status
    final results = await Connectivity().checkConnectivity();
    _isOnline = _resultsAreOnline(results);

    // Listen to changes
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final nowOnline = _resultsAreOnline(results);
      if (nowOnline != _isOnline) {
        _isOnline = nowOnline;
        notifyListeners();
      }
    });
  }

  bool _resultsAreOnline(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

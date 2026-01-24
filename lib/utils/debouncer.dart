import 'dart:async';

/// Utility class for debouncing rapid successive calls.
/// 
/// Useful for search inputs to prevent firing API calls on every keystroke.
/// 
/// Example:
/// ```dart
/// final _debouncer = Debouncer(milliseconds: 300);
/// 
/// TextField(
///   onChanged: (query) {
///     _debouncer.run(() => _performSearch(query));
///   },
/// )
/// ```
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({this.milliseconds = 300});

  /// Runs the action after the debounce delay.
  /// Cancels any pending action if called again before delay completes.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  /// Cancels any pending action.
  void cancel() {
    _timer?.cancel();
  }

  /// Disposes the debouncer. Call in widget's dispose method.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// Returns true if there's a pending action.
  bool get isPending => _timer?.isActive ?? false;
}

/// Throttle utility - ensures action runs at most once per interval.
/// Unlike debounce, it executes immediately then ignores subsequent calls.
/// 
/// Useful for scroll events, button clicks, etc.
class Throttler {
  final int milliseconds;
  DateTime? _lastRun;

  Throttler({this.milliseconds = 300});

  /// Runs the action if enough time has passed since last run.
  void run(void Function() action) {
    final now = DateTime.now();
    if (_lastRun == null ||
        now.difference(_lastRun!).inMilliseconds >= milliseconds) {
      _lastRun = now;
      action();
    }
  }

  /// Resets the throttler, allowing the next call to execute immediately.
  void reset() {
    _lastRun = null;
  }
}

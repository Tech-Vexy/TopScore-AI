import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  // Data to pass to Chat Screen
  String? _pendingMessage;
  XFile? _pendingImage;

  String? get pendingMessage => _pendingMessage;
  XFile? get pendingImage => _pendingImage;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('current_nav_index')) {
      _currentIndex = prefs.getInt('current_nav_index') ?? 0;
      notifyListeners();
    }
  }

  /// Switch the tab on HomeScreen
  Future<void> setIndex(int index) async {
    _currentIndex = index;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_nav_index', index);
  }

  /// Helper to go specifically to AI Tutor with data
  void navigateToChat({String? message, XFile? image, BuildContext? context}) {
    _pendingMessage = message;
    _pendingImage = image;
    setIndex(2); // Updates index and persists it

    // If we are deep in a stack (e.g., PDF Viewer), go back to Home
    if (context != null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// Clear data after Chat Screen consumes it
  void clearPendingData() {
    _pendingMessage = null;
    _pendingImage = null;
    // We don't notifyListeners here to avoid rebuild loops
  }
}

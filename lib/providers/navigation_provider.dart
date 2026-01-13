import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  // Data to pass to Chat Screen
  String? _pendingMessage;
  XFile? _pendingImage;

  String? get pendingMessage => _pendingMessage;
  XFile? get pendingImage => _pendingImage;

  /// Switch the tab on HomeScreen
  void setIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  /// Helper to go specifically to AI Tutor with data
  void navigateToChat({String? message, XFile? image, BuildContext? context}) {
    _pendingMessage = message;
    _pendingImage = image;
    _currentIndex = 2; // Assuming Chat is at index 2
    notifyListeners();

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

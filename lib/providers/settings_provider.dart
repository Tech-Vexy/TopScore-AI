import 'package:flutter/material.dart';
import '../services/offline_service.dart';

class SettingsProvider with ChangeNotifier {
  final OfflineService _offlineService = OfflineService();
  bool _isLiteMode = false;
  ThemeMode _themeMode = ThemeMode.system; // Default to system

  bool get isLiteMode => _isLiteMode;
  ThemeMode get themeMode => _themeMode;

  SettingsProvider() {
    _loadSettings();
  }

  void _loadSettings() {
    _isLiteMode = _offlineService.getLiteMode();
    // In a real app, save/load theme mode from SharedPreferences here
    notifyListeners();
  }

  Future<void> toggleLiteMode(bool value) async {
    _isLiteMode = value;
    await _offlineService.saveLiteMode(value);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}

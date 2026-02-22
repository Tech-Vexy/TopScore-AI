import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiTutorHistoryProvider with ChangeNotifier {
  List<Map<String, dynamic>> _threads = [];
  bool _isLoading = false;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  List<Map<String, dynamic>> get threads => _threads;
  bool get isLoading => _isLoading;

  String get _backendUrl {
    if (kIsWeb) {
      return 'https://agent.topscoreapp.ai';
    }
    if (Platform.isAndroid) {
      return 'https://agent.topscoreapp.ai';
    }
    return 'https://agent.topscoreapp.ai';
  }

  Future<void> fetchHistory(String userId, {bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _threads.isNotEmpty &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return;
    }

    if (userId == 'guest') {
      _threads = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/api/history/$userId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _threads = data.map((item) {
          return {
            'thread_id': item['thread_id'],
            'title': item['title'],
            'updated_at': item['updated_at'],
            'model': item['model'],
          };
        }).toList();

        // Sort by updated_at descending if available
        _threads.sort((a, b) {
          final aTime = a['updated_at'] ?? 0;
          final bTime = b['updated_at'] ?? 0;
          if (aTime is int && bTime is int) {
            return bTime.compareTo(aTime);
          }
          return 0;
        });

        _lastFetchTime = DateTime.now();
      } else {
        debugPrint('API Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

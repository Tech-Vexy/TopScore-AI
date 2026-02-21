import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static const String _defaultBaseUrl = 'https://agent.topscoreapp.ai';

  static String get baseUrl {
    final envUrl = kIsWeb ? null : dotenv.env['API_BASE_URL'];
    return envUrl ?? _defaultBaseUrl;
  }

  static String get wsUrl {
    final base = baseUrl;
    final scheme = base.startsWith('https') ? 'wss' : 'ws';
    final host = base.replaceFirst(RegExp(r'^https?://'), '');
    return '$scheme://$host/ws';
  }
}

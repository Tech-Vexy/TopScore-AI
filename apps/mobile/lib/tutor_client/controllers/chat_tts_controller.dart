import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';

class ChatTtsController extends ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();

  // State Variables
  bool _isTtsSpeaking = false;
  bool _isTtsPaused = false;
  String? _speakingMessageId;
  String _currentLanguage = 'en-US';

  // Getters
  bool get isTtsSpeaking => _isTtsSpeaking;
  bool get isTtsPaused => _isTtsPaused;
  String? get speakingMessageId => _speakingMessageId;
  String get currentLanguage => _currentLanguage;

  // Callbacks
  Function(void Function())? _onVoiceDialogSetState;
  final VoidCallback? onTtsComplete; // For chaining (Voice Loop)

  ChatTtsController({this.onTtsComplete}) {
    _initTts();
  }

  void setVoiceDialogSetState(Function(void Function())? callback) {
    _onVoiceDialogSetState = callback;
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    if (kIsWeb) {
      await _flutterTts.setSpeechRate(1.3);
    } else {
      await _flutterTts.setSpeechRate(0.5);
    }

    _flutterTts.setStartHandler(() {
      _isTtsSpeaking = true;
      _isTtsPaused = false;
      notifyListeners();
      _onVoiceDialogSetState?.call(() {});
    });

    _flutterTts.setCompletionHandler(() {
      _isTtsSpeaking = false;
      _isTtsPaused = false;
      _speakingMessageId = null;
      notifyListeners();
      _onVoiceDialogSetState?.call(() {});

      onTtsComplete?.call();
    });

    _flutterTts.setCancelHandler(() {
      _isTtsSpeaking = false;
      _isTtsPaused = false;
      _speakingMessageId = null;
      notifyListeners();
    });

    _flutterTts.setPauseHandler(() {
      _isTtsPaused = true;
      notifyListeners();
    });

    _flutterTts.setContinueHandler(() {
      _isTtsPaused = false;
      notifyListeners();
    });
  }

  /// Switch TTS language. Supports 'en' (English) and 'sw' (Kiswahili).
  Future<void> setLanguage(String langCode) async {
    final locale = langCode == 'sw' ? 'sw-KE' : 'en-US';
    await _flutterTts.setLanguage(locale);
    _currentLanguage = locale;
    notifyListeners();
  }

  Future<void> speak(String text, {String? messageId}) async {
    final textToSpeak = _cleanMarkdown(text);
    if (textToSpeak.isNotEmpty) {
      _speakingMessageId = messageId;
      notifyListeners();
      await _flutterTts.speak(textToSpeak);
    }
  }

  /// Speak AI response aloud during live voice mode
  Future<void> speakInVoiceMode(String text) async {
    final cleanedText = _cleanMarkdown(text);
    if (cleanedText.isEmpty) {
      // If nothing to speak, trigger completion immediately to restart listening
      onTtsComplete?.call();
      return;
    }

    _isTtsSpeaking = true;
    notifyListeners();
    _onVoiceDialogSetState?.call(() {});

    if (!kIsWeb) {
      HapticFeedback.lightImpact();
    }

    await _flutterTts.speak(cleanedText);
  }

  Future<void> pause() async {
    await _flutterTts.pause();
  }

  Future<void> resume() async {
    await _flutterTts.speak("");
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isTtsSpeaking = false;
    _isTtsPaused = false;
    _speakingMessageId = null;
    notifyListeners();
  }

  String _cleanMarkdown(String text) {
    var cleaned = text;

    // 1. Remove Fenced Code Blocks (```code```)
    cleaned = cleaned.replaceAll(RegExp(r'```[\s\S]*?```'), '');

    // 2. Remove Images (![alt](url))
    cleaned = cleaned.replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '');

    // 3. Convert Links ([text](url)) to just text
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\[(.*?)\]\(.*?\)'),
      (m) => m[1] ?? '',
    );

    // 4. Remove Horizontal Rules (---, ***)
    cleaned = cleaned.replaceAll(
        RegExp(r'^\s*([-*_])\s*(?:\1\s*){2,}$', multiLine: true), '');

    // 5. Remove Table markup (pipes and separators)
    // Strip separator lines: |---|---|
    cleaned =
        cleaned.replaceAll(RegExp(r'^\s*[:\-|\s]+$', multiLine: true), '');
    // Strip pipes: |
    cleaned = cleaned.replaceAll('|', ' ');

    // 6. Remove Header markers (#, ##, etc.)
    cleaned = cleaned.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');

    // 7. Remove Blockquote markers (>)
    cleaned = cleaned.replaceAll(RegExp(r'^>\s*', multiLine: true), '');

    // 8. Remove List bullets and numbers (-, *, +, 1.)
    cleaned = cleaned.replaceAll(
        RegExp(r'^\s*([-*+]|\d+\.)\s+', multiLine: true), ' ');

    // 9. Remove Bold/Italic markers (**, __, *, _)
    cleaned = cleaned.replaceAll(RegExp(r'(\*\*|__)(.*?)\1'), r'$2');
    cleaned = cleaned.replaceAll(RegExp(r'(\*|_)(.*?)\1'), r'$2');

    // 10. Remove Inline code markers (`)
    cleaned = cleaned.replaceAll('`', '');

    // 11. Remove LaTeX/Math markers ($$, $)
    cleaned = cleaned.replaceAll(r'$$', '').replaceAll(r'$', '');

    // 12. Cleanup extra whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\n+'), '\n');
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ');

    return cleaned.trim();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb, VoidCallback;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:universal_io/io.dart';
import 'package:http/http.dart' as http;

/// Shared audio service for recording, playback, and TTS
/// Extracted from duplicate implementations in chat screens
class AudioService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _ttsAvailable = false;
  bool get ttsAvailable => _ttsAvailable;

  Future<void> initializeTts({
    String language = "en-US",
    double speechRate = 1.0,
    double volume = 1.0,
    double pitch = 1.0,
  }) async {
    if (kIsWeb) {
      _ttsAvailable = false;
      return;
    }

    try {
      await _flutterTts.setLanguage(language);
      await _flutterTts.setSpeechRate(speechRate);
      await _flutterTts.setVolume(volume);
      await _flutterTts.setPitch(pitch);
      _ttsAvailable = true;
    } catch (e) {
      developer.log('TTS init error: $e', name: 'AudioService', level: 900);
      _ttsAvailable = false;
    }
  }

  void setTtsCompletionHandler(VoidCallback handler) {
    _flutterTts.setCompletionHandler(handler);
  }

  void setTtsCancelHandler(VoidCallback handler) {
    _flutterTts.setCancelHandler(handler);
  }

  Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }

  Future<bool> hasRecordingPermission() async {
    return await _audioRecorder.hasPermission();
  }

  Future<void> startRecording() async {
    String path = '';
    if (!kIsWeb) {
      final tempDir = await getTemporaryDirectory();
      path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    } else {
      path = 'audio_recording.m4a';
    }

    await _audioRecorder.start(const RecordConfig(), path: path);
  }

  Future<String?> stopRecording() async {
    return await _audioRecorder.stop();
  }

  Future<String?> getBase64FromRecording(String? path) async {
    if (path == null) return null;

    String? base64Audio;

    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse(path));
        if (response.statusCode == 200) {
          base64Audio = base64Encode(response.bodyBytes);
        }
      } catch (e) {
        developer.log('Error fetching blob: $e', name: 'AudioService', level: 900);
      }
    } else {
      final file = File(path);
      if (await file.exists()) {
        final audioBytes = await file.readAsBytes();
        base64Audio = base64Encode(audioBytes);
      }
    }

    return base64Audio;
  }

  Future<void> playAudio(String url) async {
    try {
      if (kIsWeb) {
        await _audioPlayer.play(UrlSource(url));
      } else {
        if (!url.startsWith('http') && !url.startsWith('data:')) {
          await _audioPlayer.play(DeviceFileSource(url));
        } else {
          await _audioPlayer.play(UrlSource(url));
        }
      }
    } catch (e) {
      developer.log('Error playing audio: $e', name: 'AudioService', level: 900);
    }
  }

  Future<void> playAudioFromBase64(String dataUri) async {
    try {
      final base64Str = dataUri.split(',').last;
      final bytes = base64Decode(base64Str);
      await _audioPlayer.play(BytesSource(bytes));
    } catch (e) {
      developer.log('Error playing base64 audio: $e', name: 'AudioService', level: 900);
    }
  }

  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show File;
import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import '../enhanced_websocket_service.dart';

class ChatAudioController extends ChangeNotifier {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final EnhancedWebSocketService _wsService;

  // State Variables
  bool _isVoiceMode = false;
  bool _isAiSpeaking = false;
  bool _isRecording = false;
  bool _isSpeechDetected = false;
  bool _isPlayingAudio = false;
  String? _playingAudioMessageId;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  // Public Getters
  bool get isVoiceMode => _isVoiceMode;
  bool get isAiSpeaking => _isAiSpeaking;
  bool get isRecording => _isRecording;
  bool get isSpeechDetected => _isSpeechDetected;
  bool get isPlayingAudio => _isPlayingAudio;
  String? get playingAudioMessageId => _playingAudioMessageId;
  Duration get audioDuration => _audioDuration;
  Duration get audioPosition => _audioPosition;

  // VAD State (Private)
  Timer? _amplitudeTimer;
  Timer? _vadTimer;
  DateTime? _lastSpeechTime;
  final double _speechThreshold = -20.0;
  final Duration _silenceTimeout = const Duration(milliseconds: 1200);

  // Callbacks
  Function(void Function())? _onVoiceDialogSetState;
  final Function(String text)? onSendMessage;
  final VoidCallback? onStartListeningCallback;

  ChatAudioController({
    required EnhancedWebSocketService wsService,
    this.onSendMessage,
    this.onStartListeningCallback,
  }) : _wsService = wsService {
    _initAudioPlayer();
  }

  void setVoiceDialogSetState(Function(void Function())? callback) {
    _onVoiceDialogSetState = callback;
  }

  void _initAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      _audioDuration = duration;
      notifyListeners();
    });

    _audioPlayer.onPositionChanged.listen((position) {
      _audioPosition = position;
      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlayingAudio = false;
      _playingAudioMessageId = null;
      _audioPosition = Duration.zero;
      notifyListeners();

      // Auto-listen loop handling for Voice Mode
      if (_isVoiceMode && _isAiSpeaking) {
        _isAiSpeaking = false;
        notifyListeners();
        _onVoiceDialogSetState?.call(() {});
        Future.delayed(const Duration(milliseconds: 300), startListening);
      }
    });
  }

  // --- Public Methods ---

  Future<void> startListening() async {
    if (!_isVoiceMode || _isAiSpeaking || _isRecording) return;

    try {
      if (await _audioRecorder.hasPermission()) {
        // Reset VAD State
        _isSpeechDetected = false;
        _lastSpeechTime = null;
        _vadTimer?.cancel();

        // Safety Timer
        final startTime = DateTime.now();
        const maxDuration = Duration(seconds: 10);

        String path = '';
        if (!kIsWeb) {
          final tempDir = await getTemporaryDirectory();
          path =
              '${tempDir.path}/live_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        } else {
          path = 'live_audio.m4a';
        }

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        _isRecording = true;
        notifyListeners();
        _onVoiceDialogSetState?.call(() {});
        onStartListeningCallback?.call();

        if (!kIsWeb) HapticFeedback.selectionClick();

        _amplitudeTimer?.cancel();
        _amplitudeTimer =
            Timer.periodic(const Duration(milliseconds: 100), (timer) async {
          if (!_isRecording) {
            timer.cancel();
            return;
          }

          if (DateTime.now().difference(startTime) > maxDuration) {
            developer.log('⏱️ Max duration reached. Forcing stop.',
                name: 'ChatAudioController');
            timer.cancel();
            stopListeningAndSend();
            return;
          }

          final amplitude = await _audioRecorder.getAmplitude();
          final currentDb = amplitude.current;

          if (currentDb > _speechThreshold) {
            _lastSpeechTime = DateTime.now();
            if (!_isSpeechDetected) {
              _isSpeechDetected = true;
              notifyListeners();
              _onVoiceDialogSetState?.call(() {});
            }
          }

          if (_isSpeechDetected && _lastSpeechTime != null) {
            final timeSinceSpeech = DateTime.now().difference(_lastSpeechTime!);
            if (timeSinceSpeech > _silenceTimeout) {
              timer.cancel();
              stopListeningAndSend();
            }
          }
        });
      }
    } catch (e) {
      developer.log('Error starting VAD recording: $e',
          name: 'ChatAudioController');
      _stopLiveVoice();
    }
  }

  Future<void> stopListeningAndSend() async {
    _isRecording = false;
    notifyListeners();
    _onVoiceDialogSetState?.call(() {});

    _amplitudeTimer?.cancel();

    // If we stopped but heard NOTHING, just return (don't send empty audio)
    // UNLESS we are manually stopping? No, typically VAD handles this.
    // If _isSpeechDetected is false, we probably shouldn't send anything.
    if (!_isSpeechDetected) return;

    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        String? base64Audio;
        if (kIsWeb) {
          final response = await http.get(Uri.parse(path));
          if (response.statusCode == 200) {
            base64Audio = base64Encode(response.bodyBytes);
          }
        } else {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            base64Audio = base64Encode(bytes);
          }
        }

        if (base64Audio != null) {
          _wsService.sendGeminiAudioMessage(
            base64Audio: base64Audio,
            mimeType: 'audio/aac',
          );
          developer.log('Gemini voice audio sent', name: 'ChatAudioController');
        }
      }
    } catch (e) {
      developer.log('Error sending VAD audio: $e', name: 'ChatAudioController');
      if (_isVoiceMode) {
        Future.delayed(const Duration(milliseconds: 500), startListening);
      }
    }
  }

  Future<void> playGeminiAudioResponse(
      String base64Audio, String mimeType) async {
    if (!_isVoiceMode) return;

    _isAiSpeaking = true;
    notifyListeners();
    _onVoiceDialogSetState?.call(() {});

    if (!kIsWeb) HapticFeedback.lightImpact();

    try {
      final audioBytes = base64Decode(base64Audio);
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        final extension = _getExtensionFromMimeType(mimeType);
        final tempPath =
            '${tempDir.path}/gemini_response_${DateTime.now().millisecondsSinceEpoch}.$extension';
        final file = File(tempPath);
        await file.writeAsBytes(audioBytes);
        await _audioPlayer.play(DeviceFileSource(tempPath));
      } else {
        final dataUrl = 'data:$mimeType;base64,$base64Audio';
        await _audioPlayer.play(UrlSource(dataUrl));
      }
      // Note: Auto-restart logic is in _audioPlayer.onPlayerComplete listener
    } catch (e) {
      developer.log("Gemini audio play error: $e", name: 'ChatAudioController');
      _isAiSpeaking = false;
      notifyListeners();
      _onVoiceDialogSetState?.call(() {});
      Future.delayed(const Duration(milliseconds: 500), startListening);
    }
  }

  Future<void> playAudioResponse(String url) async {
    if (!_isVoiceMode) return;

    _isAiSpeaking = true;
    notifyListeners();
    _onVoiceDialogSetState?.call(() {});

    if (!kIsWeb) HapticFeedback.lightImpact();

    try {
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      developer.log("Audio play error: $e", name: 'ChatAudioController');
      _isAiSpeaking = false;
      notifyListeners();
      _onVoiceDialogSetState?.call(() {});
      Future.delayed(const Duration(milliseconds: 500), startListening);
    }
  }

  // General Voice Message Playback (Chat Bubble)
  Future<void> playVoiceMessage(String messageId, String audioUrl) async {
    try {
      // Toggle off if clicking same message
      if (_playingAudioMessageId == messageId && _isPlayingAudio) {
        await _audioPlayer.pause();
        _isPlayingAudio = false;
        notifyListeners();
        return;
      }

      if (_playingAudioMessageId != null &&
          _playingAudioMessageId != messageId) {
        await _audioPlayer.stop();
      }

      _playingAudioMessageId = messageId;
      _isPlayingAudio = true;
      _audioPosition = Duration.zero;
      notifyListeners();

      if (audioUrl.startsWith('http')) {
        await _audioPlayer.play(UrlSource(audioUrl));
      } else {
        await _audioPlayer.play(DeviceFileSource(audioUrl));
      }
    } catch (e) {
      developer.log('Error playing voice message: $e',
          name: 'ChatAudioController');
      _isPlayingAudio = false;
      _playingAudioMessageId = null;
      notifyListeners();
    }
  }

  Future<void> pauseVoiceMessage() async {
    await _audioPlayer.pause();
    _isPlayingAudio = false;
    notifyListeners();
  }

  Future<void> resumeVoiceMessage() async {
    await _audioPlayer.resume();
    _isPlayingAudio = true;
    notifyListeners();
  }

  void startLiveVoiceMode() {
    _isVoiceMode = true;
    notifyListeners();
    // Typically UI will open dialog, then call startListening()
  }

  void _stopLiveVoice() {
    _amplitudeTimer?.cancel();
    _vadTimer?.cancel();
    _audioRecorder.stop();
    _audioPlayer.stop();
    // _wsService.disconnectVoice(); // Optional/If needed

    _isVoiceMode = false;
    _isAiSpeaking = false;
    _isRecording = false;
    _isSpeechDetected = false;

    _isPlayingAudio = false;
    _lastSpeechTime = null;

    notifyListeners();
  }

  /// Public method to stop everything (e.g. when dialog closes)
  void stopLiveVoiceMode() {
    _stopLiveVoice();
  }

  @override
  void dispose() {
    _amplitudeTimer?.cancel();
    _vadTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _getExtensionFromMimeType(String mimeType) {
    if (mimeType.contains('wav')) return 'wav';
    if (mimeType.contains('mp3')) return 'mp3';
    if (mimeType.contains('aac')) return 'm4a';
    return 'wav';
  }

  // Setter for isAiSpeaking (used by TTS controller potentially)
  void setAiSpeaking(bool speaking) {
    _isAiSpeaking = speaking;
    notifyListeners();
    _onVoiceDialogSetState?.call(() {});
  }
}

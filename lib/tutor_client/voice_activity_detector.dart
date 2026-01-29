import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Voice Activity Detection (VAD) for automatic speech detection
class VoiceActivityDetector {
  /// Configuration
  final double silenceThreshold;
  final Duration silenceDuration;
  final Duration minSpeechDuration;
  final Duration maxSpeechDuration;

  /// State
  bool _isListening = false;
  bool _isSpeaking = false;
  DateTime? _speechStartTime;
  DateTime? _lastSoundTime;
  Timer? _silenceTimer;
  double _currentVolume = 0.0;
  final List<double> _volumeHistory = [];

  /// Controllers
  final StreamController<VADEvent> _eventController =
      StreamController<VADEvent>.broadcast();
  final StreamController<double> _volumeController =
      StreamController<double>.broadcast();

  VoiceActivityDetector({
    this.silenceThreshold = 0.02,
    this.silenceDuration = const Duration(milliseconds: 1500),
    this.minSpeechDuration = const Duration(milliseconds: 300),
    this.maxSpeechDuration = const Duration(seconds: 60),
  });

  Stream<VADEvent> get events => _eventController.stream;
  Stream<double> get volumeStream => _volumeController.stream;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  double get currentVolume => _currentVolume;

  /// Start listening for voice activity
  void startListening() {
    _isListening = true;
    _isSpeaking = false;
    _volumeHistory.clear();
    _eventController.add(VADEvent(type: VADEventType.listening));
  }

  /// Stop listening
  void stopListening() {
    _isListening = false;
    _silenceTimer?.cancel();

    if (_isSpeaking) {
      _endSpeech();
    }

    _eventController.add(VADEvent(type: VADEventType.stopped));
  }

  /// Process an audio chunk and detect voice activity
  void processAudioChunk(Uint8List audioData) {
    if (!_isListening) return;

    // Calculate RMS volume
    final volume = _calculateRMSVolume(audioData);
    _currentVolume = volume;
    _volumeController.add(volume);

    // Update volume history for adaptive thresholding
    _volumeHistory.add(volume);
    if (_volumeHistory.length > 50) {
      _volumeHistory.removeAt(0);
    }

    // Determine if there's voice activity
    final threshold = _getAdaptiveThreshold();
    final hasVoice = volume > threshold;

    if (hasVoice) {
      _lastSoundTime = DateTime.now();
      _silenceTimer?.cancel();

      if (!_isSpeaking) {
        _startSpeech();
      }
    } else if (_isSpeaking) {
      // Check for silence timeout
      _silenceTimer ??= Timer(silenceDuration, () {
        if (_isSpeaking) {
          _endSpeech();
        }
      });
    }

    // Check max duration
    if (_isSpeaking && _speechStartTime != null) {
      final duration = DateTime.now().difference(_speechStartTime!);
      if (duration >= maxSpeechDuration) {
        _endSpeech();
      }
    }
  }

  void _startSpeech() {
    _isSpeaking = true;
    _speechStartTime = DateTime.now();
    _eventController.add(
      VADEvent(type: VADEventType.speechStart, timestamp: _speechStartTime!),
    );
    debugPrint('VAD: Speech started');
  }

  void _endSpeech() {
    if (!_isSpeaking) return;

    final endTime = DateTime.now();
    final duration = endTime.difference(_speechStartTime!);

    _isSpeaking = false;
    _silenceTimer?.cancel();
    _silenceTimer = null;

    // Only emit speech end if it meets minimum duration
    if (duration >= minSpeechDuration) {
      _eventController.add(
        VADEvent(
          type: VADEventType.speechEnd,
          timestamp: endTime,
          duration: duration,
        ),
      );
      debugPrint('VAD: Speech ended (${duration.inMilliseconds}ms)');
    } else {
      debugPrint('VAD: Speech too short, ignoring');
    }

    _speechStartTime = null;
  }

  /// Calculate RMS (Root Mean Square) volume from audio data
  double _calculateRMSVolume(Uint8List audioData) {
    if (audioData.isEmpty) return 0.0;

    // Assuming 16-bit PCM audio
    double sum = 0.0;
    final samples = audioData.length ~/ 2;

    for (int i = 0; i < samples; i++) {
      // Convert bytes to 16-bit sample
      final low = audioData[i * 2];
      final high = audioData[i * 2 + 1];
      final sample = (high << 8) | low;

      // Convert to signed and normalize to -1.0 to 1.0
      final signedSample = sample > 32767 ? sample - 65536 : sample;
      final normalized = signedSample / 32768.0;

      sum += normalized * normalized;
    }

    return samples > 0 ? (sum / samples).abs() : 0.0;
  }

  /// Get adaptive threshold based on ambient noise
  double _getAdaptiveThreshold() {
    if (_volumeHistory.isEmpty) return silenceThreshold;

    // Use the 25th percentile as the noise floor
    final sorted = List<double>.from(_volumeHistory)..sort();
    final noiseFloor = sorted[sorted.length ~/ 4];

    // Threshold is noise floor plus a margin
    return (noiseFloor * 1.5).clamp(silenceThreshold, 0.1);
  }

  void dispose() {
    _silenceTimer?.cancel();
    _eventController.close();
    _volumeController.close();
  }
}

/// VAD Event types
enum VADEventType { listening, speechStart, speechEnd, stopped }

/// VAD Event data
class VADEvent {
  final VADEventType type;
  final DateTime? timestamp;
  final Duration? duration;

  VADEvent({required this.type, this.timestamp, this.duration});
}

/// Audio level indicator for UI
class AudioLevelIndicator {
  final List<double> _levels = List.filled(10, 0.0);
  int _index = 0;

  void addLevel(double level) {
    _levels[_index] = level;
    _index = (_index + 1) % _levels.length;
  }

  List<double> get levels => List.unmodifiable(_levels);

  double get averageLevel {
    return _levels.reduce((a, b) => a + b) / _levels.length;
  }

  double get peakLevel {
    return _levels.reduce((a, b) => a > b ? a : b);
  }
}

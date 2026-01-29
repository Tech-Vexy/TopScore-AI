import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Manages queued audio playback with smooth transitions
class AudioPlaybackQueue {
  final AudioPlayer _player = AudioPlayer();
  final Queue<AudioQueueItem> _queue = Queue();
  final StreamController<AudioQueueState> _stateController =
      StreamController<AudioQueueState>.broadcast();

  bool _isPlaying = false;
  bool _isPaused = false;
  AudioQueueItem? _currentItem;
  double _playbackSpeed = 1.0;
  double _volume = 1.0;

  AudioPlaybackQueue() {
    _setupPlayerListeners();
  }

  Stream<AudioQueueState> get stateStream => _stateController.stream;
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  int get queueLength => _queue.length;
  AudioQueueItem? get currentItem => _currentItem;

  void _setupPlayerListeners() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onItemCompleted();
      }
    });

    _player.positionStream.listen((position) {
      if (_currentItem != null) {
        _emitState();
      }
    });
  }

  /// Add audio to the queue
  void enqueue(AudioQueueItem item) {
    _queue.add(item);
    debugPrint('Audio queued: ${item.id} (Queue size: ${_queue.length})');
    _emitState();

    // Start playing if not already
    if (!_isPlaying && !_isPaused) {
      _playNext();
    }
  }

  /// Add audio from base64 string
  void enqueueBase64(String base64Audio, {String? mimeType, String? id}) {
    final bytes = base64Decode(base64Audio);
    enqueue(
      AudioQueueItem(
        id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        audioData: bytes,
        mimeType: mimeType ?? 'audio/wav',
      ),
    );
  }

  /// Play the next item in queue
  Future<void> _playNext() async {
    if (_queue.isEmpty) {
      _isPlaying = false;
      _currentItem = null;
      _emitState();
      return;
    }

    _currentItem = _queue.removeFirst();
    _isPlaying = true;
    _emitState();

    try {
      // Create audio source from bytes
      final source = AudioSource.uri(
        Uri.dataFromBytes(
          _currentItem!.audioData,
          mimeType: _currentItem!.mimeType,
        ),
      );

      await _player.setAudioSource(source);
      await _player.setSpeed(_playbackSpeed);
      await _player.setVolume(_volume);
      await _player.play();

      debugPrint('Playing audio: ${_currentItem!.id}');
    } catch (e) {
      debugPrint('Audio playback error: $e');
      _onItemCompleted();
    }
  }

  void _onItemCompleted() {
    final completedItem = _currentItem;
    _currentItem = null;

    if (completedItem != null) {
      debugPrint('Audio completed: ${completedItem.id}');
    }

    // Play next in queue
    _playNext();
  }

  /// Pause playback
  Future<void> pause() async {
    if (_isPlaying) {
      await _player.pause();
      _isPaused = true;
      _emitState();
    }
  }

  /// Resume playback
  Future<void> resume() async {
    if (_isPaused) {
      await _player.play();
      _isPaused = false;
      _emitState();
    }
  }

  /// Skip current item
  Future<void> skip() async {
    await _player.stop();
    _onItemCompleted();
  }

  /// Clear the queue
  void clearQueue() {
    _queue.clear();
    _emitState();
    debugPrint('Audio queue cleared');
  }

  /// Stop playback and clear queue
  Future<void> stop() async {
    await _player.stop();
    _queue.clear();
    _isPlaying = false;
    _isPaused = false;
    _currentItem = null;
    _emitState();
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    _playbackSpeed = speed.clamp(0.5, 2.0);
    await _player.setSpeed(_playbackSpeed);
  }

  /// Set volume
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  void _emitState() {
    _stateController.add(
      AudioQueueState(
        isPlaying: _isPlaying,
        isPaused: _isPaused,
        queueLength: _queue.length,
        currentItemId: _currentItem?.id,
        position: _player.position,
        duration: _player.duration,
      ),
    );
  }

  Future<void> dispose() async {
    await _player.dispose();
    _stateController.close();
  }
}

/// An item in the audio queue
class AudioQueueItem {
  final String id;
  final Uint8List audioData;
  final String mimeType;
  final DateTime enqueuedAt;
  final Map<String, dynamic>? metadata;

  AudioQueueItem({
    required this.id,
    required this.audioData,
    this.mimeType = 'audio/wav',
    DateTime? enqueuedAt,
    this.metadata,
  }) : enqueuedAt = enqueuedAt ?? DateTime.now();
}

/// State of the audio queue
class AudioQueueState {
  final bool isPlaying;
  final bool isPaused;
  final int queueLength;
  final String? currentItemId;
  final Duration? position;
  final Duration? duration;

  AudioQueueState({
    required this.isPlaying,
    required this.isPaused,
    required this.queueLength,
    this.currentItemId,
    this.position,
    this.duration,
  });

  double get progress {
    if (duration == null || position == null || duration!.inMilliseconds == 0) {
      return 0.0;
    }
    return position!.inMilliseconds / duration!.inMilliseconds;
  }
}

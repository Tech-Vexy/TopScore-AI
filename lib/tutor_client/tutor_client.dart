/// TopScore AI Tutor Client Library
///
/// This library provides all client-side functionality for the TopScore AI Tutor,
/// including WebSocket communication, offline support, voice activity detection,
/// and audio playback.

library tutor_client;

// Core WebSocket Services
export 'websocket_service.dart';
export 'enhanced_websocket_service.dart';

// Connection Management
export 'connection_manager.dart';
export 'connection_status_widget.dart';

// Offline Support
export 'offline_storage.dart';

// Voice Features
export 'voice_activity_detector.dart';
export 'audio_playback_queue.dart';

// Widgets (re-export for convenience)
// Note: streak_widget.dart is in lib/widgets/

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Offline storage for messages and sync when online
class OfflineStorage {
  static const String _messagesKey = 'offline_messages';
  static const String _pendingKey = 'pending_messages';
  static const String _cacheKey = 'message_cache';
  static const int _maxCachedMessages = 100;

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Save a message to local cache
  Future<void> cacheMessage(CachedMessage message) async {
    final messages = await getCachedMessages(message.threadId);
    messages.add(message);

    // Keep only recent messages
    if (messages.length > _maxCachedMessages) {
      messages.removeRange(0, messages.length - _maxCachedMessages);
    }

    await _saveMessages(message.threadId, messages);
  }

  /// Get cached messages for a thread
  Future<List<CachedMessage>> getCachedMessages(String threadId) async {
    await _ensureInitialized();
    final key = '${_cacheKey}_$threadId';
    final jsonString = _prefs?.getString(key);

    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((j) => CachedMessage.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading cached messages: $e');
      return [];
    }
  }

  Future<void> _saveMessages(
    String threadId,
    List<CachedMessage> messages,
  ) async {
    await _ensureInitialized();
    final key = '${_cacheKey}_$threadId';
    final jsonString = jsonEncode(messages.map((m) => m.toJson()).toList());
    await _prefs?.setString(key, jsonString);
  }

  /// Save a pending message (to be sent when online)
  Future<void> savePendingMessage(PendingMessage message) async {
    final pending = await getPendingMessages();
    pending.add(message);
    await _savePendingMessages(pending);
    debugPrint('Saved pending message: ${message.id}');
  }

  /// Get all pending messages
  Future<List<PendingMessage>> getPendingMessages() async {
    await _ensureInitialized();
    final jsonString = _prefs?.getString(_pendingKey);

    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((j) => PendingMessage.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading pending messages: $e');
      return [];
    }
  }

  /// Remove a pending message after successful send
  Future<void> removePendingMessage(String messageId) async {
    final pending = await getPendingMessages();
    pending.removeWhere((m) => m.id == messageId);
    await _savePendingMessages(pending);
  }

  /// Clear all pending messages
  Future<void> clearPendingMessages() async {
    await _ensureInitialized();
    await _prefs?.remove(_pendingKey);
  }

  Future<void> _savePendingMessages(List<PendingMessage> messages) async {
    await _ensureInitialized();
    final jsonString = jsonEncode(messages.map((m) => m.toJson()).toList());
    await _prefs?.setString(_pendingKey, jsonString);
  }

  /// Get thread IDs with cached messages
  Future<List<String>> getCachedThreadIds() async {
    await _ensureInitialized();
    final keys = _prefs?.getKeys() ?? {};
    return keys
        .where((k) => k.startsWith(_cacheKey))
        .map((k) => k.replaceFirst('${_cacheKey}_', ''))
        .toList();
  }

  /// Clear cache for a thread
  Future<void> clearThreadCache(String threadId) async {
    await _ensureInitialized();
    await _prefs?.remove('${_cacheKey}_$threadId');
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    await _ensureInitialized();
    final keys = _prefs?.getKeys() ?? {};
    for (final key in keys) {
      if (key.startsWith(_cacheKey) || key == _pendingKey) {
        await _prefs?.remove(key);
      }
    }
  }

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
}

/// A cached message
class CachedMessage {
  final String id;
  final String threadId;
  final String content;
  final String role; // 'user' or 'assistant'
  final DateTime timestamp;
  final bool synced;
  final Map<String, dynamic>? metadata;

  CachedMessage({
    required this.id,
    required this.threadId,
    required this.content,
    required this.role,
    required this.timestamp,
    this.synced = false,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'thread_id': threadId,
    'content': content,
    'role': role,
    'timestamp': timestamp.toIso8601String(),
    'synced': synced,
    'metadata': metadata,
  };

  factory CachedMessage.fromJson(Map<String, dynamic> json) => CachedMessage(
    id: json['id'],
    threadId: json['thread_id'],
    content: json['content'],
    role: json['role'],
    timestamp: DateTime.parse(json['timestamp']),
    synced: json['synced'] ?? false,
    metadata: json['metadata'],
  );
}

/// A message pending to be sent
class PendingMessage {
  final String id;
  final String threadId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final int retryCount;
  final Map<String, dynamic>? extraData;

  PendingMessage({
    required this.id,
    required this.threadId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.retryCount = 0,
    this.extraData,
  });

  PendingMessage copyWith({int? retryCount}) => PendingMessage(
    id: id,
    threadId: threadId,
    userId: userId,
    content: content,
    createdAt: createdAt,
    retryCount: retryCount ?? this.retryCount,
    extraData: extraData,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'thread_id': threadId,
    'user_id': userId,
    'content': content,
    'created_at': createdAt.toIso8601String(),
    'retry_count': retryCount,
    'extra_data': extraData,
  };

  factory PendingMessage.fromJson(Map<String, dynamic> json) => PendingMessage(
    id: json['id'],
    threadId: json['thread_id'],
    userId: json['user_id'],
    content: json['content'],
    createdAt: DateTime.parse(json['created_at']),
    retryCount: json['retry_count'] ?? 0,
    extraData: json['extra_data'],
  );
}

/// Sync manager for offline messages
class OfflineSyncManager {
  final OfflineStorage storage = OfflineStorage();
  bool _isSyncing = false;

  Future<void> initialize() async {
    await storage.initialize();
  }

  bool get isSyncing => _isSyncing;

  /// Sync pending messages with the server
  Future<SyncResult> syncPendingMessages({
    required Future<bool> Function(PendingMessage) sendMessage,
  }) async {
    if (_isSyncing) {
      return SyncResult(
        synced: 0,
        failed: 0,
        message: 'Sync already in progress',
      );
    }

    _isSyncing = true;
    int synced = 0;
    int failed = 0;

    try {
      final pending = await storage.getPendingMessages();

      for (final message in pending) {
        try {
          final success = await sendMessage(message);
          if (success) {
            await storage.removePendingMessage(message.id);
            synced++;
          } else {
            failed++;
          }
        } catch (e) {
          debugPrint('Failed to sync message ${message.id}: $e');
          failed++;
        }
      }
    } finally {
      _isSyncing = false;
    }

    return SyncResult(
      synced: synced,
      failed: failed,
      message: synced > 0 ? '$synced messages synced' : null,
    );
  }
}

class SyncResult {
  final int synced;
  final int failed;
  final String? message;

  SyncResult({required this.synced, required this.failed, this.message});
}

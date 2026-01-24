import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/resource_model.dart';

class OfflineService {
  // Singleton Pattern
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  static const String _resourceBoxName = 'offline_resources';
  static const String _settingsBoxName = 'app_settings';

  late Box _resourceBox;
  late Box _settingsBox;

  bool _isInitialized = false;

  /// Initialize Hive and open boxes.
  /// Safe to call multiple times (checks initialization state).
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();
      _resourceBox = await Hive.openBox(_resourceBoxName);
      _settingsBox = await Hive.openBox(_settingsBoxName);
      _isInitialized = true;
      debugPrint("✅ OfflineService Initialized");
    } catch (e) {
      debugPrint("❌ Error initializing OfflineService: $e");
    }
  }

  // ==========================================
  // 📦 RESOURCE CACHING
  // ==========================================

  /// Cache a list of resources for a specific path (e.g., folder structure)
  Future<void> cacheResources(
    String path,
    List<ResourceModel> resources,
  ) async {
    try {
      final List<Map<String, dynamic>> serialized = resources
          .map((r) => r.toMap())
          .toList();
      await _resourceBox.put(path, serialized);
    } catch (e) {
      debugPrint("❌ Error caching resources for path $path: $e");
    }
  }

  /// Retrieve cached resources. Returns empty list on error or empty cache.
  List<ResourceModel> getCachedResources(String path) {
    if (!_isInitialized) return [];
    try {
      final data = _resourceBox.get(path);

      if (data != null && data is List) {
        return data.map((item) {
          // Hive returns LinkedMap, explicitly cast to Map<String, dynamic>
          final map = Map<String, dynamic>.from(item as Map);
          return ResourceModel.fromMap(map, map['id'] ?? 'unknown');
        }).toList();
      }
    } catch (e) {
      debugPrint("❌ Error retrieving cached resources for $path: $e");
    }
    return [];
  }

  /// Cache a single individual resource (e.g., for Recently Opened)
  Future<void> cacheSingleResource(ResourceModel resource) async {
    try {
      await _resourceBox.put('resource_${resource.id}', resource.toMap());
    } catch (e) {
      debugPrint("❌ Error caching resource ${resource.id}: $e");
    }
  }

  /// Retrieve a single resource
  ResourceModel? getCachedResource(String id) {
    try {
      final data = _resourceBox.get('resource_$id');
      if (data != null && data is Map) {
        final map = Map<String, dynamic>.from(data);
        return ResourceModel.fromMap(map, id);
      }
    } catch (e) {
      debugPrint("❌ Error retrieving resource $id: $e");
    }
    return null;
  }

  /// Clear all cached resources (useful for Pull-to-Refresh or Logout)
  Future<void> clearAllResources() async {
    await _resourceBox.clear();
  }

  // ==========================================
  // ⚙️ SETTINGS & PREFERENCES
  // ==========================================

  Future<void> saveLiteMode(bool isEnabled) async {
    if (!_isInitialized) return;
    await _settingsBox.put('lite_mode', isEnabled);
  }

  bool getLiteMode() {
    if (!_isInitialized) return false;
    return _settingsBox.get('lite_mode', defaultValue: false);
  }

  /// Generic String List Getter (SharedPreferences style)
  List<String> getStringList(String key) {
    if (!_isInitialized) return []; // Return empty list if not initialized (e.g., on web)
    try {
      final data = _settingsBox.get(key);
      if (data != null && data is List) {
        return data.cast<String>().toList();
      }
    } catch (e) {
      debugPrint("❌ Error getting string list for $key: $e");
    }
    return [];
  }

  /// Generic String List Setter
  Future<void> setStringList(String key, List<String> value) async {
    if (!_isInitialized) return; // Skip if not initialized (e.g., on web)
    await _settingsBox.put(key, value);
  }

  /// Clear all settings
  Future<void> clearSettings() async {
    await _settingsBox.clear();
  }
}

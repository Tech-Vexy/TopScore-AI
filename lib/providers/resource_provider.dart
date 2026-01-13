import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/firebase_storage_service.dart';
import '../models/resource_model.dart';
import '../services/offline_service.dart';

class ResourceProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final OfflineService _offlineService = OfflineService();

  List<ResourceModel> _resources = [];
  List<ResourceModel> _storageSearchResults = [];
  List<ResourceModel> _recentStorageResources = [];
  bool _isLoading = false;

  List<ResourceModel> get resources => _resources;
  List<ResourceModel> get recentDriveResources =>
      _recentStorageResources; // Kept name for UI compatibility, mapped to storage
  List<ResourceModel> get driveSearchResults =>
      _storageSearchResults; // Kept name for UI compatibility
  List<ResourceModel> get currentStorageItems => _currentStorageItems;
  String get currentPath => _currentPath;
  bool get isLoading => _isLoading;

  List<ResourceModel> _currentStorageItems = [];
  String _currentPath = 'resources/';

  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  Future<void> fetchStorageItems(String path) async {
    _isLoading = true;
    _currentPath = path;

    // 1. Try Load from Cache first (Instant UI)
    final cached = _offlineService.getCachedResources(path);
    if (cached.isNotEmpty) {
      _currentStorageItems = cached;
      notifyListeners();
    }

    // If we have cache, we don't show full loading spinner, maybe just a linear progress?
    // For now, we keep isLoading true to indicate "syncing"
    notifyListeners();

    try {
      // 2. Fetch Fresh Data
      final freshItems = await _storageService.listItems(path);

      // 3. Update Cache & UI
      if (freshItems.isNotEmpty) {
        _currentStorageItems = freshItems;
        await _offlineService.cacheResources(path, freshItems);
      }
    } catch (e) {
      debugPrint("Error fetching storage items: $e");
      // If network calls fail, we rely on what we loaded from cache
      if (_currentStorageItems.isEmpty) {
        _currentStorageItems = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRecentDriveResources({bool forceRefresh = false}) async {
    // Fetches from Firebase Storage 'resources/' folder
    if (!forceRefresh &&
        _recentStorageResources.isNotEmpty &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return; // Return cached data
    }

    try {
      _recentStorageResources = await _storageService.getRecentFiles(5);
      _lastFetchTime = DateTime.now();
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching recent storage resources: $e");
    }
  }

  Future<void> fetchResources(int grade, {String? subject}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _resources = await _firestoreService.getResources(
        grade,
        subject: subject,
      );
    } catch (e) {
      debugPrint("Error fetching resources: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchStorageFiles(String query) async {
    if (query.isEmpty) {
      _storageSearchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _storageSearchResults = await _storageService.searchFiles(query);
    } catch (e) {
      debugPrint("Error searching storage files: $e");
      _storageSearchResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Deprecated usage mapping for UI
  Future<void> searchDriveFiles(
    String query,
    dynamic ignoredGoogleSignIn,
  ) async {
    return searchStorageFiles(query);
  }

  void clearDriveSearch() {
    _storageSearchResults = [];
    notifyListeners();
  }

  // Recently Opened Files Tracking
  List<ResourceModel> _recentlyOpened = [];
  List<ResourceModel> get recentlyOpened => _recentlyOpened;

  Future<void> loadRecentlyOpened() async {
    try {
      final recentIds = _offlineService.getStringList('recently_opened');

      // Load full resource data from cache
      _recentlyOpened = [];
      for (final id in recentIds.take(5)) {
        final cached = _offlineService.getCachedResource(id);
        if (cached != null) {
          _recentlyOpened.add(cached);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading recently opened: $e");
    }
  }

  Future<void> trackFileOpen(ResourceModel resource) async {
    try {
      // Add to front of list, remove duplicates
      _recentlyOpened.removeWhere((r) => r.id == resource.id);
      _recentlyOpened.insert(0, resource);

      // Keep only last 5
      if (_recentlyOpened.length > 5) {
        _recentlyOpened = _recentlyOpened.take(5).toList();
      }

      // Save to SharedPreferences (now Hive settings)
      final ids = _recentlyOpened.map((r) => r.id).toList();
      await _offlineService.setStringList('recently_opened', ids);

      // Cache the resource data
      await _offlineService.cacheSingleResource(resource);

      notifyListeners();
    } catch (e) {
      debugPrint("Error tracking file open: $e");
    }
  }
}

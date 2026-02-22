import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firebase_file.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/offline_service.dart';
import 'dart:convert';

enum ResourceState { initial, loading, loaded, error, empty }

class ResourcesProvider extends ChangeNotifier {
  final Map<String, List<FirebaseFile>> _tabCache = {};
  final Map<String, DocumentSnapshot?> _lastDocumentCache = {};
  final Map<String, bool> _hasMoreCache = {};

  ResourceState _state = ResourceState.initial;
  String _searchQuery = '';
  String _currentCategory = 'All Files';

  // Helper methodologies for translating UI tabs into query scopes
  String? _getCollectionScope(String tabName) {
    if (tabName == 'All Files') return null;
    if (tabName == '844 Files') return '844_files';
    // CBC Files, Notes, Lesson Plans, Schemes Of Work all target cbc_files
    return 'cbc_files';
  }

  String? _getPathPrefix(String tabName) {
    if (tabName == 'Notes') return 'resources/Notes/';
    if (tabName == 'Lesson Plans') return 'resources/Lesson Plans/';
    // Standardize 'Schemes of Work' / 'Schemes Of Work' edge-cases from DB paths
    if (tabName == 'Schemes Of Work' || tabName == 'Schemes of Work') {
      return 'resources/Schemes_Of_Work/';
    }

    // Everything else ('All Files', 'CBC Files', '844 Files') fetches entire collections
    return null;
  }

  // Getters
  List<FirebaseFile> get files => _tabCache[_currentCategory] ?? [];
  ResourceState get state => _state;
  bool get hasMore => _hasMoreCache[_currentCategory] ?? true;
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    // When searching, we might wants to clear results or handle differently.
    // For now, let's just trigger a re-fetch.
    notifyListeners();
  }

  void setCategory(String category) {
    if (_currentCategory == category) {
      return;
    }
    _currentCategory = category;

    // If we haven't loaded this category yet, it will be initial.
    if (!_tabCache.containsKey(_currentCategory)) {
      _state = ResourceState.initial;
    } else {
      _state = files.isEmpty ? ResourceState.empty : ResourceState.loaded;
    }
    notifyListeners();
  }

  Future<void> fetchFiles({
    required UserModel user,
    bool isRefresh = false,
  }) async {
    // Avoid multiple simultaneous loads for the same category
    if (_state == ResourceState.loading) {
      return;
    }

    // If not refreshing and no more data, stop
    if (!isRefresh &&
        _hasMoreCache[_currentCategory] == false &&
        _searchQuery.isEmpty) {
      return;
    }

    if (isRefresh) {
      _tabCache.remove(_currentCategory);
      _lastDocumentCache.remove(_currentCategory);
      _hasMoreCache.remove(_currentCategory);
    }

    _state = ResourceState.loading;
    notifyListeners();

    try {
      List<FirebaseFile> newFiles;

      if (_searchQuery.isNotEmpty) {
        // Search logic
        newFiles = await StorageService.searchFiles(
          _searchQuery,
          curriculum: user.educationLevel ?? user.curriculum,
          grade: user.grade,
          role: user.role,
          collectionScope: _getCollectionScope(_currentCategory),
        );
        _hasMoreCache[_currentCategory] = false;
      } else {
        // Pagination logic
        newFiles = await StorageService.getPaginatedFiles(
          curriculum: user.educationLevel ?? user.curriculum,
          grade: user.grade,
          role: user.role,
          pathPrefix: _getPathPrefix(_currentCategory),
          collectionScope: _getCollectionScope(_currentCategory),
          lastDocument: _lastDocumentCache[_currentCategory],
          limit: 20,
        );
        _hasMoreCache[_currentCategory] = newFiles.length >= 20;
        if (newFiles.isNotEmpty) {
          _lastDocumentCache[_currentCategory] = newFiles.last.snapshot;
        }
      }

      if (_tabCache[_currentCategory] == null) {
        _tabCache[_currentCategory] = [];
      }
      _tabCache[_currentCategory]!.addAll(newFiles);

      _state = (_tabCache[_currentCategory] ?? []).isEmpty
          ? ResourceState.empty
          : ResourceState.loaded;
    } catch (e) {
      _state = ResourceState.error;
      debugPrint("Error fetching files: $e");
    }
    notifyListeners();
  }

  // ==========================================
  // Recently Opened Files Tracking
  // ==========================================
  List<FirebaseFile> _recentlyOpened = [];
  List<FirebaseFile> get recentlyOpened => _recentlyOpened;
  static const String _recentFilesPrefKey = 'recently_opened_v2';
  final OfflineService _offlineService = OfflineService();

  Future<void> loadRecentlyOpened() async {
    try {
      final recentJsonList = _offlineService.getStringList(_recentFilesPrefKey);

      _recentlyOpened = recentJsonList.map((jsonStr) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        return FirebaseFile.fromMap(data);
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading recently opened: $e");
    }
  }

  Future<void> trackFileOpen(FirebaseFile file) async {
    try {
      // Add to front, remove duplicates based on path
      _recentlyOpened.removeWhere((r) => r.path == file.path);
      _recentlyOpened.insert(0, file);

      // Keep only last 10
      if (_recentlyOpened.length > 10) {
        _recentlyOpened = _recentlyOpened.take(10).toList();
      }

      // Save to OfflineService (Hive)
      final jsonList =
          _recentlyOpened.map((f) => jsonEncode(f.toMap())).toList();
      await _offlineService.setStringList(_recentFilesPrefKey, jsonList);

      notifyListeners();
    } catch (e) {
      debugPrint("Error tracking file open: $e");
    }
  }
}

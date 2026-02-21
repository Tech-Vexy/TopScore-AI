import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // For Debouncer

import '../pdf_viewer_screen.dart';
import '../../services/storage_service.dart';
import '../../models/firebase_file.dart';
import '../../config/app_theme.dart';

class ResourceManagementScreen extends StatefulWidget {
  const ResourceManagementScreen({super.key});

  @override
  State<ResourceManagementScreen> createState() =>
      _ResourceManagementScreenState();
}

class _ResourceManagementScreenState extends State<ResourceManagementScreen>
    with SingleTickerProviderStateMixin {
  // --- Controllers & Scroll ---
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // --- State Variables ---
  final List<FirebaseFile> _files = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _hasError = false;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 20;

  // --- Navigation & Filtering ---
  String _searchQuery = '';
  bool _isSearching = false;
  late TabController _tabController;

  final List<String> _tabCategories = [
    'All Documents',
    '844',
    'CBC',
    'Lesson Plans',
    'Notes',
    'Schemes Of Work',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCategories.length, vsync: this);
    _tabController.addListener(_handleTabSelection);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _fetchFiles();
      }
    });

    _searchController.addListener(_onSearchChanged);

    // Initial fetch for the default tab (All Documents)
    _fetchFiles();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- Search Logic ---
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
          _isSearching = _searchQuery.isNotEmpty;

          // Reset pagination/state for new search
          _files.clear();
          _lastDocument = null;
          _hasMore = true;
        });
        _fetchFiles();
      }
    });
  }

  // --- Data Loading ---
  // _loadFolders removed as folders are hardcoded.

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      _files.clear();
      _lastDocument = null;
      _hasMore = true;
      _fetchFiles();
    }
  }

  String? _getCurrentPathPrefix() {
    // For "All Documents", "CBC", and "844", we want to search the root of the respective collection/context
    // without restricting to a subfolder like "resources/CBC/".
    // We assume 'resources/' is the base path for all.
    final category = _tabCategories[_tabController.index];

    if (_tabController.index == 0 || category == 'CBC' || category == '844') {
      return 'resources/';
    }

    final pathName =
        category == 'Schemes Of Work' ? 'Schemes_Of_Work' : category;
    return 'resources/$pathName/';
  }

  Future<void> _fetchFiles() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      List<FirebaseFile> newFiles;

      if (_isSearching) {
        // Determine curriculum context for search if possible, or search across all?
        // For now, let's keep search broad or maybe default to valid curriculum if tab is specific.
        // But implementation plan said: "If No Curriculum is specified... query BOTH or default".
        // Let's rely on the tab context if it's 'CBC' or '844'.
        String? searchCurriculum;
        if (_tabCategories[_tabController.index] == 'CBC') {
          searchCurriculum = 'CBC';
        }
        if (_tabCategories[_tabController.index] == '844') {
          searchCurriculum = '8-4-4';
        }

        newFiles = await StorageService.searchFiles(
          _searchQuery,
          limit: _pageSize,
          curriculum: searchCurriculum,
        );
        _hasMore = false;
      } else {
        final pathPrefix = _getCurrentPathPrefix();
        // Determine curriculum from tab
        String? curriculum;
        final category = _tabCategories[_tabController.index];

        if (category == 'CBC') {
          curriculum = 'CBC';
        } else if (category == '844') {
          curriculum = '8-4-4';
        } else {
          // For other tabs (Notes, Schemes, etc.), we might need a default or context.
          // User request implies we have 2 collections.
          // If we are in 'Notes', which collection?
          // The "All Documents" tab (index 0) likely wants everything, but pagination across 2 collections is hard.
          // Let's assume 'All Documents' might default to one or just show from the default 'resources' if that still exists,
          // OR we pick one.
          // However, looking at _getCurrentPathPrefix:
          // if index == 0 -> 'resources/'
          // if category == 'Schemes Of Work' -> 'resources/Schemes_Of_Work/'
          // This implies folder structure.
          // If we switch to collections `cbc_files` and `844_files`, the `path` field still likely contains `resources/...`.
          // So we just need to target the right collection.

          // Strategy:
          // 1. CBC Tab -> collection: cbc_files, pathPrefix: resources/ (or specific?)
          // 2. 844 Tab -> collection: 844_files
          // 3. Notes -> ?? Maybe we need a curriculum selector? Or maybe 'Notes' means "CBC Notes" by default?
          // Let's Default to CBC for now as per plan "Current Plan: Default to CBC".
          if (category != 'All Documents') {
            curriculum = 'CBC'; // Default to CBC for categorization tabs
          }
        }

        newFiles = await StorageService.getPaginatedFiles(
          limit: _pageSize,
          lastDocument: _lastDocument,
          fileType: '.pdf',
          pathPrefix: pathPrefix,
          curriculum: curriculum,
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _files.addAll(newFiles);
          if (newFiles.length < _pageSize) {
            _hasMore = false;
          } else {
            _lastDocument = newFiles.last.snapshot;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching resources: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Failed to load resources. Pull down to retry.'),
            backgroundColor: Colors.red.shade700,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _refreshFiles,
            ),
          ),
        );
      }
    }
  }

  Future<void> _refreshFiles() async {
    _files.clear();
    _lastDocument = null;
    _hasMore = true;
    _hasError = false;
    await _fetchFiles();
  }

  Future<void> _syncResources() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);

    try {
      final result = await StorageService.migrateStorageToFirestore(
        allowedExtensions: ['.pdf'],
        forceUpdate: true, // Re-index everything to fix metadata
      );

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
                'Sync Complete: ${result.successCount} files updated/indexed.'),
            backgroundColor: Colors.green,
          ),
        );
        _files.clear();
        _lastDocument = null;
        _hasMore = true;
        _fetchFiles();
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text('Sync failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openFile(FirebaseFile file) async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PdfViewerScreen(storagePath: file.path, title: file.name),
      ),
    );
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(Theme.of(context)),
            Expanded(child: _buildBody(Theme.of(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Portal Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "ALL EDUCATIONAL RESOURCES",
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _syncResources,
                  icon: const Icon(Icons.sync,
                      size: 18, color: Color(0xFF00897B)),
                  label: const Text(
                    "Re-index",
                    style: TextStyle(color: Color(0xFF00897B), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Search Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search resources...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: theme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) {
                      _files.clear();
                      _lastDocument = null;
                      _hasMore = true;
                      _fetchFiles();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _files.clear();
                    _lastDocument = null;
                    _hasMore = true;
                    _fetchFiles();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Search',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: const Color(0xFF00897B),
            labelColor: const Color(0xFF00897B),
            unselectedLabelColor:
                theme.colorScheme.onSurface.withValues(alpha: 0.6),
            labelStyle: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
            unselectedLabelStyle: GoogleFonts.nunito(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: _tabCategories.map((title) => Tab(text: title)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading && _files.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_files.isEmpty && _hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: theme.hintColor),
            const SizedBox(height: 12),
            Text('Failed to load resources', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _refreshFiles,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_files.isEmpty) {
      return _buildEmptyState(
        theme,
        _isSearching ? 'No results found' : 'No resources found',
        _isSearching ? Icons.search_off : Icons.folder_open,
      );
    }

    return _buildFileList(theme);
  }

  Widget _buildFileList(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _refreshFiles,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _files.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _files.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _buildFileCard(_files[index], theme, index + 1);
        },
      ),
    );
  }

  Widget _buildFileCard(FirebaseFile file, ThemeData theme, int index) {
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppTheme.buildGlassContainer(
        context,
        borderRadius: 16,
        padding: EdgeInsets.zero,
        opacity: isDark ? 0.1 : 0.4,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.picture_as_pdf,
              color: Colors.redAccent,
              size: 24,
            ),
          ),
          title: Text(
            "$index. ${file.name}",
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.blue[900], // Dark blue like the link in image
              decoration: TextDecoration.underline,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              if (file.gradeLabel.isNotEmpty == true) ...[
                Text(
                  file.gradeLabel,
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.circle, size: 4, color: theme.dividerColor),
                ),
              ],
              Text(
                file.subject ?? file.category ?? 'General',
                style: TextStyle(fontSize: 12, color: theme.hintColor),
              ),
              if (file.curriculum != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.circle, size: 4, color: theme.dividerColor),
                ),
                Text(
                  file.curriculum!,
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
              ],
            ],
          ),
          trailing: Icon(Icons.chevron_right, size: 20, color: theme.hintColor),
          onTap: () => _openFile(file),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: theme.disabledColor),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.nunito(color: theme.hintColor, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

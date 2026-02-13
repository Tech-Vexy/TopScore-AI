import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // For Debouncer

import '../pdf_viewer_screen.dart';
import '../../services/storage_service.dart';
import '../../models/firebase_file.dart';
import '../../config/app_theme.dart';
import '../../widgets/session_history_carousel.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  // --- Controllers & Scroll ---
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // --- State Variables ---
  final List<FirebaseFile> _files = [];
  List<String> _folders = [];

  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 20;

  // --- Navigation & Filtering ---
  List<String> _breadcrumbs = ['Library'];
  String? _currentFolder; // Represents the current Subject
  String? _selectedGrade;
  String? _selectedCurriculum;
  String _searchQuery = '';
  bool _isSearching = false;

  bool _showSyncButton = false;

  @override
  void initState() {
    super.initState();
    _loadFolders();
    _fetchFiles(); // Initial fetch (likely empty if we go Folder-First)

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _fetchFiles();
      }
    });

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
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
  Future<void> _loadFolders() async {
    try {
      // Fetch a batch to identify available subjects/folders
      // In a real app, this might be a separate "subjects" collection
      final files = await StorageService.getAllFilesFromFirestore(limit: 1000);
      final folderSet = files.map((f) => f.subject).whereType<String>().toSet();

      if (mounted) {
        setState(() {
          _folders = folderSet.toList()..sort();
          _showSyncButton = files.isEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error loading folders: $e');
    }
  }

  Future<void> _fetchFiles() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      List<FirebaseFile> newFiles;

      if (_isSearching) {
        // PERFOM SEARCH
        newFiles = await StorageService.searchFiles(
          _searchQuery,
          limit: _pageSize,
        );
        // Note: StorageService.searchFiles currently doesn't support pagination cursor efficiently
        // so we might just get the first batch or need to enhance the service.
        // For now, assuming search returns a limited set.
        _hasMore = false;
      } else {
        // NORMAL BROWSE
        newFiles = await StorageService.getPaginatedFiles(
          limit: _pageSize,
          lastDocument: _lastDocument,
          fileType: '.pdf',
          folder:
              _currentFolder, // null = All (but handled by UI to show folders first)
          level: _selectedGrade,
          curriculum: _selectedCurriculum,
        );
      }

      if (mounted) {
        if (newFiles.isEmpty) {
          setState(() {
            _hasMore = false;
            _isLoading = false;
            if (_files.isEmpty && !_isSearching && _currentFolder == null) {
              _showSyncButton = true;
            }
          });
          return;
        }

        setState(() {
          _files.addAll(newFiles);
          // Only update cursor if not searching (since search might not use it same way)
          if (!_isSearching) _lastDocument = newFiles.last.snapshot;
          _isLoading = false;
          _showSyncButton = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching resources: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Actions ---
  void _enterFolder(String folderName) {
    setState(() {
      _currentFolder = folderName;
      _breadcrumbs.add(folderName);
      _files.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    _fetchFiles();
  }

  void _navigateBack() {
    if (_breadcrumbs.length > 1) {
      setState(() {
        _breadcrumbs.removeLast();
        _currentFolder = _breadcrumbs.length > 1 ? _breadcrumbs.last : null;

        // Reset file list
        _files.clear();
        _lastDocument = null;
        _hasMore = true;
        _searchController.clear();
        _isSearching = false;
        _searchQuery = '';
      });

      // If we went back to root ("Library"), we might not need to fetch files
      // if we want to show the folder grid again.
      // But if we want to show "All files" mixed at root, we fetch.
      // Let's assume root = Folder Grid, so no fetch needed unless we want to preload?
      // Actually, let's just clear files so _buildBody shows the Folder Grid.
    }
  }

  void _navigateToBreadcrumb(int index) {
    if (index == _breadcrumbs.length - 1) return; // Already here

    setState(() {
      // Truncate breadcrumbs
      _breadcrumbs = _breadcrumbs.sublist(0, index + 1);
      _currentFolder = index == 0 ? null : _breadcrumbs.last;

      _files.clear();
      _lastDocument = null;
      _hasMore = true;
      _searchController.clear();
      _isSearching = false;
      _searchQuery = '';
    });

    // Only fetch if we are NOT at root (Root shows folders)
    if (_currentFolder != null) {
      _fetchFiles();
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

  Future<void> _syncFiles() async {
    // ... (Keep existing sync logic or simplify)
    // For brevity, just calling the logic
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sync Library'),
        content: const Text('Clear and re-sync all files?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sync'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await StorageService.deleteAllFileIndexes();
      await StorageService.migrateStorageToFirestore(
        allowedExtensions: ['.pdf'],
      );

      // Reset
      setState(() {
        _files.clear();
        _lastDocument = null;
        _hasMore = true;
        _folders.clear();
      });
      await _loadFolders();
      // Don't auto-fetch files at root if we show folders

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Synced!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    // Handle system back button to navigate up folders
    return PopScope(
      canPop: _breadcrumbs.length <= 1 && !_isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigateBack();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(Theme.of(context)),
              _buildBreadcrumbs(Theme.of(context)),
              Expanded(child: _buildBody(Theme.of(context))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Sync
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Library",
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (_showSyncButton)
                IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed: _syncFiles,
                  tooltip: 'Sync Library',
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search resources...',
              prefixIcon: Icon(Icons.search, color: theme.hintColor),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        // Trigger update immediately
                        _onSearchChanged();
                      },
                    )
                  : null,
              filled: true,
              fillColor: theme.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),

          // Filters (Grade/Curriculum) - visible if searching or inside a folder??
          // Or always visible? Let's keep them always visible for global filtering.
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'All Curriculums',
                  _selectedCurriculum,
                  (val) {
                    setState(() {
                      _selectedCurriculum = val;
                      _files.clear();
                      _lastDocument = null;
                      _hasMore = true;
                    });
                    _fetchFiles();
                  },
                  ['CBC', '8.4.4'],
                  theme,
                ),

                const SizedBox(width: 8),

                _buildFilterChip(
                  'All Grades',
                  _selectedGrade,
                  (val) {
                    setState(() {
                      _selectedGrade = val;
                      _files.clear();
                      _lastDocument = null;
                      _hasMore = true;
                    });
                    _fetchFiles();
                  },
                  [
                    'Grade 1',
                    'Grade 2',
                    'Grade 3',
                    'Grade 4',
                    'Grade 5',
                    'Grade 6',
                    'Grade 7',
                    'Grade 8',
                    'Grade 9',
                    'Form 1',
                    'Form 2',
                    'Form 3',
                    'Form 4',
                  ],
                  theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String? currentValue,
    Function(String?) onChanged,
    List<String> options,
    ThemeData theme,
  ) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text("All")),
        ...options.map((opt) => PopupMenuItem(value: opt, child: Text(opt))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: currentValue != null
              ? theme.primaryColor.withValues(alpha: 0.1)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: currentValue != null
                ? theme.primaryColor
                : theme.dividerColor.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Text(
              currentValue ?? label,
              style: TextStyle(
                color: currentValue != null
                    ? theme.primaryColor
                    : theme.hintColor,
                fontWeight: currentValue != null
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: currentValue != null
                  ? theme.primaryColor
                  : theme.hintColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs(ThemeData theme) {
    if (_breadcrumbs.length <= 1 && !_isSearching) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 48,
      width: double.infinity,
      color: theme.scaffoldBackgroundColor,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _isSearching ? 1 : _breadcrumbs.length,
        separatorBuilder: (ctx, index) =>
            Icon(Icons.chevron_right, size: 16, color: theme.hintColor),
        itemBuilder: (ctx, index) {
          if (_isSearching) {
            return Center(
              child: Text(
                'Search Results',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            );
          }

          final isLast = index == _breadcrumbs.length - 1;
          return GestureDetector(
            onTap: () => _navigateToBreadcrumb(index),
            child: Center(
              child: Text(
                _breadcrumbs[index],
                style: TextStyle(
                  color: isLast ? theme.primaryColor : theme.hintColor,
                  fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // 1. Searching
    if (_isSearching) {
      if (_isLoading && _files.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_files.isEmpty) {
        return _buildEmptyState(theme, 'No results found', Icons.search_off);
      }
      return _buildFileList(theme);
    }

    // 2. Root Level (Show Folders)
    if (_currentFolder == null) {
      if (_isLoading && _folders.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_folders.isEmpty) {
        return _buildEmptyState(theme, 'No subjects found', Icons.folder_off);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Optional: History Carosel can go here or above
          const SessionHistoryCarousel(),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Text(
              "Subjects",
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.3,
              ),
              itemCount: _folders.length,
              itemBuilder: (context, index) {
                final folder = _folders[index];
                return _buildFolderCard(folder, theme);
              },
            ),
          ),
        ],
      );
    }

    // 3. Inside Folder (Show Files)
    if (_isLoading && _files.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_files.isEmpty) {
      return _buildEmptyState(
        theme,
        'No files in this folder',
        Icons.description_outlined,
      );
    }

    return _buildFileList(theme);
  }

  Widget _buildFolderCard(String title, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    // Dynamic color based on title hash for variety
    final color = Colors.primaries[title.hashCode % Colors.primaries.length];

    return GestureDetector(
      onTap: () => _enterFolder(title),
      child: AppTheme.buildGlassContainer(
        context,
        borderRadius: 16,
        opacity: isDark ? 0.1 : 0.6,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.folder, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _files.clear();
          _lastDocument = null;
          _hasMore = true;
        });
        await _fetchFiles();
      },
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
          return _buildFileCard(_files[index], theme);
        },
      ),
    );
  }

  Widget _buildFileCard(FirebaseFile file, ThemeData theme) {
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
            file.name,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              if (file.level != null)
                Text(
                  file.level!,
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
              if (file.level != null && file.curriculum != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.circle, size: 4, color: theme.dividerColor),
                ),
              if (file.curriculum != null)
                Text(
                  file.curriculum!,
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
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
          if (_showSyncButton) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _syncFiles,
              icon: const Icon(Icons.sync),
              label: const Text('Sync Library'),
            ),
          ],
        ],
      ),
    );
  }
}

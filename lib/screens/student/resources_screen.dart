import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for pagination cursor

import '../pdf_viewer_screen.dart';
import '../../services/storage_service.dart';
import '../../models/firebase_file.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  // Pagination State
  final ScrollController _scrollController = ScrollController();
  final List<FirebaseFile> _files = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 15;

  // Admin State
  bool _showMigrationButton = false;

  @override
  void initState() {
    super.initState();
    _fetchFiles(); // Initial Load

    // Setup Pagination Listener
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _fetchFiles();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // --- PAGINATION LOGIC ---
  Future<void> _fetchFiles() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // 1. Fetch paginated data from Firestore
      // Note: You need to update your StorageService to accept 'limit' and 'startAfter'
      // If service update isn't possible, this logic mimics filtering client-side
      // but ideally, this query should be:
      // .where('extension', isEqualTo: '.pdf').limit(_pageSize).startAfterDocument(_lastDocument)

      final newFiles = await StorageService.getPaginatedFiles(
        limit: _pageSize,
        lastDocument: _lastDocument,
        fileType: '.pdf', // Ensure Service filters by PDF
      );

      if (newFiles.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
          // Only show migration button if the VERY FIRST load is empty
          if (_files.isEmpty) _showMigrationButton = true;
        });
        return;
      }

      setState(() {
        _files.addAll(newFiles);
        // Assuming your model stores the raw snapshot, or your service returns it.
        // If not, you might need to change how you track the cursor.
        _lastDocument = newFiles.last.snapshot;
        _isLoading = false;

        // Hide migration button if we successfully loaded files
        _showMigrationButton = false;
      });
    } catch (e) {
      debugPrint("Error fetching resources: $e");
      setState(() => _isLoading = false);
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

  // --- ADMIN: Migration Tool (Clear & Re-index) ---
  Future<void> _runMigration() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Re-index Library?"),
        content: const Text(
          "This will DELETE all current indexes and re-scan Storage for PDF files only.\n\nThis may take a moment.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Clear & Index",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      // 1. Clear existing collection
      await StorageService.deleteAllFileIndexes();

      // 2. Index ONLY .pdf files
      await StorageService.migrateStorageToFirestore(
        allowedExtensions: ['.pdf'], // Pass filter to service
      );

      // 3. Reset UI
      if (mounted) {
        setState(() {
          _files.clear();
          _lastDocument = null;
          _hasMore = true;
          _showMigrationButton = false; // Hide button after success
        });

        // 4. Reload fresh data
        await _fetchFiles();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Library successfully re-indexed!")),
          );
        }
      }
    } catch (e) {
      debugPrint("Migration failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Library",
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          // Conditionally hide migration button
          if (_showMigrationButton)
            IconButton(
              icon: const Icon(Icons.sync, color: Colors.orange),
              tooltip: "Initialize Library",
              onPressed: _runMigration,
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                // Pass full list for search (or implement server-side search)
                delegate: _FileSearchDelegate(_files, _openFile),
              );
            },
          ),
        ],
      ),
      body: _files.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  // Add +1 for the loading spinner at the bottom
                  itemCount: _files.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _files.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final file = _files[index];
                    return _buildFileCard(file, theme);
                  },
                ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf, size: 70, color: theme.disabledColor),
          const SizedBox(height: 16),
          Text(
            "No PDFs found",
            style: GoogleFonts.nunito(
              color: theme.hintColor,
              fontSize: 18,
            ),
          ),
          if (_showMigrationButton) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _runMigration,
              icon: const Icon(Icons.cloud_upload),
              label: const Text("Index Storage Now"),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildFileCard(FirebaseFile file, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
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
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          "PDF Document",
          style: TextStyle(fontSize: 12, color: theme.hintColor),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: theme.iconTheme.color?.withValues(alpha: 0.5),
        ),
        onTap: () => _openFile(file),
      ),
    );
  }
}

class _FileSearchDelegate extends SearchDelegate {
  final List<FirebaseFile> allFiles;
  final Function(FirebaseFile) onFileTap;

  _FileSearchDelegate(this.allFiles, this.onFileTap);

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: theme.hintColor),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
              icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    // Only searching currently loaded files
    // For large datasets, consider an Algolia/ElasticSearch backend integration
    final results = allFiles.where((file) {
      final q = query.toLowerCase();
      return file.name.toLowerCase().contains(q);
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final file = results[index];
        return ListTile(
          leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
          title: Text(file.name),
          onTap: () => onFileTap(file),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../pdf_viewer_screen.dart';
import '../../services/storage_service.dart';
import '../../models/firebase_file.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  late Future<List<FirebaseFile>> _filesFuture;

  @override
  void initState() {
    super.initState();
    _filesFuture = _fetchAndFilterFiles();
  }

  // --- NEW: Fetch and Filter Logic ---
  Future<List<FirebaseFile>> _fetchAndFilterFiles() async {
    try {
      final allFiles = await StorageService.getAllFilesFromFirestore();

      // Filter Client-Side
      return allFiles.where((file) {
        final name = file.name.toLowerCase();
        return name.endsWith('.pdf') ||
            name.endsWith('.doc') ||
            name.endsWith('.docx');
      }).toList();
    } catch (e) {
      debugPrint("Error fetching resources: $e");
      return [];
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

  // --- ADMIN: Migration Tool ---
  Future<void> _runMigration() async {
    // ... (Keep existing migration logic)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Migrate to Firestore?"),
        content: const Text("Index all files to Firestore."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Migrate"),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await StorageService.migrateStorageToFirestore();
      if (mounted) {
        setState(() {
          _filesFuture = _fetchAndFilterFiles(); // Refresh filtered list
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Migration complete!")));
      }
    } catch (e) {
      // Handle error
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
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: () => _runMigration(),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final files = await _filesFuture;
              if (!context.mounted) return;
              showSearch(
                context: context,
                delegate: _FileSearchDelegate(files, _openFile),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<FirebaseFile>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final files = snapshot.data ?? [];
          if (files.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_off, size: 70, color: theme.disabledColor),
                  const SizedBox(height: 16),
                  Text(
                    "No documents found",
                    style: GoogleFonts.nunito(
                      color: theme.hintColor,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              return _buildFileCard(file, theme);
            },
          );
        },
      ),
    );
  }

  Widget _buildFileCard(FirebaseFile file, ThemeData theme) {
    // ... (Keep existing UI)
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
        leading: _getFileIcon(file.name),
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
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: theme.iconTheme.color?.withValues(alpha: 0.5),
        ),
        onTap: () => _openFile(file),
      ),
    );
  }

  Widget _getFileIcon(String fileName) {
    // Same icon logic as FilesScreen
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'pdf') {
      return const Icon(
        Icons.picture_as_pdf,
        color: Color(0xFFFF6B6B),
        size: 28,
      );
    }
    return const Icon(Icons.description, color: Color(0xFF4A90E2), size: 28);
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
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
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
    final results = allFiles.where((file) {
      final q = query.toLowerCase();
      return file.name.toLowerCase().contains(q);
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final file = results[index];
        return ListTile(
          leading: const Icon(Icons.description, color: Colors.grey),
          title: Text(file.name),
          onTap: () => onFileTap(file),
        );
      },
    );
  }
}

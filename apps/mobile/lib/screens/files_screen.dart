import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/firebase_file.dart';
import '../services/storage_service.dart';
import 'pdf_viewer_screen.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  late Future<List<FirebaseFile>> _filesFuture;

  @override
  void initState() {
    super.initState();
    // Use local filter method instead of calling service directly
    _filesFuture = _fetchAndFilterFiles();
  }

  // --- NEW: Fetch and Filter Logic ---
  Future<List<FirebaseFile>> _fetchAndFilterFiles() async {
    try {
      // 1. Get all files from Firestore (Files + Images)
      final allFiles = await StorageService.getAllFilesFromFirestore();

      // 2. Filter Client-Side: Keep only Documents
      return allFiles.where((file) {
        final name = file.name.toLowerCase();
        return name.endsWith('.pdf') ||
            name.endsWith('.doc') ||
            name.endsWith('.docx');
      }).toList();
    } catch (e) {
      debugPrint("Error fetching files: $e");
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Library Resources",
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final files = await _filesFuture;
              if (!context.mounted) return;
              showSearch(
                context: context,
                delegate: FileSearchDelegate(files, _openFile),
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
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    "Error loading resources",
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                ],
              ),
            );
          }

          final files = snapshot.data ?? [];
          if (files.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 60, color: theme.disabledColor),
                  const SizedBox(height: 16),
                  Text(
                    "No documents found",
                    style: TextStyle(color: theme.hintColor),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: files.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final file = files[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: theme.cardColor,
                child: ListTile(
                  leading: _getFileIcon(file.name),
                  title: Text(
                    file.name,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => _openFile(file),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    late Color color;
    late IconData icon;

    switch (ext) {
      case 'pdf':
        color = const Color(0xFFFF6B6B);
        icon = Icons.picture_as_pdf;
        break;
      case 'doc':
      case 'docx':
        color = const Color(0xFF4A90E2);
        icon = Icons.description;
        break;
      default:
        color = Colors.grey;
        icon = Icons.insert_drive_file;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }
}

// --- SEARCH DELEGATE ---
class FileSearchDelegate extends SearchDelegate {
  final List<FirebaseFile> allFiles;
  final Function(FirebaseFile) onFileTap;

  FileSearchDelegate(this.allFiles, this.onFileTap);

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = allFiles.where((file) {
      final q = query.toLowerCase();
      return file.name.toLowerCase().contains(q) ||
          (file.ref?.fullPath.toLowerCase().contains(q) ?? false);
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final file = results[index];
        return ListTile(
          leading: const Icon(Icons.picture_as_pdf, color: Colors.grey),
          title: Text(file.name),
          onTap: () => onFileTap(file),
        );
      },
    );
  }
}

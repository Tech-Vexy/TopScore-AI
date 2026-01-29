import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/firebase_file.dart';

class StorageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _filesCollection = 'files';

  // ============================================================
  // FIRESTORE-BASED METHODS (NEW - Recommended for search)
  // ============================================================

  /// Gets all files from Firestore (fast, paginated)
  static Future<List<FirebaseFile>> getAllFilesFromFirestore({
    int limit = 1000,
  }) async {
    try {
      // Check if user is authenticated before querying Firestore
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('User not authenticated, skipping Firestore query');
        return [];
      }

      final snapshot = await _firestore
          .collection(_filesCollection)
          .orderBy('name')
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => FirebaseFile.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching files from Firestore: $e');
      // Return empty list instead of fallback to avoid duplicate errors
      return [];
    }
  }

  /// Paginated fetch with optional file type filtering
  static Future<List<FirebaseFile>> getPaginatedFiles({
    int limit = 15,
    DocumentSnapshot? lastDocument,
    String? fileType,
  }) async {
    try {
      Query query = _firestore.collection(_filesCollection);

      // Apply Filter
      if (fileType != null) {
        // Remove leading dot if present (e.g. ".pdf" -> "pdf")
        final type =
            fileType.startsWith('.') ? fileType.substring(1) : fileType;
        query = query.where('type', isEqualTo: type.toLowerCase());
      }

      // Retrieve Ordered Data
      query = query.orderBy('name');

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.limit(limit).get();
      return snapshot.docs
          .map((doc) => FirebaseFile.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint("Error fetching paginated files: $e");
      return [];
    }
  }

  /// Prefix search on file names (fast, uses Firestore index)
  /// Example: searchFiles("algebra") matches "Algebra Chapter 1.pdf"
  static Future<List<FirebaseFile>> searchFiles(
    String query, {
    int limit = 30,
  }) async {
    if (query.trim().isEmpty) {
      return getAllFilesFromFirestore(limit: limit);
    }

    final searchTerm = query.toLowerCase().trim();

    try {
      final snapshot = await _firestore
          .collection(_filesCollection)
          .where('fileNameLower', isGreaterThanOrEqualTo: searchTerm)
          .where('fileNameLower', isLessThanOrEqualTo: '$searchTerm\uf8ff')
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => FirebaseFile.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error searching files: $e');
      return [];
    }
  }

  /// Filter files by subject and/or level (uses composite index)
  static Future<List<FirebaseFile>> filterBySubjectLevel({
    String? subject,
    String? level,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore.collection(_filesCollection);

      if (subject != null && subject.isNotEmpty) {
        query = query.where('subject', isEqualTo: subject);
      }
      if (level != null && level.isNotEmpty) {
        query = query.where('level', isEqualTo: level);
      }

      final snapshot = await query.limit(limit).get();
      return snapshot.docs
          .map((doc) => FirebaseFile.fromFirestore(doc as DocumentSnapshot))
          .toList();
    } catch (e) {
      debugPrint('Error filtering files: $e');
      return [];
    }
  }

  /// Search files by tag (array-contains query)
  static Future<List<FirebaseFile>> searchByTag(
    String tag, {
    int limit = 30,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_filesCollection)
          .where('tags', arrayContains: tag.toLowerCase())
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => FirebaseFile.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error searching by tag: $e');
      return [];
    }
  }

  // ============================================================
  // MIGRATION SCRIPT (Run once to populate Firestore)
  // ============================================================

  /// Clears all indexed files from Firestore
  /// Processes deletions in batches to avoid Firestore's 500 operation limit
  static Future<void> clearAllIndexedFiles() async {
    try {
      debugPrint('Starting to clear all indexed files from Firestore...');

      // Get all documents in the files collection
      final snapshot = await _firestore.collection(_filesCollection).get();
      final docs = snapshot.docs;

      debugPrint('Found ${docs.length} indexed files to delete');

      if (docs.isEmpty) {
        debugPrint('No files to delete');
        return;
      }

      // Firestore batch limit is 500 operations, use 400 to be safe
      const batchSize = 400;
      int processed = 0;

      // Process deletions in batches
      while (processed < docs.length) {
        final batch = _firestore.batch();
        final end = (processed + batchSize < docs.length)
            ? processed + batchSize
            : docs.length;

        for (int i = processed; i < end; i++) {
          batch.delete(docs[i].reference);
        }

        await batch.commit();
        processed = end;
        debugPrint('Deleted batch: $processed/${docs.length} files');
      }

      debugPrint('Successfully cleared all indexed files from Firestore');
    } catch (e) {
      debugPrint('Error clearing indexed files: $e');
      rethrow;
    }
  }

  // Alias for user code compatibility
  static Future<void> deleteAllFileIndexes() => clearAllIndexedFiles();

  /// Migrates all files from Firebase Storage to Firestore metadata collection.
  /// Run this once via an admin button or command.
  static Future<MigrationResult> migrateStorageToFirestore({
    List<String>? allowedExtensions,
  }) async {
    int successCount = 0;
    int errorCount = 0;
    final List<String> errors = [];

    try {
      // 1. Get all files from Storage
      final storageFiles = await listAllFiles();
      debugPrint('Found ${storageFiles.length} files in Storage');

      // 2. Check existing files in Firestore to avoid duplicates
      final existingPaths = await _getExistingFilePaths();

      // 3. Add each file to Firestore
      for (final file in storageFiles) {
        if (existingPaths.contains(file.path)) {
          debugPrint('Skipping existing file: ${file.name}');
          continue;
        }

        // Apply Extension Filter
        if (allowedExtensions != null) {
          final ext = '.${file.name.split('.').last.toLowerCase()}';
          // Check if the extension is in the allowed list (case-insensitive done by lowercase above)
          // Ensure allowedExtensions are also lowercased or handled correctly.
          // Assuming user passes ['.pdf']
          if (!allowedExtensions.contains(ext)) continue;
        }

        try {
          // Extract metadata from path
          final metadata = FirebaseFile.extractMetadataFromPath(file.path);

          await _firestore.collection(_filesCollection).add({
            'name': file.name,
            'fileNameLower': file.name.toLowerCase(),
            'path': file.path,
            'subject': metadata['subject'],
            'level': metadata['level'],
            'type': file.name.split('.').last.toLowerCase(),
            'uploadedAt': FieldValue.serverTimestamp(),
            'tags': _extractTags(
              file.name,
              metadata['subject'],
              metadata['level'],
            ),
          });

          successCount++;
          debugPrint('Migrated: ${file.name}');
        } catch (e) {
          errorCount++;
          errors.add('${file.name}: $e');
          debugPrint('Error migrating ${file.name}: $e');
        }
      }

      return MigrationResult(
        totalFiles: storageFiles.length,
        successCount: successCount,
        errorCount: errorCount,
        errors: errors,
      );
    } catch (e) {
      debugPrint('Migration failed: $e');
      return MigrationResult(
        totalFiles: 0,
        successCount: 0,
        errorCount: 1,
        errors: ['Migration failed: $e'],
      );
    }
  }

  /// Get all existing file paths in Firestore (to avoid duplicates)
  static Future<Set<String>> _getExistingFilePaths() async {
    final snapshot = await _firestore.collection(_filesCollection).get();
    return snapshot.docs
        .map((doc) => doc.data()['path'] as String?)
        .whereType<String>()
        .toSet();
  }

  /// Extract searchable tags from file name and metadata
  static List<String> _extractTags(
    String name,
    String? subject,
    String? level,
  ) {
    final tags = <String>[];

    // Add subject and level as tags
    if (subject != null) tags.add(subject.toLowerCase());
    if (level != null) tags.add(level.toLowerCase());

    // Extract words from filename (excluding extension)
    final nameWithoutExt = name.replaceAll(RegExp(r'\.[^.]+$'), '');
    final words = nameWithoutExt.split(RegExp(r'[\s_\-]+'));
    for (final word in words) {
      if (word.length > 2) {
        tags.add(word.toLowerCase());
      }
    }

    return tags.toSet().toList(); // Remove duplicates
  }

  // ============================================================
  // LEGACY METHOD (Kept for fallback and migration)
  // ============================================================

  /// Recursively fetches all files from Firebase Storage (SLOW for large datasets)
  /// Use this only for migration or as fallback when Firestore is unavailable.
  static Future<List<FirebaseFile>> listAllFiles({String path = ''}) async {
    List<FirebaseFile> allFiles = [];

    final ref = FirebaseStorage.instance.ref(path);

    try {
      final result = await ref.listAll();

      // Add all files found in THIS folder
      for (final fileRef in result.items) {
        allFiles.add(FirebaseFile.fromStorageRef(fileRef));
      }

      // RECURSION: Find sub-folders and dive into them
      for (final folderRef in result.prefixes) {
        final subFolderFiles = await listAllFiles(path: folderRef.fullPath);
        allFiles.addAll(subFolderFiles);
      }
    } catch (e) {
      debugPrint("Error listing files at $path: $e");
    }

    return allFiles;
  }
}

/// Result of migration operation
class MigrationResult {
  final int totalFiles;
  final int successCount;
  final int errorCount;
  final List<String> errors;

  MigrationResult({
    required this.totalFiles,
    required this.successCount,
    required this.errorCount,
    required this.errors,
  });

  bool get isSuccess => errorCount == 0;

  @override
  String toString() =>
      'Migration: $successCount/$totalFiles succeeded, $errorCount errors';
}

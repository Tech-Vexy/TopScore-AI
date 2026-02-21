import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/firebase_file.dart';

class StorageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _filesCollection = 'resources';

  /// Normalizes curriculum strings to the canonical stored values.
  /// User profiles store 'CBC' or '8-4-4'. Firestore docs also use these.
  /// This handles variants like 'KCSE', '844', '8.4.4' → '8-4-4'.
  static String? _normalizeCurriculum(String? curriculum) {
    if (curriculum == null || curriculum.isEmpty) return null;
    final upper = curriculum.toUpperCase().trim();
    if (upper == 'CBC' || upper == 'PRIMARY' || upper == 'JUNIOR') {
      return 'CBC';
    }
    if (upper == '8-4-4' ||
        upper == '844' ||
        upper == '8.4.4' ||
        upper == 'KCSE') {
      return '8-4-4';
    }
    if (upper == 'IGCSE') return 'IGCSE';
    return curriculum;
  }

  /// Applies a Firestore curriculum filter using the normalized value.
  static Query _applyCurriculumFilter(Query query, String? curriculum) {
    final normalized = _normalizeCurriculum(curriculum);
    if (normalized != null) {
      query = query.where('curriculum', isEqualTo: normalized);
    }
    return query;
  }

  /// Determines the Firestore collection based on curriculum.
  static String _getCollectionName(String? curriculum) {
    final normalized = _normalizeCurriculum(curriculum);
    if (normalized == 'CBC') return 'cbc_files';
    if (normalized == '8-4-4') return '844_files';
    return _filesCollection; // Default fallback to 'resources'
  }

  // ============================================================
  // FIRESTORE-BASED METHODS (Recommended for search)
  // ============================================================

  /// Gets files from Firestore filtered by the student's grade and curriculum.
  static Future<List<FirebaseFile>> getAllFilesFromFirestore({
    int limit = 1000,
    int? grade,
    String? curriculum,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('User not authenticated, skipping Firestore query');
        return [];
      }

      final collectionName = _getCollectionName(curriculum);
      Query query = _firestore.collection(collectionName);

      if (grade != null) {
        query = query.where('grade', isEqualTo: grade);
      }
      query = _applyCurriculumFilter(query, curriculum);

      query = query.orderBy('name').limit(limit);

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => FirebaseFile.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching files from Firestore: $e');
      return [];
    }
  }

  /// Paginated fetch with optional file type filtering
  static Future<List<FirebaseFile>> getPaginatedFiles({
    int limit = 15,
    DocumentSnapshot? lastDocument,
    String? fileType,
    String? folder,
    int? grade,
    String? curriculum,
    String? category,
    String? pathPrefix,
  }) async {
    try {
      final collectionName = _getCollectionName(curriculum);
      Query query = _firestore.collection(collectionName);

      // Apply Folder Filter (Subject) -> Replaced by pathPrefix logic potentially,
      // but keeping for backward compatibility if needed.
      // If pathPrefix is set, we use that for "folder" navigation.
      if (folder != null && folder.isNotEmpty) {
        query = query.where('subject', isEqualTo: folder);
      }

      // Apply Path Filter (Prefix Search for Folder Navigation)
      if (pathPrefix != null && pathPrefix.isNotEmpty) {
        // Ensure prefix ends with / if it's a folder, though the caller should handle this.
        // We use the standard prefix query technique:
        // path >= 'prefix' AND path < 'prefix' + last_char_increment
        final endPrefix = '$pathPrefix\uf8ff';
        query = query
            .where('path', isGreaterThanOrEqualTo: pathPrefix)
            .where('path', isLessThan: endPrefix);
      }

      // Apply Grade Filter (Numeric)
      if (grade != null) {
        query = query.where('grade', isEqualTo: grade);
      }

      // Apply Curriculum Filter (normalized)
      query = _applyCurriculumFilter(query, curriculum);

      // Apply Category Filter
      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      // Apply File Type Filter
      if (fileType != null) {
        final type =
            fileType.startsWith('.') ? fileType.substring(1) : fileType;
        query = query.where('type', isEqualTo: type.toLowerCase());
      }

      // Retrieve Ordered Data
      // IMPORTANT: In Firestore, if you have an inequality filter (like our path range),
      // the first orderBy field MUST be the same as the filtered field.
      if (pathPrefix != null && pathPrefix.isNotEmpty) {
        query = query.orderBy('path');
      }
      query = query.orderBy('name');

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.limit(limit).get();
      return snapshot.docs
          .map((doc) => FirebaseFile.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching paginated files: $e');
      if (e.toString().contains('FAILED_PRECONDITION')) {
        debugPrint(
            'TIP: You likely need to create a Firestore composite index in the Firebase Console.');
      }
      return [];
    }
  }

  /// Exhaustive search across file names, tags, and subjects.
  /// Combines multiple Firestore queries for comprehensive results:
  ///   1. Prefix match on fileNameLower (files whose name starts with query)
  ///   2. Tag match (files tagged with the search keyword)
  ///   3. Subject match (files whose subject starts with the query)
  /// All queries are filtered by the student's grade and curriculum.
  static Future<List<FirebaseFile>> searchFiles(
    String query, {
    int limit = 50,
    int? grade,
    String? curriculum,
    String? category,
  }) async {
    if (query.trim().isEmpty) {
      return getAllFilesFromFirestore(
        limit: limit,
        grade: grade,
        curriculum: curriculum,
      );
    }

    final searchTerm = query.toLowerCase().trim();
    final Map<String, FirebaseFile> resultsMap = {};

    // Helper to build a base query with grade+curriculum+category filters
    Query buildBaseQuery() {
      final collectionName = _getCollectionName(curriculum);
      Query q = _firestore.collection(collectionName);
      if (grade != null) {
        q = q.where('grade', isEqualTo: grade);
      }
      q = _applyCurriculumFilter(q, curriculum);
      if (category != null && category.isNotEmpty) {
        q = q.where('category', isEqualTo: category);
      }
      return q;
    }

    // Strategy 1: Prefix match on fileNameLower
    try {
      final prefixQuery = buildBaseQuery()
          .where('fileNameLower', isGreaterThanOrEqualTo: searchTerm)
          .where('fileNameLower', isLessThanOrEqualTo: '$searchTerm\uf8ff')
          .limit(limit);

      final snapshot = await prefixQuery.get();
      for (final doc in snapshot.docs) {
        resultsMap[doc.id] = FirebaseFile.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Search prefix query error: $e');
    }

    // Strategy 2: Tag-based search (matches substring keywords in filename/subject)
    if (resultsMap.length < limit) {
      try {
        final tagQuery = buildBaseQuery()
            .where('tags', arrayContains: searchTerm)
            .limit(limit);

        final snapshot = await tagQuery.get();
        for (final doc in snapshot.docs) {
          resultsMap.putIfAbsent(doc.id, () => FirebaseFile.fromFirestore(doc));
        }
      } catch (e) {
        debugPrint('Search tag query error: $e');
      }
    }

    // Strategy 3: Subject prefix match
    if (resultsMap.length < limit) {
      try {
        // Capitalize first letter for subject match (e.g. "math" → "Math")
        final subjectTerm =
            searchTerm[0].toUpperCase() + searchTerm.substring(1);
        final subjectQuery = buildBaseQuery()
            .where('subject', isGreaterThanOrEqualTo: subjectTerm)
            .where('subject', isLessThanOrEqualTo: '$subjectTerm\uf8ff')
            .limit(limit);

        final snapshot = await subjectQuery.get();
        for (final doc in snapshot.docs) {
          resultsMap.putIfAbsent(doc.id, () => FirebaseFile.fromFirestore(doc));
        }
      } catch (e) {
        debugPrint('Search subject query error: $e');
      }
    }

    // Sort results by name for consistent ordering
    final results = resultsMap.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return results.take(limit).toList();
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

  /// Clears all indexed files from Firestore (from all known collections)
  static Future<void> clearAllIndexedFiles() async {
    final collections = [_filesCollection, 'cbc_files', '844_files'];

    for (final collection in collections) {
      await _clearCollection(collection);
    }
  }

  static Future<void> _clearCollection(String collectionName) async {
    try {
      debugPrint('Starting to clear indexed files from $collectionName...');

      // Get all documents in the files collection
      final snapshot = await _firestore.collection(collectionName).get();
      final docs = snapshot.docs;

      debugPrint(
          'Found ${docs.length} indexed files to delete in $collectionName');

      if (docs.isEmpty) {
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
        debugPrint(
            'Deleted batch from $collectionName: $processed/${docs.length} files');
      }

      debugPrint('Successfully cleared files from $collectionName');
    } catch (e) {
      debugPrint('Error clearing indexed files from $collectionName: $e');
      rethrow;
    }
  }

  // Alias for user code compatibility
  static Future<void> deleteAllFileIndexes() => clearAllIndexedFiles();

  /// Migrates all files from Firebase Storage to Firestore metadata collection.
  /// Run this once via an admin button or command.
  static Future<MigrationResult> migrateStorageToFirestore({
    List<String>? allowedExtensions,
    bool forceUpdate = false,
  }) async {
    int successCount = 0;
    int errorCount = 0;
    final List<String> errors = [];

    try {
      // 1. Get all files from Storage
      final storageFiles = await listAllFiles();
      debugPrint('Found ${storageFiles.length} files in Storage');

      // 2. Check existing files in Firestore to avoid duplicates

      // 3. Add each file to Firestore
      for (final file in storageFiles) {
        String? existingDocId;
        bool exists = false;

        // Extract metadata from path first to determine collection
        final metadata = FirebaseFile.extractMetadataFromPath(file.path);
        final curriculum = metadata['curriculum'];
        final collectionName = _getCollectionName(curriculum);

        // Check if exists in the specific collection
        final existingQuery = await _firestore
            .collection(collectionName)
            .where('path', isEqualTo: file.path)
            .limit(1)
            .get();

        if (existingQuery.docs.isNotEmpty) {
          exists = true;
          existingDocId = existingQuery.docs.first.id;
        }

        if (exists && !forceUpdate) {
          debugPrint('Skipping existing file: ${file.name}');
          continue;
        }

        // Apply Extension Filter
        if (allowedExtensions != null) {
          final ext = '.${file.name.split('.').last.toLowerCase()}';
          if (!allowedExtensions.contains(ext)) continue;
        }

        try {
          // Fetch High-fidelity Storage Metadata if possible (for size and downloadUrl)
          String? downloadUrl;
          int? size;
          try {
            if (file.ref != null) {
              downloadUrl = await file.ref!.getDownloadURL();
              final meta = await file.ref!.getMetadata();
              size = meta.size;
            }
          } catch (e) {
            debugPrint(
                'Could not fetch extra storage info for ${file.name}: $e');
          }

          final Map<String, dynamic> docData = {
            'name': file.name,
            'fileNameLower': file.name.toLowerCase(),
            'path': file.path,
            'subject': metadata['subject'],
            'grade': metadata['grade'],
            'curriculum': metadata['curriculum'],
            'category': metadata['category'],
            'type': file.name.split('.').last.toLowerCase(),
            'size': size,
            'downloadUrl': downloadUrl,
            'uploadedAt': FieldValue.serverTimestamp(),
            'tags': _extractTags(
              file.name,
              metadata['subject'],
              metadata['grade']?.toString(),
              metadata['curriculum'],
              (metadata['tags'] as List<dynamic>?)?.cast<String>(),
            ),
          };

          if (exists && existingDocId != null) {
            await _firestore
                .collection(collectionName)
                .doc(existingDocId)
                .update(docData);
            debugPrint('Updated in $collectionName: ${file.name}');
          } else {
            await _firestore.collection(collectionName).add(docData);
            debugPrint('Migrated to $collectionName: ${file.name}');
          }
          successCount++;
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

  /// Extract searchable tags from file name and metadata
  static List<String> _extractTags(
    String name,
    String? subject,
    String? level,
    String? curriculum, [
    List<String>? extraTags,
  ]) {
    final tags = <String>[];

    // Add subject, level, and curriculum as tags
    if (subject != null) tags.add(subject.toLowerCase());
    if (level != null) tags.add(level.toLowerCase());
    if (curriculum != null) tags.add(curriculum.toLowerCase());
    if (extraTags != null) {
      tags.addAll(extraTags.map((t) => t.toLowerCase()));
    }

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

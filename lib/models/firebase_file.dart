import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Represents a file stored in Firebase Storage with metadata indexed in Firestore.
class FirebaseFile {
  final String? id; // Firestore document ID (null for Storage-only files)
  final Reference? ref; // Storage reference (null for Firestore-only results)
  final String name;
  final String path;
  final String? fileNameLower; // Lowercase name for case-insensitive search
  final String? subject; // Extracted from path (e.g., "Math", "Physics")
  final String? level; // Extracted from path (e.g., "Form 1", "Form 2")
  final String? curriculum; // "CBC", "844", "KCSE", etc.
  final String type; // File extension (pdf, jpg, etc.)
  final int? size; // File size in bytes
  final DateTime? uploadedAt;
  final List<String>? tags; // List of tags (e.g. "KCSE", "2023")
  final DocumentSnapshot? snapshot; // For pagination cursor

  const FirebaseFile({
    this.id,
    this.ref,
    required this.name,
    required this.path,
    this.fileNameLower,
    this.subject,
    this.level,
    this.curriculum,
    this.type = 'pdf',
    this.size,
    this.uploadedAt,
    this.tags,
    this.snapshot,
  });

  /// Create from Firebase Storage Reference (existing behavior)
  factory FirebaseFile.fromStorageRef(Reference ref) {
    final meta = extractMetadataFromPath(ref.fullPath);
    return FirebaseFile(
      ref: ref,
      name: ref.name,
      path: ref.fullPath,
      fileNameLower: ref.name.toLowerCase(),
      subject: meta['subject'],
      level: meta['level'],
      curriculum: meta['curriculum'],
      type: ref.name.split('.').last.toLowerCase(),
      tags: (meta['tags'] as List<dynamic>?)?.cast<String>(),
    );
  }

  /// Create from Firestore document (new behavior)
  factory FirebaseFile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirebaseFile(
      id: doc.id,
      name: data['name'] ?? 'Unknown',
      path: data['path'] ?? '',
      fileNameLower: data['fileNameLower'],
      subject: data['subject'],
      level: data['level'],
      curriculum: data['curriculum'],
      type: data['type'] ?? 'pdf',
      size: data['size'],
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate(),
      tags: (data['tags'] as List<dynamic>?)?.cast<String>(),
      snapshot: doc,
    );
  }

  /// Convert to Firestore document map (for writing)
  Map<String, dynamic> toFirestoreMap() {
    return {
      'name': name,
      'fileNameLower': fileNameLower ?? name.toLowerCase(),
      'path': path,
      'subject': subject,
      'level': level,
      'curriculum': curriculum,
      'type': type,
      'size': size,
      'uploadedAt': uploadedAt != null
          ? Timestamp.fromDate(uploadedAt!)
          : FieldValue.serverTimestamp(),
      'tags': tags ?? [],
    };
  }

  /// Extract metadata from storage path
  /// Example: "844/Math/Form1/Algebra/chapter1.pdf"
  /// Returns: {subject: "Math", level: "Form1"}
  static Map<String, dynamic> extractMetadataFromPath(String path) {
    // 1. Split and clean
    var parts = path.split('/');
    // Remove filename from parts for analysis if needed, or keep it to check depth?
    // Generally 'path' is full path including filename.
    // If we want folders, we shouldn't use the last part as a folder.

    // 2. Remove "resources" prefix if present
    if (parts.isNotEmpty && parts[0].toLowerCase() == 'resources') {
      parts.removeAt(0);
    }

    String? cur;
    String? subj;
    String? lvl;
    List<String> extraTags = [];

    int i = 0;

    // 3. Consume prefixes (Curriculum or Document Type)
    // We loop to consume multiple prefixes (e.g. 844/Notes/Math)
    while (i < parts.length) {
      String part = parts[i];
      // Try to avoid using the filename as a structural folder
      if (i == parts.length - 1) break;

      String upper = part.toUpperCase();
      bool isConsumed = false;

      // Check Curriculum
      if (upper.contains('844') || upper.contains('KCSE')) {
        cur = '8.4.4';
        isConsumed = true;
      } else if (upper.contains('CBC') ||
          upper.contains('PRIMARY') ||
          upper.contains('JUNIOR')) {
        cur = 'CBC';
        isConsumed = true;
      }
      // Check Document Types / Schemas
      else if (upper.contains('LESSON') ||
          upper.contains('Plan') ||
          upper.contains('NOTES') ||
          upper.contains('SCHEME') ||
          upper.contains('EXAM')) {
        extraTags.add(part);
        isConsumed = true;
      }

      if (isConsumed) {
        i++;
      } else {
        // Reached the Subject
        break;
      }
    }

    // 4. Extract Subject and Level
    // The next available part is treated as Subject
    if (i < parts.length - 1) {
      subj = parts[i];
      i++;
    }

    // The next part (if not filename) is Level
    if (i < parts.length - 1) {
      lvl = parts[i];
    }

    return {
      'curriculum': cur,
      'subject': subj,
      'level': lvl,
      'tags': extraTags,
    };
  }

  @override
  String toString() => 'FirebaseFile(name: $name, path: $path)';
}

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
  final String type; // File extension (pdf, jpg, etc.)
  final int? size; // File size in bytes
  final DateTime? uploadedAt;
  final List<String>? tags; // Keywords for search

  const FirebaseFile({
    this.id,
    this.ref,
    required this.name,
    required this.path,
    this.fileNameLower,
    this.subject,
    this.level,
    this.type = 'pdf',
    this.size,
    this.uploadedAt,
    this.tags,
  });

  /// Create from Firebase Storage Reference (existing behavior)
  factory FirebaseFile.fromStorageRef(Reference ref) {
    final pathParts = ref.fullPath.split('/');
    return FirebaseFile(
      ref: ref,
      name: ref.name,
      path: ref.fullPath,
      fileNameLower: ref.name.toLowerCase(),
      subject: pathParts.length > 2 ? pathParts[1] : null,
      level: pathParts.length > 3 ? pathParts[2] : null,
      type: ref.name.split('.').last.toLowerCase(),
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
      type: data['type'] ?? 'pdf',
      size: data['size'],
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate(),
      tags: (data['tags'] as List<dynamic>?)?.cast<String>(),
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
  static Map<String, String?> extractMetadataFromPath(String path) {
    final parts = path.split('/');
    return {
      'subject': parts.length > 1 ? parts[1] : null,
      'level': parts.length > 2 ? parts[2] : null,
    };
  }

  @override
  String toString() => 'FirebaseFile(name: $name, path: $path)';
}

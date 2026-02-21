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
  final int? grade; // Extracted from path or set via admin
  final String? curriculum; // "CBC", "844", "KCSE", etc.
  final String?
      category; // "Notes", "Curriculum", "Schemes of Work", "Lesson Plans"
  final String type; // File extension (pdf, jpg, etc.)
  final int? size; // File size in bytes
  final String? downloadUrl;
  final DateTime? uploadedAt;
  final List<String>? tags; // List of tags (e.g. "KCSE", "2023")
  final DocumentSnapshot? snapshot; // For pagination cursor
  final String? strand; // CBC strand (e.g., "Numbers", "Measurement")
  final String? subStrand; // CBC sub-strand (e.g., "Whole Numbers", "Length")

  const FirebaseFile({
    this.id,
    this.ref,
    required this.name,
    required this.path,
    this.fileNameLower,
    this.subject,
    this.grade,
    this.curriculum,
    this.category,
    this.type = 'pdf',
    this.size,
    this.downloadUrl,
    this.uploadedAt,
    this.tags,
    this.snapshot,
    this.strand,
    this.subStrand,
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
      grade: meta['grade'],
      curriculum: meta['curriculum'],
      category: meta['category'],
      type: ref.name.split('.').last.toLowerCase(),
      tags: (meta['tags'] as List<dynamic>?)?.cast<String>(),
    );
  }

  /// Create from Firestore document (new behavior)
  factory FirebaseFile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirebaseFile(
      id: doc.id,
      name: data['name'] ?? data['title'] ?? 'Unknown',
      path: data['path'] ?? data['storagePath'] ?? '',
      fileNameLower: data['fileNameLower'] ??
          (data['name'] ?? data['title'] ?? '').toLowerCase(),
      subject: data['subject'],
      grade: data['grade'] ?? data['level'],
      curriculum: data['curriculum'],
      category: data['category'],
      type: data['type'] ??
          (data['path'] ?? data['storagePath'] ?? '')
              .split('.')
              .last
              .toLowerCase(),
      size: data['size'] ?? data['fileSize'],
      downloadUrl: data['downloadUrl'],
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate(),
      tags: data['tags'] != null ? List<String>.from(data['tags']) : null,
      snapshot: doc,
      strand: data['strand'],
      subStrand: data['subStrand'] ?? data['sub_strand'],
    );
  }

  /// Convert to Firestore document map (for writing)
  Map<String, dynamic> toFirestoreMap() {
    return {
      'name': name,
      'fileNameLower': fileNameLower ?? name.toLowerCase(),
      'path': path,
      'subject': subject,
      'grade': grade,
      'curriculum': curriculum,
      'category': category,
      'type': type,
      'size': size,
      'uploadedAt': uploadedAt != null
          ? Timestamp.fromDate(uploadedAt!)
          : FieldValue.serverTimestamp(),
      'tags': tags ?? [],
      if (strand != null) 'strand': strand,
      if (subStrand != null) 'subStrand': subStrand,
    };
  }

  /// Extract metadata from storage path
  /// Example: "844/Math/Form1/Algebra/chapter1.pdf"
  /// Extracts metadata (subject, level, curriculum, category) from a file path
  static Map<String, dynamic> extractMetadataFromPath(String path) {
    // Standard path structure: resources/Category/Curriculum/Level/Subject/file.pdf
    // Example: resources/Notes/IGCSE/Year 10/Biology/Cell-Biology.pdf
    List<String> parts = path.split('/');
    if (parts.isEmpty) return {};

    // Skip "resources" if it's the first part
    if (parts[0].toLowerCase() == 'resources') {
      parts.removeAt(0);
    }

    String? cur;
    String? subj;
    String? cat;
    int? grd;
    List<String> extraTags = [];

    // Analyze parts one by one
    for (String part in parts) {
      if (part == parts.last) break; // Skip the filename itself

      String upper = part.toUpperCase();
      bool consumed = false;

      // 1. Identify Curriculum
      if (cur == null) {
        if (upper.contains('CBC') ||
            upper.contains('PRIMARY') ||
            upper.contains('JUNIOR')) {
          cur = 'CBC';
          cat ??= 'Curriculum'; // NEW: Default category for curriculum parts
          consumed = true;
        } else if (upper.contains('844') ||
            upper.contains('8.4.4') ||
            upper.contains('8-4-4') ||
            upper.contains('KCSE')) {
          cur = '8-4-4';
          cat ??= 'Curriculum'; // NEW: Default category for curriculum parts
          consumed = true;
        } else if (upper.contains('IGCSE')) {
          cur = 'IGCSE';
          consumed = true;
        }
      }

      // 2. Identify Category
      if (!consumed && cat == null) {
        if (upper.contains('NOTES')) {
          cat = 'Notes';
          consumed = true;
        } else if (upper.contains('SCHEME')) {
          cat = 'Schemes Of Work';
          consumed = true;
        } else if (upper.contains('LESSON') || upper.contains('PLAN')) {
          cat = 'Lesson Plans';
          consumed = true;
        } else if (upper.contains('CURRICULUM')) {
          cat = 'Curriculum';
          consumed = true;
        }
      }

      // 3. Identify Grade/Level
      if (!consumed && grd == null) {
        if (upper.contains('GRADE') ||
            upper.contains('FORM') ||
            upper.contains('CLASS') ||
            upper.contains('YEAR')) {
          final numMatch = RegExp(r'\d+').firstMatch(part);
          if (numMatch != null) {
            grd = int.tryParse(numMatch.group(0)!);
            consumed = true;
          }
        }
      }

      // 4. If not consumed by major categories, it's likely the Subject
      if (!consumed) {
        // Simple heuristic: if it's not a major category or curriculum, it's the subject
        // Only take the first such part as the primary subject
        if (subj == null) {
          subj = part;
        } else {
          extraTags.add(part);
        }
      }
    }

    return {
      'curriculum': cur,
      'subject': subj,
      'grade': grd,
      'category': cat,
      'tags': extraTags,
    };
  }

  String get gradeLabel {
    if (grade == null) return 'General';
    final cur = curriculum?.toUpperCase() ?? '';
    if (cur == 'KCSE' || cur == '8-4-4' || cur == '8.4.4') return 'Form $grade';
    return 'Grade $grade';
  }

  @override
  String toString() => 'FirebaseFile(name: $name, path: $path)';
}

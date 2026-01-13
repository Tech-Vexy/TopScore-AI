import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/resource_model.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _basePath = 'resources/';

  /// Lists files and folders at the given [path].
  /// [path] should be relative to root, e.g. "resources/Grade 1/".
  Future<List<ResourceModel>> listItems(String path) async {
    try {
      // Ensure path ends with / if not empty, for listAll to work on folder
      String targetPath = path;
      if (targetPath.isNotEmpty && !targetPath.endsWith('/')) {
        targetPath += '/';
      }

      final ListResult result = await _storage.ref(targetPath).listAll();

      List<ResourceModel> items = [];

      // 1. Process Folders (Prefixes)
      for (final prefix in result.prefixes) {
        items.add(
          ResourceModel(
            id: prefix.name, // The folder name
            title: prefix.name,
            type: 'folder',
            subject: '',
            grade: 0,
            curriculum: '',
            downloadUrl: '',
            fileSize: 0,
            premium: false,
            source: 'firebase_storage',
            isFolder: true,
            storagePath: prefix.fullPath,
          ),
        );
      }

      // 2. Process Files
      // Parallelize metadata fetching for speed
      final files = await Future.wait(
        result.items.map((ref) async {
          try {
            FullMetadata? metadata;
            try {
              metadata = await ref.getMetadata();
            } catch (_) {} // metadata might fail via permission

            final url = await ref.getDownloadURL();

            return ResourceModel(
              id: ref.name,
              title: ref.name,
              type: _guessType(ref.name, metadata?.contentType),
              subject: 'General',
              grade: 0,
              curriculum: 'CBC',
              downloadUrl: url,
              fileSize: metadata?.size ?? 0,
              premium: false,
              source: 'firebase_storage',
              isFolder: false,
              createdAt: metadata?.timeCreated,
              storagePath: ref.fullPath,
            );
          } catch (e) {
            debugPrint("Skipping file ${ref.name}: $e");
            return null;
          }
        }),
      );

      items.addAll(files.whereType<ResourceModel>());
      return items;
    } catch (e) {
      debugPrint("Error listing storage items at $path: $e");
      return [];
    }
  }

  /// Lists files in the 'resources' folder and filters by name.
  /// Note: This performs a client-side filter after listing all files.
  /// For large buckets, a Firestore index is recommended.
  Future<List<ResourceModel>> searchFiles(String query) async {
    try {
      // Searching recursively is hard with just Storage API.
      // We will search the root 'resources/' for now or require backend support.
      // But adhering to previous implementation:
      final ListResult result = await _storage.ref(_basePath).listAll();
      final queryLower = query.toLowerCase();

      final matchingRefs = result.items
          .where((ref) => ref.name.toLowerCase().contains(queryLower))
          .toList();

      return await _mapRefsToResources(matchingRefs);
    } catch (e) {
      debugPrint('Error searching Firebase Storage: $e');
      return [];
    }
  }

  /// Gets the most recent files from the 'resources' folder.
  /// Note: This fetches metadata for ALL files to sort by time.
  Future<List<ResourceModel>> getRecentFiles(int limit) async {
    try {
      final ListResult result = await _storage.ref(_basePath).listAll();

      List<FullMetadata?> allMetadata = await Future.wait(
        result.items.map((ref) async {
          try {
            return await ref.getMetadata();
          } catch (_) {
            return null;
          }
        }),
      );

      List<MapEntry<Reference, FullMetadata>> filesWithMeta = [];
      for (int i = 0; i < result.items.length; i++) {
        if (allMetadata[i] != null) {
          filesWithMeta.add(MapEntry(result.items[i], allMetadata[i]!));
        }
      }

      filesWithMeta.sort((a, b) {
        final aTime = a.value.timeCreated ?? DateTime(0);
        final bTime = b.value.timeCreated ?? DateTime(0);
        return bTime.compareTo(aTime);
      });

      final topRefs = filesWithMeta.take(limit).map((e) => e.key).toList();
      return await _buildResourcesFromRefs(topRefs, filesWithMeta);
    } catch (e) {
      debugPrint('Error fetching recent files from Storage: $e');
      return [];
    }
  }

  Future<List<ResourceModel>> _mapRefsToResources(List<Reference> refs) async {
    return await Future.wait(
      refs.map((ref) async {
        try {
          final FullMetadata metadata = await ref.getMetadata();
          final String downloadUrl = await ref.getDownloadURL();

          return ResourceModel(
            id: ref.name,
            title: ref.name,
            type: _guessType(ref.name, metadata.contentType),
            subject: 'General',
            grade: 0,
            curriculum: 'CBC',
            downloadUrl: downloadUrl,
            fileSize: metadata.size ?? 0,
            premium: false,
            source: 'firebase_storage',
            createdAt: metadata.timeCreated,
            isFolder: false,
          );
        } catch (e) {
          debugPrint('Error mapping ref ${ref.name}: $e');
          return null;
        }
      }),
    ).then((list) => list.whereType<ResourceModel>().toList());
  }

  Future<List<ResourceModel>> _buildResourcesFromRefs(
    List<Reference> refs,
    List<MapEntry<Reference, FullMetadata>> knownMeta,
  ) async {
    return await Future.wait(
      refs.map((ref) async {
        try {
          final metaEntry = knownMeta.firstWhere(
            (e) => e.key.fullPath == ref.fullPath,
            orElse: () => MapEntry(ref, FullMetadata({})),
          );
          FullMetadata metadata = metaEntry.value;
          if (metadata.size == null) {
            metadata = await ref.getMetadata();
          }

          final String downloadUrl = await ref.getDownloadURL();

          return ResourceModel(
            id: ref.name,
            title: ref.name,
            type: _guessType(ref.name, metadata.contentType),
            subject: 'General',
            grade: 0,
            curriculum: 'CBC',
            downloadUrl: downloadUrl,
            fileSize: metadata.size ?? 0,
            premium: false,
            source: 'firebase_storage',
            createdAt: metadata.timeCreated,
            isFolder: false,
          );
        } catch (e) {
          return null;
        }
      }),
    ).then((list) => list.whereType<ResourceModel>().toList());
  }

  Future<String?> uploadResource({
    required Uint8List fileBytes,
    required String fileName,
    required String contentType,
    required String title,
    required String subject,
    required int grade,
    required String teacherId,
  }) async {
    try {
      final String storagePath = _basePath + fileName;
      final ref = _storage.ref(storagePath);
      final metadata = SettableMetadata(contentType: contentType);

      await ref.putData(fileBytes, metadata);
      final downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('resources').add({
        'title': title,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'uploadedBy': teacherId,
        'type': _guessType(fileName, contentType),
        'subject': subject,
        'grade': grade,
        'ragStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'fileSize': fileBytes.length,
      });

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading resource: $e');
      return null;
    }
  }

  String _guessType(String name, String? contentType) {
    final lower = name.toLowerCase();
    if (lower.contains('exam') || lower.contains('paper')) return 'past_paper';
    if (lower.contains('note')) return 'notes';
    if (lower.contains('scheme')) return 'schemes';
    if (contentType == 'application/pdf') return 'notes';
    return 'other';
  }
}

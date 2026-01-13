import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/resource_model.dart';
import '../models/download_model.dart';

class DownloadService {
  static const String _storageKey = 'elimu_downloads';

  Future<String> get _localPath async {
    if (kIsWeb) return ''; // No local path on web
    final directory = await getApplicationDocumentsDirectory();
    final elimuDir = Directory('${directory.path}/TopScoreAI');
    if (!await elimuDir.exists()) {
      await elimuDir.create(recursive: true);
    }
    return elimuDir.path;
  }

  Future<String> downloadResource(
    ResourceModel resource,
    Function(double) onProgress,
  ) async {
    if (kIsWeb) throw UnsupportedError("Downloads not supported on Web");
    final path = await _localPath;

    // Process URL to handle Google Drive links
    final downloadUrl = _processUrl(resource.downloadUrl);

    // Try to determine extension from URL, default to pdf if not clear
    String extension = 'pdf';
    final uri = Uri.parse(downloadUrl);
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty) {
      final lastSegment = pathSegments.last;
      if (lastSegment.contains('.')) {
        extension = lastSegment.split('.').last;
      }
    }

    final filename =
        '${resource.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.$extension';
    final file = File('$path/$filename');

    final request = http.Request('GET', Uri.parse(downloadUrl));
    final response = await http.Client().send(request);
    final contentLength = response.contentLength ?? 0;

    List<int> bytes = [];
    double received = 0;

    response.stream.listen(
      (List<int> newBytes) {
        bytes.addAll(newBytes);
        received += newBytes.length;
        if (contentLength > 0) {
          onProgress(received / contentLength);
        }
      },
      onDone: () async {
        await file.writeAsBytes(bytes);
        await _saveDownloadRecord(
          DownloadTaskModel(
            id: resource.id,
            resourceId: resource.id,
            localPath: file.path,
            downloadedAt: DateTime.now().millisecondsSinceEpoch,
            filename: filename,
          ),
        );
      },
      onError: (e) {
        throw e;
      },
      cancelOnError: true,
    );

    return file.path;
  }

  String _processUrl(String url) {
    // Convert Google Drive View URLs to Download URLs
    // Example: https://drive.google.com/file/d/1234567890abcdef/view?usp=sharing
    // Becomes: https://drive.google.com/uc?export=download&id=1234567890abcdef
    if (url.contains('drive.google.com') &&
        (url.contains('/view') || url.contains('/file/d/'))) {
      try {
        final id = url.split('/d/')[1].split('/')[0];
        return 'https://drive.google.com/uc?export=download&id=$id';
      } catch (e) {
        return url;
      }
    }
    return url;
  }

  Future<void> _saveDownloadRecord(DownloadTaskModel task) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> downloads = prefs.getStringList(_storageKey) ?? [];

    // Remove existing if any
    downloads.removeWhere((item) {
      final t = DownloadTaskModel.fromJson(jsonDecode(item));
      return t.id == task.id;
    });

    downloads.add(jsonEncode(task.toJson()));
    await prefs.setStringList(_storageKey, downloads);
  }

  Future<List<DownloadTaskModel>> listDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> downloads = prefs.getStringList(_storageKey) ?? [];
    return downloads
        .map((item) => DownloadTaskModel.fromJson(jsonDecode(item)))
        .toList();
  }

  Future<void> deleteDownload(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> downloads = prefs.getStringList(_storageKey) ?? [];

    DownloadTaskModel? taskToDelete;
    downloads.removeWhere((item) {
      final t = DownloadTaskModel.fromJson(jsonDecode(item));
      if (t.id == id) {
        taskToDelete = t;
        return true;
      }
      return false;
    });

    if (taskToDelete != null) {
      final file = File(taskToDelete!.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await prefs.setStringList(_storageKey, downloads);
  }
}

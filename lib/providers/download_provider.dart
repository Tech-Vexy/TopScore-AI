import 'package:flutter/material.dart';
import '../services/download_service.dart';
import '../models/download_model.dart';
import '../models/resource_model.dart';

class DownloadProvider with ChangeNotifier {
  final DownloadService _downloadService = DownloadService();

  List<DownloadTaskModel> _downloads = [];
  bool _isLoading = false;
  final Map<String, double> _downloadProgress = {};

  List<DownloadTaskModel> get downloads => _downloads;
  bool get isLoading => _isLoading;
  Map<String, double> get downloadProgress => _downloadProgress;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    _downloads = await _downloadService.listDownloads();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> downloadResource(ResourceModel resource) async {
    _downloadProgress[resource.id] = 0.0;
    notifyListeners();

    try {
      await _downloadService.downloadResource(resource, (progress) {
        _downloadProgress[resource.id] = progress;
        notifyListeners();
      });
      
      // Refresh list after download
      _downloads = await _downloadService.listDownloads();
      _downloadProgress.remove(resource.id);
    } catch (e) {
      debugPrint("Download error: $e");
      _downloadProgress.remove(resource.id);
    } finally {
      notifyListeners();
    }
  }

  Future<void> deleteDownload(String id) async {
    await _downloadService.deleteDownload(id);
    _downloads = await _downloadService.listDownloads();
    notifyListeners();
  }

  bool isDownloaded(String resourceId) {
    return _downloads.any((task) => task.resourceId == resourceId);
  }
  
  bool isDownloading(String resourceId) {
    return _downloadProgress.containsKey(resourceId);
  }
  
  double getProgress(String resourceId) {
    return _downloadProgress[resourceId] ?? 0.0;
  }
}

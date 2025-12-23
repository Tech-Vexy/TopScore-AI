import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../services/firestore_service.dart';
import '../services/google_drive_service.dart';
import '../models/resource_model.dart';

class ResourceProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<ResourceModel> _resources = [];
  List<drive.File> _driveSearchResults = [];
  bool _isLoading = false;

  List<ResourceModel> get resources => _resources;
  List<ResourceModel> get recentDriveResources => _recentDriveResources;
  List<drive.File> get driveSearchResults => _driveSearchResults;
  bool get isLoading => _isLoading;

  List<ResourceModel> _recentDriveResources = [];

  Future<void> fetchRecentDriveResources() async {
    try {
      _recentDriveResources = await _firestoreService.getRecentDriveResources(
        5,
      );
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching recent drive resources: $e");
    }
  }

  Future<void> fetchResources(int grade, {String? subject}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _resources = await _firestoreService.getResources(
        grade,
        subject: subject,
      );
    } catch (e) {
      debugPrint("Error fetching resources: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchDriveFiles(String query, GoogleSignIn googleSignIn) async {
    if (query.isEmpty) {
      _driveSearchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final driveService = GoogleDriveService(googleSignIn);
      _driveSearchResults = await driveService.searchFiles(query);
    } catch (e) {
      debugPrint("Error searching drive files: $e");
      _driveSearchResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearDriveSearch() {
    _driveSearchResults = [];
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/resource_model.dart';

class ResourceProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<ResourceModel> _resources = [];
  bool _isLoading = false;

  List<ResourceModel> get resources => _resources;
  bool get isLoading => _isLoading;

  Future<void> fetchResources(int grade, {String? subject}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _resources = await _firestoreService.getResources(grade, subject: subject);
    } catch (e) {
      print("Error fetching resources: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

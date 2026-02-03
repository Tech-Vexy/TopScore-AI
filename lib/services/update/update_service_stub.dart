import 'package:flutter/material.dart';
import 'update_service.dart';

UpdateService getUpdateService() => UpdateServiceStub();

class UpdateServiceStub implements UpdateService {
  @override
  void init(BuildContext context) {
    // No-op for mobile/desktop
  }
}

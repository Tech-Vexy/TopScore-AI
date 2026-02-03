import 'package:flutter/material.dart';

import 'update_service_stub.dart'
    if (dart.library.html) 'update_service_web.dart';

abstract class UpdateService {
  void init(BuildContext context);
  factory UpdateService() => getUpdateService();
}

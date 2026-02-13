class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  void startAutoCheck() {
    // No-op on non-web platforms.
  }

  Future<void> checkForUpdate() async {
    // No-op on non-web platforms.
  }
}

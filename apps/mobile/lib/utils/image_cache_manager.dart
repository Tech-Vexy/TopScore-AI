import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom cache manager for profile images with aggressive caching
/// to prevent 429 (Too Many Requests) errors from Google's servers
class ProfileImageCacheManager extends CacheManager {
  static const key = 'profileImageCache';

  static final ProfileImageCacheManager _instance = ProfileImageCacheManager._();
  factory ProfileImageCacheManager() => _instance;

  ProfileImageCacheManager._()
      : super(
          Config(
            key,
            // Cache images for 30 days (very aggressive for profile pictures)
            stalePeriod: const Duration(days: 30),
            // Keep up to 200 cached images (generous for user avatars)
            maxNrOfCacheObjects: 200,
            // Repository for web and mobile compatibility
            repo: JsonCacheInfoRepository(databaseName: key),
            // File service with custom settings
            fileService: HttpFileService(),
          ),
        );
}

/// Custom cache manager for AI avatar and app images with aggressive caching
class AppImageCacheManager extends CacheManager {
  static const key = 'appImageCache';

  static final AppImageCacheManager _instance = AppImageCacheManager._();
  factory AppImageCacheManager() => _instance;

  AppImageCacheManager._()
      : super(
          Config(
            key,
            // Cache for 90 days (very long for static app assets)
            stalePeriod: const Duration(days: 90),
            // Keep up to 100 cached images
            maxNrOfCacheObjects: 100,
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: HttpFileService(),
          ),
        );
}

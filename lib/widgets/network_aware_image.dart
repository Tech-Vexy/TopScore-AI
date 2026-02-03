import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NetworkAwareImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool isProfilePicture;

  const NetworkAwareImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
    this.isProfilePicture = false,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Validation: Check for null, empty, or invalid URLs
    if (imageUrl == null ||
        imageUrl!.isEmpty ||
        imageUrl!.contains('profile/picture/0')) {
      // Filter out the bad URL
      return _buildErrorWidget(context);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,

      // 2. Optimization: Resize image in memory to save RAM
      memCacheWidth: width != null ? (width! * 2).toInt() : null,

      // 3. Loading State
      placeholder: (context, url) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.grey.withValues(alpha: 0.1),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),

      // 4. Error State (429s, 404s, etc.)
      errorWidget: (context, url, error) => _buildErrorWidget(context),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          color: Colors.grey.withValues(alpha: 0.2),
          child: Icon(
            isProfilePicture ? Icons.person : Icons.broken_image,
            color: Colors.grey,
            size: (width != null) ? width! * 0.5 : 24,
          ),
        );
  }
}

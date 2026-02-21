import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

// Import removed to fix error - we will fallback to launching URL
// import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Extracts YouTube video information from a URL
class YouTubeVideoInfo {
  final String videoId;
  final String url;
  final String? title;

  const YouTubeVideoInfo({
    required this.videoId,
    required this.url,
    this.title,
  });

  String get thumbnailUrl =>
      'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  String get embedUrl => 'https://www.youtube.com/embed/$videoId';
}

/// Helper to parse video IDs
String? _parseVideoId(String url) {
  // Robust regex for all YouTube URL formats (mobile, short, standard)
  final RegExp regex = RegExp(
    r'^.*(?:youtu.be\/|v\/|e\/|u\/\w+\/|embed\/|v=)([^#\&\?]*).*',
    caseSensitive: false,
  );

  final match = regex.firstMatch(url);
  if (match != null && match.group(1)!.length == 11) {
    return match.group(1);
  }
  return null;
}

/// Reusable single YouTube video card for inline display
class SingleYouTubeCard extends StatelessWidget {
  final String videoId;
  final String url;
  final String? title;
  final bool isDark;

  const SingleYouTubeCard({
    super.key,
    required this.videoId,
    required this.url,
    this.title,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final videoInfo =
        YouTubeVideoInfo(videoId: videoId, url: url, title: title);

    return Container(
      width: double.infinity,
      // IMPROVEMENT: Use AspectRatio instead of fixed height for 16:9 consistency
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              CachedNetworkImage(
                imageUrl: videoInfo.thumbnailUrl,
                fit: BoxFit.cover,
                // IMPROVEMENT: Cache resized image to save memory
                memCacheHeight: 400,
                placeholder: (context, url) => Container(
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                  child: const Icon(Icons.error_outline, color: Colors.grey),
                ),
              ),

              // Gradient Overlay (Better text readability)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),

              // Play Button
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.red[600],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 36),
                ),
              ),

              // Video Title
              if (title != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      title!,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // YouTube Badge
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_fill,
                          size: 12, color: Colors.red[400]),
                      const SizedBox(width: 4),
                      Text(
                        'YouTube',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tap Handler
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // Fallback to launching URL since youtube_player_flutter is not available
                    launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Markdown builder that intercepts YouTube links
class YouTubeLinkBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final bool isDark;
  final bool isStreaming;

  YouTubeLinkBuilder(this.context, this.isDark, {this.isStreaming = false});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final href = element.attributes['href'];
    if (href == null) return null;

    final videoId = _parseVideoId(href);

    // If it's a valid YouTube link
    if (videoId != null) {
      final textContent = element.textContent;

      // While streaming, strictly show the text link to avoid UI jumping
      if (isStreaming) {
        return _buildTextLink(href, textContent, preferredStyle);
      }

      // After streaming, show link + video card
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTextLink(href, textContent, preferredStyle),
          SingleYouTubeCard(
            videoId: videoId,
            url: href,
            title: textContent.isNotEmpty ? textContent : null,
            isDark: isDark,
          ),
        ],
      );
    }

    return null;
  }

  Widget _buildTextLink(String href, String textContent, TextStyle? style) {
    return GestureDetector(
      onTap: () =>
          launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication),
      child: Text(
        textContent.isEmpty ? href : textContent,
        style: style?.copyWith(
          color: Colors.blueAccent,
          decoration: TextDecoration.underline,
          decorationColor: Colors.blueAccent.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

/// Helper method for web registration (noop on mobile)
void registerYouTubeViewFactory(String viewId, String videoId) {
  // Implementation in platform-specific files
}

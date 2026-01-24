import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import 'youtube_registry_stub.dart'
    if (dart.library.js_interop) 'youtube_registry_web.dart';

/// Extracts YouTube video information from a URL
class YouTubeVideoInfo {
  final String videoId;
  final String url;
  final String? title;

  YouTubeVideoInfo({
    required this.videoId,
    required this.url,
    this.title,
  });

  String get thumbnailUrl =>
      'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  String get embedUrl => 'https://www.youtube.com/embed/$videoId';
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
      height: 200,
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            CachedNetworkImage(
              imageUrl: videoInfo.thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (context, url, error) => Container(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                child: const Icon(Icons.error, color: Colors.red),
              ),
            ),
            // Dark overlay
            Container(color: Colors.black.withValues(alpha: 0.2)),
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
                child:
                    const Icon(Icons.play_arrow, color: Colors.white, size: 36),
              ),
            ),
            // Video title at bottom
            if (title != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Text(
                    title!,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            // YouTube badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tap handler
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => YouTubePlayerDialog(video: videoInfo),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Markdown builder that intercepts YouTube links and renders inline video cards
class YouTubeLinkBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final bool isDark;
  final bool isStreaming;

  YouTubeLinkBuilder(this.context, this.isDark, {this.isStreaming = false});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final href = element.attributes['href'];
    if (href == null) return null;

    // Regex to extract Video ID
    final RegExp youtubeRegex = RegExp(
      r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );

    final match = youtubeRegex.firstMatch(href);

    // If it's a YouTube link
    if (match != null) {
      final videoId = match.group(1)!;
      final textContent = element.textContent;

      // While streaming, only show the link text (no video card)
      if (isStreaming) {
        return GestureDetector(
          onTap: () => launchUrl(Uri.parse(href)),
          child: Text(
            textContent.isEmpty ? href : textContent,
            style: preferredStyle?.copyWith(
              color: Colors.blueAccent,
              decoration: TextDecoration.underline,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        );
      }

      // After streaming is complete, show full video card
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Keep the clickable text link - wrapped to prevent overflow
          GestureDetector(
            onTap: () => launchUrl(Uri.parse(href)),
            child: Text(
              textContent.isEmpty ? href : textContent,
              style: preferredStyle?.copyWith(
                color: Colors.blueAccent,
                decoration: TextDecoration.underline,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          // 2. Render the Video Card immediately below
          SingleYouTubeCard(
            videoId: videoId,
            url: href,
            title: textContent.isNotEmpty ? textContent : null,
            isDark: isDark,
          ),
        ],
      );
    }

    // Return null to let standard Markdown renderer handle non-YouTube links
    return null;
  }
}

/// Extracts all YouTube video URLs from markdown text
List<YouTubeVideoInfo> extractYouTubeVideos(String text) {
  final List<YouTubeVideoInfo> videos = [];

  // Pattern to match YouTube URLs (various formats)
  // Supports: youtube.com/watch?v=, youtu.be/, youtube.com/embed/
  final RegExp youtubeRegex = RegExp(
    r'(?:https?://)?(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([a-zA-Z0-9_-]{11})(?:[^\s\)]*)?',
    caseSensitive: false,
  );

  // Also extract titles from markdown links like [Title](url)
  final RegExp markdownLinkRegex = RegExp(
    r'\[([^\]]+)\]\(((?:https?://)?(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([a-zA-Z0-9_-]{11})[^\)]*)\)',
    caseSensitive: false,
  );

  // First, extract markdown links with titles
  final Set<String> processedIds = {};

  for (final match in markdownLinkRegex.allMatches(text)) {
    final title = match.group(1);
    final url = match.group(2);
    final videoId = match.group(3);

    // Skip if we couldn't extract required fields
    if (url == null || videoId == null || videoId.length != 11) continue;

    if (!processedIds.contains(videoId)) {
      processedIds.add(videoId);
      videos.add(YouTubeVideoInfo(
        videoId: videoId,
        url: url,
        title: title,
      ));
    }
  }

  // Then, extract any remaining plain URLs
  for (final match in youtubeRegex.allMatches(text)) {
    final videoId = match.group(1);
    final url = match.group(0);

    // Skip if we couldn't extract required fields
    if (url == null || videoId == null || videoId.length != 11) continue;

    if (!processedIds.contains(videoId)) {
      processedIds.add(videoId);
      videos.add(YouTubeVideoInfo(
        videoId: videoId,
        url: url.startsWith('http') ? url : 'https://$url',
      ));
    }
  }

  return videos;
}

/// A widget that displays YouTube video thumbnails with play button
class YouTubeEmbedWidget extends StatelessWidget {
  final List<YouTubeVideoInfo> videos;

  const YouTubeEmbedWidget({super.key, required this.videos});

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Icon(
                Icons.play_circle_filled,
                size: 18,
                color: Colors.red[600],
              ),
              const SizedBox(width: 6),
              Text(
                "Videos",
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: videos.length == 1 ? 220 : 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return _buildVideoCard(
                  context, video, isDark, videos.length == 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideoCard(BuildContext context, YouTubeVideoInfo video,
      bool isDark, bool isSingle) {
    return GestureDetector(
      onTap: () => _openInAppPlayer(context, video),
      child: Container(
        width: isSingle ? MediaQuery.of(context).size.width - 80 : 280,
        margin: EdgeInsets.only(right: isSingle ? 0 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              CachedNetworkImage(
                imageUrl: video.thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: const Icon(Icons.error, color: Colors.red),
                ),
              ),

              // Dark gradient overlay for text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Play button
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
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),

              // Video title (if available)
              if (video.title != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      video.title!,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // YouTube badge
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
                      Icon(
                        Icons.play_circle_fill,
                        size: 12,
                        color: Colors.red[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'YouTube',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openInAppPlayer(BuildContext context, YouTubeVideoInfo video) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => YouTubePlayerDialog(video: video),
    );
  }
}

/// In-app YouTube player dialog - Web compatible using iframe
class YouTubePlayerDialog extends StatefulWidget {
  final YouTubeVideoInfo video;

  const YouTubePlayerDialog({super.key, required this.video});

  @override
  State<YouTubePlayerDialog> createState() => _YouTubePlayerDialogState();
}

class _YouTubePlayerDialogState extends State<YouTubePlayerDialog> {
  late String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId =
        'youtube-player-${widget.video.videoId}-${DateTime.now().millisecondsSinceEpoch}';

    if (kIsWeb) {
      _registerWebView();
    }
  }

  void _registerWebView() {
    registerYouTubeViewFactory(_viewId, widget.video.videoId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isWide ? screenWidth * 0.1 : 16,
        vertical: 24,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isWide ? 800 : screenWidth - 32,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with title and close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_fill,
                    color: Colors.red[600],
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.video.title ?? 'YouTube Video',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // YouTube Player - Web iframe
            Flexible(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: kIsWeb
                      ? HtmlElementView(viewType: _viewId)
                      : _buildFallbackPlayer(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackPlayer(BuildContext context) {
    // Fallback for non-web platforms - open in browser
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => launchUrl(Uri.parse(widget.video.url)),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in YouTube'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../../constants/colors.dart';
import '../../widgets/network_aware_image.dart';
import '../../widgets/gemini_reasoning_view.dart';
import '../../widgets/math_markdown.dart';
import '../../widgets/youtube_embed_widget.dart';
import '../../widgets/quiz_widget.dart';
import '../../widgets/math_stepper_widget.dart';
import '../../widgets/virtual_lab/video_carousel.dart';
import '../../utils/markdown/mermaid_builder.dart';
import '../message_model.dart';
import '../../models/user_model.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;
  final String? playingAudioMessageId;
  final bool isPlayingAudio;
  final Duration audioDuration;
  final Duration audioPosition;
  final String? speakingMessageId;
  final bool isTtsSpeaking;
  final bool isTtsPaused;
  final UserModel? user;

  // Callbacks
  final VoidCallback onPlayVoice;
  final VoidCallback onPauseVoice;
  final VoidCallback onResumeVoice;
  final Function(String) onSpeak;
  final VoidCallback onStopTts;
  final VoidCallback onPauseTts;
  final VoidCallback onResumeTts;
  final VoidCallback onCopy;
  final VoidCallback onToggleBookmark;
  final VoidCallback onShare;
  final VoidCallback onRegenerate;
  final Function(int) onFeedback;
  final VoidCallback onEdit;
  final VoidCallback onDownloadImage;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.playingAudioMessageId,
    this.isPlayingAudio = false,
    this.audioDuration = Duration.zero,
    this.audioPosition = Duration.zero,
    this.speakingMessageId,
    this.isTtsSpeaking = false,
    this.isTtsPaused = false,
    required this.onPlayVoice,
    required this.onPauseVoice,
    required this.onResumeVoice,
    required this.onSpeak,
    required this.onStopTts,
    required this.onPauseTts,
    required this.onResumeTts,
    required this.onCopy,
    required this.onToggleBookmark,
    required this.onShare,
    required this.onRegenerate,
    required this.onFeedback,
    required this.onEdit,
    required this.onDownloadImage,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final isDark = theme.brightness == Brightness.dark;

    if (isUser) {
      return _buildUserBubble(context, theme, isDark);
    } else {
      return _buildAiBubble(context, theme, isDark);
    }
  }

  Widget _buildUserBubble(BuildContext context, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (message.audioUrl != null &&
                          message.text == '🎤 Audio Message')
                        _buildVoicePlayer(context, theme),
                      if (message.imageUrl != null) _buildImage(context),
                      if (!(message.audioUrl != null &&
                          message.text == '🎤 Audio Message'))
                        _buildMarkdown(context, theme, isDark),
                    ],
                  ),
                ),
                _buildUserActions(theme),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildAiBubble(BuildContext context, ThemeData theme, bool isDark) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 850),
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.only(right: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAiAvatar(isStreaming),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thinking skeleton — shows when streaming starts before any content
                        if (isStreaming &&
                            message.text.isEmpty &&
                            (message.reasoning == null ||
                                message.reasoning!.isEmpty))
                          _ThinkingSkeleton(isDark: isDark),
                        if (message.reasoning != null &&
                            message.reasoning!.isNotEmpty)
                          GeminiReasoningView(
                            content: message.reasoning!,
                            isThinking: message.text.isEmpty,
                          ),
                        if (message.text.isNotEmpty)
                          _buildMarkdown(context, theme, isDark),

                        // Specialized Widgets
                        if (message.quizData != null)
                          QuizWidget(
                            quizData: message.quizData!,
                            onComplete: (score) {},
                          ),
                        if (message.mathSteps != null &&
                            message.mathSteps!.isNotEmpty)
                          MathStepperWidget(
                            steps: message.mathSteps!,
                            finalAnswer: message.mathAnswer,
                          ),
                        if (message.videos != null &&
                            message.videos!.isNotEmpty)
                          VideoCarousel(videos: message.videos!),

                        // Sources
                        if (message.sources != null &&
                            message.sources!.isNotEmpty)
                          _buildSources(theme, isDark),

                        if (!message.isUser &&
                            message.isComplete &&
                            !isStreaming)
                          _buildAiActions(theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoicePlayer(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              playingAudioMessageId == message.id && isPlayingAudio
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              color: Colors.white,
              size: 32,
            ),
            onPressed: () {
              if (playingAudioMessageId == message.id && isPlayingAudio) {
                onPauseVoice();
              } else if (playingAudioMessageId == message.id &&
                  !isPlayingAudio) {
                onResumeVoice();
              } else {
                onPlayVoice();
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: playingAudioMessageId == message.id
                        ? (audioDuration.inMilliseconds > 0
                            ? audioPosition.inMilliseconds /
                                audioDuration.inMilliseconds
                            : 0.0)
                        : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  playingAudioMessageId == message.id
                      ? '${_formatDuration(audioPosition)} / ${_formatDuration(audioDuration)}'
                      : 'Voice message',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: NetworkAwareImage(
              imageUrl: message.imageUrl!,
              height: 150,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: InkWell(
              onTap: onDownloadImage,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.download_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserActions(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSmallActionIcon(
            Icons.edit_outlined,
            onEdit,
            theme,
            tooltip: 'Edit',
          ),
          _buildSmallActionIcon(
            Icons.copy_all_outlined,
            onCopy,
            theme,
            tooltip: 'Copy',
          ),
        ],
      ),
    );
  }

  Widget _buildAiAvatar(bool isStreaming) {
    return Container(
      margin: const EdgeInsets.only(right: 16, top: 0),
      child: isStreaming
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 2),
              builder: (context, value, child) {
                return Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      transform: GradientRotation(value * 2 * 3.14159),
                      colors: const [
                        Color(0xFF4285F4),
                        Color(0xFFEA4335),
                        Color(0xFFFBBC05),
                        Color(0xFF34A853),
                        Color(0xFF4285F4),
                      ],
                    ),
                  ),
                  child: const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.auto_awesome,
                        size: 20, color: Color(0xFF4285F4)),
                  ),
                );
              },
            )
          : CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
            ),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.primary,
        child: ClipOval(
          child: NetworkAwareImage(
            imageUrl: user?.photoURL,
            isProfilePicture: true,
            errorWidget: Container(
              color: AppColors.primary,
              child: Center(
                child: Text(
                  (user?.displayName != null && user!.displayName.isNotEmpty)
                      ? user!.displayName[0].toUpperCase()
                      : 'S',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkdown(BuildContext context, ThemeData theme, bool isDark) {
    return MarkdownBody(
      data: _cleanContent(message.text),
      selectable: true,
      softLineBreak: true,
      sizedImageBuilder: (config) {
        if (config.uri.scheme == 'http' || config.uri.scheme == 'https') {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: NetworkAwareImage(
              imageUrl: config.uri.toString(),
              fit: BoxFit.contain,
              width: config.width,
              height: config.height,
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            config.uri.toString(),
            fit: BoxFit.contain,
            width: config.width,
            height: config.height,
          ),
        );
      },
      builders: {
        'latex': LatexElementBuilder(),
        'mermaid': MermaidElementBuilder(),
        'a': YouTubeLinkBuilder(context, isDark, isStreaming: isStreaming),
      },
      extensionSet: md.ExtensionSet(
        [...md.ExtensionSet.gitHubFlavored.blockSyntaxes, MermaidBlockSyntax()],
        [
          md.EmojiSyntax(),
          LatexSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        ],
      ),
      styleSheet: MarkdownStyleSheet(
        p: GoogleFonts.dmSans(
          fontSize: 16,
          height: 1.6,
          color: theme.colorScheme.onSurface,
        ),
        h1: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: theme.primaryColor,
        ),
        h2: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: theme.primaryColor.withValues(alpha: 0.8),
        ),
        h3: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        strong: const TextStyle(fontWeight: FontWeight.bold),
        em: const TextStyle(fontStyle: FontStyle.italic),
        listBullet: GoogleFonts.inter(fontSize: 16, color: theme.primaryColor),
        listIndent: 24.0,
        blockquote: GoogleFonts.inter(
          fontSize: 15,
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: theme.primaryColor, width: 4)),
          color: theme.primaryColor.withValues(alpha: 0.05),
        ),
        code: GoogleFonts.firaCode(
          fontSize: 14,
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
          color: isDark ? Colors.tealAccent : Colors.teal.shade700,
        ),
        codeblockPadding: const EdgeInsets.all(12),
        codeblockDecoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildAiActions(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 400;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (speakingMessageId == message.id && isTtsSpeaking)
                  ..._buildTtsControls(theme)
                else
                  _buildActionIcon(
                    Icons.volume_up_outlined,
                    () => onSpeak(message.text),
                    theme,
                    tooltip: 'Listen',
                  ),
                _buildActionIcon(
                  Icons.copy_all_outlined,
                  onCopy,
                  theme,
                  tooltip: 'Copy',
                ),
                if (!isNarrow) ...[
                  _buildActionIcon(
                    message.isBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    onToggleBookmark,
                    theme,
                    tooltip: 'Bookmark',
                    color: message.isBookmarked ? Colors.amber : null,
                  ),
                  _buildActionIcon(
                    Icons.share_outlined,
                    onShare,
                    theme,
                    tooltip: 'Share',
                  ),
                  _buildActionIcon(
                    Icons.refresh_outlined,
                    onRegenerate,
                    theme,
                    tooltip: 'Regenerate',
                  ),
                ],
              ],
            ),
            Row(
              children: [
                _buildActionIcon(
                  Icons.thumb_up_alt_outlined,
                  () => onFeedback(1),
                  theme,
                  isActive: message.feedback == 1,
                ),
                _buildActionIcon(
                  Icons.thumb_down_alt_outlined,
                  () => onFeedback(-1),
                  theme,
                  isActive: message.feedback == -1,
                ),
                if (isNarrow)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'bookmark':
                          onToggleBookmark();
                          break;
                        case 'share':
                          onShare();
                          break;
                        case 'regenerate':
                          onRegenerate();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'bookmark',
                        child: ListTile(
                          leading: Icon(
                            message.isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: message.isBookmarked ? Colors.amber : null,
                          ),
                          title: const Text('Bookmark'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: ListTile(
                          leading: Icon(Icons.share_outlined),
                          title: Text('Share'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'regenerate',
                        child: ListTile(
                          leading: Icon(Icons.refresh_outlined),
                          title: Text('Regenerate'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildTtsControls(ThemeData theme) {
    return [
      if (isTtsPaused)
        _buildActionIcon(
          Icons.play_arrow,
          onResumeTts,
          theme,
          isActive: true,
          color: AppColors.googleBlue,
        )
      else
        _buildActionIcon(
          Icons.pause,
          onPauseTts,
          theme,
          isActive: true,
          color: AppColors.googleBlue,
        ),
      _buildActionIcon(
        Icons.stop,
        onStopTts,
        theme,
        isActive: true,
        color: Colors.redAccent,
      ),
    ];
  }

  Widget _buildActionIcon(
    IconData icon,
    VoidCallback onTap,
    ThemeData theme, {
    String? tooltip,
    bool isActive = false,
    Color? color,
  }) {
    final finalColor = color ??
        (isActive
            ? AppColors.googleBlue
            : theme.colorScheme.onSurface.withValues(alpha: 0.6));
    return IconButton(
      icon: Icon(icon, size: 18, color: finalColor),
      tooltip: tooltip,
      onPressed: onTap,
      splashRadius: 20,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(8),
    );
  }

  Widget _buildSmallActionIcon(
    IconData icon,
    VoidCallback onTap,
    ThemeData theme, {
    String? tooltip,
  }) {
    return IconButton(
      icon: Icon(icon, size: 16, color: theme.disabledColor),
      onPressed: onTap,
      tooltip: tooltip,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(8),
    );
  }

  Widget _buildSources(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: theme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                "Sources",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: message.sources!
                .map((s) => _buildSourceChip(s, theme, isDark))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceChip(SourceMetadata source, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        source.title,
        style: TextStyle(
          fontSize: 11,
          color: theme.primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _cleanContent(String content) {
    return cleanContent(content);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

// --- Thinking Skeleton Widget ---

class _ThinkingSkeleton extends StatefulWidget {
  final bool isDark;

  const _ThinkingSkeleton({required this.isDark});

  @override
  State<_ThinkingSkeleton> createState() => _ThinkingSkeletonState();
}

class _ThinkingSkeletonState extends State<_ThinkingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final shimmerColor = widget.isDark
            ? Colors.white.withValues(alpha: _animation.value * 0.15)
            : Colors.grey.withValues(alpha: _animation.value * 0.2);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLine(shimmerColor, 0.85),
              const SizedBox(height: 8),
              _buildLine(shimmerColor, 0.65),
              const SizedBox(height: 8),
              _buildLine(shimmerColor, 0.45),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLine(Color color, double widthFraction) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      width: 300 * widthFraction,
    );
  }
}

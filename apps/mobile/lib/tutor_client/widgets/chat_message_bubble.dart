import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../constants/colors.dart';
import '../../services/clipboard_service.dart';
import '../../services/haptics_service.dart';
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

class ChatMessageBubble extends StatefulWidget {
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
  final Function(ChatMessage) onReply;
  final VoidCallback onLongPress;

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
    required this.onReply,
    required this.onLongPress,
    this.user,
  });

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble> {
  bool isPlaybackError = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: Key('msg_${widget.message.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Swipe left to reply
          widget.onReply(widget.message);
          return false; // Don't actually dismiss
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.reply, color: Colors.grey),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.reply, color: Colors.grey),
      ),
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return widget.message.isUser
              ? _buildUserBubble(context, theme, isDark, settings)
              : _buildAiBubble(context, theme, isDark, settings);
        },
      ),
    );
  }

  Widget _buildUserBubble(BuildContext context, ThemeData theme, bool isDark,
      SettingsProvider settings) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF37393E), const Color(0xFF2B2D31)]
                      : [const Color(0xFF0B57D0), const Color(0xFF4285F4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(4), // Distinct tip
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.message.replyToText != null)
                    _buildReplyPreview(theme, true),
                  if (widget.message.audioUrl != null &&
                      widget.message.text == '🎤 Audio Message')
                    _buildVoicePlayer(context, theme),
                  if (widget.message.imageUrl != null) _buildImage(context),
                  if (!(widget.message.audioUrl != null &&
                      widget.message.text == '🎤 Audio Message'))
                    _buildMarkdown(context, theme, isDark, settings),
                ],
              ),
            ),
            _buildUserActions(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildAiBubble(BuildContext context, ThemeData theme, bool isDark,
      SettingsProvider settings) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          HapticsService.instance.mediumImpact();
          ClipboardService.instance
              .copyWithFeedback(context, widget.message.text);
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Small AI label
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF1E1F22) : Colors.white,
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.15),
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 22,
                          height: 22,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TopScore AI',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              // Thinking skeleton
              if (widget.isStreaming &&
                  widget.message.text.isEmpty &&
                  (widget.message.reasoning == null ||
                      widget.message.reasoning!.isEmpty))
                _ThinkingSkeleton(isDark: isDark),
              if (widget.message.reasoning != null &&
                  widget.message.reasoning!.isNotEmpty)
                GeminiReasoningView(
                  content: widget.message.reasoning!,
                  isThinking: widget.message.text.isEmpty,
                ),
              if (widget.message.replyToText != null)
                _buildReplyPreview(theme, false),
              if (widget.message.text.isNotEmpty)
                _buildMarkdown(context, theme, isDark, settings),

              // Specialized Widgets
              if (widget.message.quizData != null)
                QuizWidget(
                  quizData: widget.message.quizData!,
                  onComplete: (score) {},
                ),
              if (widget.message.mathSteps != null &&
                  widget.message.mathSteps!.isNotEmpty)
                MathStepperWidget(
                  steps: widget.message.mathSteps!,
                  finalAnswer: widget.message.mathAnswer,
                ),
              if (widget.message.videos != null &&
                  widget.message.videos!.isNotEmpty)
                VideoCarousel(videos: widget.message.videos!),

              // Sources
              if (widget.message.sources != null &&
                  widget.message.sources!.isNotEmpty)
                _buildSources(theme, isDark),

              if (!widget.message.isUser &&
                  widget.message.isComplete &&
                  !widget.isStreaming)
                _buildAiActions(theme),
            ],
          ),
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
              widget.playingAudioMessageId == widget.message.id &&
                      widget.isPlayingAudio
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              color: Colors.white,
              size: 32,
            ),
            onPressed: () {
              if (widget.playingAudioMessageId == widget.message.id &&
                  widget.isPlayingAudio) {
                widget.onPauseVoice();
              } else if (widget.playingAudioMessageId == widget.message.id &&
                  !widget.isPlayingAudio) {
                widget.onResumeVoice();
              } else {
                widget.onPlayVoice();
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
                    widthFactor:
                        widget.playingAudioMessageId == widget.message.id
                            ? (widget.audioDuration.inMilliseconds > 0
                                ? widget.audioPosition.inMilliseconds /
                                    widget.audioDuration.inMilliseconds
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
                  widget.playingAudioMessageId == widget.message.id
                      ? '${_formatDuration(widget.audioPosition)} / ${_formatDuration(widget.audioDuration)}'
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
              imageUrl: widget.message.imageUrl!,
              height: 150,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: InkWell(
              onTap: widget.onDownloadImage,
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
            widget.onEdit,
            theme,
            tooltip: 'Edit',
          ),
          _buildSmallActionIcon(
            Icons.copy_all_outlined,
            widget.onCopy,
            theme,
            tooltip: 'Copy',
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdown(BuildContext context, ThemeData theme, bool isDark,
      SettingsProvider settings) {
    return MarkdownBody(
      data: _cleanContent(widget.message.text),
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
        'a': YouTubeLinkBuilder(context, isDark,
            isStreaming: widget.isStreaming),
        'pre': _CodeBlockBuilder(isDark: isDark),
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
          fontSize: settings.fontSize + 2,
          height: settings.lineHeight,
          color: widget.message.isUser
              ? Colors.white
              : theme.colorScheme.onSurface,
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
              : Colors.black.withValues(alpha: 0.08),
          color: isDark ? Colors.tealAccent : Colors.teal.shade800,
        ),
        codeblockPadding: EdgeInsets.zero,
        codeblockDecoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildAiActions(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          // Left action group
          if (widget.speakingMessageId == widget.message.id &&
              widget.isTtsSpeaking)
            ..._buildTtsControls(theme)
          else
            _buildActionIcon(
              Icons.volume_up_outlined,
              () => widget.onSpeak(widget.message.text),
              theme,
              tooltip: 'Read aloud',
            ),
          _buildActionIcon(Icons.content_copy_rounded, widget.onCopy, theme,
              tooltip: 'Copy'),
          _buildActionIcon(Icons.refresh_rounded, widget.onRegenerate, theme,
              tooltip: 'Regenerate'),
          _buildActionIcon(
            widget.message.isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_outline_rounded,
            widget.onToggleBookmark,
            theme,
            tooltip: 'Bookmark',
            color: widget.message.isBookmarked ? Colors.amber : null,
          ),
          _buildActionIcon(Icons.share_outlined, widget.onShare, theme,
              tooltip: 'Share'),

          // Separator
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.2),
          ),

          // Feedback
          _buildActionIcon(
            Icons.thumb_up_outlined,
            () => widget.onFeedback(1),
            theme,
            isActive: widget.message.feedback == 1,
            color: widget.message.feedback == 1 ? AppColors.accentTeal : null,
          ),
          _buildActionIcon(
            Icons.thumb_down_outlined,
            () => widget.onFeedback(-1),
            theme,
            isActive: widget.message.feedback == -1,
            color: widget.message.feedback == -1 ? Colors.redAccent : null,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTtsControls(ThemeData theme) {
    return [
      if (widget.isTtsPaused)
        _buildActionIcon(
          Icons.play_arrow,
          widget.onResumeTts,
          theme,
          isActive: true,
          color: AppColors.googleBlue,
        )
      else
        _buildActionIcon(
          Icons.pause,
          widget.onPauseTts,
          theme,
          isActive: true,
          color: AppColors.googleBlue,
        ),
      _buildActionIcon(
        Icons.stop,
        widget.onStopTts,
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
    return Semantics(
      label: tooltip ?? 'Action button',
      button: true,
      child: IconButton(
        icon: Icon(icon, size: 18, color: finalColor),
        tooltip: tooltip,
        onPressed: onTap,
        splashRadius: 20,
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildSmallActionIcon(
    IconData icon,
    VoidCallback onTap,
    ThemeData theme, {
    String? tooltip,
  }) {
    return Semantics(
      label: tooltip ?? 'Small action button',
      button: true,
      child: IconButton(
        icon: Icon(icon, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
        onPressed: onTap,
        tooltip: tooltip,
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(8),
      ),
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
            children: widget.message.sources!
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

  Widget _buildReplyPreview(ThemeData theme, bool isUser) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isUser
            ? Colors.white.withValues(alpha: 0.1)
            : theme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isUser ? Colors.white70 : theme.primaryColor,
            width: 3,
          ),
        ),
      ),
      child: Text(
        widget.message.replyToText!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: isUser
              ? Colors.white.withValues(alpha: 0.8)
              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

// --- Code Block with Copy Button ---

class _CodeBlockBuilder extends MarkdownElementBuilder {
  final bool isDark;

  _CodeBlockBuilder({required this.isDark});

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // Extract code text from the element tree
    String codeText = element.textContent;

    // Try to detect language from the class attribute of the <code> child
    String? language;
    if (element.children != null && element.children!.isNotEmpty) {
      final firstChild = element.children!.first;
      if (firstChild is md.Element && firstChild.attributes['class'] != null) {
        final className = firstChild.attributes['class']!;
        if (className.startsWith('language-')) {
          language = className.substring('language-'.length);
        }
      }
    }

    return _CodeBlockWidget(
      code: codeText,
      language: language,
      isDark: isDark,
    );
  }
}

class _CodeBlockWidget extends StatefulWidget {
  final String code;
  final String? language;
  final bool isDark;

  const _CodeBlockWidget({
    required this.code,
    this.language,
    required this.isDark,
  });

  @override
  State<_CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<_CodeBlockWidget> {
  bool _copied = false;

  void _copyCode() {
    ClipboardService.instance.copyWithFeedback(context, widget.code);
    HapticFeedback.mediumImpact();
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color:
            widget.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar with language label + copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                if (widget.language != null)
                  Text(
                    widget.language!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color:
                          widget.isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: _copyCode,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _copied
                        ? Row(
                            key: const ValueKey('copied'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: AppColors.accentTeal,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Copied',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.accentTeal,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            key: const ValueKey('copy'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.content_copy_rounded,
                                size: 14,
                                color: widget.isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Copy',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          // Code content
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              widget.code,
              style: GoogleFonts.firaCode(
                fontSize: 14,
                color: widget.isDark ? Colors.tealAccent : Colors.teal.shade700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
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

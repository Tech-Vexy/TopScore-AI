import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import '../../services/subscription_service.dart';
import '../../constants/colors.dart';
import '../../screens/subscription/subscription_screen.dart';
import '../message_model.dart';

class ChatInputArea extends StatefulWidget {
  final TextEditingController textController;
  final FocusNode messageFocusNode;
  final String? pendingFileName;
  final String? pendingPreviewData;
  final String? pendingFileUrl;
  final bool isUploading;
  final bool isTyping;
  final bool isGenerating;
  final bool isRecording;
  final List<Map<String, String>> suggestions;
  final List<String> placeholderMessages;
  final VoidCallback onSendMessage;
  final Function({String? text}) onSendMessageWithText;
  final VoidCallback onShowAttachmentMenu;
  final VoidCallback onPaste;
  final VoidCallback onStopGeneration;
  final VoidCallback onStopListeningAndSend;
  final VoidCallback onStartLiveVoiceMode;
  final VoidCallback onClearPendingAttachment;
  final VoidCallback onShuffleQuestions;
  final VoidCallback onDictation;
  final ChatMessage? replyingToMessage;
  final VoidCallback? onCancelReply;

  const ChatInputArea({
    super.key,
    required this.textController,
    required this.messageFocusNode,
    this.pendingFileName,
    this.pendingPreviewData,
    this.pendingFileUrl,
    required this.isUploading,
    required this.isTyping,
    required this.isGenerating,
    required this.isRecording,
    required this.suggestions,
    required this.placeholderMessages,
    required this.onSendMessage,
    required this.onSendMessageWithText,
    required this.onShowAttachmentMenu,
    required this.onPaste,
    required this.onStopGeneration,
    required this.onStopListeningAndSend,
    required this.onStartLiveVoiceMode,
    required this.onClearPendingAttachment,
    required this.onShuffleQuestions,
    required this.onDictation,
    this.replyingToMessage,
    this.onCancelReply,
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  @override
  void initState() {
    super.initState();
    widget.textController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant ChatInputArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textController != widget.textController) {
      oldWidget.textController.removeListener(_onTextChanged);
      widget.textController.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  String get _effectiveHint {
    if (widget.isUploading) return 'Uploading...';

    final base = widget.placeholderMessages.isNotEmpty
        ? widget.placeholderMessages[0]
        : 'Ask anything...';

    final isDesktop =
        kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return isDesktop ? '$base (Enter to send)' : base;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CallbackShortcuts(
      bindings: kIsWeb
          ? <ShortcutActivator, VoidCallback>{}
          : {
              const SingleActivator(LogicalKeyboardKey.keyV, control: true):
                  widget.onPaste,
              const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
                  widget.onPaste,
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.pendingFileName != null)
                  _buildAttachmentPreview(theme, isDark),

                if (widget.replyingToMessage != null)
                  _buildReplyPreview(theme, isDark),

                // Main input pill
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(28),
                    border: widget.isRecording
                        ? Border.all(color: Colors.redAccent, width: 2)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor
                            .withValues(alpha: isDark ? 0.08 : 0.04),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Attachment button (left inside pill)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: IconButton(
                          icon: const Icon(Icons.add_rounded, size: 24),
                          color: isDark ? Colors.white : Colors.black,
                          tooltip: 'Add attachment',
                          onPressed: () async {
                            final isPremium = await SubscriptionService()
                                .isSessionPremiumOrTrial();
                            if (isPremium) {
                              widget.onShowAttachmentMenu();
                            } else {
                              if (!context.mounted) return;
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  title: const Text('Pro Feature'),
                                  content: const Text(
                                    'File & image uploads require Pro. Upgrade to unlock.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const SubscriptionScreen(),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.googleBlue,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Upgrade'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      ),

                      // Text field
                      Expanded(
                        child: TextField(
                          controller: widget.textController,
                          focusNode: widget.messageFocusNode,
                          style: GoogleFonts.inter(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.send,
                          minLines: 1,
                          maxLines: 6,
                          decoration: InputDecoration(
                            hintText: widget.isRecording
                                ? "Listening…"
                                : _effectiveHint,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            hintStyle: TextStyle(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.45),
                              fontSize: 16,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => widget.onSendMessageWithText(
                            text: widget.textController.text,
                          ),
                        ),
                      ),

                      // Right-side buttons inside pill
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Mic button (Dictation)
                            IconButton(
                              icon: Icon(
                                widget.isRecording
                                    ? Icons.mic_off_rounded
                                    : Icons.mic_rounded,
                                size: 22,
                              ),
                              color: widget.isRecording
                                  ? Colors.redAccent
                                  : isDark
                                      ? Colors.white
                                      : Colors.black,
                              tooltip: widget.isRecording
                                  ? 'Stop & send'
                                  : 'Voice input',
                              onPressed: widget.isRecording
                                  ? widget.onStopListeningAndSend
                                  : widget.onDictation,
                              visualDensity: VisualDensity.compact,
                            ),

                            // Send or Live Voice Mode button
                            _buildPillActionButton(theme, isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(ThemeData theme, bool isDark) {
    final isImage = widget.pendingFileName != null &&
        (widget.pendingFileName!.toLowerCase().endsWith('.png') ||
            widget.pendingFileName!.toLowerCase().endsWith('.jpg') ||
            widget.pendingFileName!.toLowerCase().endsWith('.jpeg') ||
            widget.pendingFileName!.toLowerCase().endsWith('.gif') ||
            widget.pendingFileName!.toLowerCase().endsWith('.webp'));

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 54,
              height: 54,
              child: isImage && widget.pendingPreviewData != null
                  ? Image.memory(
                      base64Decode(
                        widget.pendingPreviewData!.contains(',')
                            ? widget.pendingPreviewData!.split(',').last
                            : widget.pendingPreviewData!,
                      ),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: theme.primaryColor.withValues(alpha: 0.12),
                      child: const Icon(Icons.description_rounded),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.pendingFileName ?? 'Attachment',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.isUploading ? 'Uploading…' : 'Attached',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isUploading ? null : Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed:
                widget.isUploading ? null : widget.onClearPendingAttachment,
          ),
        ],
      ),
    );
  }

  Widget _buildPillActionButton(ThemeData theme, bool isDark) {
    final hasContent = widget.textController.text.trim().isNotEmpty ||
        widget.pendingFileUrl != null;

    final iconColor = isDark ? Colors.white : Colors.black;

    if (widget.isGenerating) {
      return IconButton(
        icon: Icon(Icons.stop_rounded, size: 22, color: iconColor),
        onPressed: widget.onStopGeneration,
        tooltip: 'Stop generation',
        visualDensity: VisualDensity.compact,
      );
    }

    if (hasContent) {
      return IconButton(
        icon: Icon(
          Icons.arrow_upward_rounded,
          size: 22,
          color: iconColor,
        ),
        tooltip: 'Send message',
        onPressed: widget.onSendMessage,
        visualDensity: VisualDensity.compact,
      );
    }

    // fallback — Live Voice Mode
    return IconButton(
      icon: Icon(
        Icons.graphic_eq_rounded,
        size: 22,
        color: iconColor,
      ),
      tooltip: 'Live Voice Mode',
      onPressed: widget.onStartLiveVoiceMode,
      visualDensity: VisualDensity.compact,
    );
  }

  // Remove the old circle button builders since we are using compact icons inside the pill

  Widget _buildReplyPreview(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: theme.primaryColor,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.replyingToMessage!.isUser
                      ? 'Replying to you'
                      : 'Replying to TopScore AI',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.replyingToMessage!.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: widget.onCancelReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

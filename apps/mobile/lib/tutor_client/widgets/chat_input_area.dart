import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io' show Platform;

class ChatInputArea extends StatefulWidget {
  final TextEditingController textController;
  final FocusNode messageFocusNode;
  final String? pendingFileName;
  final String? pendingPreviewData;
  final String? pendingFileUrl;
  final bool isUploading;
  final bool isTyping;
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

  const ChatInputArea({
    super.key,
    required this.textController,
    required this.messageFocusNode,
    this.pendingFileName,
    this.pendingPreviewData,
    this.pendingFileUrl,
    required this.isUploading,
    required this.isTyping,
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
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  late Timer _placeholderTimer;
  int _currentPlaceholderIndex = 0;
  int _currentSuggestionIndex = 0;

  @override
  void initState() {
    super.initState();
    _startPlaceholderRotation();
  }

  @override
  void dispose() {
    _placeholderTimer.cancel();
    super.dispose();
  }

  void _startPlaceholderRotation() {
    _placeholderTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          // Rotate placeholder text
          if (widget.textController.text.isEmpty) {
            _currentPlaceholderIndex = (_currentPlaceholderIndex + 1) %
                widget.placeholderMessages.length;
          }

          // Rotate suggestions
          if (widget.suggestions.isNotEmpty &&
              !widget.isTyping &&
              widget.textController.text.isEmpty) {
            _currentSuggestionIndex =
                (_currentSuggestionIndex + 1) % widget.suggestions.length;
          }
        });
      }
    });
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 850,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.pendingFileName != null)
                  _buildAttachmentPreview(theme, isDark),
                if (widget.suggestions.isNotEmpty &&
                    widget.textController.text.isEmpty &&
                    !widget.isTyping)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (
                              Widget child,
                              Animation<double> animation,
                            ) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.0, 0.2),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: Center(
                              key: ValueKey<int>(_currentSuggestionIndex),
                              child: _buildChip(
                                widget.suggestions[_currentSuggestionIndex %
                                    widget.suggestions.length],
                                theme,
                                isDark,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.refresh_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            onPressed: () {
                              widget.onShuffleQuestions();
                              // Reset index when shuffling to start fresh
                              setState(() {
                                _currentSuggestionIndex = 0;
                              });
                            },
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            tooltip: 'Shuffle suggestions',
                          ),
                        ),
                      ],
                    ),
                  ),
                AnimatedBuilder(
                  animation: widget.messageFocusNode,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.4 : 0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(
                          12, 10, 12, 10), // Increased internal padding
                      child: child,
                    );
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.add_rounded,
                          color: theme.primaryColor,
                          size: 26,
                        ),
                        onPressed: widget.onShowAttachmentMenu,
                        tooltip: 'Add attachment',
                        padding: const EdgeInsets.all(10),
                        visualDensity: VisualDensity.compact,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: TextField(
                            focusNode: widget.messageFocusNode,
                            controller: widget.textController,
                            contextMenuBuilder: (context, editableTextState) {
                              final List<ContextMenuButtonItem> buttonItems =
                                  editableTextState.contextMenuButtonItems;
                              buttonItems.insert(
                                0,
                                ContextMenuButtonItem(
                                  label: 'Paste',
                                  onPressed: () {
                                    editableTextState.hideToolbar();
                                    widget.onPaste();
                                  },
                                ),
                              );
                              return AdaptiveTextSelectionToolbar.buttonItems(
                                anchors: editableTextState.contextMenuAnchors,
                                buttonItems: buttonItems,
                              );
                            },
                            style: GoogleFonts.outfit(
                              color: theme.colorScheme.onSurface,
                              fontSize: 16,
                              height: 1.45,
                            ),
                            maxLines: 6,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: (kIsWeb ||
                                    Platform.isWindows ||
                                    Platform.isMacOS ||
                                    Platform.isLinux)
                                ? TextInputAction.send
                                : TextInputAction.newline,
                            decoration: InputDecoration(
                              hintText: widget.isUploading
                                  ? 'Uploading...'
                                  : (() {
                                      final baseHint =
                                          widget.placeholderMessages[
                                              _currentPlaceholderIndex %
                                                  widget.placeholderMessages
                                                      .length];
                                      final isDesktopOrWeb = kIsWeb ||
                                          Platform.isWindows ||
                                          Platform.isMacOS ||
                                          Platform.isLinux;
                                      return isDesktopOrWeb
                                          ? '$baseHint\n(Enter to send, Shift+Enter for new line)'
                                          : baseHint;
                                    })(),
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                                fontWeight: FontWeight.w300,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (kIsWeb ||
                                    Platform.isWindows ||
                                    Platform.isMacOS ||
                                    Platform.isLinux)
                                ? (value) =>
                                    widget.onSendMessageWithText(text: value)
                                : null,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!widget.isRecording &&
                                widget.textController.text.isEmpty &&
                                !widget.isTyping)
                              IconButton(
                                onPressed: widget.onStartLiveVoiceMode,
                                icon: const Icon(Icons.graphic_eq_rounded),
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                                tooltip: 'Live Voice Mode',
                                visualDensity: VisualDensity.compact,
                              ),
                            const SizedBox(width: 4),
                            _buildSendButton(theme, isDark),
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

  Widget _buildChip(
    Map<String, String> suggestion,
    ThemeData theme,
    bool isDark,
  ) {
    final emoji = suggestion['emoji'] ?? '✨';
    final text = suggestion['title'] ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onSendMessageWithText(text: text);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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
            widget.pendingPreviewData != null);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isImage
                      ? Colors.transparent
                      : theme.primaryColor.withValues(alpha: 0.1),
                  image: isImage && widget.pendingPreviewData != null
                      ? DecorationImage(
                          image: MemoryImage(
                              base64Decode(widget.pendingPreviewData!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: !isImage
                    ? Icon(
                        Icons.insert_drive_file,
                        color: theme.primaryColor,
                        size: 24,
                      )
                    : null,
              ),
              if (widget.isUploading)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.pendingFileName ?? 'File',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.isUploading ? 'Uploading...' : 'Ready',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: widget.isUploading
                        ? theme.primaryColor
                        : Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            onPressed:
                widget.isUploading ? null : widget.onClearPendingAttachment,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(ThemeData theme, bool isDark) {
    final hasText = widget.textController.text.trim().isNotEmpty;
    final hasAttachment = widget.pendingFileUrl != null;
    final canSend = hasText || hasAttachment;

    if (widget.isTyping) {
      return _buildCircleButton(
        icon: Icons.stop_rounded,
        color: isDark ? Colors.white : Colors.black,
        iconColor: isDark ? Colors.black : Colors.white,
        onPressed: widget.onStopGeneration,
        tooltip: 'Stop',
      );
    }

    if (widget.isRecording) {
      return _buildCircleButton(
        icon: Icons.graphic_eq,
        color: Colors.redAccent,
        iconColor: Colors.white,
        onPressed: widget.onStopListeningAndSend,
        tooltip: 'Stop Recording',
      );
    }

    if (canSend) {
      return _buildCircleButton(
        icon: Icons.arrow_upward_rounded,
        color: theme.primaryColor,
        iconColor: Colors.white,
        onPressed: widget.onSendMessage,
        tooltip: 'Send',
      );
    }

    return _buildCircleButton(
      icon: Icons.mic_none_rounded,
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.05),
      iconColor: theme.colorScheme.onSurface,
      onPressed: widget.onDictation,
      tooltip: 'Dictate',
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(icon, size: 22, color: iconColor),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
}

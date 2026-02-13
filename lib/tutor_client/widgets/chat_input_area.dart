import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class ChatInputArea extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode messageFocusNode;
  final String? pendingFileName;
  final String? pendingPreviewData;
  final String? pendingFileUrl;
  final bool isUploading;
  final bool isTyping;
  final bool isRecording;
  final List<Map<String, String>>
  suggestions; // Updated to match backend structure
  final int currentPlaceholderIndex;
  final List<String> placeholderMessages;
  final VoidCallback onSendMessage;
  final Function({String? text}) onSendMessageWithText;
  final VoidCallback onShowAttachmentMenu;
  final VoidCallback onPaste; // Renamed from onHandleImagePaste
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
    required this.suggestions, // Updated
    required this.currentPlaceholderIndex,
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CallbackShortcuts(
      bindings: kIsWeb
          ? <ShortcutActivator, VoidCallback>{}
          : {
              const SingleActivator(LogicalKeyboardKey.keyV, control: true):
                  onPaste,
              const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
                  onPaste,
            },
      child: Container(
        // Removed fixed padding to allow the shadow to render without clipping if constrained
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 750,
            ), // Grok/ChatGPT width
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Attachment Preview (Floats above the pill)
                if (pendingFileName != null)
                  _buildAttachmentPreview(theme, isDark),

                // Suggestions Chips (Float ABOVE the pill)
                if (suggestions.isNotEmpty &&
                    textController.text.isEmpty &&
                    !isTyping)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 12,
                    ), // Space between chips and input
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ...suggestions.map((suggestion) {
                          return _buildChip(suggestion, theme, isDark);
                        }),
                        // Shuffle button
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
                            onPressed: onShuffleQuestions,
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            tooltip: 'Shuffle suggestions',
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main Input Pill
                AnimatedBuilder(
                  animation: messageFocusNode,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(
                                0xFF121212,
                              ) // Slightly darker for more premium feel
                            : Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        // Dual shadow for enhanced floating effect
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.38 : 0.12,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.20 : 0.06,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
                      child: child,
                    );
                  },
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.end, // Align to bottom for multiline
                    children: [
                      // Attachment Button
                      IconButton(
                        icon: Icon(
                          Icons.add_circle_outline_rounded,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          size: 26,
                        ),
                        onPressed: onShowAttachmentMenu,
                        tooltip: 'Add attachment',
                        padding: const EdgeInsets.all(10),
                        visualDensity: VisualDensity.compact,
                      ),

                      // Text Input
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: TextField(
                            focusNode: messageFocusNode,
                            controller: textController,
                            // ... context menu logic ...
                            contextMenuBuilder: (context, editableTextState) {
                              final List<ContextMenuButtonItem> buttonItems =
                                  editableTextState.contextMenuButtonItems;
                              buttonItems.insert(
                                0,
                                ContextMenuButtonItem(
                                  label:
                                      'Paste', // Changed label to generic 'Paste'
                                  onPressed: () {
                                    editableTextState.hideToolbar();
                                    onPaste();
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
                              height:
                                  1.45, // Better line height for vertical centering
                            ),
                            maxLines: 6, // Allow expansion
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: isUploading
                                  ? 'Uploading...'
                                  : placeholderMessages[currentPlaceholderIndex %
                                        placeholderMessages.length],
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                                fontWeight: FontWeight.w300, // Lighter
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical:
                                    12, // Increased for better breathing room
                              ),
                            ),
                            onSubmitted: (value) =>
                                onSendMessageWithText(text: value),
                          ),
                        ),
                      ),

                      // Right Side Actions (Voice/Send)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isRecording &&
                                textController.text.isEmpty &&
                                !isTyping)
                              IconButton(
                                onPressed: onStartLiveVoiceMode,
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

                // legacy suggestions removed (now handled above)
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Chips UI Helper
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
          onSendMessageWithText(text: text);
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

  // Attachment Preview (unchanged logic)
  Widget _buildAttachmentPreview(ThemeData theme, bool isDark) {
    // ... (Keep existing implementation logic but ensure context fits)
    // For brevity, replicating logic here or assuming context.
    // Re-implementing for safety as view context showed it.
    final isImage =
        pendingFileName != null &&
        (pendingFileName!.toLowerCase().endsWith('.png') ||
            pendingFileName!.toLowerCase().endsWith('.jpg') ||
            pendingFileName!.toLowerCase().endsWith('.jpeg') ||
            pendingPreviewData != null);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10), // Adjusted margin
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
        // ... (Keep existing Row children as seen in view_file) ...
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 48, // Slightly smaller
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isImage
                      ? Colors.transparent
                      : theme.primaryColor.withValues(alpha: 0.1),
                  image: isImage && pendingPreviewData != null
                      ? DecorationImage(
                          image: MemoryImage(base64Decode(pendingPreviewData!)),
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
              if (isUploading)
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
                  pendingFileName ?? 'File',
                  style: GoogleFonts.inter(
                    fontSize: 13, // Smaller text
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isUploading ? 'Uploading...' : 'Ready',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isUploading
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
            onPressed: isUploading ? null : onClearPendingAttachment,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(ThemeData theme, bool isDark) {
    final hasText = textController.text.trim().isNotEmpty;
    final hasAttachment = pendingFileUrl != null;
    final canSend = hasText || hasAttachment;

    // Loading/Stop Button
    if (isTyping) {
      return _buildCircleButton(
        icon: Icons.stop_rounded,
        color: isDark ? Colors.white : Colors.black,
        iconColor: isDark ? Colors.black : Colors.white,
        onPressed: onStopGeneration,
        tooltip: 'Stop',
      );
    }

    // Recording Button
    if (isRecording) {
      return _buildCircleButton(
        icon: Icons.graphic_eq,
        color: Colors.redAccent,
        iconColor: Colors.white,
        onPressed: onStopListeningAndSend,
        tooltip: 'Stop Recording',
      );
    }

    // Active Send Button
    if (canSend) {
      return _buildCircleButton(
        icon: Icons.arrow_upward_rounded,
        color: theme.primaryColor,
        iconColor: Colors.white,
        onPressed: onSendMessage,
        tooltip: 'Send',
      );
    }

    // Default Mic Button (when empty)
    return _buildCircleButton(
      icon: Icons.mic_none_rounded,
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.05),
      iconColor: theme.colorScheme.onSurface,
      onPressed: onDictation,
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

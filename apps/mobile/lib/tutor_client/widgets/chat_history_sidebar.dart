import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ChatHistorySidebar extends StatelessWidget {
  final bool isDark;
  final List<dynamic> threads;
  final String historySearchQuery;
  final TextEditingController historySearchController;
  final bool isLoadingHistory;
  final String? currentThreadId;
  final VoidCallback onCloseSidebar;
  final Function({bool closeDrawer}) onStartNewChat;
  final Function(String) onLoadThread;
  final Function(String, String) onRenameThread;
  final Function(String) onDeleteThread;
  final VoidCallback onFinishLesson;
  final Function(String) onSearchChanged;

  const ChatHistorySidebar({
    super.key,
    required this.isDark,
    required this.threads,
    required this.historySearchQuery,
    required this.historySearchController,
    required this.isLoadingHistory,
    this.currentThreadId,
    required this.onCloseSidebar,
    required this.onStartNewChat,
    required this.onLoadThread,
    required this.onRenameThread,
    required this.onDeleteThread,
    required this.onFinishLesson,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isSwahili = authProvider.userModel?.preferredLanguage == 'sw';

    final filteredThreads = threads.where((thread) {
      final title = (thread['title'] as String? ?? '').toLowerCase();
      final query = historySearchQuery.toLowerCase();
      return title.contains(query);
    }).toList();

    return Container(
      color: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with logo (matches collapsed rail)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 16,
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          // Prominent New Chat button (Grok-style pill)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: InkWell(
              onTap: () => onStartNewChat(closeDrawer: false),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isSwahili ? "Mazungumzo Mapya" : "New Chat",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: InkWell(
              onTap: () {
                onCloseSidebar();
                onFinishLesson();
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isSwahili ? "Maliza Somo" : "Finish Lesson",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: historySearchController,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  suffixIcon: historySearchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () => onSearchChanged(''),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                onChanged: onSearchChanged,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Replaced SingleChildScrollView + Column with direct conditional rendering
          // The ListView.builder in _buildGroupedThreadList now handles scrolling and expansion
          isLoadingHistory
              ? const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : filteredThreads.isEmpty
                  ? Expanded(
                      child: Center(
                        child: Text(
                          threads.isEmpty ? "No chats yet" : "No matches found",
                          style: TextStyle(color: theme.disabledColor),
                        ),
                      ),
                    )
                  : _buildGroupedThreadList(
                      context,
                      filteredThreads,
                      theme,
                    ),
          // Thin divider above footer
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark ? Colors.grey[850] : Colors.grey[300],
          ),
          // Collapse toggle only (Settings & Upgrade removed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: onCloseSidebar,
                  child: Text(
                    '«',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedThreadList(
    BuildContext context,
    List<dynamic> threads,
    ThemeData theme,
  ) {
    // 1. Group threads by date
    final Map<String, List<dynamic>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final thread in threads) {
      final group = _getDateGroup(thread, today);
      groups.putIfAbsent(group, () => []).add(thread);
    }

    // 2. Ordered group keys
    const groupOrder = ['Today', 'Yesterday', 'Last 7 Days', 'Older'];

    // 3. Flatten into a list of items (Headers + Threads) for virtualization
    final List<dynamic> flattenedItems = [];
    for (final groupName in groupOrder) {
      if (groups.containsKey(groupName)) {
        flattenedItems.add(groupName); // String -> Header
        flattenedItems.addAll(groups[groupName]!); // Map -> Thread
      }
    }

    // 4. Virtualized List
    return Expanded(
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: flattenedItems.length,
        itemBuilder: (context, index) {
          final item = flattenedItems[index];
          if (item is String) {
            return _buildSectionHeader(item);
          } else {
            return _buildThreadItem(context, item, theme);
          }
        },
      ),
    );
  }

  String _getDateGroup(dynamic thread, DateTime today) {
    try {
      final updatedAt = thread['updated_at'] ?? thread['created_at'];
      if (updatedAt == null) return 'Older';

      DateTime threadDate;
      if (updatedAt is int) {
        threadDate = DateTime.fromMillisecondsSinceEpoch(updatedAt);
      } else if (updatedAt is String) {
        threadDate = DateTime.tryParse(updatedAt) ?? today;
      } else {
        return 'Older';
      }

      final threadDay = DateTime(
        threadDate.year,
        threadDate.month,
        threadDate.day,
      );
      final difference = today.difference(threadDay).inDays;

      if (difference == 0) return 'Today';
      if (difference == 1) return 'Yesterday';
      if (difference <= 7) return 'Last 7 Days';
      return 'Older';
    } catch (_) {
      return 'Older';
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[500],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildThreadItem(
    BuildContext context,
    dynamic thread,
    ThemeData theme,
  ) {
    final isSelected = thread['thread_id'] == currentThreadId;
    return InkWell(
      onTap: () => onLoadThread(thread['thread_id']),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: isSelected
              ? Border(left: BorderSide(color: theme.primaryColor, width: 3))
              : null,
          color: isSelected
              ? theme.primaryColor.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                thread['title'] ?? 'New Chat',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : Colors.grey[400],
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              splashRadius: 20,
              padding: EdgeInsets.zero,
              tooltip: 'Options',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: theme.colorScheme.onSurface,
                      ),
                      const SizedBox(width: 12),
                      const Text('Rename'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Delete',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'rename') {
                  onRenameThread(thread['thread_id'], thread['title'] ?? '');
                } else if (value == 'delete') {
                  onDeleteThread(thread['thread_id']);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

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
  final VoidCallback onDeleteAllThreads;
  final VoidCallback onFinishLesson; // keep but can hide if not core
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
    required this.onDeleteAllThreads,
    required this.onFinishLesson,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isSwahili = authProvider.userModel?.preferredLanguage == 'sw';

    final filteredThreads = threads.where((thread) {
      final title = (thread['title'] as String? ?? 'New Chat').toLowerCase();
      final query = historySearchQuery.toLowerCase();
      return title.contains(query);
    }).toList();

    return Container(
      width: 320, // typical sidebar width — Grok-ish
      color: isDark ? const Color(0xFF0A0A0B) : const Color(0xFFFAFAFC),
      child: Column(
        children: [
          // Header area — minimal, logo optional or just New Chat
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                  onPressed: onCloseSidebar,
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // New Chat button — Grok places this prominently at top
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: FilledButton.icon(
              onPressed: () => onStartNewChat(closeDrawer: false),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                isSwahili ? "Mazungumzo Mapya" : "New Chat",
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.12),
                foregroundColor: theme.colorScheme.primary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),

          // Search field — clean, borderless, Grok-like
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: historySearchController,
              onChanged: onSearchChanged,
              style:
                  TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search conversations…',
                hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                suffixIcon: historySearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => onSearchChanged(''),
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                isDense: true,
              ),
            ),
          ),

          Expanded(
            child: isLoadingHistory
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : filteredThreads.isEmpty
                    ? Center(
                        child: Text(
                          threads.isEmpty
                              ? "No conversations yet"
                              : "No matches",
                          style: TextStyle(
                              color: theme.disabledColor, fontSize: 14),
                        ),
                      )
                    : _buildThreadList(context, filteredThreads, theme),
          ),

          if (threads.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete All Chats'),
                      content: const Text(
                          'Are you sure you want to delete all your conversations? This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onDeleteAllThreads();
                          },
                          style:
                              TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Delete All'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_sweep_outlined,
                    size: 20, color: Colors.redAccent),
                label: const Text(
                  "Delete All",
                  style: TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ),

          // Footer — very minimal (Grok often just has collapse arrow or nothing)
          Divider(
              height: 1, color: isDark ? Colors.grey[900] : Colors.grey[300]),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '« Collapse',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadList(
      BuildContext context, List<dynamic> threads, ThemeData theme) {
    final Map<String, List<dynamic>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final thread in threads) {
      final group = _getDateGroup(thread, today);
      groups.putIfAbsent(group, () => []).add(thread);
    }

    final orderedGroups = ['Today', 'Yesterday', 'Previous 7 days', 'Older']
        .where((g) => groups.containsKey(g))
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount:
          orderedGroups.length + threads.length, // rough — better to flatten
      itemBuilder: (context, index) {
        // Simple version — you can keep your flattenedItems logic
        // Here simplified for clarity

        int headerCount = 0;
        for (final group in orderedGroups) {
          if (index == headerCount) {
            return _buildSectionHeader(group);
          }
          headerCount++;
          final groupItems = groups[group]!;
          if (index < headerCount + groupItems.length) {
            final thread = groupItems[index - headerCount];
            return _buildThreadTile(thread, theme);
          }
          headerCount += groupItems.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.grey[600] : Colors.grey[700],
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildThreadTile(dynamic thread, ThemeData theme) {
    final isSelected = thread['thread_id'] == currentThreadId;
    final title = thread['title'] as String? ?? 'New Chat';

    return Material(
      color: isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.09)
          : Colors.transparent,
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selected: isSelected,
        selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.09),
        leading: isSelected
            ? Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : null,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14.5,
            color: isSelected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withValues(alpha: 0.85),
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_horiz_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          position: PopupMenuPosition.over,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'rename',
              child: const ListTile(
                leading: Icon(Icons.edit_outlined, size: 20),
                title: Text('Rename'),
                dense: true,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: const ListTile(
                leading: Icon(Icons.delete_outline,
                    size: 20, color: Colors.redAccent),
                title:
                    Text('Delete', style: TextStyle(color: Colors.redAccent)),
                dense: true,
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'rename') {
              onRenameThread(thread['thread_id'], title);
            } else if (value == 'delete') {
              onDeleteThread(thread['thread_id']);
            }
          },
        ),
        onTap: () => onLoadThread(thread['thread_id']),
      ),
    );
  }

  String _getDateGroup(dynamic thread, DateTime today) {
    // your existing logic — unchanged
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

      final diff = today
          .difference(
              DateTime(threadDate.year, threadDate.month, threadDate.day))
          .inDays;

      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      if (diff <= 7) return 'Previous 7 days';
      return 'Older';
    } catch (_) {
      return 'Older';
    }
  }
}

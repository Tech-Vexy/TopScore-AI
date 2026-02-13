import 'package:flutter/material.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class CollapsedSidebar extends StatelessWidget {
  final bool isDark;
  final Function(String) onModeChange;
  final VoidCallback onStartNewChat;

  const CollapsedSidebar({
    super.key,
    required this.isDark,
    required this.onModeChange,
    required this.onStartNewChat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 60,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              radius: 18,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Search
          _buildNavIcon(
            context: context,
            icon: Icons.search_rounded,
            tooltip: 'Search',
            theme: theme,
            onTap: () => onModeChange('expanded'),
          ),
          const SizedBox(height: 8),
          // New Chat
          _buildNavIcon(
            context: context,
            icon: Icons.edit_outlined,
            tooltip: 'New Chat',
            theme: theme,
            onTap: onStartNewChat,
          ),
          const SizedBox(height: 8),
          // History
          _buildNavIcon(
            context: context,
            icon: Icons.history_rounded,
            tooltip: 'History',
            theme: theme,
            onTap: () => onModeChange('expanded'),
          ),

          const Spacer(),

          // Bottom area: avatar + >> toggle
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                // User avatar
                _buildUserAvatar(context, theme),
                const SizedBox(height: 20),
                // >> Expand toggle
                GestureDetector(
                  onTap: () => onModeChange('expanded'),
                  child: Icon(
                    Icons.keyboard_double_arrow_right_rounded,
                    size: 18,
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

  Widget _buildNavIcon({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required ThemeData theme,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: IconButton(
        icon: Icon(
          icon,
          color: highlighted
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          size: 22,
        ),
        onPressed: onTap,
        tooltip: tooltip,
        style: highlighted
            ? IconButton.styleFrom(
                backgroundColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.08,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context, ThemeData theme) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    return CircleAvatar(
      radius: 14,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      backgroundImage: (user?.photoURL != null && user!.photoURL!.isNotEmpty)
          ? NetworkImage(user.photoURL!)
          : null,
      child: (user?.photoURL == null || user!.photoURL!.isEmpty)
          ? Icon(
              Icons.person,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            )
          : null,
    );
  }
}

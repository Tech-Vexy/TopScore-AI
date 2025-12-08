import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../providers/auth_provider.dart';
import '../tutor_client/chat_screen.dart';
import 'student/resources_screen.dart';
import 'tools/tools_screen.dart';
import 'support/support_screen.dart';
import 'subscription/subscription_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;
    final displayName = user?.displayName?.split(' ')[0] ?? 'Student';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.school, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'TopScore AI',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Provider.of<AuthProvider>(context, listen: false).signOut(),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, $displayName! 👋',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.surface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ready to learn something new today?',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: AppColors.surface.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ChatScreen()),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                    label: const Text('Ask AI Tutor'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            Text(
              'Explore Features',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            
            // Features Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _buildFeatureCard(
                  context,
                  title: 'AI Tutor',
                  description: 'Get instant help & explanations',
                  icon: Icons.psychology,
                  color: AppColors.googleBlue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChatScreen()),
                  ),
                ),
                _buildFeatureCard(
                  context,
                  title: 'Resources',
                  description: 'Study materials & past papers',
                  icon: Icons.library_books,
                  color: AppColors.googleGreen,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ResourcesScreen()),
                  ),
                ),
                _buildFeatureCard(
                  context,
                  title: 'Smart Tools',
                  description: 'Scanner, Calculator & more',
                  icon: Icons.build,
                  color: AppColors.googleYellow,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ToolsScreen()),
                  ),
                ),
                _buildFeatureCard(
                  context,
                  title: 'Support',
                  description: 'We are here to help you',
                  icon: Icons.support_agent,
                  color: AppColors.googleRed,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SupportScreen()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            
            // Subscription Banner
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.googleYellow.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.googleYellow.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star, color: AppColors.googleYellow),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upgrade to Premium',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Unlock unlimited access to all features',
                            style: GoogleFonts.outfit(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/resource_provider.dart';
import '../../models/resource_model.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../constants/colors.dart';

import '../../models/user_model.dart';
import '../subscription/subscription_screen.dart';
import 'ai_tutor_screen.dart';
import '../tools/pdf_viewer_screen.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  // Navigation State
  String _currentView = 'levels'; // levels, grades, types, list
  String _headerTitle = 'Learning Resources';

  // Selection State
  String? _selectedLevelTitle;
  List<int> _currentGrades = [];
  int? _selectedGrade;
  String? _selectedType;
  final TextEditingController _searchController = TextEditingController();

  // Data Definitions
  final Map<String, List<int>> _educationLevels = {
    'High School (KCSE)': [10, 11, 12, 13], // Form 1-4
    'Junior Secondary (CBC)': [7, 8, 9],
    'Primary (CBC)': [1, 2, 3, 4, 5, 6],
    'Pre-Primary': [-1, 0], // PP1, PP2
  };

  final Map<String, String> _resourceTypes = {
    'Schemes of Work': 'scheme',
    'Exams & Past Papers': 'exam',
    'Class Notes': 'notes',
    'Lesson Plans': 'plan',
    'Curriculum Designs': 'design',
    'Assignments': 'assignment',
  };

  @override
  void initState() {
    super.initState();
  }

  void _navigateToGrades(String level, List<int> grades) {
    setState(() {
      _currentView = 'grades';
      _selectedLevelTitle = level;
      _currentGrades = grades;
      _headerTitle = level;
    });
  }

  void _navigateToTypes(int grade) {
    setState(() {
      _currentView = 'types';
      _selectedGrade = grade;
      _headerTitle = _getGradeLabel(grade);
    });
  }

  void _navigateToResources(String typeLabel, String typeKey) {
    setState(() {
      _currentView = 'list';
      _selectedType = typeKey;
      _headerTitle = "$typeLabel - ${_getGradeLabel(_selectedGrade!)}";
    });
    _fetchResources();
  }

  void _navigateBack() {
    setState(() {
      if (_currentView == 'list') {
        _currentView = 'types';
        _headerTitle = _getGradeLabel(_selectedGrade!);
      } else if (_currentView == 'types') {
        _currentView = 'grades';
        _headerTitle = _selectedLevelTitle!;
      } else if (_currentView == 'grades') {
        _currentView = 'levels';
        _headerTitle = 'Learning Resources';
      } else if (_currentView == 'search') {
        _currentView = 'levels';
        _headerTitle = 'Learning Resources';
        _searchController.clear();
        Provider.of<ResourceProvider>(
          context,
          listen: false,
        ).clearDriveSearch();
      }
    });
  }

  String _getGradeLabel(int grade) {
    if (grade == -1) return 'PP1';
    if (grade == 0) return 'PP2';
    if (grade >= 1 && grade <= 9) return 'Grade $grade';
    if (grade >= 10) return 'Form ${grade - 9}';
    return 'Grade $grade';
  }

  void _fetchResources() {
    if (_selectedGrade != null) {
      // Note: We are fetching all resources for the grade and filtering by type in the UI
      // for now, as the provider might not support type filtering yet.
      Provider.of<ResourceProvider>(
        context,
        listen: false,
      ).fetchResources(_selectedGrade!);
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    // Use external application mode for Google Drive links to ensure they open correctly
    // in the Drive app or browser, rather than an in-app webview.
    final mode = urlString.contains('drive.google.com')
        ? LaunchMode.externalApplication
        : LaunchMode.platformDefault;

    if (!await launchUrl(url, mode: mode)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $urlString')));
      }
    }
  }

  void _showSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Content'),
        content: const Text(
          'This resource is only available to premium subscribers. '
          'Please upgrade your plan to access unlimited resources.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              );
            },
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      endDrawer: _buildDrawer(user, theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AiTutorScreen()),
          );
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Ask AI'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                // Custom Header (replaces AppBar)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentView != 'levels')
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: theme.colorScheme.onSurface,
                          ),
                          onPressed: _navigateBack,
                        )
                      else
                        const SizedBox(width: 48), // Spacer for alignment

                      Text(
                        _headerTitle,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),

                      Builder(
                        builder: (context) => IconButton(
                          icon: Icon(
                            Icons.menu,
                            color: theme.colorScheme.onSurface,
                          ),
                          onPressed: () => Scaffold.of(context).openEndDrawer(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Search Google Drive & Resources...',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _navigateBack();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 20,
                        ),
                      ),
                      onSubmitted: (query) {
                        if (query.isNotEmpty) {
                          setState(() {
                            _currentView = 'search';
                            _headerTitle = 'Results for "$query"';
                          });
                          final authProvider = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          Provider.of<ResourceProvider>(
                            context,
                            listen: false,
                          ).searchDriveFiles(query, authProvider.googleSignIn);
                        }
                      },
                    ),
                  ),
                ),

                // Main Content
                Expanded(child: _buildCurrentView(theme)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(UserModel? user, ThemeData theme) {
    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            accountName: Text(
              user?.displayName ?? 'Guest',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: theme.cardColor,
              child: Text(
                user?.displayName?.substring(0, 1).toUpperCase() ?? 'G',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home_rounded, color: theme.iconTheme.color),
            title: Text(
              'Home',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _currentView = 'levels';
                _headerTitle = 'Learning Resources';
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_rounded, color: AppColors.primary),
            title: const Text(
              'Premium Subscription',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.person_rounded, color: theme.iconTheme.color),
            title: Text(
              'Profile',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            onTap: () {
              Navigator.pop(context);
              // Navigate to profile
            },
          ),
          ListTile(
            leading: Icon(Icons.settings_rounded, color: theme.iconTheme.color),
            title: Text(
              'Settings',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            onTap: () {
              Navigator.pop(context);
              // Navigate to settings
            },
          ),
          Divider(color: theme.dividerColor),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
            onTap: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView(ThemeData theme) {
    switch (_currentView) {
      case 'levels':
        return _buildLevelsView(theme);
      case 'grades':
        return _buildGradesView(theme);
      case 'types':
        return _buildTypesView(theme);
      case 'list':
        return _buildResourceListView(theme);
      case 'search':
        return _buildSearchResultsView(theme);
      default:
        return _buildLevelsView(theme);
    }
  }

  Widget _buildLevelsView(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          "Categories",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: _educationLevels.entries.map((entry) {
              final isLast = entry.key == _educationLevels.keys.last;
              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    title: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    onTap: () => _navigateToGrades(entry.key, entry.value),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: theme.dividerColor,
                    ),
                ],
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 32),

        Text(
          "Featured Resources",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        // Placeholder for featured resources
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildFeaturedItem("KCSE 2023 Biology Paper 1", theme),
              Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: theme.dividerColor,
              ),
              _buildFeaturedItem("KCSE 2022 Mathematics Paper 2", theme),
              Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: theme.dividerColor,
              ),
              _buildFeaturedItem("KCSE 2021 English Paper 3", theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedItem(String title, ThemeData theme) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      onTap: () {
        // Handle featured item tap
      },
    );
  }

  Color _getGoogleColor(int index) {
    final colors = [
      AppColors.googleBlue,
      AppColors.googleRed,
      AppColors.googleYellow,
      AppColors.googleGreen,
    ];
    return colors[index % colors.length];
  }

  Widget _buildGradesView(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: _currentGrades.asMap().entries.map((entry) {
        final index = entry.key;
        final grade = entry.value;
        return _buildCategoryCard(
          title: _getGradeLabel(grade),
          icon: Icons.class_,
          color: _getGoogleColor(index),
          onTap: () => _navigateToTypes(grade),
          theme: theme,
        );
      }).toList(),
    );
  }

  Widget _buildTypesView(ThemeData theme) {
    int index = 1;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: _resourceTypes.entries.map((entry) {
        return _buildListItem(
          number: index++,
          title:
              "${_getGradeLabel(_selectedGrade!).toUpperCase()} ${entry.key.toUpperCase()}",
          onTap: () => _navigateToResources(entry.key, entry.value),
          theme: theme,
        );
      }).toList(),
    );
  }

  Widget _buildResourceListView(ThemeData theme) {
    return Consumer<ResourceProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter resources by type locally for now
        // In a real app, this should be done on the backend
        final resources = provider.resources.where((r) {
          // Simple mapping or loose matching for demo purposes
          // If the resource type in DB is 'notes', and selected is 'notes', match.
          // If DB has 'past_paper' and selected is 'exam', match.
          if (_selectedType == 'exam' &&
              (r.type == 'past_paper' || r.type == 'mock')) {
            return true;
          }
          if (_selectedType == 'notes' &&
              (r.type == 'notes' || r.type == 'topical')) {
            return true;
          }
          // Fallback: show all if type doesn't match strictly, or implement strict types in DB
          return r.type.contains(_selectedType!) || _selectedType == 'scheme';
        }).toList();

        if (resources.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open,
                  size: 64,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'No resources found for this category',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: resources.length,
          itemBuilder: (context, index) {
            final resource = resources[index];
            return _buildResourceCard(resource, theme);
          },
        );
      },
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItem({
    required int number,
    required String title,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Text(
                "$number.",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.googleBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourceCard(ResourceModel resource, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          final user = Provider.of<AuthProvider>(
            context,
            listen: false,
          ).userModel;
          if (user != null && user.isSubscribed) {
            if (resource.downloadUrl.toLowerCase().contains('.pdf')) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PdfViewerScreen(
                    url: resource.downloadUrl,
                    title: resource.title,
                  ),
                ),
              );
            } else {
              _launchUrl(resource.downloadUrl);
            }
          } else {
            _showSubscriptionDialog();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.googleBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getResourceIcon(resource.type),
                  color: AppColors.googleBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildTag(resource.subject, AppColors.googleBlue),
                        const SizedBox(width: 8),
                        _buildTag(
                          _getGradeLabel(resource.grade),
                          AppColors.googleRed,
                        ),
                        if (resource.year != null) ...[
                          const SizedBox(width: 8),
                          _buildTag(
                            '${resource.year}',
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  final isSubscribed = auth.userModel?.isSubscribed ?? false;
                  return Icon(
                    isSubscribed ? Icons.download_rounded : Icons.lock_rounded,
                    color: isSubscribed
                        ? AppColors.googleGreen
                        : AppColors.googleRed,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultsView(ThemeData theme) {
    return Consumer<ResourceProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.driveSearchResults.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'No results found',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              "Google Drive Results",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...provider.driveSearchResults.map((file) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: theme.cardColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.googleBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.googleDrive,
                      color: AppColors.googleBlue,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    file.name ?? 'Untitled',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    file.mimeType ?? 'Unknown type',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () {
                    if (file.webViewLink != null) {
                      _launchUrl(file.webViewLink!);
                    }
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  IconData _getResourceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'past_paper':
      case 'exam':
        return Icons.description;
      case 'notes':
        return Icons.menu_book;
      case 'video':
        return Icons.play_circle;
      default:
        return Icons.insert_drive_file;
    }
  }
}

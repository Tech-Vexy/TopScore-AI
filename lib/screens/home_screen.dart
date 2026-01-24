import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:go_router/go_router.dart';

import '../constants/colors.dart';
import '../providers/auth_provider.dart';
import '../providers/resource_provider.dart';
import '../providers/navigation_provider.dart';
import '../tutor_client/chat_screen.dart';
import 'student/resources_screen.dart';
import 'tools/tools_screen.dart';
import 'profile_screen.dart' as profile_page;
import 'tools/science_lab_screen.dart';
import 'student/career_compass_screen.dart';
import 'discussion/group_allocation_screen.dart';

import '../widgets/interest_update_sheet.dart';
import '../widgets/shimmer_loading.dart'; // Performance: shimmer placeholders
import 'pdf_viewer_screen.dart';
import '../models/firebase_file.dart';
import '../services/storage_service.dart';
import '../models/resource_model.dart';

// --- Feature Model (Local Definition for Safety) ---
class FeatureItem {
  final String title;
  final IconData icon;
  final Color color;
  final Color endColor;
  final int routeIndex;

  FeatureItem(
    this.title,
    this.icon,
    this.color,
    this.endColor,
    this.routeIndex,
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final List<Widget> _screens = [
    const HomeTab(),
    const ResourcesScreen(),
    const ChatScreen(),
    const ToolsScreen(),
    const profile_page.ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final resourceProvider = Provider.of<ResourceProvider>(
        context,
        listen: false,
      );
      resourceProvider.fetchRecentDriveResources();
      resourceProvider.loadRecentlyOpened();
      _checkMissingInterests();
    });
  }

  void _checkMissingInterests() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;

    if (user != null &&
        user.role == 'student' &&
        (user.interests == null || user.interests!.isEmpty)) {
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        builder: (context) => InterestUpdateSheet(userId: user.uid),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<NavigationProvider>(
      builder: (context, navProvider, _) {
        return Scaffold(
          body: IndexedStack(
            index: navProvider.currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: navProvider.currentIndex,
              onDestinationSelected: (index) {
                navProvider.setIndex(index);
              },
              backgroundColor: Colors.transparent,
              indicatorColor: AppColors.accentTeal.withValues(alpha: 0.2),
              elevation: 0,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: FaIcon(FontAwesomeIcons.house, size: 20),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: FaIcon(FontAwesomeIcons.folderOpen, size: 20),
                  label: 'Library',
                ),
                NavigationDestination(
                  icon: FaIcon(FontAwesomeIcons.brain, size: 20),
                  label: 'AI Tutor',
                ),
                NavigationDestination(
                  icon: FaIcon(FontAwesomeIcons.briefcase, size: 20),
                  label: 'Tools',
                ),
                NavigationDestination(
                  icon: FaIcon(FontAwesomeIcons.user, size: 20),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static List<FirebaseFile>? _cachedAllFiles;
  List<FirebaseFile> _allFiles = [];
  List<FirebaseFile> _filteredFiles = [];
  bool _isLoadingFiles = true;
  bool _isSearching = false;

  final List<FeatureItem> _features = [
    FeatureItem(
      "Career Compass",
      FontAwesomeIcons.compass,
      const Color(0xFF6C63FF),
      const Color(0xFF8B80FF),
      -2,
    ),
    FeatureItem(
      "Study Groups",
      FontAwesomeIcons.peopleGroup,
      const Color(0xFFFF6B6B),
      const Color(0xFFFF8E8E),
      -1,
    ),
    FeatureItem(
      "Science Lab",
      FontAwesomeIcons.flask,
      const Color(0xFF4ECDC4),
      const Color(0xFF6EE7E0),
      -3,
    ),
    // Removed "My Library" as requested
  ];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    if (_cachedAllFiles != null) {
      if (mounted) {
        setState(() {
          _allFiles = _cachedAllFiles!;
          _filteredFiles = List.from(_allFiles);
          _isLoadingFiles = false;
        });
      }
      return;
    }

    try {
      final files = await StorageService.getAllFilesFromFirestore();
      _cachedAllFiles = files;
      if (mounted) {
        setState(() {
          _allFiles = files;
          _filteredFiles = files;
          _isLoadingFiles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFiles = false);
      }
    }
  }

  Future<void> _filterFiles(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredFiles = List.from(_allFiles);
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await StorageService.searchFiles(query);
      if (mounted) {
        setState(() {
          _filteredFiles = results;
        });
      }
    } catch (e) {
      final lowerQuery = query.toLowerCase();
      if (mounted) {
        setState(() {
          _filteredFiles = _allFiles.where((file) {
            return file.name.toLowerCase().contains(lowerQuery) ||
                file.path.toLowerCase().contains(lowerQuery);
          }).toList();
        });
      }
    }
  }

  Future<void> _openFile(BuildContext context, FirebaseFile file) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String url = '';
      if (file.ref != null) {
        url = await file.ref!.getDownloadURL();
      }

      if (!context.mounted) return;

      // Track file opening
      final resourceProvider = Provider.of<ResourceProvider>(
        context,
        listen: false,
      );
      final resourceModel = ResourceModel(
        id: file.path,
        title: file.name,
        type: 'file',
        subject: '',
        grade: 0,
        curriculum: '',
        downloadUrl: url,
        fileSize: 0,
        premium: false,
        storagePath: file.path,
      );
      await resourceProvider.trackFileOpen(resourceModel);

      if (!context.mounted) return;

      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            url: url,
            title: file.name,
            storagePath: file.path,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error opening file: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;
    final displayName = user?.displayName.split(' ')[0] ?? 'Student';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _ReusableSearchBar(
              onSearchChanged: _filterFiles,
              hintText: 'Search files, notes, topics...',
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, displayName, 12),
                    const SizedBox(height: 20),

                    _buildHeroCard(context),
                    const SizedBox(height: 20),

                    if (_isSearching)
                      _buildSearchResultsSection(context)
                    else ...[
                      Text(
                        "Explore",
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildActionGrid(context),
                      const SizedBox(height: 20),
                    ],

                    _buildRecentlyOpenedSection(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ...existing code...

  Widget _buildSearchResultsSection(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoadingFiles) {
      // Performance: Use shimmer loading instead of spinner for perceived speed
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: ResourceListShimmer(itemCount: 5),
      );
    }

    if (_filteredFiles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off, size: 60, color: theme.disabledColor),
              const SizedBox(height: 16),
              Text(
                "No files found",
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Search Results (${_filteredFiles.length})",
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredFiles.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final file = _filteredFiles[index];
            return _buildFileCard(context, file);
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFileCard(BuildContext context, FirebaseFile file) {
    final theme = Theme.of(context);
    final pathParts = file.path.split('/');
    final folderContext = pathParts.length > 1
        ? pathParts[pathParts.length - 2]
        : "General";

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _getFileIcon(file.name),
        title: Text(
          file.name,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          folderContext,
          style: GoogleFonts.nunito(color: theme.hintColor, fontSize: 12),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: theme.iconTheme.color?.withValues(alpha: 0.5),
        ),
        onTap: () => _openFile(context, file),
      ),
    );
  }

  Widget _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    late Color color;
    late IconData icon;

    switch (ext) {
      case 'pdf':
        color = const Color(0xFFFF6B6B);
        icon = Icons.picture_as_pdf;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        color = const Color(0xFF4ECDC4);
        icon = Icons.image;
        break;
      case 'doc':
      case 'docx':
        color = const Color(0xFF4A90E2);
        icon = Icons.description;
        break;
      default:
        color = Colors.grey;
        icon = Icons.insert_drive_file;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  Widget _buildHeader(BuildContext context, String name, int streak) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Jambo, $name! 👋",
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Let's discover your path today.",
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        // ... streak widget ...
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF8B80FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "CAREER INSIGHT",
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Discover Your\nFuture Path",
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CareerCompassScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF6C63FF),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    "Start Guide",
                    style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Icon(FontAwesomeIcons.compass, size: 70, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: _features.length,
      itemBuilder: (context, index) {
        final feature = _features[index];
        return _buildGridItem(
          feature.title,
          feature.icon,
          feature.color,
          feature.endColor,
          () {
            if (feature.routeIndex == -1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GroupAllocationScreen(),
                ),
              );
            } else if (feature.routeIndex == 1) {
              context.go('/library');
            } else if (feature.routeIndex == -3) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScienceLabScreen()),
              );
            } else if (feature.routeIndex == -2) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CareerCompassScreen()),
              );
            }
            // Add other routes
          },
        );
      },
    );
  }

  Widget _buildGridItem(
    String title,
    IconData icon,
    Color startColor,
    Color endColor,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: startColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: FaIcon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyOpenedSection(BuildContext context) {
    final theme = Theme.of(context);
    // Performance: Use Selector to only rebuild when recentlyOpened changes
    return Selector<ResourceProvider, List<ResourceModel>>(
      selector: (_, provider) => provider.recentlyOpened,
      builder: (context, recentlyOpened, _) {
        if (recentlyOpened.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Recently Opened",
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: recentlyOpened.length,
                itemBuilder: (context, index) {
                  return _buildRecentFileCard(recentlyOpened[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentFileCard(ResourceModel resource) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PdfViewerScreen(
                  url: resource.downloadUrl.isNotEmpty
                      ? resource.downloadUrl
                      : null,
                  storagePath: resource.downloadUrl.isEmpty
                      ? resource.storagePath
                      : null,
                  title: resource.title,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.description,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue Reading',
                      style: GoogleFonts.nunito(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      resource.title,
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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
      ),
    );
  }
}

class _ReusableSearchBar extends StatefulWidget {
  final Function(String) onSearchChanged;
  final String hintText;
  final EdgeInsets? margin;

  const _ReusableSearchBar({
    required this.onSearchChanged,
    this.hintText = '',
    this.margin,
  });

  @override
  State<_ReusableSearchBar> createState() => _ReusableSearchBarState();
}

class _ReusableSearchBarState extends State<_ReusableSearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      widget.onSearchChanged(value);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        onChanged: _onSearchChanged,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: GoogleFonts.nunito(color: theme.hintColor),
          prefixIcon: Icon(Icons.search, color: theme.iconTheme.color),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _controller.clear();
                    _debounce?.cancel();
                    widget.onSearchChanged('');
                    setState(() {});
                  },
                )
              : null,
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:go_router/go_router.dart';

import '../constants/colors.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/resource_provider.dart';
import 'tools/science_lab_screen.dart';
import 'student/career_compass_screen.dart';
import 'discussion/group_allocation_screen.dart';

import '../widgets/interest_update_sheet.dart';
import '../widgets/animated_search_bar.dart';
import '../widgets/enhanced_card.dart';
import '../widgets/bounce_wrapper.dart';
import '../widgets/skeleton_loader.dart';
import 'pdf_viewer_screen.dart';
import '../models/firebase_file.dart';
import '../services/storage_service.dart';
import '../models/resource_model.dart';
import '../widgets/session_history_carousel.dart';

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

/// HomeScreen is kept as a simple wrapper around HomeTab for backward compatibility.
/// Navigation is handled by go_router's StatefulShellRoute in router.dart.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    return const HomeTab();
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
      final user =
          Provider.of<AuthProvider>(context, listen: false).userModel;
      final files = await StorageService.getAllFilesFromFirestore(
        grade: user?.grade,
        curriculum: user?.curriculum,
      );
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
      final user =
          Provider.of<AuthProvider>(context, listen: false).userModel;
      final results = await StorageService.searchFiles(
        query,
        grade: user?.grade,
        curriculum: user?.curriculum,
      );
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
            AnimatedSearchBar(
              onSearchChanged: _filterFiles,
              hintText: 'Search files, notes, topics...',
              margin: const EdgeInsets.fromLTRB(
                AppTheme.spacingMd,
                AppTheme.spacingMd,
                AppTheme.spacingMd,
                AppTheme.spacingSm,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _loadFiles();
                  if (context.mounted) {
                    final resourceProvider = Provider.of<ResourceProvider>(
                      context,
                      listen: false,
                    );
                    await resourceProvider.fetchRecentDriveResources();
                    await resourceProvider.loadRecentlyOpened();
                  }
                },
                color: AppColors.accentTeal,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, displayName, 12),
                      const SizedBox(height: AppTheme.spacingLg),
                      const SessionHistoryCarousel(),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildHeroCard(context),
                      const SizedBox(height: AppTheme.spacingLg),
                      if (_isSearching)
                        _buildSearchResultsSection(context)
                      else ...[
                        Text(
                          "Explore",
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        _buildActionGrid(context),
                        const SizedBox(height: AppTheme.spacingXl),
                      ],
                    ],
                  ),
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
        child: SkeletonList(itemCount: 5),
      );
    }

    if (_filteredFiles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing2xl),
        child: Center(
          child: Column(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: AppTheme.durationSlow,
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingXl),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.search_off,
                        size: 60,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppTheme.spacingLg),
              Text(
                "No files found",
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                "Try a different search term",
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
        Row(
          children: [
            Text(
              "Search Results",
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSm,
                vertical: AppTheme.spacingXs,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text(
                '${_filteredFiles.length}',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentTeal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredFiles.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppTheme.spacingMd),
          itemBuilder: (context, index) {
            final file = _filteredFiles[index];
            return _buildFileCard(context, file);
          },
        ),
        const SizedBox(height: AppTheme.spacingXl),
      ],
    );
  }

  Widget _buildFileCard(BuildContext context, FirebaseFile file) {
    final theme = Theme.of(context);
    final pathParts = file.path.split('/');
    final folderContext =
        pathParts.length > 1 ? pathParts[pathParts.length - 2] : "General";

    return EnhancedCard(
      onTap: () => _openFile(context, file),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          _getFileIcon(file.name),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.spacingXs),
                Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 14,
                      color: theme.hintColor,
                    ),
                    const SizedBox(width: AppTheme.spacingXs),
                    Expanded(
                      child: Text(
                        folderContext,
                        style: GoogleFonts.nunito(
                          color: theme.hintColor,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: theme.iconTheme.color?.withValues(alpha: 0.4),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacingSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: AppTheme.durationSlow,
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    "Jambo, $name! 👋",
                    style: GoogleFonts.nunito(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXs),
                Text(
                  "Let's discover your path today.",
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: BounceWrapper(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CareerCompassScreen(),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF8B80FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            boxShadow: AppTheme.getGlowShadow(
              const Color(0xFF6C63FF),
              intensity: 0.3,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSm,
                        vertical: AppTheme.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        "CAREER INSIGHT",
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Text(
                      "Discover Your\nFuture Path",
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMd,
                        vertical: AppTheme.spacingSm,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Start Guide",
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF6C63FF),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingXs),
                          const Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: Color(0xFF6C63FF),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  FontAwesomeIcons.compass,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
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
    return BounceWrapper(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.getGlowShadow(startColor, intensity: 0.25),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: FaIcon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReusableSearchBar extends StatefulWidget {
  final Function(String) onSearchChanged;

  const _ReusableSearchBar({
    required this.onSearchChanged,
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
          hintText: 'Search files, notes, topics...',
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

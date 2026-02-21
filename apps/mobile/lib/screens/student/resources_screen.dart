import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../pdf_viewer_screen.dart';
import '../../services/storage_service.dart';
import '../../models/firebase_file.dart';
import '../../config/app_theme.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late TabController _tabController;
  Timer? _debounce;

  final List<FirebaseFile> _files = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _hasError = false;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 20;

  String _searchQuery = '';
  bool _isSearching = false;

  final List<String> _tabCategories = [
    'My Documents',
    'Curriculum',
    'Notes',
    'Schemes Of Work',
    'Lesson Plans',
  ];

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: _tabCategories.length, vsync: this);
    _tabController.addListener(_handleTabSelection);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _fetchFiles();
      }
    });

    _searchController.addListener(_onSearchChanged);
    _fetchFiles();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
          _isSearching = _searchQuery.isNotEmpty;
          _files.clear();
          _lastDocument = null;
          _hasMore = true;
        });
        _fetchFiles();
      }
    });
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      _files.clear();
      _lastDocument = null;
      _hasMore = true;
      _fetchFiles();
    }
  }

  Future<void> _fetchFiles() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.userModel;
      if (user == null) throw Exception("User not authenticated");

      List<FirebaseFile> newFiles;
      final category = _tabCategories[_tabController.index];
      final currentCategory = category == 'My Documents' ? null : category;

      if (_isSearching) {
        newFiles = await StorageService.searchFiles(
          _searchQuery,
          limit: _pageSize,
          grade: user.grade,
          curriculum: user.curriculum,
          category: currentCategory,
        );
        _hasMore = false;
      } else {
        newFiles = await StorageService.getPaginatedFiles(
          limit: _pageSize,
          lastDocument: _lastDocument,
          fileType: '.pdf',
          grade: user.grade,
          curriculum: user.curriculum,
          category: currentCategory,
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _files.addAll(newFiles);
          if (newFiles.length < _pageSize) {
            _hasMore = false;
          } else {
            _lastDocument = newFiles.last.snapshot;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching resources: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Failed to load resources. Pull down to retry.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _refreshFiles,
            ),
          ),
        );
      }
    }
  }

  Future<void> _refreshFiles() async {
    _files.clear();
    _lastDocument = null;
    _hasMore = true;
    _hasError = false;
    await _fetchFiles();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchQuery = '';
      _isSearching = false;
      _files.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    _fetchFiles();
  }

  Future<void> _openFile(FirebaseFile file) async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PdfViewerScreen(storagePath: file.path, title: file.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(Theme.of(context), user?.gradeLabel ?? ""),
            Expanded(child: _buildBody(Theme.of(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, String gradeLabel) {
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom:
              BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Text(
                  "MY RESOURCES",
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: 0.5,
                  ),
                ),
                if (gradeLabel.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      gradeLabel,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: AppColors.accentTeal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Access materials prepared for your level",
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSearchBox(theme),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.accentTeal,
            indicatorWeight: 2.5,
            labelColor: AppColors.accentTeal,
            unselectedLabelColor:
                theme.colorScheme.onSurface.withValues(alpha: 0.6),
            labelStyle: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
            unselectedLabelStyle: GoogleFonts.nunito(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: _tabCategories.map((title) {
              if (title == 'Curriculum') {
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                return Tab(
                    text: authProvider.userModel?.curriculum ?? 'CBC');
              }
              return Tab(text: title);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Search resources...',
          hintStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.hintColor,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: _isSearching ? AppColors.accentTeal : theme.hintColor,
            size: 22,
          ),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 20, color: theme.hintColor),
                  onPressed: _clearSearch,
                  splashRadius: 18,
                )
              : null,
          filled: true,
          fillColor: isDark
              ? AppColors.surfaceVariantDark
              : AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.accentTeal, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading && _files.isEmpty) {
      return _buildShimmerList(theme);
    }

    if (_files.isEmpty && _hasError) {
      return _buildErrorState(theme);
    }

    if (_files.isEmpty) {
      return _buildEmptyState(theme);
    }

    return RefreshIndicator(
      onRefresh: _refreshFiles,
      color: AppColors.accentTeal,
      child: Column(
        children: [
          if (_isSearching || _files.isNotEmpty)
            _buildResultsHeader(theme),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _files.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _files.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.accentTeal,
                      ),
                    ),
                  );
                }
                return _buildFileCard(_files[index], theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Text(
            _isSearching
                ? '${_files.length} result${_files.length == 1 ? '' : 's'} found'
                : '${_files.length} document${_files.length == 1 ? '' : 's'}',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (_hasMore) ...[
            const SizedBox(width: 4),
            Text(
              '+',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileCard(FirebaseFile file, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final categoryColor = _getCategoryColor(file.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppTheme.buildGlassContainer(
        context,
        borderRadius: 14,
        padding: EdgeInsets.zero,
        opacity: isDark ? 0.08 : 0.35,
        child: InkWell(
          onTap: () => _openFile(file),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // File type icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(file.category),
                    color: categoryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name.replaceAll('.pdf', '').replaceAll('-', ' ').replaceAll('_', ' '),
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: theme.colorScheme.onSurface,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _buildMetaChip(
                            file.subject ?? file.category ?? 'General',
                            categoryColor,
                            theme,
                          ),
                          if (file.gradeLabel.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _buildMetaChip(
                              file.gradeLabel,
                              AppColors.accentTeal,
                              theme,
                            ),
                          ],
                          if (file.size != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              _formatFileSize(file.size!),
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Arrow
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(String label, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: _refreshFiles,
          color: AppColors.accentTeal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? AppColors.accentTeal
                                  : AppColors.accentTeal)
                              .withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isSearching
                              ? Icons.search_off_rounded
                              : Icons.folder_open_rounded,
                          size: 48,
                          color: AppColors.accentTeal.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isSearching
                            ? 'No results found'
                            : 'No documents yet',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isSearching
                            ? 'Try a different search term or category'
                            : 'Resources for your level will appear here',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.hintColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_isSearching) ...[
                        const SizedBox(height: 20),
                        TextButton.icon(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          label: Text(
                            'Clear search',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accentTeal,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: _refreshFiles,
          color: AppColors.accentTeal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.cloud_off_rounded,
                          size: 48,
                          color: AppColors.error.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Failed to load resources',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check your connection and try again',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.hintColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _refreshFiles,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(
                          'Retry',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerList(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final baseColor =
        isDark ? AppColors.shimmerBaseDark : AppColors.shimmerBase;
    final highlightColor =
        isDark ? AppColors.shimmerHighlightDark : AppColors.shimmerHighlight;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ShimmerCard(
            baseColor: baseColor,
            highlightColor: highlightColor,
            borderRadius: 14,
          ),
        );
      },
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'notes':
        return AppColors.primaryBlue;
      case 'curriculum':
        return AppColors.accentTeal;
      case 'schemes of work':
        return AppColors.cardOrange;
      case 'lesson plans':
        return AppColors.cardPurple;
      default:
        return AppColors.primaryBlue;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'notes':
        return Icons.description_rounded;
      case 'curriculum':
        return Icons.school_rounded;
      case 'schemes of work':
        return Icons.calendar_month_rounded;
      case 'lesson plans':
        return Icons.assignment_rounded;
      default:
        return Icons.picture_as_pdf_rounded;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Shimmer loading placeholder card
class _ShimmerCard extends StatefulWidget {
  final Color baseColor;
  final Color highlightColor;
  final double borderRadius;

  const _ShimmerCard({
    required this.baseColor,
    required this.highlightColor,
    required this.borderRadius,
  });

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: widget.baseColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: widget.baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 14,
                      width: 140,
                      decoration: BoxDecoration(
                        color: widget.baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          height: 10,
                          width: 50,
                          decoration: BoxDecoration(
                            color: widget.baseColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 10,
                          width: 60,
                          decoration: BoxDecoration(
                            color: widget.baseColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

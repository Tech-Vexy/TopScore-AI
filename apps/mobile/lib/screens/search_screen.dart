import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/resource_model.dart';
import '../../services/storage_service.dart';
import '../../providers/search_provider.dart';
import '../services/haptics_service.dart';

/// Global search screen covering resources, topics, and AI history.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<ResourceModel> _results = [];
  bool _isLoading = false;
  String _query = '';

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _query = '';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _query = query;
    });

    try {
      // Firestore text search using title prefix
      final lowerQuery = query.trim().toLowerCase();
      final upperBound = '$lowerQuery\uf8ff';

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.userModel;
      final curriculum = user?.educationLevel ?? user?.curriculum;
      final collectionName = StorageService.getCollectionName(curriculum);

      final snap = await FirebaseFirestore.instance
          .collection(collectionName)
          .where('titleLower', isGreaterThanOrEqualTo: lowerQuery)
          .where('titleLower', isLessThanOrEqualTo: upperBound)
          .limit(30)
          .get();

      final results =
          snap.docs.map((d) => ResourceModel.fromMap(d.data(), d.id)).toList();

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onResultTap(ResourceModel resource) {
    // Save to history
    Provider.of<SearchProvider>(context, listen: false)
        .addSearch(resource.title);
    context.pop(resource);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: (v) {
            Future.delayed(const Duration(milliseconds: 400), () {
              if (_controller.text == v) _search(v);
            });
          },
          decoration: InputDecoration(
            hintText: 'Search resources, topics...',
            border: InputBorder.none,
            hintStyle: GoogleFonts.nunito(color: Colors.grey),
          ),
          style: GoogleFonts.nunito(fontSize: 16),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() {
                  _results = [];
                  _query = '';
                });
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_query.isEmpty) {
      final searchProvider = Provider.of<SearchProvider>(context);
      final history = searchProvider.history;
      final suggestions = searchProvider.getSuggestions(_controller.text);

      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_controller.text.isNotEmpty && suggestions.isNotEmpty) ...[
            Text(
              'Suggestions',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...suggestions.map((s) => ListTile(
                  leading: const Icon(Icons.search, size: 20),
                  title: Text(s, style: GoogleFonts.nunito()),
                  onTap: () {
                    _controller.text = s;
                    _search(s);
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
            const SizedBox(height: 24),
          ],
          if (history.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Searches',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => searchProvider.clearHistory(),
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: history
                  .map((s) => ActionChip(
                        label: Text(s),
                        onPressed: () {
                          HapticsService.instance.lightImpact();
                          _controller.text = s;
                          _search(s);
                        },
                        backgroundColor:
                            theme.primaryColor.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 32),
          ],
          Text(
            'Popular Topics',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPopularTopic(
              'Algebra & Equations', 'Mathematics', Icons.calculate_outlined),
          _buildPopularTopic(
              'Organic Chemistry', 'Chemistry', Icons.science_outlined),
          _buildPopularTopic(
              'World War II', 'History', Icons.history_edu_outlined),
          _buildPopularTopic('Newton\'s Laws', 'Physics', Icons.speed_outlined),
        ],
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('No results for "$_query"',
                style: GoogleFonts.nunito(fontSize: 15, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = _results[i];
        final icon = r.type == 'video'
            ? '🎥'
            : r.type == 'pdf'
                ? '📄'
                : '📁';
        return ListTile(
          leading: Text(icon, style: const TextStyle(fontSize: 22)),
          title: Text(r.title,
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          subtitle: Text('${r.subject} · Grade ${r.grade}',
              style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey)),
          onTap: () => _onResultTap(r),
        );
      },
    );
  }

  Widget _buildPopularTopic(String title, String subtitle, IconData icon) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).primaryColor),
      ),
      title:
          Text(title, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey)),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: () {
        _controller.text = title;
        _search(title);
      },
    );
  }
}

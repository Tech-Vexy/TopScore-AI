import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../models/resource_model.dart';

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

      final snap = await FirebaseFirestore.instance
          .collection('resources')
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
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔎', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Search for resources or topics',
                style: GoogleFonts.nunito(fontSize: 15, color: Colors.grey)),
          ],
        ),
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
          onTap: () => context.pop(r),
        );
      },
    );
  }
}

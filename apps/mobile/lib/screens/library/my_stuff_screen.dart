import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class MyStuffScreen extends StatelessWidget {
  const MyStuffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Please login")));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "My Knowledge Bank",
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('library')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final docs = snapshot.data!.docs;

          return MasonryGridView.count(
            crossAxisCount: 2, // 2 Columns like Pinterest
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _ArtifactCard(data: data);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No saved knowledge yet!",
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Ask the AI to generate a graph or formula.",
            style: GoogleFonts.nunito(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ArtifactCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ArtifactCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] ?? 'text';
    final content = data['content'] ?? '';
    final title = data['title'] ?? 'Untitled';
    final subject = data['subject'] ?? 'General';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- CONTENT SECTION ---
          if (type == 'image' || type == 'graph')
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: CachedNetworkImage(
                imageUrl: content,
                placeholder: (c, u) => Container(
                  height: 150,
                  color: Colors.grey[100],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (c, u, e) => const Icon(Icons.error),
                fit: BoxFit.cover,
              ),
            )
          else if (type == 'formula')
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.blue.withValues(alpha: 0.05),
              child: Math.tex(
                content, // Renders LaTeX string e.g., "E=mc^2"
                textStyle: const TextStyle(fontSize: 16),
              ),
            )
          else // Mnemonic or Text
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFFFF4E5), // Light Orange background
              child: Text(
                content,
                style: GoogleFonts.caveat(fontSize: 20, height: 1.2),
              ),
            ),

          // --- FOOTER SECTION ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildTag(type),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        subject,
                        style: GoogleFonts.nunito(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
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
  }

  Widget _buildTag(String type) {
    Color color;
    IconData icon;

    switch (type) {
      case 'image':
        color = Colors.blue;
        icon = Icons.image;
        break;
      case 'formula':
        color = Colors.purple;
        icon = Icons.functions;
        break;
      case 'graph':
        color = Colors.green;
        icon = Icons.bar_chart;
        break;
      default:
        color = Colors.orange;
        icon = Icons.lightbulb;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 12, color: color),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- IMPORT YOUR TOOL SCREENS HERE ---
import 'calculator_screen.dart';
import 'smart_scanner_screen.dart';
import 'flashcard_generator_screen.dart';
import 'timetable_screen.dart';
import 'science_lab_screen.dart';
import 'periodic_table_screen.dart';
import '../files_screen.dart'; // Corrected path for sibling of parent

class ToolCardData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String routeId;

  const ToolCardData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.routeId,
  });
}

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Define your tools here
    const List<ToolCardData> tools = [
      ToolCardData(
        title: "Science Lab",
        description: "Virtual experiments",
        icon: Icons.science_rounded,
        color: Color(0xFF6C63FF),
        routeId: 'science_lab',
      ),
      ToolCardData(
        title: "Periodic Table",
        description: "Elements & Properties",
        icon: Icons.grid_4x4_rounded,
        color: Color(0xFFE91E63),
        routeId: 'periodic_table',
      ),
      ToolCardData(
        title: "Doc Scanner",
        description: "Digitize notes instantly",
        icon: Icons.document_scanner_rounded,
        color: Color(0xFF4ECDC4),
        routeId: 'scanner',
      ),
      ToolCardData(
        title: "Scientific Calc",
        description: "Solve complex math",
        icon: Icons.calculate_rounded,
        color: Color(0xFF4A90E2),
        routeId: 'calculator',
      ),
      ToolCardData(
        title: "AI Flashcards",
        description: "Generate study cards",
        icon: Icons.flash_on_rounded,
        color: Color(0xFFA389F4),
        routeId: 'flashcards',
      ),
      ToolCardData(
        title: "Smart Timetable",
        description: "Plan your week",
        icon: Icons.calendar_month_rounded,
        color: Color(0xFFFFD93D),
        routeId: 'timetable',
      ),
      ToolCardData(
        title: "PDF Library",
        description: "Open & read documents",
        icon: Icons.picture_as_pdf_rounded,
        color: Color(0xFFFF6B6B),
        routeId: 'library',
      ),
    ];

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Smart Toolkit",
          style: GoogleFonts.nunito(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- HEADER BANNER ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E3192).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
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
                            "Productivity Hub",
                            style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Everything you need to boost your study efficiency in one place.",
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.build,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- RESPONSIVE GRID ---
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                return _buildToolCard(context, tools[index]);
              }, childCount: tools.length),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, ToolCardData tool) {
    return GestureDetector(
      onTap: () {
        // --- FIXED NAVIGATION LOGIC ---
        // 1. Identify the screen first
        Widget? targetScreen;

        switch (tool.routeId) {
          case 'calculator':
            targetScreen = const CalculatorScreen();
            break;
          case 'scanner':
            targetScreen = const SmartScannerScreen();
            break;
          case 'flashcards':
            targetScreen = const FlashcardGeneratorScreen();
            break;
          case 'timetable':
            targetScreen = const TimetableScreen();
            break;
          case 'science_lab':
            targetScreen = const ScienceLabScreen();
            break;
          case 'periodic_table':
            targetScreen = const PeriodicTableScreen();
            break;
          case 'library':
            targetScreen = const FilesScreen();
            break;
        }

        // 2. Safe Navigation Check
        if (targetScreen != null) {
          // Capture in a final local variable to ensure non-nullability in closure
          final Widget destination = targetScreen;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Feature ${tool.title} coming soon!")),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tool.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(tool.icon, color: tool.color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              tool.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tool.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../config/app_theme.dart';
import '../../widgets/bounce_wrapper.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';
import '../../tutor_client/chat_screen.dart';
import '../../widgets/interest_update_sheet.dart';

class CareerCompassScreen extends StatefulWidget {
  const CareerCompassScreen({super.key});

  @override
  State<CareerCompassScreen> createState() => _CareerCompassScreenState();
}

class _CareerCompassScreenState extends State<CareerCompassScreen> {
  // Map Interest Categories to Compass Directions/Domains
  final Map<String, String> _domainMapping = {
    'Technology & Coding': 'Tech',
    'Medicine & Health': 'Health',
    'Engineering': 'Eng',
    'Arts & Design': 'Arts',
    'Business & Finance': 'Biz',
    'Law & Justice': 'Law',
    'Sports & Fitness': 'Sport',
    'Media & Writing': 'Media',
    'Agriculture & Nature': 'Agri',
    'Teaching & Education': 'Edu',
    'Music & Performance': 'Music',
    'Public Service': 'Gov',
  };

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;
    final interests = user?.interests ?? [];

    // Fallback if no interests are set
    if (interests.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            "Career Compass",
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.explore_off, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 20),
              Text(
                "No Direction Set",
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Select your interests to generate your compass.",
                style: GoogleFonts.nunito(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => _showInterestSheet(context, user?.uid ?? ''),
                icon: const Icon(Icons.edit),
                label: const Text("Set Interests"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentTeal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Career Compass",
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () => _showInterestSheet(context, user?.uid ?? ''),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.heroGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // --- 1. THE RADAR CHART (COMPASS) ---
                AppTheme.buildGlassContainer(
                  context,
                  borderRadius: 24,
                  padding: const EdgeInsets.all(20),
                  opacity: 0.1,
                  child: Column(
                    children: [
                      Text(
                        "Your Interest Map",
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 240,
                        child: CustomPaint(
                          painter: RadarChartPainter(
                            interests: interests,
                            allDomains: _domainMapping,
                            primaryColor: Colors.white,
                          ),
                          child: Container(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Center(
                  child: BounceWrapper(
                    onTap: () {
                      final gradeInfo = user?.grade != null
                          ? "Grade ${user?.grade}"
                          : "my grade";
                      final curriculumInfo = user?.curriculum != null
                          ? "the ${user?.curriculum} curriculum"
                          : "my curriculum";
                      final prompt =
                          "I'm a student in $gradeInfo following $curriculumInfo. My interests are ${interests.join(', ')}. Based on my learning context, what career advice and study paths do you have for me?";

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            initialMessage: prompt,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FaIcon(FontAwesomeIcons.robot,
                              size: 18, color: AppColors.primaryPurple),
                          const SizedBox(width: 10),
                          Text(
                            "Get AI Advice",
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryPurple,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // --- 2. AI CAREER SUGGESTIONS ---
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Suggested Paths",
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildCareerSuggestions(interests),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInterestSheet(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => InterestUpdateSheet(userId: uid),
    );
  }

  Widget _buildCareerSuggestions(List<String> interests) {
    // Basic logic to map interests to careers (Replace with AI later)
    final careers = <Map<String, dynamic>>[];

    if (interests.any((i) => i.contains("Tech"))) {
      careers.add({
        'title': 'Software Engineer',
        'desc': 'Build apps and systems that solve real-world problems.',
        'icon': FontAwesomeIcons.code,
        'color': Colors.blue,
      });
    }
    if (interests.any((i) => i.contains("Health") || i.contains("Medicine"))) {
      careers.add({
        'title': 'Biomedical Scientist',
        'desc': 'Combine biology and tech to improve healthcare.',
        'icon': FontAwesomeIcons.dna,
        'color': Colors.redAccent,
      });
    }
    if (interests.any((i) => i.contains("Business") || i.contains("Finance"))) {
      careers.add({
        'title': 'Financial Analyst',
        'desc': 'Analyze market trends and guide investment decisions.',
        'icon': FontAwesomeIcons.chartLine,
        'color': Colors.green,
      });
    }
    // Default if specific logic misses
    if (careers.isEmpty) {
      careers.add({
        'title': 'General Explorer',
        'desc': 'Your diverse interests open many doors. Keep learning!',
        'icon': FontAwesomeIcons.compass,
        'color': Colors.purple,
      });
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: careers.length,
      itemBuilder: (context, index) {
        final career = careers[index];
        return BounceWrapper(
          onTap: () {
            final prompt =
                "Tell me more about becoming a ${career['title']}. What should I study now and what are the future opportunities?";
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  initialMessage: prompt,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: AppTheme.buildGlassContainer(
              context,
              borderRadius: 16,
              padding: const EdgeInsets.all(4),
              opacity: 0.1,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (career['color'] as Color).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FaIcon(career['icon'], color: Colors.white),
                ),
                title: Text(
                  career['title'],
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  career['desc'],
                  style: GoogleFonts.nunito(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- CUSTOM PAINTER FOR RADAR CHART ---
class RadarChartPainter extends CustomPainter {
  final List<String> interests;
  final Map<String, String> allDomains;
  final Color primaryColor;

  RadarChartPainter({
    required this.interests,
    required this.allDomains,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = min(centerX, centerY) * 0.8;

    final paintLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final paintFill = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 1. Draw Spider Web (Grid)
    // Draw concentric polygons (e.g., 3 levels)
    for (int i = 1; i <= 3; i++) {
      double r = radius * (i / 3);
      _drawPolygon(canvas, centerX, centerY, r, allDomains.length, paintLine);
    }

    // 2. Draw Spokes and Labels
    final angleStep = (2 * pi) / allDomains.length;
    final path = Path();
    final List<Offset> points = [];

    int index = 0;
    allDomains.forEach((fullInterest, shortLabel) {
      final angle = (index * angleStep) - (pi / 2); // Start from top (-90 deg)

      // Draw Spoke
      final spokeX = centerX + radius * cos(angle);
      final spokeY = centerY + radius * sin(angle);
      canvas.drawLine(
        Offset(centerX, centerY),
        Offset(spokeX, spokeY),
        paintLine,
      );

      // Draw Label
      final labelRadius = radius * 1.2; // Push text out a bit
      final labelX = centerX + labelRadius * cos(angle);
      final labelY = centerY + labelRadius * sin(angle);

      textPainter.text = TextSpan(
        text: shortLabel,
        style: GoogleFonts.nunito(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(labelX - textPainter.width / 2, labelY - textPainter.height / 2),
      );

      // 3. Calculate Data Points based on user interests
      // If user has interest, set value to 100% (radius), else 20%
      final hasInterest = interests.contains(fullInterest);
      final valueRadius = hasInterest ? radius * 0.9 : radius * 0.2;

      final pointX = centerX + valueRadius * cos(angle);
      final pointY = centerY + valueRadius * sin(angle);
      points.add(Offset(pointX, pointY));

      if (index == 0) {
        path.moveTo(pointX, pointY);
      } else {
        path.lineTo(pointX, pointY);
      }

      index++;
    });

    path.close();

    // 4. Draw Data Shape
    canvas.drawPath(path, paintFill);
    canvas.drawPath(path, paintBorder);

    // 5. Draw Dots at vertices
    final dotPaint = Paint()..color = primaryColor;
    for (var point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  void _drawPolygon(
    Canvas canvas,
    double cx,
    double cy,
    double r,
    int sides,
    Paint paint,
  ) {
    final path = Path();
    final angleStep = (2 * pi) / sides;

    for (int i = 0; i < sides; i++) {
      final angle = (i * angleStep) - (pi / 2);
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

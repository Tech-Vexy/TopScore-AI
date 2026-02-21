import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../tutor_client/chat_screen.dart';

class ScienceLabScreen extends StatefulWidget {
  const ScienceLabScreen({super.key});

  @override
  State<ScienceLabScreen> createState() => _ScienceLabScreenState();
}

class _ScienceLabScreenState extends State<ScienceLabScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late TabController _tabController;
  final TextEditingController _customExperimentController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customExperimentController.dispose();
    super.dispose();
  }

  // --- AI ACTIONS ---

  Future<void> _identifyEquipment() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              initialImageFile: File(photo.path),
              initialMessage:
                  "Identify this lab equipment and list 3 safety rules for using it.",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error accessing camera: $e")));
      }
    }
  }

  void _startSimulation(String experimentName, String initialPrompt) {
    // Safety Check before starting
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Safety Check 🥽"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSafetyCheckItem("Wear virtual safety goggles"),
            _buildSafetyCheckItem("Read instructions carefully"),
            _buildSafetyCheckItem("Do not mix unknown chemicals"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    initialMessage:
                        "Simulate a virtual science experiment: $experimentName. $initialPrompt. Guide me step-by-step and describe the reactions vividly.",
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            child: const Text("Start Simulation"),
          ),
        ],
      ),
    );
  }

  void _launchCustomSimulation() {
    final text = _customExperimentController.text.trim();
    if (text.isEmpty) return;

    _customExperimentController.clear();
    FocusScope.of(context).unfocus(); // Close keyboard

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          initialMessage:
              "I want to perform a custom experiment: \"$text\". "
              "Please simulate this scenario. Describe the setup, the reaction/process, and the final result. "
              "If it is dangerous, explain why.",
        ),
      ),
    );
  }

  Widget _buildSafetyCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(text, style: GoogleFonts.nunito(fontSize: 14)),
        ],
      ),
    );
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF6C63FF),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF8B85FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: FaIcon(
                        FontAwesomeIcons.flask,
                        size: 150,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Science Lab",
                            style: GoogleFonts.nunito(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Simulate. Experiment. Discover.",
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.nunito(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              unselectedLabelStyle: GoogleFonts.nunito(
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
                Tab(text: "Chemistry"),
                Tab(text: "Physics"),
                Tab(text: "Biology"),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSubjectTab("Chemistry", [
              _buildExperimentData(
                "Sodium + Water",
                Colors.red,
                FontAwesomeIcons.fire,
                "Reaction of Alkali Metals",
                "Simulate dropping Sodium into water.",
              ),
              _buildExperimentData(
                "Titration",
                Colors.blue,
                FontAwesomeIcons.droplet,
                "Acid-Base Neutralization",
                "Simulate a titration with Phenolphthalein.",
              ),
              _buildExperimentData(
                "Electrolysis",
                Colors.amber,
                FontAwesomeIcons.bolt,
                "Splitting Water",
                "Explain electrolysis of water into Hydrogen and Oxygen.",
              ),
              _buildExperimentData(
                "Flame Tests",
                Colors.orange,
                FontAwesomeIcons.fireBurner,
                "Metal Ion Identification",
                "Show me the flame colors for Lithium, Sodium, Potassium, and Copper.",
              ),
              _buildExperimentData(
                "Rusting",
                Colors.brown,
                FontAwesomeIcons.link,
                "Oxidation of Iron",
                "Set up 3 test tubes to investigate conditions necessary for rusting.",
              ),
            ]),
            _buildSubjectTab("Physics", [
              _buildExperimentData(
                "Pendulum",
                Colors.purple,
                FontAwesomeIcons.stopwatch,
                "Simple Harmonic Motion",
                "Simulate a pendulum. How does length affect the period?",
              ),
              _buildExperimentData(
                "Ohm's Law",
                Colors.orange,
                FontAwesomeIcons.plug,
                "Electricity & Circuits",
                "Build a virtual circuit. Show relationship between Voltage and Current.",
              ),
              _buildExperimentData(
                "Refraction",
                Colors.cyan,
                FontAwesomeIcons.glasses,
                "Light & Optics",
                "Shine a light through a glass block. Calculate the refractive index.",
              ),
              _buildExperimentData(
                "Hooke's Law",
                Colors.teal,
                FontAwesomeIcons.ruler,
                "Elasticity",
                "Add weights to a spring and measure extension.",
              ),
              _buildExperimentData(
                "Archimedes",
                Colors.indigo,
                FontAwesomeIcons.ship,
                "Density & Buoyancy",
                "Submerge an object in water. Explain why it floats.",
              ),
            ]),
            _buildSubjectTab("Biology", [
              _buildExperimentData(
                "Photosynthesis",
                Colors.green,
                FontAwesomeIcons.leaf,
                "Plant Energy",
                "Visualize reactions inside a chloroplast.",
              ),
              _buildExperimentData(
                "Cell Division",
                Colors.pink,
                FontAwesomeIcons.dna,
                "Mitosis & Meiosis",
                "Walk me through the stages of Mitosis.",
              ),
              _buildExperimentData(
                "Heart Beat",
                Colors.redAccent,
                FontAwesomeIcons.heartPulse,
                "Human Anatomy",
                "Explain the double circulation of blood.",
              ),
              _buildExperimentData(
                "Osmosis",
                Colors.lightBlue,
                FontAwesomeIcons.glassWater,
                "Cell Transport",
                "Place potato strips in salt water vs distilled water.",
              ),
              _buildExperimentData(
                "Food Tests",
                Colors.orangeAccent,
                FontAwesomeIcons.utensils,
                "Nutrient Analysis",
                "Simulate Benedict's test for reducing sugars.",
              ),
            ]),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _identifyEquipment,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF6C63FF),
        icon: const Icon(Icons.camera_alt),
        label: Text(
          "Scan Equipment",
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSubjectTab(
    String subject,
    List<Map<String, dynamic>> experiments,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // --- NEW: Custom Experiment Input ---
        _buildCustomInput(),

        const SizedBox(height: 24),

        // Tools Section
        Text(
          "Lab Tools",
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildToolCard(
              FontAwesomeIcons.robot,
              "AI Assistant",
              Colors.indigo,
              () => _identifyEquipment(),
            ),
            const SizedBox(width: 12),
            _buildToolCard(
              FontAwesomeIcons.tableCells,
              "Periodic Table",
              Colors.teal,
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Opening Periodic Table...")),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Experiments List
        Text(
          "$subject Experiments",
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ...experiments.map(
          (exp) => _buildExperimentCard(
            title: exp['title'],
            color: exp['color'],
            icon: exp['icon'],
            subtitle: exp['subtitle'],
            onTap: () => _startSimulation(exp['title'], exp['prompt']),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomInput() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _customExperimentController,
              decoration: InputDecoration(
                hintText: "Describe an experiment...",
                hintStyle: GoogleFonts.nunito(color: Colors.grey[400]),
                border: InputBorder.none,
                icon: const Icon(
                  Icons.science_outlined,
                  color: Color(0xFF6C63FF),
                ),
              ),
              style: GoogleFonts.nunito(color: theme.colorScheme.onSurface),
              onSubmitted: (_) => _launchCustomSimulation(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Color(0xFF6C63FF)),
            onPressed: _launchCustomSimulation,
            tooltip: "Start Custom Experiment",
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildExperimentData(
    String title,
    Color color,
    IconData icon,
    String subtitle,
    String prompt,
  ) {
    return {
      'title': title,
      'color': color,
      'icon': icon,
      'subtitle': subtitle,
      'prompt': prompt,
    };
  }

  Widget _buildToolCard(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              FaIcon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExperimentCard({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: FaIcon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.play_arrow_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

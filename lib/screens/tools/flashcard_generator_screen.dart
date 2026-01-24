import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/ai_service.dart';
import '../../models/flashcard_model.dart';

class FlashcardGeneratorScreen extends StatefulWidget {
  const FlashcardGeneratorScreen({super.key});

  @override
  State<FlashcardGeneratorScreen> createState() =>
      _FlashcardGeneratorScreenState();
}

class _FlashcardGeneratorScreenState extends State<FlashcardGeneratorScreen> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _sourceTextController = TextEditingController();
  final AIService _aiService = AIService();
  
  bool _isLoading = false;
  FlashcardSet? _flashcardSet;
  int _cardAmount = 5;
  String _educationLevel = 'High School';
  int _currentCardIndex = 0;

  final List<String> _levels = [
    'Primary School',
    'Form 1',
    'Form 2', 
    'Form 3',
    'Form 4',
    'High School',
    'University',
  ];

  Future<void> _generateFlashcards() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a topic first.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.userModel?.uid ?? 'guest_user';
      
      final flashcardSet = await _aiService.generateFlashcards(
        userId: userId,
        topic: topic,
        amount: _cardAmount,
        level: _educationLevel,
        sourceText: _sourceTextController.text.trim().isNotEmpty 
            ? _sourceTextController.text.trim() 
            : null,
      );

      setState(() {
        _flashcardSet = flashcardSet;
        _currentCardIndex = 0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString().replaceFirst('Exception: ', '')}")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _nextCard() {
    if (_flashcardSet != null && _currentCardIndex < _flashcardSet!.cards.length - 1) {
      setState(() => _currentCardIndex++);
    }
  }

  void _previousCard() {
    if (_currentCardIndex > 0) {
      setState(() => _currentCardIndex--);
    }
  }

  void _reset() {
    setState(() {
      _flashcardSet = null;
      _topicController.clear();
      _sourceTextController.clear();
      _currentCardIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "AI Flashcards",
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          if (_flashcardSet != null)
            IconButton(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              tooltip: 'Start Over',
            ),
        ],
      ),
      body: _flashcardSet == null ? _buildInputSection(theme) : _buildFlashcardViewer(theme),
    );
  }

  Widget _buildInputSection(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            "Generate AI Flashcards",
            style: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Enter a topic and let AI create study flashcards for you!",
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),

          // Topic Input
          Text(
            "Topic *",
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _topicController,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: "e.g., Photosynthesis, Newton's Laws, Quadratic Equations",
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: theme.brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.topic),
            ),
          ),
          const SizedBox(height: 20),

          // Education Level Dropdown
          Text(
            "Education Level",
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _educationLevel,
                isExpanded: true,
                dropdownColor: theme.cardColor,
                items: _levels.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _educationLevel = value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Number of Cards Slider
          Text(
            "Number of Cards: $_cardAmount",
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Slider(
            value: _cardAmount.toDouble(),
            min: 3,
            max: 20,
            divisions: 17,
            label: _cardAmount.toString(),
            activeColor: const Color(0xFF6C63FF),
            onChanged: (value) {
              setState(() => _cardAmount = value.round());
            },
          ),
          const SizedBox(height: 20),

          // Source Text (Optional)
          Text(
            "Source Text (Optional)",
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _sourceTextController,
              maxLines: null,
              expands: true,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Paste your notes here to generate flashcards from specific content...",
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Generate Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateFlashcards,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isLoading ? "Generating..." : "Generate Flashcards",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashcardViewer(ThemeData theme) {
    final cards = _flashcardSet!.cards;
    final currentCard = cards[_currentCardIndex];

    return Column(
      children: [
        // Title & Progress
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                _flashcardSet!.title,
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Card ${_currentCardIndex + 1} of ${cards.length}",
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_currentCardIndex + 1) / cards.length,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
              ),
            ],
          ),
        ),

        // Flashcard
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FlipCard(
              direction: FlipDirection.HORIZONTAL,
              front: _buildCardFace(
                currentCard.front,
                const Color(0xFF6C63FF),
                "Tap to flip",
              ),
              back: _buildCardFaceWithExplanation(
                currentCard.back,
                currentCard.explanation,
                const Color(0xFFFF6B6B),
              ),
            ),
          ),
        ),

        // Navigation
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _currentCardIndex > 0 ? _previousCard : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text("Previous"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _currentCardIndex < cards.length - 1 ? _nextCard : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text("Next"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardFace(String text, Color color, String hint) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Text(
            hint,
            style: GoogleFonts.nunito(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFaceWithExplanation(String answer, String? explanation, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      answer,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (explanation != null && explanation.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "💡 $explanation",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Text(
            "Tap to flip back",
            style: GoogleFonts.nunito(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

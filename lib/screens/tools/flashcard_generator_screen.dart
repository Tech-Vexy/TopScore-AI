import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flip_card/flip_card.dart';
import 'package:google_fonts/google_fonts.dart';

class FlashcardGeneratorScreen extends StatefulWidget {
  const FlashcardGeneratorScreen({super.key});

  @override
  State<FlashcardGeneratorScreen> createState() =>
      _FlashcardGeneratorScreenState();
}

class _FlashcardGeneratorScreenState extends State<FlashcardGeneratorScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _flashcards = [];

  Future<void> _generateFlashcards() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter some text first.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'generate_flashcards',
      );

      final result = await callable.call(<String, dynamic>{
        'text': text,
        'apiKey': apiKey, // Passing key for MVP as per plan
      });

      final data = result.data as Map<String, dynamic>;
      final cards = List<Map<String, dynamic>>.from(data['flashcards']);

      setState(() {
        _flashcards = cards;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      setState(() => _isLoading = false);
    }
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
      ),
      body: Column(
        children: [
          // Input Section
          if (_flashcards.isEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      "Paste your notes below to generate flashcards.",
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? Colors.white10
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _textController,
                          maxLines: null,
                          expands: true,
                          style: TextStyle(color: theme.colorScheme.onSurface),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Enter text here...",
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(
                          _isLoading ? "Generating..." : "Generate Flashcards",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Results Section
          if (_flashcards.isNotEmpty)
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Generated ${_flashcards.length} Cards",
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _flashcards = [];
                              _textController.clear();
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text("Reset"),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _flashcards.length,
                      itemBuilder: (context, index) {
                        final card = _flashcards[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: FlipCard(
                            direction: FlipDirection.HORIZONTAL,
                            front: _buildCardFace(
                              card['front'],
                              const Color(0xFF6C63FF),
                            ),
                            back: _buildCardFace(
                              card['back'],
                              const Color(0xFFFF6B6B),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardFace(String text, Color color) {
    return Container(
      height: 200,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

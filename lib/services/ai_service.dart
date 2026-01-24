import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../models/flashcard_model.dart';
import '../models/quiz_model.dart';

// Data models for structured responses
class AIResponse {
  final String text;
  final VisualizationType? visualizationType;
  final dynamic visualizationData;

  AIResponse({
    required this.text,
    this.visualizationType,
    this.visualizationData,
  });
}

enum VisualizationType {
  diagram,
  mathEquation,
  stepByStep,
  comparison,
  timeline,
  chart,
}

class VisualExample {
  final String title;
  final String description;
  final List<String> steps;
  final Map<String, dynamic>? data;

  VisualExample({
    required this.title,
    required this.description,
    this.steps = const [],
    this.data,
  });

  factory VisualExample.fromJson(Map<String, dynamic> json) {
    return VisualExample(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      steps: List<String>.from(json['steps'] ?? []),
      data: json['data'],
    );
  }
}

class AIService {
  // Use 10.0.2.2 for Android emulator, localhost for iOS/Web
  // static const String _wsUrl = 'ws://10.0.2.2:8080/ws';
  static const String _wsUrl = 'wss://agent.topscoreapp.ai/ws';
  static const String _baseUrl = 'https://agent.topscoreapp.ai';

  WebSocketChannel? _channel;

  AIService() {
    _connect();
  }

  void _connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
    } catch (e) {
      debugPrint('Error connecting to WebSocket: $e');
    }
  }

  Future<AIResponse> sendMessage(
    String message, {
    Map<String, dynamic>? context,
    Uint8List? attachmentBytes,
    String? mimeType,
  }) async {
    try {
      if (_channel == null) _connect();

      final Map<String, dynamic> payload = {
        'type': 'message',
        'content': message,
      };

      if (context != null) {
        payload['context'] = context;
      }

      if (attachmentBytes != null) {
        payload['attachment'] = base64Encode(attachmentBytes);
        payload['mimeType'] = mimeType ?? 'image/jpeg';
      }

      _channel!.sink.add(jsonEncode(payload));

      // Wait for the response from the stream
      // Note: This assumes a simple request-response pattern.
      // For a robust app, you'd want a message ID to correlate responses.
      final responsePayload = await _channel!.stream.first;
      final data = jsonDecode(responsePayload);

      final responseText =
          data['text'] ??
          "I'm having trouble thinking right now. Can you ask again?";

      return _parseResponseWithVisualization(responseText);
    } catch (e) {
      debugPrint('Error in sendMessage: $e');
      // Reconnect on error
      _connect();
      return AIResponse(
        text: "Oh no! My connection is a bit shaky. Please try again. ($e)",
      );
    }
  }

  // Request specific visualization for a concept
  Future<VisualExample> requestVisualization(
    String concept, {
    required String subject,
    required int grade,
  }) async {
    try {
      final prompt =
          """
Create a visual example for: $concept
Subject: $subject, Grade: $grade

Provide response in this format:
TITLE: [Short title]
DESCRIPTION: [Brief explanation]
STEPS:
1. [First step]
2. [Second step]
3. [Third step]
DATA: [Any numbers, values, or key facts in simple format]
""";

      // Reuse sendMessage for simplicity
      final response = await sendMessage(prompt);
      return _parseVisualExample(response.text, concept);
    } catch (e) {
      debugPrint('Error in requestVisualization: $e');
      return VisualExample(
        title: concept,
        description: "Let's explore this concept together!",
      );
    }
  }

  // Get examples with diagrams
  Future<List<VisualExample>> getExamplesWithDiagrams(
    String topic, {
    required int count,
    required String subject,
  }) async {
    try {
      final prompt =
          """
Give me $count visual examples for: $topic (Subject: $subject)

For each example, provide:
- A title
- Simple explanation
- Step-by-step breakdown
- Use Kenyan context (matatus, M-Pesa, ugali, football, etc.)

Make it fun and easy to visualize!
""";

      final response = await sendMessage(prompt);
      return _parseMultipleExamples(response.text);
    } catch (e) {
      debugPrint('Error in getExamplesWithDiagrams: $e');
      return [];
    }
  }

  Future<String> analyzeImage(Uint8List imageBytes, String prompt) async {
    try {
      final response = await sendMessage(
        prompt,
        attachmentBytes: imageBytes,
        mimeType: 'image/jpeg',
      );
      return response.text;
    } catch (e) {
      return "Error analyzing image: $e";
    }
  }

  AIResponse _parseResponseWithVisualization(String responseText) {
    // Check for visualization markers
    if (responseText.contains('[DIAGRAM:')) {
      final match = RegExp(r'\[DIAGRAM: ([^\]]+)\]').firstMatch(responseText);
      if (match != null) {
        return AIResponse(
          text: responseText.replaceAll(match.group(0)!, '').trim(),
          visualizationType: VisualizationType.diagram,
          visualizationData: match.group(1),
        );
      }
    }

    if (responseText.contains('[STEPS:')) {
      final match = RegExp(r'\[STEPS: ([^\]]+)\]').firstMatch(responseText);
      if (match != null) {
        final steps = match
            .group(1)!
            .split(RegExp(r'\d+\.'))
            .where((s) => s.trim().isNotEmpty)
            .toList();
        return AIResponse(
          text: responseText.replaceAll(match.group(0)!, '').trim(),
          visualizationType: VisualizationType.stepByStep,
          visualizationData: steps,
        );
      }
    }

    if (responseText.contains('[MATH:')) {
      final match = RegExp(r'\[MATH: ([^\]]+)\]').firstMatch(responseText);
      if (match != null) {
        return AIResponse(
          text: responseText.replaceAll(match.group(0)!, '').trim(),
          visualizationType: VisualizationType.mathEquation,
          visualizationData: match.group(1),
        );
      }
    }

    if (responseText.contains('[COMPARE:')) {
      final match = RegExp(r'\[COMPARE: ([^\]]+)\]').firstMatch(responseText);
      if (match != null) {
        return AIResponse(
          text: responseText.replaceAll(match.group(0)!, '').trim(),
          visualizationType: VisualizationType.comparison,
          visualizationData: match.group(1),
        );
      }
    }

    return AIResponse(text: responseText);
  }

  VisualExample _parseVisualExample(String responseText, String fallbackTitle) {
    final titleMatch = RegExp(r'TITLE: (.+)').firstMatch(responseText);
    final descMatch = RegExp(r'DESCRIPTION: (.+)').firstMatch(responseText);
    final stepsMatch = RegExp(
      r'STEPS:([\s\S]+?)(?=DATA:|$)',
    ).firstMatch(responseText);

    final steps = <String>[];
    if (stepsMatch != null) {
      final stepsText = stepsMatch.group(1)!;
      steps.addAll(
        stepsText
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .map((line) => line.replaceAll(RegExp(r'^\d+\.\s*'), '').trim())
            .toList(),
      );
    }

    return VisualExample(
      title: titleMatch?.group(1)?.trim() ?? fallbackTitle,
      description: descMatch?.group(1)?.trim() ?? '',
      steps: steps,
    );
  }

  List<VisualExample> _parseMultipleExamples(String responseText) {
    final examples = <VisualExample>[];
    final sections = responseText.split(RegExp(r'Example \d+:|##'));

    for (var section in sections) {
      if (section.trim().isEmpty) continue;

      final lines = section
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;

      final title = lines.first.replaceAll(RegExp(r'^\*+\s*'), '').trim();
      final description = lines.length > 1 ? lines[1].trim() : '';
      final steps = lines
          .skip(2)
          .map((l) => l.replaceAll(RegExp(r'^\d+\.\s*[-•]\s*'), '').trim())
          .toList();

      examples.add(
        VisualExample(title: title, description: description, steps: steps),
      );
    }

    return examples;
  }

  // Reset chat session
  void resetChat() {
    _channel?.sink.close();
    _connect();
  }

  /// Generate AI-powered flashcards from a topic or source text
  /// 
  /// [userId] - The ID of the student (for personalization/logging)
  /// [topic] - The main subject or topic (e.g., "Photosynthesis")
  /// [amount] - Number of cards to generate (default: 5, max: 20)
  /// [level] - Education level (default: "High School")
  /// [sourceText] - Optional text content to generate cards from
  Future<FlashcardSet> generateFlashcards({
    required String userId,
    required String topic,
    int amount = 5,
    String level = 'High School',
    String? sourceText,
  }) async {
    final url = Uri.parse('$_baseUrl/flashcards/generate');

    final payload = {
      'user_id': userId,
      'topic': topic,
      'amount': amount,
      'level': level,
      if (sourceText != null && sourceText.isNotEmpty) 'source_text': sourceText,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return FlashcardSet.fromJson(data);
      } else {
        debugPrint('Flashcard API error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to generate flashcards: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error generating flashcards: $e');
      throw Exception('Error connecting to server: $e');
    }
  }

  /// Generate an AI-powered quiz from a topic or source text
  /// 
  /// [userId] - The ID of the student (for personalization/logging)
  /// [topic] - The main subject or topic (e.g., "World War I")
  /// [questionCount] - Number of questions to generate (default: 5, max: 10)
  /// [difficulty] - Difficulty level: "Easy", "Medium", "Hard" (default: "Medium")
  /// [level] - Education level (default: "High School")
  /// [sourceText] - Optional text content to generate quiz from
  Future<Quiz> generateQuiz({
    required String userId,
    required String topic,
    int questionCount = 5,
    String difficulty = 'Medium',
    String level = 'High School',
    String? sourceText,
  }) async {
    final url = Uri.parse('$_baseUrl/quiz/generate');

    final payload = {
      'user_id': userId,
      'topic': topic,
      'question_count': questionCount,
      'difficulty': difficulty,
      'level': level,
      if (sourceText != null && sourceText.isNotEmpty) 'source_text': sourceText,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Quiz.fromJson(data);
      } else {
        debugPrint('Quiz API error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to generate quiz: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error generating quiz: $e');
      throw Exception('Error connecting to server: $e');
    }
  }
}

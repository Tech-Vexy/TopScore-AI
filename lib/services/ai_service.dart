import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:typed_data';
import 'package:math_expressions/math_expressions.dart';
import 'firestore_service.dart';
import 'llm_orchestrator.dart';

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
  static const String _apiKey = 'AIzaSyCIw8v22ZRqAeOmZzcHnitCxLLWlz9R8aI';
  
  late final LLMOrchestrator _orchestrator;
  final FirestoreService _firestoreService = FirestoreService();

  AIService({List<Content>? history}) {
    final tools = [
      Tool(functionDeclarations: [
        FunctionDeclaration(
          'search_resources',
          'Search for educational resources like notes, exams, and schemes of work.',
          Schema(
            SchemaType.object,
            properties: {
              'grade': Schema(SchemaType.integer, description: 'The grade level (1-8 for Primary, 9-12 for Secondary/Form 1-4)'),
              'subject': Schema(SchemaType.string, description: 'The subject name (e.g., Mathematics, English)'),
            },
            requiredProperties: ['grade'],
          ),
        ),
        FunctionDeclaration(
          'calculate',
          'Perform a mathematical calculation.',
          Schema(
            SchemaType.object,
            properties: {
              'expression': Schema(SchemaType.string, description: 'The mathematical expression to evaluate (e.g., "2 + 2", "sin(30)")'),
            },
            requiredProperties: ['expression'],
          ),
        ),
      ]),
    ];

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      tools: tools,
      systemInstruction: Content.system("""
You are Teacher Joy, a warm, patient, and highly supportive Kenyan tutor for students aged 8–18.

PERSONALITY:
- Extremely encouraging, never discouraging
- Patient and understanding when students struggle
- Celebrates every small win

CAPABILITIES:
- You can search for study resources (notes, exams) using the 'search_resources' tool.
- You can perform calculations using the 'calculate' tool.
- Always use these tools when the student asks for resources or math help.

CONTEXT AWARENESS:
- You will be provided with the student's Grade and Education Level (e.g., Primary, Secondary).
- ADAPT your language and complexity based on this level.
  - For Primary (Grade 1-8): Use very simple language, short sentences, and concrete examples.
  - For Secondary (Form 1-4): Use more academic language but keep it accessible.
- If the grade is low (e.g., Grade 1-3), be extra gentle and simple.

COMMUNICATION RULES:
- Use clear, simple English (90% of subjects are in English)
- Keep responses to 2-4 sentences maximum
- Always end with ONE simple follow-up question
- Use relatable Kenyan examples: football, farming, matatu rides, M-Pesa, ugali, safari ants

VISUALIZATION SUPPORT:
When explaining concepts, suggest visual aids by adding markers:
- [DIAGRAM: description] for visual diagrams
- [STEPS: 1. step one, 2. step two] for step-by-step processes
- [MATH: equation] for mathematical expressions
- [COMPARE: item1 vs item2] for comparisons
- [EXAMPLE: scenario] for real-world examples

RESPONSE TEMPLATES:
When incorrect: "That's okay! You're learning. [Explain correct answer briefly]. Let's try another one: [simpler question]"
When correct: "Excellent work! Well done! You're getting stronger. [Follow-up question]"
When confused: "No worries! Let me explain it differently. [Simpler explanation with example]"
"""),
    );

    _orchestrator = LLMOrchestrator(
      model: model,
      history: history,
      toolHandlers: {
        'search_resources': _searchResources,
        'calculate': _calculate,
      },
    );
  }

  Future<AIResponse> sendMessage(String message, {Map<String, dynamic>? context, Uint8List? attachmentBytes, String? mimeType}) async {
    try {
      String prompt = message;
      if (context != null) {
        String contextStr = "[Context:";
        if (context['grade'] != null) contextStr += " Grade ${context['grade']},";
        if (context['educationLevel'] != null) contextStr += " Level ${context['educationLevel']},";
        if (context['subject'] != null) contextStr += " Subject: ${context['subject']}";
        contextStr += "]";
        prompt = "$contextStr $message";
      }
      
      Content content;
      if (attachmentBytes != null && mimeType != null) {
        if (mimeType.startsWith('text/')) {
           // For text files, decode and append to prompt
           String textContent = String.fromCharCodes(attachmentBytes);
           content = Content.text("$prompt\n\n[Attached File Content]:\n$textContent");
        } else {
           // For images and PDFs
           content = Content.multi([
            TextPart(prompt),
            DataPart(mimeType, attachmentBytes),
          ]);
        }
      } else if (attachmentBytes != null) {
        // Fallback for legacy image calls
        content = Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', attachmentBytes),
        ]);
      } else {
        content = Content.text(prompt);
      }

      final response = await _orchestrator.sendMessage(content);
      final responseText = response.text ?? "I'm having trouble thinking right now. Can you ask again?";
      
      return _parseResponseWithVisualization(responseText);
    } catch (e) {
      print('Error in sendMessage: $e');
      return AIResponse(
        text: "Oh no! My connection is a bit shaky. Please try again.",
      );
    }
  }

  Future<Map<String, Object?>> _searchResources(Map<String, Object?> args) async {
    final grade = (args['grade'] as num).toInt();
    final subject = args['subject'] as String?;
    
    try {
      final resources = await _firestoreService.getResources(grade, subject: subject);
      if (resources.isEmpty) {
        return {'result': 'No resources found for Grade $grade ${subject != null ? 'in $subject' : ''}.'};
      }
      return {
        'result': resources.map((r) => '${r.title} (${r.type}) - ${r.downloadUrl}').join('\n')
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _calculate(Map<String, Object?> args) async {
    final expression = args['expression'] as String;
    try {
      GrammarParser p = GrammarParser();
      Expression exp = p.parse(expression.replaceAll('×', '*').replaceAll('÷', '/'));
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      return {'result': eval};
    } catch (e) {
      return {'error': 'Invalid expression: $e'};
    }
  }

  // Request specific visualization for a concept
  Future<VisualExample> requestVisualization(
    String concept, 
    {required String subject, required int grade}
  ) async {
    try {
      final prompt = """
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

      final response = await _orchestrator.sendMessage(Content.text(prompt));
      final responseText = response.text ?? "";
      
      return _parseVisualExample(responseText, concept);
    } catch (e) {
      print('Error in requestVisualization: $e');
      return VisualExample(
        title: concept,
        description: "Let's explore this concept together!",
      );
    }
  }

  // Get examples with diagrams
  Future<List<VisualExample>> getExamplesWithDiagrams(
    String topic,
    {required int count, required String subject}
  ) async {
    try {
      final prompt = """
Give me $count visual examples for: $topic (Subject: $subject)

For each example, provide:
- A title
- Simple explanation
- Step-by-step breakdown
- Use Kenyan context (matatus, M-Pesa, ugali, football, etc.)

Make it fun and easy to visualize!
""";

      final response = await _orchestrator.sendMessage(Content.text(prompt));
      final responseText = response.text ?? "";
      
      return _parseMultipleExamples(responseText);
    } catch (e) {
      print('Error in getExamplesWithDiagrams: $e');
      return [];
    }
  }

  Future<String> analyzeImage(Uint8List imageBytes, String prompt) async {
    try {
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await _orchestrator.generateContent(content);
      return response.text ?? "I couldn't analyze the image. Please try again.";
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
        final steps = match.group(1)!.split(RegExp(r'\d+\.')).where((s) => s.trim().isNotEmpty).toList();
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
    final stepsMatch = RegExp(r'STEPS:([\s\S]+?)(?=DATA:|$)').firstMatch(responseText);
    
    final steps = <String>[];
    if (stepsMatch != null) {
      final stepsText = stepsMatch.group(1)!;
      steps.addAll(
        stepsText.split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.replaceAll(RegExp(r'^\d+\.\s*'), '').trim())
          .toList()
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
      
      final lines = section.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) continue;
      
      final title = lines.first.replaceAll(RegExp(r'^\*+\s*'), '').trim();
      final description = lines.length > 1 ? lines[1].trim() : '';
      final steps = lines.skip(2).map((l) => l.replaceAll(RegExp(r'^\d+\.\s*[-•]\s*'), '').trim()).toList();
      
      examples.add(VisualExample(
        title: title,
        description: description,
        steps: steps,
      ));
    }
    
    return examples;
  }

  // Reset chat session
  void resetChat() {
    _orchestrator.reset();
  }
}
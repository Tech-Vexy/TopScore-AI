import 'package:google_generative_ai/google_generative_ai.dart';

/// A handler for a specific tool function.
typedef ToolHandler = Future<Map<String, Object?>> Function(Map<String, Object?> args);

/// Orchestrates the interaction between the LLM and the available tools.
/// Manages the chat session and the function calling loop.
class LLMOrchestrator {
  final GenerativeModel _model;
  final Map<String, ToolHandler> _toolHandlers;
  late ChatSession _chat;

  LLMOrchestrator({
    required GenerativeModel model,
    required Map<String, ToolHandler> toolHandlers,
    List<Content>? history,
  }) : _model = model,
       _toolHandlers = toolHandlers {
    _chat = _model.startChat(history: history);
  }

  void reset({List<Content>? history}) {
    _chat = _model.startChat(history: history);
  }


  /// Sends a message to the LLM and handles any resulting function calls.
  Future<GenerateContentResponse> sendMessage(Content content) async {
    var response = await _chat.sendMessage(content);

    // Orchestration loop: Keep executing tools until the model provides a final text response
    while (response.functionCalls.isNotEmpty) {
      final functionCalls = response.functionCalls;
      final functionResponses = <FunctionResponse>[];

      for (final call in functionCalls) {
        final handler = _toolHandlers[call.name];
        Map<String, Object?> result;
        
        if (handler != null) {
          try {
            print('Orchestrator: Executing tool ${call.name} with args ${call.args}');
            result = await handler(call.args);
          } catch (e) {
            print('Orchestrator: Error executing tool ${call.name}: $e');
            result = {'error': e.toString()};
          }
        } else {
          print('Orchestrator: Tool ${call.name} not found');
          result = {'error': 'Tool not found: ${call.name}'};
        }
        
        functionResponses.add(FunctionResponse(call.name, result));
      }

      // Send tool outputs back to the model
      response = await _chat.sendMessage(
        Content.functionResponses(functionResponses),
      );
    }

    return response;
  }

  /// Generates content for a single prompt without chat history (e.g. image analysis)
  Future<GenerateContentResponse> generateContent(List<Content> content) async {
    return _model.generateContent(content);
  }
}

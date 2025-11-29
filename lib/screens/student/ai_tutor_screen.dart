import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../constants/colors.dart';
import '../../services/ai_service.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';


class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key});

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final ImagePicker _picker = ImagePicker();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;
  bool _isHistoryLoading = true;
  late AIService _aiService;
  
  XFile? _selectedImage;
  Uint8List? _selectedFileBytes;
  String? _selectedMimeType;
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;
    
    List<Content> history = [];
    
    if (user != null) {
      try {
        final chatDocs = await _firestoreService.getChatHistory(user.uid);
        
        for (var doc in chatDocs) {
          final text = doc['text'] as String;
          final isUser = doc['isUser'] as bool;
          
          VisualizationType? visType;
          if (doc['visualizationType'] != null) {
            // Handle enum conversion safely
            try {
              visType = VisualizationType.values.firstWhere(
                (e) => e.toString() == doc['visualizationType']
              );
            } catch (_) {}
          }

          // Add to UI messages
          _messages.add(ChatMessage(
            text: text,
            isUser: isUser,
            visualizationType: visType,
            visualizationData: doc['visualizationData'],
          ));

          // Add to AI history
          if (isUser) {
            history.add(Content.text(text));
          } else {
            history.add(Content.model([TextPart(text)]));
          }
        }
      } catch (e) {
        print("Error loading chat history: $e");
      }
    }

    if (_messages.isEmpty) {
       _messages.add(
        ChatMessage(
          text: "Hello! I'm Teacher Joy. How can I help you with your studies today?",
          isUser: false,
        ),
      );
    }

    _aiService = AIService(history: history);
    
    if (mounted) {
      setState(() {
        _isHistoryLoading = false;
      });
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImage = pickedFile;
          _selectedFileBytes = bytes;
          _selectedFileName = pickedFile.name;
          _selectedMimeType = 'image/jpeg';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
        withData: true,
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        setState(() {
          _selectedFileBytes = file.bytes;
          _selectedFileName = file.name;
          _selectedMimeType = _getMimeType(file.extension);
          _selectedImage = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }



  String _getMimeType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'txt': return 'text/plain';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default: return 'application/octet-stream';
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedImage = null;
      _selectedFileBytes = null;
      _selectedFileName = null;
      _selectedMimeType = null;
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedFileBytes == null) return;

    final fileBytes = _selectedFileBytes;
    final imageFile = _selectedImage;
    final mimeType = _selectedMimeType;
    final fileName = _selectedFileName;

    _messageController.clear();
    _clearSelection();

    setState(() {
      _messages.add(ChatMessage(
        text: text, 
        isUser: true,
        imageBytes: fileBytes,
        imagePath: imageFile?.path,
        mimeType: mimeType,
        fileName: fileName,
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      // Get user context if available
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.userModel;
      
      // Save user message to Firestore
      if (user != null) {
        _firestoreService.saveChatMessage(user.uid, {
          'text': text,
          'isUser': true,
          // Note: We are not saving file bytes to Firestore to avoid size limits.
          // In a production app, upload to Storage and save URL.
        });
      }
      
      Map<String, dynamic>? contextData;
      if (user != null) {
        contextData = {
          'grade': user.grade,
          'educationLevel': user.educationLevel,
          'subject': 'General',
        };
      }

      final response = await _aiService.sendMessage(
        text, 
        context: contextData,
        attachmentBytes: fileBytes,
        mimeType: mimeType,
      );
      
      // Save AI response to Firestore
      if (user != null) {
        _firestoreService.saveChatMessage(user.uid, {
          'text': response.text,
          'isUser': false,
          'visualizationType': response.visualizationType?.toString(),
          'visualizationData': response.visualizationData,
        });
      }
      
      setState(() {
        _messages.add(ChatMessage(
          text: response.text,
          isUser: false,
          visualizationType: response.visualizationType,
          visualizationData: response.visualizationData,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "I'm having trouble connecting right now. Please try again.",
          isUser: false,
          isError: true,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isHistoryLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
        children: [
          // Chat Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Teacher Joy',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'AI Tutor • Always here to help',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Loading Indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Teacher Joy is thinking...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedFileBytes != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    height: 100,
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _selectedMimeType?.startsWith('image/') == true
                                  ? Image.memory(
                                      _selectedFileBytes!,
                                      height: 100,
                                      width: 100,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      height: 100,
                                      width: 100,
                                      color: Colors.grey[200],
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.insert_drive_file, color: Colors.grey[600], size: 32),
                                          const SizedBox(height: 4),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            child: Text(
                                              _selectedFileName ?? 'File',
                                              style: TextStyle(fontSize: 10, color: Colors.grey[800]),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: _clearSelection,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file, color: AppColors.primary),
                      onPressed: _pickFile,
                    ),

                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary),
                      onPressed: () => _pickImage(ImageSource.gallery),
                    ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Ask a question...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white),
                        onPressed: _isLoading ? null : _sendMessage,
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

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.imageBytes != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: message.mimeType?.startsWith('image/') == true || message.mimeType == null
                      ? Image.memory(
                          message.imageBytes!,
                          width: 200,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 200,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.insert_drive_file, color: Colors.grey[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  message.fileName ?? 'Attached File',
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: message.isUser ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!message.isUser) ...[
                    const Text(
                      'Teacher Joy',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  MarkdownBody(
                    data: message.text,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: message.isUser ? Colors.white : AppColors.text,
                        fontSize: 15,
                      ),
                      strong: TextStyle(
                        color: message.isUser ? Colors.white : AppColors.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Add visualizations if present
                  if (message.visualizationType != null && message.visualizationData != null)
                    _buildVisualization(message.visualizationType!, message.visualizationData),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualization(VisualizationType type, dynamic data) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: _buildVisualizationContent(type, data),
    );
  }

  Widget _buildVisualizationContent(VisualizationType type, dynamic data) {
    switch (type) {
      case VisualizationType.diagram:
        return _buildDiagram(data.toString());
      
      case VisualizationType.stepByStep:
        return _buildSteps(data as List<String>);
      
      case VisualizationType.mathEquation:
        return _buildMathEquation(data.toString());
      
      case VisualizationType.comparison:
        return _buildComparison(data.toString());
      
      case VisualizationType.timeline:
        return _buildTimeline(data);
      
      case VisualizationType.chart:
        return _buildChart(data);
    }
  }

  Widget _buildDiagram(String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image_outlined, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            const Text(
              'Visual Diagram',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.text,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSteps(List<String> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.list_alt_rounded, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            const Text(
              'Step by Step',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      step.trim(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMathEquation(String equation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calculate_rounded, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            const Text(
              'Math Expression',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              equation,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparison(String comparison) {
    final parts = comparison.split(' vs ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.compare_arrows_rounded, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            const Text(
              'Comparison',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (parts.length == 2) ...[
          _buildComparisonItem(parts[0].trim(), Colors.blue),
          const SizedBox(height: 8),
          const Center(
            child: Icon(Icons.swap_vert_rounded, color: Colors.grey, size: 20),
          ),
          const SizedBox(height: 8),
          _buildComparisonItem(parts[1].trim(), Colors.green),
        ] else
          Text(
            comparison,
            style: const TextStyle(fontSize: 14, color: AppColors.text),
          ),
      ],
    );
  }

  Widget _buildComparisonItem(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: color.withValues(alpha: 0.9),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTimeline(dynamic data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.timeline_rounded, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            const Text(
              'Timeline',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          data.toString(),
          style: const TextStyle(fontSize: 14, color: AppColors.text),
        ),
      ],
    );
  }

  Widget _buildChart(dynamic data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bar_chart_rounded, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            const Text(
              'Chart',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          data.toString(),
          style: const TextStyle(fontSize: 14, color: AppColors.text),
        ),
      ],
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final VisualizationType? visualizationType;
  final dynamic visualizationData;
  final Uint8List? imageBytes;
  final String? imagePath;
  final String? mimeType;
  final String? fileName;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.visualizationType,
    this.visualizationData,
    this.imageBytes,
    this.imagePath,
    this.mimeType,
    this.fileName,
  });
}
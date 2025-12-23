import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../services/agent_service.dart';
import '../models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final AgentService _agentService = AgentService();
  
  bool _isConnected = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _agentService.connect();
  }

  void _setupListeners() {
    // Listen for connection status
    _agentService.statusStream.listen((connected) {
      setState(() => _isConnected = connected);
      if (connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connected to Agent 🟢"), duration: Duration(seconds: 1)),
        );
      }
    });

    // Listen for incoming messages
    _agentService.messageStream.listen((data) {
      _handleServerMessage(data);
    });
  }

  void _handleServerMessage(Map<String, dynamic> data) {
    setState(() {
      final type = data['type'];
      
      // 1. Resume: Server sends full history on reconnect
      if (type == 'resume') {
        _messages.clear(); // Or merge intelligently
        if (data['query'] != null) {
          _messages.add(ChatMessage(
            id: 'hist_u', 
            sender: MessageSender.user, 
            content: data['query']
          ));
        }
        _messages.add(ChatMessage(
          id: 'hist_ai', 
          sender: MessageSender.ai, 
          content: data['content'] ?? ""
        ));
      } 
      
      // 2. Chunk: Real-time typing
      else if (type == 'chunk') {
        // Find the last AI message, or create one if missing
        if (_messages.isEmpty || _messages.last.sender != MessageSender.ai) {
          _messages.add(ChatMessage(
            id: DateTime.now().toString(), 
            sender: MessageSender.ai, 
            content: ""
          ));
        }
        
        // Append text
        _messages.last.content += data['content'] ?? "";
        _messages.last.isThinking = false;
      }
      
      // 3. Status: Done/Thinking
      else if (type == 'status') {
        if (data['status'] == 'complete') {
          if (_messages.isNotEmpty && _messages.last.sender == MessageSender.ai) {
            _messages.last.isThinking = false;
          }
        } else if (data['status'] == 'thinking' || data['status'] == 'researching') {
          if (_messages.isNotEmpty && _messages.last.sender == MessageSender.ai) {
            _messages.last.isThinking = true;
          }
        }
      }
      
      // 4. Error handling
      else if (type == 'error') {
        _messages.add(ChatMessage(
          id: DateTime.now().toString(),
          sender: MessageSender.ai,
          content: "Error: ${data['content'] ?? 'Unknown error occurred'}",
        ));
      }
    });
    
    // Auto-scroll to bottom
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

  void _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    // Convert image to base64 if present
    String? base64Image;
    if (_selectedImage != null) {
      final bytes = await _selectedImage!.readAsBytes();
      base64Image = "data:image/jpeg;base64,${base64Encode(bytes)}";
    }

    // Add UI Message
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().toString(),
        sender: MessageSender.user,
        content: text,
        imageUrl: _selectedImage?.path, // For local preview
      ));
      
      // Add "Thinking" placeholder for AI
      _messages.add(ChatMessage(
        id: "thinking", 
        sender: MessageSender.ai, 
        content: "", 
        isThinking: true
      ));
    });

    _agentService.sendMessage(text, imageBase64: base64Image);

    _textController.clear();
    setState(() => _selectedImage = null);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("TopScore AI"),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _isConnected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _MessageBubble(message: msg);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_selectedImage != null)
            Container(
              height: 100,
              padding: const EdgeInsets.only(bottom: 8),
              alignment: Alignment.centerLeft,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _selectedImage = null),
                    ),
                  )
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.photo_camera),
                onPressed: _pickImage,
                tooltip: "Attach image",
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    hintText: "Ask a math question...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20))
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.send, 
                  color: _isConnected ? Colors.blue : Colors.grey
                ),
                onPressed: _isConnected ? _handleSend : null,
                tooltip: "Send message",
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85
        ),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(message.imageUrl!), 
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            
            if (message.isThinking)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Thinking ", 
                    style: TextStyle(fontStyle: FontStyle.italic)
                  ),
                  SizedBox(
                    width: 14, 
                    height: 14, 
                    child: CircularProgressIndicator(strokeWidth: 2)
                  ),
                ],
              )
            else if (message.content.isNotEmpty)
              MarkdownBody(
                data: message.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 16),
                  code: const TextStyle(
                    backgroundColor: Colors.black12, 
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  codeblockPadding: const EdgeInsets.all(8),
                  blockquote: const TextStyle(
                    color: Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                  h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  listBullet: const TextStyle(fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

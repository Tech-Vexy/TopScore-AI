import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:universal_io/io.dart';
import 'package:http/http.dart' as http;
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/auth_provider.dart';
import 'latex_builder.dart';
import 'message_model.dart';
import 'websocket_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  late final WebSocketService _wsService;
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isTyping = false;
  bool _isRecording = false;
  String? _currentStreamingMessageId;
  String? _statusMessage;
  
  // History
  List<Map<String, dynamic>> _threads = [];
  bool _isLoadingHistory = false;
  
  // Settings
  String _modelPreference = 'smart'; // 'fast' or 'smart'
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _wsService = WebSocketService(userId: authProvider.userModel?.uid ?? 'guest');
    _wsService.connect();
    _wsService.messageStream.listen(_handleIncomingMessage);
    _wsService.isConnectedStream.listen((connected) {
      setState(() {
        _isConnected = connected;
      });
    });
    _loadHistory();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(1.0);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }
  
  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    final threads = await _wsService.fetchThreads();
    setState(() {
      _threads = threads;
      _isLoadingHistory = false;
    });
  }
  
  Future<void> _loadThread(String threadId) async {
    setState(() {
      _messages.clear();
      _wsService.setThreadId(threadId);
    });
    
    final messages = await _wsService.fetchMessages(threadId);
    
    setState(() {
      _messages.addAll(messages.map((m) => ChatMessage(
        id: const Uuid().v4(),
        text: m['content'],
        isUser: m['type'] == 'user',
        timestamp: DateTime.now(), // We don't have real timestamps from backend yet
      )));
    });
    
    // Close drawer if open
    if (Scaffold.of(context).isDrawerOpen) {
      Navigator.pop(context);
    }
  }
  
  void _startNewChat() {
    final newId = const Uuid().v4();
    _wsService.setThreadId(newId);
    setState(() {
      _messages.clear();
    });
    Navigator.pop(context); // Close drawer
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    setState(() {
      switch (data['type']) {
        case 'status':
          _statusMessage = data['content'];
          break;
        case 'token':
          _statusMessage = null;
          _handleToken(data['content']);
          break;
        case 'transcription':
          _addSystemMessage('Transcription: ${data['content']}');
          break;
        case 'audio_response':
          // Handle TTS response
          // content is "data:audio/mp3;base64,..."
          _playAudioFromBase64(data['content']);
          break;
        case 'error':
          _addSystemMessage('Error: ${data['content']}');
          break;
        case 'end_turn':
          _currentStreamingMessageId = null;
          _isTyping = false;
          _statusMessage = null;
          break;
      }
    });
  }

  void _handleToken(String token) {
    if (_currentStreamingMessageId == null) {
      // Start a new AI message
      final newMessage = ChatMessage(
        id: const Uuid().v4(),
        text: token,
        isUser: false,
        timestamp: DateTime.now(),
      );
      _messages.add(newMessage);
      _currentStreamingMessageId = newMessage.id;
      _isTyping = true;
    } else {
      // Append to existing message
      final index = _messages.indexWhere((m) => m.id == _currentStreamingMessageId);
      if (index != -1) {
        final oldMsg = _messages[index];
        _messages[index] = ChatMessage(
          id: oldMsg.id,
          text: oldMsg.text + token,
          isUser: oldMsg.isUser,
          timestamp: oldMsg.timestamp,
          audioUrl: oldMsg.audioUrl,
          imageUrl: oldMsg.imageUrl,
        );
      }
    }
    _scrollToBottom();
  }

  void _addSystemMessage(String text) {
    _messages.add(ChatMessage(
      id: const Uuid().v4(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    ));
    _scrollToBottom();
  }

  void _sendMessage({String? text, String? imageData}) {
    final messageText = text ?? _textController.text;
    if (messageText.trim().isEmpty && imageData == null) return;

    if (text == null) _textController.clear();

    setState(() {
      _messages.add(ChatMessage(
        id: const Uuid().v4(),
        text: messageText,
        isUser: true,
        timestamp: DateTime.now(),
        imageUrl: imageData != null ? 'Image Attached' : null, // Placeholder for UI
      ));
      _isTyping = true;
    });

    _wsService.sendMessage(
      message: messageText, 
      imageData: imageData,
      modelPreference: _modelPreference,
    );
    _scrollToBottom();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        withData: true, // Important for Web
      );

      if (result != null) {
        String? base64Image;
        String? extension = result.files.single.extension;
        
        if (kIsWeb) {
          // On Web, use bytes directly
          if (result.files.single.bytes != null) {
            base64Image = base64Encode(result.files.single.bytes!);
          }
        } else {
          // On Mobile/Desktop, read from path
          if (result.files.single.path != null) {
            File file = File(result.files.single.path!);
            final bytes = await file.readAsBytes();
            base64Image = base64Encode(bytes);
          }
        }

        if (base64Image != null) {
          final dataUri = 'data:image/$extension;base64,$base64Image';
          _sendMessage(text: "Sent an image", imageData: dataUri);
        }
      }
    } catch (e) {
      print('Error picking file: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        // On Web, path is ignored or handled differently by record package
        // On Mobile, we need a valid path
        String path = '';
        if (!kIsWeb) {
          final tempDir = await getTemporaryDirectory();
          path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        } else {
          // For web, we can provide a dummy name or it might be ignored depending on implementation
          path = 'audio_recording.m4a';
        }
        
        await _audioRecorder.start(const RecordConfig(), path: path);
        
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      print('Error starting record: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        String? base64Audio;
        
        if (kIsWeb) {
          // On Web, path is a blob URL. Fetch it.
          try {
            final response = await http.get(Uri.parse(path));
            if (response.statusCode == 200) {
              base64Audio = base64Encode(response.bodyBytes);
            }
          } catch (e) {
            print('Error fetching blob: $e');
          }
        } else {
          // On Mobile, path is a file path
          final file = File(path);
          if (await file.exists()) {
            final audioBytes = await file.readAsBytes();
            base64Audio = base64Encode(audioBytes);
          }
        }

        if (base64Audio != null) {
          // Add a message bubble for the audio
          setState(() {
            _messages.add(ChatMessage(
              id: const Uuid().v4(),
              text: '🎤 Audio Message',
              isUser: true,
              timestamp: DateTime.now(),
              audioUrl: path, // Store local path/blob for playback
            ));
            _isTyping = true;
          });

          final audioData = 'data:audio/m4a;base64,$base64Audio';
          
          _wsService.sendMessage(
            message: '', 
            audioData: audioData,
          );
          _scrollToBottom();
        }
      }
    } catch (e) {
      print('Error stopping record: $e');
    }
  }

  Future<void> _playAudio(String url) async {
    try {
      if (kIsWeb) {
        // On Web, always use UrlSource (works for http and blob:)
        await _audioPlayer.play(UrlSource(url));
      } else {
        if (!url.startsWith('http') && !url.startsWith('data:')) {
           await _audioPlayer.play(DeviceFileSource(url));
        } else {
           await _audioPlayer.play(UrlSource(url));
        }
      }
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  Future<void> _playAudioFromBase64(String dataUri) async {
    try {
      final base64Str = dataUri.split(',').last;
      final bytes = base64Decode(base64Str);
      await _audioPlayer.play(BytesSource(bytes));
    } catch (e) {
      print('Error playing base64 audio: $e');
    }
  }
  
  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
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
  void dispose() {
    _wsService.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('AI TUTOR', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 0,
        foregroundColor: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startNewChat,
            tooltip: 'New Chat',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<String>(
              value: _modelPreference,
              underline: Container(),
              icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurface.withOpacity(0.6)),
              dropdownColor: theme.cardColor,
              items: [
                DropdownMenuItem(value: 'fast', child: Text('Fast', style: TextStyle(color: theme.colorScheme.onSurface))),
                DropdownMenuItem(value: 'smart', child: Text('Smart', style: TextStyle(color: theme.colorScheme.onSurface))),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _modelPreference = value);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isConnected ? AppColors.googleGreen : AppColors.googleRed,
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.school, color: Colors.white, size: 48),
                    const SizedBox(height: 10),
                    Text(
                      'Chat History',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _isLoadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _threads.length,
                      itemBuilder: (context, index) {
                        final thread = _threads[index];
                        final isSelected = thread['thread_id'] == _wsService.threadId;
                        return ListTile(
                          leading: Icon(
                            Icons.chat_bubble_outline,
                            color: isSelected ? AppColors.googleBlue : theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          title: Text(
                            thread['title'] ?? 'Untitled Chat',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppColors.googleBlue : theme.colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            thread['updated_at']?.toString().split(' ')[0] ?? '',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                          ),
                          tileColor: isSelected ? AppColors.googleBlue.withOpacity(0.1) : null,
                          onTap: () => _loadThread(thread['thread_id']),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message, theme);
              },
            ),
          ),
          if (_isTyping && _currentStreamingMessageId == null)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const _TypingIndicator(),
              ),
            ),
          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.googleBlue),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _statusMessage!,
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontStyle: FontStyle.italic, fontSize: 12),
                  ),
                ],
              ),
            ),
          _buildInputArea(theme),
        ],
      ),
    );
  }

  String _preprocessText(String text) {
    return text
        .replaceAll(r'\[', r'$$')
        .replaceAll(r'\]', r'$$')
        .replaceAll(r'\(', r'$')
        .replaceAll(r'\)', r'$');
  }

  Widget _buildMessageBubble(ChatMessage message, ThemeData theme) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser ? AppColors.googleBlue : theme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.audioUrl != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    color: isUser ? Colors.white : AppColors.googleBlue,
                    onPressed: () => _playAudio(message.audioUrl!),
                  ),
                  Text("Audio Message", style: TextStyle(color: isUser ? Colors.white : theme.colorScheme.onSurface)),
                ],
              ),
            if (message.imageUrl != null)
               Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image, color: isUser ? Colors.white : theme.colorScheme.onSurface),
                  SizedBox(width: 8),
                  Text("Image Attached", style: TextStyle(color: isUser ? Colors.white : theme.colorScheme.onSurface)),
                ],
              ),
            if (message.text.isNotEmpty)
              isUser 
                ? Text(
                    message.text,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarkdownBody(
                        data: _preprocessText(message.text),
                        builders: {
                          'latex': LatexElementBuilder(),
                        },
                        extensionSet: md.ExtensionSet(
                          [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                          [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, LatexInlineSyntax()],
                        ),
                        styleSheet: MarkdownStyleSheet(
                          p: GoogleFonts.outfit(fontSize: 16, color: theme.colorScheme.onSurface),
                          code: GoogleFonts.firaCode(backgroundColor: theme.colorScheme.surfaceContainerHighest),
                          codeblockDecoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.volume_up, size: 20),
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            onPressed: () => _speak(message.text),
                            tooltip: 'Read Aloud',
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            onPressed: () => _copyToClipboard(message.text),
                            tooltip: 'Copy',
                          ),
                        ],
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              onPressed: _pickFile,
              tooltip: 'Upload Image',
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textController,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Ask anything...',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onLongPress: _startRecording,
              onLongPressUp: _stopRecording,
              child: CircleAvatar(
                backgroundColor: _isRecording ? AppColors.googleRed : AppColors.googleBlue,
                child: IconButton(
                  icon: Icon(_isRecording ? Icons.mic : (_textController.text.isEmpty ? Icons.mic : Icons.send)),
                  color: Colors.white,
                  onPressed: () {
                    if (_textController.text.isNotEmpty) {
                      _sendMessage();
                    } else {
                      // Tap to toggle recording if preferred over long press
                      if (_isRecording) {
                        _stopRecording();
                      } else {
                        _startRecording();
                      }
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      )..repeat(reverse: true);
    });

    // Stagger starts
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: _controllers[index], curve: Curves.easeInOut),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.googleBlue,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

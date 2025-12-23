import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:record/record.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'camera_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:universal_io/io.dart';
import 'package:http/http.dart' as http;
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import '../providers/auth_provider.dart';
import 'latex_builder.dart';
import 'message_model.dart';
import 'websocket_service.dart';
import '../services/ocr_service.dart';
import '../utils/paste_handler/paste_handler.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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

  // Streaming
  final List<String> _tokenQueue = [];
  Timer? _typingTimer;
  bool _pendingTurnEnd = false;

  // WebSocket Subscriptions
  StreamSubscription? _wsMessageSub;
  StreamSubscription? _wsConnectionSub;

  // History
  List<Map<String, dynamic>> _threads = [];
  bool _isLoadingHistory = false;
  bool _isLoadingMessages = false;

  // Settings
  String _modelPreference = 'smart';
  final FocusNode _messageFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _wsService = WebSocketService(
      userId: authProvider.userModel?.uid ?? 'guest',
    );
    _wsService.connect();
    _wsMessageSub = _wsService.messageStream.listen(_handleIncomingMessage);
    // Connection listener removed as _isConnected is unused
    _loadHistory();
    _initTts();

    // Handle Enter key to send message
    _messageFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        if (_textController.text.trim().isNotEmpty) {
          _sendMessage();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    // Register generic paste handler (currently Web only)
    registerPasteHandler(
      onImagePasted: (dataUri) {
        if (!mounted) return;
        // Check if we can send directly
        // Usually we want to confirm or just send
        // Since the user just pasted, sending immediately is acceptable or we could preview
        // Current implementation of _pickFile sends immediately, so we follow that pattern.
        _sendMessage(text: "Pasted Image", imageData: dataUri);
      },
    );
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(1.0);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _saveLastThreadId(String threadId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_thread_id', threadId);
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    final threads = await _wsService.fetchThreads();

    if (!mounted) return;

    setState(() {
      _threads = threads;
      _isLoadingHistory = false;
    });

    // Always start with a new chat
    _startNewChat(closeDrawer: false);
  }

  Future<void> _loadThread(String threadId) async {
    await _saveLastThreadId(threadId);

    // Close the drawer if it was open (for mobile/tablet) on selection
    if (mounted && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.pop(context);
    } // And also close our custom web drawer if we want that behavior:
    // setState(() => _isSidebarOpen = false); // Optional: uncomment if you want auto-close on web too.

    setState(() {
      _isLoadingMessages = true;
      _messages.clear();
      _wsService.setThreadId(threadId);
    });

    try {
      final messages = await _wsService.fetchMessages(threadId);

      if (!mounted) return;

      setState(() {
        _messages.addAll(
          messages.map(
            (m) => ChatMessage(
              id: const Uuid().v4(),
              text: m['content'],
              isUser: m['type'] == 'user',
              timestamp: DateTime.now(),
            ),
          ),
        );
      });
    } catch (e) {
      // Error processing messages
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }

    // Close drawer if open (original logic)

    // Close drawer if open
    if (mounted && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.pop(context);
    }

    // Slight delay to scroll to bottom after rendering
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _startNewChat({bool closeDrawer = true}) {
    final newId = const Uuid().v4();
    _wsService.setThreadId(newId);
    _saveLastThreadId(newId);

    // Add new thread to the list
    setState(() {
      _messages.clear();
      _threads.insert(0, {
        'thread_id': newId,
        'title': 'New Chat',
        'updated_at': DateTime.now().toIso8601String(),
      });
    });

    if (closeDrawer && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.pop(context); // Close drawer
    }
  }

  void _updateThreadTitle(String firstMessage) {
    final threadIndex = _threads.indexWhere(
      (t) => t['thread_id'] == _wsService.threadId,
    );
    if (threadIndex != -1 && _threads[threadIndex]['title'] == 'New Chat') {
      setState(() {
        _threads[threadIndex]['title'] = firstMessage.length > 30
            ? '${firstMessage.substring(0, 30)}...'
            : firstMessage;
        _threads[threadIndex]['updated_at'] = DateTime.now().toIso8601String();
      });
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    if (data['type'] == 'token' ||
        data['type'] == 'message' ||
        data['type'] == 'chunk') {
      _tokenQueue.add(data['content']);
      if (_typingTimer == null || !_typingTimer!.isActive) {
        _startStreaming();
      }
      return;
    }

    if (data['type'] == 'end_turn') {
      _pendingTurnEnd = true;
      if (_tokenQueue.isEmpty &&
          (_typingTimer == null || !_typingTimer!.isActive)) {
        _finalizeTurn();
      }
      return;
    }

    setState(() {
      switch (data['type']) {
        case 'status':
          _statusMessage = data['content'];
          if (_statusMessage?.contains("Searching Google Drive") ?? false) {
            _statusMessage = "📚 Checking your library...";
          }
          break;
        case 'transcription':
          _addSystemMessage('Transcription: ${data['content']}');
          break;
        case 'audio_response':
          _playAudioFromBase64(data['content']);
          break;
        case 'error':
          _addSystemMessage(data['content']);
          break;
      }
    });
  }

  void _startStreaming() {
    _typingTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_tokenQueue.isEmpty) {
        timer.cancel();
        if (_pendingTurnEnd) {
          _finalizeTurn();
        }
        return;
      }

      int chunk = 1;
      if (_tokenQueue.length > 50) {
        chunk = 5;
      } else if (_tokenQueue.length > 20) {
        chunk = 2;
      }

      String text = "";
      for (int i = 0; i < chunk && _tokenQueue.isNotEmpty; i++) {
        text += _tokenQueue.removeAt(0);
      }

      setState(() {
        _appendStreamingText(text);
      });
      _scrollToBottom();
    });
  }

  void _finalizeTurn() {
    setState(() {
      _currentStreamingMessageId = null;
      _isTyping = false;
      _statusMessage = null;
      _pendingTurnEnd = false;
    });
  }

  void _appendStreamingText(String token) {
    _statusMessage = null;
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
      final index = _messages.indexWhere(
        (m) => m.id == _currentStreamingMessageId,
      );
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
  }

  void _addSystemMessage(String text) {
    _messages.add(
      ChatMessage(
        id: const Uuid().v4(),
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
    _scrollToBottom();
  }

  void _sendMessage({String? text, String? imageData, String? extractedText}) {
    final messageText = text ?? _textController.text;
    if (messageText.trim().isEmpty && imageData == null) return;

    if (text == null) _textController.clear();

    // Update thread title with first message
    if (_messages.isEmpty) {
      _updateThreadTitle(messageText);
    }

    setState(() {
      _messages.add(
        ChatMessage(
          id: const Uuid().v4(),
          text: messageText,
          isUser: true,
          timestamp: DateTime.now(),
          imageUrl: imageData != null
              ? 'Image Attached'
              : null, // Placeholder for UI
        ),
      );
      _isTyping = true;
    });

    _wsService.sendMessage(
      message: messageText,
      imageData: imageData,
      extractedText: extractedText,
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

          // Perform OCR if on Mobile
          String? extractedText;
          if (!kIsWeb && result.files.single.path != null) {
            extractedText = await OCRService.extractTextFromPath(
              result.files.single.path!,
            );
          }

          _sendMessage(
            text: extractedText != null
                ? "Sent an image with text"
                : "Sent an image",
            imageData: dataUri,
            extractedText: extractedText,
          );
        }
      }
    } catch (e) {
      // Error picking file
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CameraScreen()),
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final base64Image = base64Encode(bytes);
        // Default to jpg, typically camera output
        final extension = photo.path.split('.').last;
        final dataUri = 'data:image/$extension;base64,$base64Image';

        // Perform OCR
        String? extractedText;
        if (!kIsWeb) {
          extractedText = await OCRService.extractTextFromPath(photo.path);
        }

        _sendMessage(
          text: extractedText != null
              ? "Sent a photo with text"
              : "Sent a photo",
          imageData: dataUri,
          extractedText: extractedText,
        );
      }
    } catch (e) {
      // Error taking photo
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
          path =
              '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
      // Error starting record
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
            // Error fetching blob
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
            _messages.add(
              ChatMessage(
                id: const Uuid().v4(),
                text: '🎤 Audio Message',
                isUser: true,
                timestamp: DateTime.now(),
                audioUrl: path, // Store local path/blob for playback
              ),
            );
            _isTyping = true;
          });

          final audioData = 'data:audio/m4a;base64,$base64Audio';

          _wsService.sendMessage(message: '', audioData: audioData);
          _scrollToBottom();
        }
      }
    } catch (e) {
      // Error stopping record
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
      // Error playing audio
    }
  }

  Future<void> _playAudioFromBase64(String dataUri) async {
    try {
      final base64Str = dataUri.split(',').last;
      final bytes = base64Decode(base64Str);
      await _audioPlayer.play(BytesSource(bytes));
    } catch (e) {
      // Error playing base64 audio
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
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
    _wsMessageSub?.cancel();
    _wsConnectionSub?.cancel();
    _wsService.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _typingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    removePasteHandler();
    OCRService.dispose();
    super.dispose();
  }

  Future<void> _deleteThread(String threadId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Are you sure you want to delete this chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _wsService.deleteThread(threadId);
      if (success) {
        setState(() {
          _threads.removeWhere((t) => t['thread_id'] == threadId);
        });

        // If we deleted the current thread, switch to another or new chat
        if (_wsService.threadId == threadId) {
          if (_threads.isNotEmpty) {
            _loadThread(_threads.first['thread_id']);
          } else {
            _startNewChat(closeDrawer: false);
          }
        }
      }
    }
  }

  Future<void> _editMessage(ChatMessage message) async {
    final messageIndex = _messages.indexOf(message);
    if (messageIndex == -1) return;

    // Show dialog to edit the message
    final textController = TextEditingController(text: message.text);
    final editedText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: textController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Edit your message...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (editedText == null ||
        editedText.trim().isEmpty ||
        editedText == message.text) {
      textController.dispose();
      return;
    }

    textController.dispose();

    // Clear all messages after the edited message (including AI responses)
    setState(() {
      _messages.removeRange(messageIndex + 1, _messages.length);
      _messages[messageIndex] = ChatMessage(
        id: message.id,
        text: editedText,
        isUser: true,
        timestamp: message.timestamp,
        audioUrl: message.audioUrl,
        imageUrl: message.imageUrl,
      );
      _isTyping = true;
    });

    // Update message in backend and regenerate response
    final success = await _wsService.editMessage(
      threadId: _wsService.threadId,
      messageId: message.id,
      newContent: editedText,
    );

    if (success) {
      // The backend should send the new AI response via WebSocket
      // which will be handled by _handleIncomingMessage
    } else {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to edit message')));
    }
  }

  Future<void> _regenerateResponse(ChatMessage aiMessage) async {
    final messageIndex = _messages.indexOf(aiMessage);
    if (messageIndex == -1 || messageIndex == 0) return;

    // Find the user message that came before this AI response
    ChatMessage? userMessage;
    for (int i = messageIndex - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        userMessage = _messages[i];
        break;
      }
    }

    if (userMessage == null) return;

    // Remove the current AI response and any messages after it
    setState(() {
      _messages.removeRange(messageIndex, _messages.length);
      _isTyping = true;
    });

    // Request regeneration from backend
    final success = await _wsService.regenerateResponse(
      threadId: _wsService.threadId,
    );

    if (success) {
      // The backend will send the new AI response via SSE/WebSocket
    } else {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to regenerate response')),
      );
    }
  }

  Future<void> _provideFeedback(ChatMessage message, int feedbackValue) async {
    final messageIndex = _messages.indexOf(message);
    if (messageIndex == -1) return;

    // Toggle feedback: if same value is clicked again, remove feedback
    final newFeedback = message.feedback == feedbackValue
        ? null
        : feedbackValue;

    // Update message locally
    setState(() {
      _messages[messageIndex] = ChatMessage(
        id: message.id,
        text: message.text,
        isUser: message.isUser,
        timestamp: message.timestamp,
        audioUrl: message.audioUrl,
        imageUrl: message.imageUrl,
        feedback: newFeedback,
      );
    });

    // Send feedback to backend
    final success = await _wsService.sendFeedback(
      threadId: _wsService.threadId,
      messageId: message.id,
      feedback: newFeedback,
    );

    if (!success) {
      // Failed to send feedback
    }
  }

  bool _isSidebarOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _isSidebarOpen ? 260 : 0,
              curve: Curves.easeInOut,
              child: Container(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100]!,
                child: _isSidebarOpen
                    ? _buildSideBar(theme, isDark)
                    : const SizedBox.shrink(),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        if (!_isSidebarOpen)
                          IconButton(
                            icon: Icon(
                              Icons.menu,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            onPressed: () =>
                                setState(() => _isSidebarOpen = true),
                            tooltip: 'Show menu',
                          ),
                        Expanded(
                          child: Center(
                            child: Text(
                              "AI Tutor",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        if (!_isSidebarOpen) const SizedBox(width: 48),
                      ],
                    ),
                  ),

                  Expanded(
                    child: _isLoadingMessages
                        ? Center(
                            child: CircularProgressIndicator(
                              color: theme.primaryColor,
                            ),
                          )
                        : _messages.isEmpty
                        ? _buildEmptyState(isDark)
                        : ListView.builder(
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
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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
                              color: Colors.black.withValues(alpha: 0.05),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.googleBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _statusMessage!,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildInputArea(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: FaIcon(
              FontAwesomeIcons.handSparkles,
              size: 48,
              color: AppColors.accentTeal,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '👋 Welcome!',
            style: GoogleFonts.roboto(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textDark : AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start a conversation or select a thread',
            style: GoogleFonts.roboto(
              fontSize: 16,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          // Quick prompts
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildQuickPrompt(
                'Help me study',
                FontAwesomeIcons.bookOpen,
                isDark,
              ),
              _buildQuickPrompt(
                'Explain a concept',
                FontAwesomeIcons.lightbulb,
                isDark,
              ),
              _buildQuickPrompt(
                'Solve a problem',
                FontAwesomeIcons.calculator,
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompt(String text, IconData icon, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _sendMessage(text: text),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceVariantDark
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.accentTeal.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(icon, size: 14, color: AppColors.accentTeal),
              const SizedBox(width: 8),
              Text(
                text,
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textDark : AppColors.text,
                ),
              ),
            ],
          ),
        ),
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
    final isDark = theme.brightness == Brightness.dark;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isUser ? AppColors.accentGradient : null,
          color: isUser
              ? null
              : (isDark ? AppColors.surfaceElevatedDark : AppColors.surface),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser
                ? const Radius.circular(20)
                : const Radius.circular(4),
            bottomRight: isUser
                ? const Radius.circular(4)
                : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: isUser
                  ? AppColors.accentTeal.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: isUser
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                ),
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
                  Text(
                    "Audio Message",
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            if (message.imageUrl != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.image,
                    color: isUser ? Colors.white : theme.colorScheme.onSurface,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Image Attached",
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            if (message.text.isNotEmpty)
              isUser
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          message.text,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _editMessage(message),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.edit,
                                color: Colors.white70,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Edit",
                                style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarkdownBody(
                          data: _preprocessText(message.text),
                          builders: {'latex': LatexElementBuilder()},
                          extensionSet: md.ExtensionSet(
                            [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                            [
                              ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                              LatexInlineSyntax(),
                            ],
                          ),
                          styleSheet: MarkdownStyleSheet(
                            p: GoogleFonts.outfit(
                              fontSize: 16,
                              color: theme.colorScheme.onSurface,
                            ),
                            code: GoogleFonts.firaCode(
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.dividerColor.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.thumb_up, size: 20),
                              color: message.feedback == 1
                                  ? Colors.green
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.4,
                                    ),
                              onPressed: () => _provideFeedback(message, 1),
                              tooltip: 'Good response',
                            ),
                            IconButton(
                              icon: Icon(Icons.thumb_down, size: 20),
                              color: message.feedback == -1
                                  ? Colors.red
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.4,
                                    ),
                              onPressed: () => _provideFeedback(message, -1),
                              tooltip: 'Poor response',
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              onPressed: () => _regenerateResponse(message),
                              tooltip: 'Regenerate',
                            ),
                            IconButton(
                              icon: const Icon(Icons.volume_up, size: 20),
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              onPressed: () => _speak(message.text),
                              tooltip: 'Read Aloud',
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
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

  Widget _buildSideBar(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar Header: Menu & Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.menu,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                onPressed: () => setState(() => _isSidebarOpen = false),
                tooltip: 'Hide menu',
              ),
              // Search icon placeholder
            ],
          ),
        ),

        // New Chat Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: InkWell(
            onTap: _startNewChat,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Icon(Icons.add, size: 20, color: theme.colorScheme.onSurface),
                  const SizedBox(width: 12),
                  Text(
                    Provider.of<AuthProvider>(
                              context,
                            ).userModel?.preferredLanguage ==
                            'sw'
                        ? "Mazungumzo Mapya"
                        : "New chat",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Sections
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chats History
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                  child: Text(
                    "Chats",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                _isLoadingHistory
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.primaryColor,
                          ),
                        ),
                      )
                    : _threads.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          "No chats yet",
                          style: TextStyle(color: theme.disabledColor),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _threads.length,
                        itemBuilder: (context, index) {
                          final thread = _threads[index];
                          final isSelected =
                              thread['thread_id'] == _wsService.threadId;
                          return InkWell(
                            onTap: () => _loadThread(thread['thread_id']),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      thread['title'] ?? 'New Chat',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isSelected
                                            ? theme.primaryColor
                                            : theme.colorScheme.onSurface,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () =>
                                        _deleteThread(thread['thread_id']),
                                    tooltip: 'Delete chat',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final containerColor = isDark
        ? const Color(0xFF1E1E1E)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Plus Button with Popup Menu
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.add,
                  size: 24,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                offset: const Offset(0, -200), // Adjust to appear above
                color: theme.colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'upload',
                    child: Row(
                      children: [
                        Icon(
                          Icons.attach_file_rounded,
                          color: theme.colorScheme.onSurface,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Upload files',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'drive',
                    child: Row(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.googleDrive,
                          color: theme.colorScheme.onSurface,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Add from Drive',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'photos',
                    child: Row(
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          color: theme.colorScheme.onSurface,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Photos',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'camera',
                    child: Row(
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          color: theme.colorScheme.onSurface,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Camera',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'upload':
                      _pickFile();
                      break;
                    case 'drive':
                      // Drive integration
                      break;
                    case 'photos':
                      _pickFile();
                      break;
                    case 'camera':
                      _takePhoto();
                      break;
                  }
                },
              ),

              const SizedBox(width: 12),

              // Text Field
              Expanded(
                child: TextField(
                  focusNode: _messageFocusNode,
                  controller: _textController,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  maxLines: 6,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText:
                        Provider.of<AuthProvider>(
                              context,
                            ).userModel?.preferredLanguage ==
                            'sw'
                        ? 'Uliza chochote...'
                        : 'Ask anything...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (text) => setState(() {}),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),

              const SizedBox(width: 12),

              // Mic Button
              if (_textController.text.isEmpty) ...[
                IconButton(
                  icon: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: _isRecording
                        ? Colors.red
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  tooltip: _isRecording ? 'Stop recording' : 'Voice input',
                ),
                const SizedBox(width: 8),
              ],

              // Send Button
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _textController.text.isEmpty && !_isRecording
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.1)
                      : AppColors.primary,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: FaIcon(
                    FontAwesomeIcons.arrowRight,
                    size: 14,
                    color: _textController.text.isEmpty && !_isRecording
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                        : Colors.white,
                  ),
                  onPressed: () {
                    if (_textController.text.isNotEmpty) {
                      _sendMessage();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Model Selector
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.psychology,
                  color: isDark ? Colors.white70 : Colors.black54,
                  size: 24,
                ),
                tooltip: 'Select Model',
                onSelected: (val) => setState(() => _modelPreference = val),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'fast', child: Text('⚡ Fast')),
                  const PopupMenuItem(value: 'smart', child: Text('🧠 Smart')),
                  const PopupMenuItem(
                    value: 'vision',
                    child: Text('👁️ Vision'),
                  ),
                  const PopupMenuItem(
                    value: 'deep_research',
                    child: Text('🕵️‍♂️ Deep Research'),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
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

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
        lowerBound: 0.4,
      );
    });

    // Stagger starts
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _controllers[i].repeat(reverse: true);
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
          scale: CurvedAnimation(
            parent: _controllers[index],
            curve: Curves.easeInOut,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.accentTeal,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

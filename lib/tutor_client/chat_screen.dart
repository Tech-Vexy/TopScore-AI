import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:record/record.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'camera_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:universal_io/io.dart';
import 'package:http/http.dart' as http;
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';

import '../constants/colors.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/network_aware_image.dart';

import 'message_model.dart';
import 'websocket_service.dart';

import '../utils/paste_handler/paste_handler.dart';
import '../widgets/quiz_widget.dart';
import '../widgets/math_stepper_widget.dart';
import '../utils/markdown/mermaid_builder.dart';
import '../widgets/math_markdown.dart';

import '../widgets/virtual_lab/video_carousel.dart';
import '../../models/video_result.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic>? chatThread;
  final File? initialImageFile;
  final XFile? initialImage; // NEW: Cross-platform image
  final String? initialMessage;

  const ChatScreen({
    super.key,
    this.chatThread,
    this.initialImageFile,
    this.initialImage,
    this.initialMessage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Smart Backend URL Detection
  // Smart Backend URL Detection
  String get _backendUrl {
    if (kIsWeb) {
      return 'https://agent.topscoreapp.ai'; // MUST be localhost for Web
    }
    if (Platform.isAndroid) {
      return 'https://agent.topscoreapp.ai';
    }
    return 'https://agent.topscoreapp.ai'; // Replace with your PC IP
  }

  final TextEditingController _textController = TextEditingController();
  late final WebSocketService _wsService;
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isTyping = false;
  bool _isRecording = false;
  // Add this new variable to track cancellation
  bool _userStoppedGeneration = false;
  String? _currentStreamingMessageId;
  String? _statusMessage;

  // Streaming
  final List<String> _tokenQueue = [];
  Timer? _typingTimer;

  // WebSocket Subscriptions
  StreamSubscription? _wsMessageSub;
  StreamSubscription? _wsConnectionSub;

  // History
  List<Map<String, dynamic>> _threads = [];
  Set<String> _bookmarkedMessageIds = {};
  bool _isLoadingHistory = false;
  bool _isLoadingMessages = false;

  // Settings
  final Map<String, String> _availableModels = {
    'auto': '✨ Auto',
    'groq:llama-3.1-8b-instant': '⚡ Fast (Llama 3.1)',
    'google-gla:gemini-2.5-pro': '🧠 Thinking (Gemini 2.5)',
    'google-gla:gemini-3-flash-preview': '🎓 Smart (Gemini 3 Flash)',
    'cerebras:qwen-3-32b': '🚀 Cerebras (Qwen 32B)',
  };

  String _selectedModelKey = 'auto';

  final List<Map<String, dynamic>> _tools = [
    {
      'id': 'graphing',
      'label': 'Graphing Tool',
      'icon': FontAwesomeIcons.chartLine,
    },
    {
      'id': 'geometry',
      'label': 'Geometry Tool',
      'icon': FontAwesomeIcons.shapes,
    },
    {
      'id': 'deep_research',
      'label': 'Deep Research',
      'icon': FontAwesomeIcons.globe,
    },
  ];

  final FocusNode _messageFocusNode = FocusNode();
  bool _isSidebarOpen = false;

  // Live Voice Mode Variables (UPDATED)
  // Removed: stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isVoiceMode = false;
  bool _isAiSpeaking = false;

  // VAD (Voice Activity Detection) State
  Timer? _amplitudeTimer;
  Timer? _silenceTimer;
  bool _hasDetectedSpeech = false;
  final double _silenceThreshold =
      -30.0; // dB (Adjust based on mic sensitivity)
  final Duration _silenceDuration = const Duration(
    milliseconds: 1500,
  ); // 1.5s silence = stop

  // Attachment Staging
  String? _pendingPreviewData; // Base64 Data URI (For local display ONLY)
  String? _pendingFileUrl; // Firebase Storage URL (For sending to AI)

  String? _pendingFileName; // Display name
  bool _isUploading = false; // To show spinner

  // NEW: Track ELI5 mode
  bool _isEli5Mode = false;

  String _appBarTitle = "New Chat"; // State variable for AppBar title

  // Dynamic Suggestions Data Source
  final List<Map<String, dynamic>> _allSuggestions = [
    {
      'title': 'Explain Quantum Physics',
      'subtitle': 'in simple terms',
      'icon': Icons.science_outlined,
    },
    {
      'title': 'Help me study',
      'subtitle': 'create a quiz for biology',
      'icon': Icons.school_outlined,
    },
    {
      'title': 'Debug my code',
      'subtitle': 'find errors in this Python script',
      'icon': Icons.bug_report_outlined,
    },
    {
      'title': 'Translate text',
      'subtitle': 'to Swahili',
      'icon': Icons.translate_outlined,
    },
    {
      'title': 'Write an Essay',
      'subtitle': 'about climate change',
      'icon': Icons.edit_note_outlined,
    },
    {
      'title': 'Solve Math Problem',
      'subtitle': 'step-by-step calculus',
      'icon': Icons.calculate_outlined,
    },
    {
      'title': 'History Fact',
      'subtitle': 'tell me about the Mau Mau',
      'icon': Icons.history_edu_outlined,
    },
    {
      'title': 'Business Idea',
      'subtitle': 'brainstorm startup concepts',
      'icon': Icons.lightbulb_outline,
    },
    {
      'title': 'Practice Interview',
      'subtitle': 'for a software engineer role',
      'icon': Icons.work_outline,
    },
    {
      'title': 'Summarize Text',
      'subtitle': 'shorten this long article',
      'icon': Icons.summarize_outlined,
    },
  ];

  late List<Map<String, dynamic>> _currentSuggestions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProviderData();
      _fetchBookmarks();
    });

    // Use widget parameter if available
    if (widget.chatThread != null) {
      _appBarTitle = widget.chatThread!['title'] ?? "New Chat";
    }

    // Shuffle and pick 4 suggestions
    _allSuggestions.shuffle();
    _currentSuggestions = _allSuggestions.take(4).toList();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _wsService = WebSocketService(
      userId: authProvider.userModel?.uid ?? 'guest',
    );
    _wsService.connect();

    _wsMessageSub = _wsService.messageStream.listen(_handleIncomingMessage);
    _fetchThreadList();

    // Handle Initial Data (from Science Lab or other screens)
    if (widget.initialMessage != null) {
      _textController.text = widget.initialMessage!;
    }

    if (widget.initialImageFile != null || widget.initialImage != null) {
      // Process initial image in background
      _processInitialImage();
    } else if (widget.initialMessage != null) {
      // If only message, send it immediately after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _sendMessage();
      });
    }

    // Load previous context if this is an existing thread
    if (widget.chatThread != null) {
      _loadThread(widget.chatThread!['thread_id']);
    }

    _initTts();

    // Handle Enter key to send message and Paste shortcut
    _messageFocusNode.onKeyEvent = (node, event) {
      // 1. Enter to Send
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        if (_textController.text.trim().isNotEmpty) {
          _sendMessage();
          return KeyEventResult.handled;
        }
      }

      // 2. Paste Shortcut (Ctrl+V or Cmd+V)
      final isPaste =
          event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.keyV &&
          (HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed);

      if (isPaste) {
        // Trigger image check asynchronously
        // Return 'ignored' so default text paste still happens if no image
        _handleImagePaste();
        return KeyEventResult.ignored;
      }

      return KeyEventResult.ignored;
    };

    // Register paste handler (Web only)
    registerPasteHandler(
      onImagePasted: (dataUri) async {
        if (!mounted) return;
        final base64Str = dataUri.split(',')[1];
        final bytes = base64Decode(base64Str);
        setState(() {
          _pendingPreviewData = dataUri;
          _pendingFileName = "Pasted Image.png";
          _isUploading = true;
        });
        final url = await _uploadToFirebase(
          bytes,
          'pasted_web_image.png',
          'image/png',
        );
        if (mounted && url != null) {
          setState(() => _pendingFileUrl = url);
        }
      },
    );

    _initLiveVoice();
  }

  // --- Helper Methods (Data Loading) ---

  void _checkProviderData() {
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    if (navProvider.pendingMessage != null ||
        navProvider.pendingImage != null) {
      if (navProvider.pendingMessage != null) {
        _textController.text = navProvider.pendingMessage!;
      }
      if (navProvider.pendingImage != null) {
        setState(() {
          _isUploading = true;
          _pendingFileName = "Screenshot.png";
        });
        _processProviderImage(navProvider.pendingImage!);
      } else if (navProvider.pendingMessage != null) {
        _sendMessage();
      }
      navProvider.clearPendingData();
    }
  }

  Future<void> _processProviderImage(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final url = await _uploadToFirebase(
        bytes,
        'pasted_image_${DateTime.now().millisecondsSinceEpoch}.png',
        'image/png',
      );
      if (mounted) {
        setState(() {
          _pendingFileUrl = url;
          _isUploading = false;
        });
        _sendMessage();
      }
    } catch (e) {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _fetchBookmarks() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userModel?.uid;
    if (userId == null) return;
    try {
      final ref = FirebaseDatabase.instance.ref('users/$userId/bookmarks');
      final snapshot = await ref.get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map;
        setState(() {
          _bookmarkedMessageIds = data.keys.cast<String>().toSet();
          // Update any currently loaded messages
          for (var i = 0; i < _messages.length; i++) {
            if (_bookmarkedMessageIds.contains(_messages[i].id)) {
              _messages[i] = _messages[i].copyWith(isBookmarked: true);
            }
          }
        });
      }
    } catch (e) {
      developer.log("Error fetching bookmarks: $e");
    }
  }

  Future<void> _processInitialImage() async {
    if (widget.initialImageFile == null && widget.initialImage == null) return;

    try {
      setState(() {
        _isUploading = true;
        _pendingFileName = "Captured Image.jpg";
      });

      Uint8List bytes;
      final initialImage = widget.initialImage;
      final initialImageFile = widget.initialImageFile;

      if (initialImage != null) {
        // XFile path for web/mobile
        bytes = await initialImage.readAsBytes();
      } else if (initialImageFile != null) {
        // Fallback legacy File
        bytes = await initialImageFile.readAsBytes();
      } else {
        return;
      }

      final url = await _uploadToFirebase(
        bytes,
        'camera_capture_${DateTime.now().millisecondsSinceEpoch}.jpg',
        'image/jpeg',
      );

      if (mounted) {
        setState(() {
          _pendingFileUrl = url;
          _isUploading = false;
        });

        // Auto-send if we have a prompt
        if (widget.initialMessage != null && url != null) {
          _sendMessage();
        }
      }
    } catch (e) {
      developer.log("Error processing initial image: $e", name: "ChatScreen");
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(1.0);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _initLiveVoice() async {
    // TTS completion handler for loop-back logic
    _flutterTts.setCompletionHandler(() {
      setState(() => _isAiSpeaking = false);

      // If still in Voice Mode and AI finished, listen again
      if (_isVoiceMode) {
        Future.delayed(const Duration(milliseconds: 500), _startListening);
      }
    });
  }

  Future<void> _saveLastThreadId(String threadId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_thread_id', threadId);
  }

  Future<void> _fetchThreadList() async {
    setState(() => _isLoadingHistory = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userModel?.uid ?? 'guest';

      // --- NEW: API CALL ---
      final response = await http.get(
        Uri.parse('$_backendUrl/api/history/$userId'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        final List<Map<String, dynamic>> loadedThreads = data.map((item) {
          return {
            'thread_id': item['thread_id'],
            'title': item['title'],
            'updated_at': item['updated_at'],
            'model': item['model'],
          };
        }).toList();

        setState(() {
          _threads = loadedThreads;
          _isLoadingHistory = false;
        });
      } else {
        developer.log('API Error: ${response.statusCode}', name: 'ChatScreen');
        setState(() => _isLoadingHistory = false);
      }
    } catch (e) {
      developer.log('Error loading history: $e', name: 'ChatScreen');
      setState(() {
        _threads = [];
        _isLoadingHistory = false;
      });
    }

    // Initialize with a new chat if empty
    if (_threads.isEmpty) {
      // Just set the ID, don't add to _threads list
      final newId = const Uuid().v4();
      _wsService.setThreadId(newId);
      _saveLastThreadId(newId);
    }
  }

  Future<void> _loadThread(String threadId) async {
    await _saveLastThreadId(threadId);

    if (mounted && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.pop(context);
    }

    setState(() {
      _isLoadingMessages = true;
      _messages.clear();
      _wsService.setThreadId(threadId);
    });

    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/api/chat/$threadId'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<ChatMessage> loadedMessages = [];

        for (var msgData in data) {
          // Debug Log: Check what role the backend is actually sending
          // developer.log('Msg Role: ${msgData['role']}', name: 'ChatLoader');

          // Parse Sources
          List<SourceMetadata>? sources;
          if (msgData['sources'] != null) {
            sources = (msgData['sources'] as List)
                .map((s) => SourceMetadata.fromJson(s))
                .toList();
          }

          // --- NEW: Parse Quiz Data ---
          Map<String, dynamic>? quizData;
          if (msgData['quiz_data'] != null) {
            quizData = Map<String, dynamic>.from(msgData['quiz_data']);
          }

          // --- NEW: Parse Math Data ---
          List<String>? mathSteps;
          String? mathAnswer;
          if (msgData['math_data'] != null) {
            final mData = msgData['math_data'];
            if (mData['steps'] != null) {
              mathSteps = List<String>.from(mData['steps']);
            }
            mathAnswer = mData['final_answer'];
          }

          // --- NEW: Parse Video Data ---
          List<VideoResult>? videoResults;
          if (msgData['video_results'] != null) {
            videoResults = (msgData['video_results'] as List)
                .map((v) => VideoResult.fromJson(v))
                .toList();
          }

          // Robust Role Check
          // Handles 'User', 'user', 'USER', 'student', etc.
          final role = msgData['role']?.toString().toLowerCase() ?? '';
          final isUser = role == 'user' || role == 'student' || role == 'human';

          loadedMessages.add(
            ChatMessage(
              id: msgData['id'] ?? const Uuid().v4(),
              text: msgData['content']?.toString() ?? '',
              isUser: isUser, // <--- UPDATED CHECK
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                msgData['timestamp'] is int
                    ? msgData['timestamp']
                    : DateTime.now().millisecondsSinceEpoch,
              ),
              imageUrl: msgData['file_url'],
              audioUrl: msgData['audio_url'],
              sources: sources,
              quizData: quizData,
              mathSteps: mathSteps,
              mathAnswer: mathAnswer,
              videos: videoResults,
            ),
          );
        }

        setState(() {
          _messages.addAll(loadedMessages);
          _isLoadingMessages = false;
        });
      } else {
        developer.log('API Error: ${response.statusCode}', name: 'ChatScreen');
        setState(() => _isLoadingMessages = false);
      }
    } catch (e) {
      developer.log('Error loading messages: $e', name: 'ChatScreen');
      setState(() {
        _isLoadingMessages = false;
      });
    }

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _startNewChat({bool closeDrawer = true}) {
    final newId = const Uuid().v4();
    _wsService.setThreadId(newId);
    _saveLastThreadId(newId);

    setState(() {
      _messages.clear();
      // REMOVED: _threads.insert(0, {...})
      // We do NOT add to the sidebar list yet. It stays hidden until a message is sent.
    });

    if (closeDrawer && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.pop(context);
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _messageFocusNode.requestFocus();
    });
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    final type = data['type'];
    final messageId = data['id'];

    if (type == null) return;

    if (_userStoppedGeneration &&
        (type == 'chunk' || type == 'reasoning_chunk')) {
      return;
    }

    switch (type) {
      case 'response_start':
        if (messageId != null) {
          _currentStreamingMessageId = messageId;
          final exists = _messages.any((m) => m.id == messageId);
          if (!exists) {
            setState(() {
              _messages.add(
                ChatMessage(
                  id: messageId,
                  text: "",
                  isUser: false,
                  timestamp: DateTime.now(),
                ),
              );
              _isTyping = true;
              _statusMessage = "Thinking...";
            });
            _scrollToBottom();
          }
        }
        break;

      case 'tool_start':
        setState(() {
          _isTyping = true;
          _statusMessage = "Using tools...";
        });
        break;

      case 'audio':
        final audioUrl = data['url'] ?? data['audio_url'];
        if (audioUrl != null && _isVoiceMode) {
          _playAudioResponse(audioUrl);
        }
        break;

      case 'connected':
        developer.log(
          'WebSocket connected: ${data['session_id']}',
          name: 'ChatScreen',
        );
        break;

      case 'title_updated':
        final newTitle = data['title'];
        if (newTitle != null && newTitle.toString().isNotEmpty) {
          setState(() {
            _appBarTitle = newTitle;
            final threadIndex = _threads.indexWhere(
              (t) => t['thread_id'] == _wsService.threadId,
            );
            if (threadIndex != -1) {
              _threads[threadIndex]['title'] = newTitle;
            }
          });
        }
        break;

      case 'chunk':
        final chunkContent = data['content'] as String? ?? '';
        setState(() {
          if (messageId != null) {
            final index = _messages.indexWhere((m) => m.id == messageId);
            if (index != -1) {
              final oldMsg = _messages[index];
              _messages[index] = oldMsg.copyWith(
                text: oldMsg.text + chunkContent,
              );
              _currentStreamingMessageId = messageId;
            } else {
              _messages.add(
                ChatMessage(
                  id: messageId,
                  text: chunkContent,
                  isUser: false,
                  timestamp: DateTime.now(),
                ),
              );
              _currentStreamingMessageId = messageId;
            }
          } else if (_currentStreamingMessageId != null) {
            final index = _messages.indexWhere(
              (m) => m.id == _currentStreamingMessageId,
            );
            if (index != -1) {
              final oldMsg = _messages[index];
              _messages[index] = oldMsg.copyWith(
                text: oldMsg.text + chunkContent,
              );
            }
          } else if (_messages.isNotEmpty && !_messages.last.isUser) {
            final lastIdx = _messages.length - 1;
            final oldMsg = _messages[lastIdx];
            _messages[lastIdx] = oldMsg.copyWith(
              text: oldMsg.text + chunkContent,
            );
            _currentStreamingMessageId = oldMsg.id;
          }
        });
        _scrollToBottom();
        break;

      case 'reasoning_chunk':
        final rContent = data['content'] as String? ?? '';
        setState(() {
          if (_currentStreamingMessageId != null) {
            final index = _messages.indexWhere(
              (m) => m.id == _currentStreamingMessageId,
            );
            if (index != -1) {
              final oldMsg = _messages[index];
              _messages[index] = oldMsg.copyWith(
                reasoning: (oldMsg.reasoning ?? "") + rContent,
              );
            }
          }
        });
        break;

      case 'done':
      case 'complete':
      case 'end':
      case 'message':
      case 'error':
        _finalizeTurn();
        // Update content if provided
        if (data.containsKey('content')) {
          final content = data['content'] as String? ?? '';
          if (content.isNotEmpty) {
            setState(() {
              final index = _messages.indexWhere((m) => m.id == messageId);
              if (index != -1) {
                _messages[index] = _messages[index].copyWith(text: content);
              } else if (messageId != null) {
                _messages.add(
                  ChatMessage(
                    id: messageId,
                    text: content,
                    isUser: false,
                    timestamp: DateTime.now(),
                  ),
                );
              }
            });
            _scrollToBottom();
          }
        }
        if (type == 'error') {
          final errorMsg = data['message'] ?? 'Unknown error';
          if (!_messages.any((m) => m.text.contains(errorMsg))) {
            _addSystemMessage('Error: $errorMsg');
          }
        }
        break;

      default:
        // Handle Sources
        if (data.containsKey('sources')) {
          _handleSources(data);
        }
        break;
    }
  }

  void _handleSources(Map<String, dynamic> data) {
    final sourcesData = data['sources'];
    if (sourcesData == null || sourcesData is! List) return;

    final sourcesList = sourcesData
        .map((s) => SourceMetadata.fromJson(s))
        .toList();

    setState(() {
      if (_currentStreamingMessageId != null) {
        final index = _messages.indexWhere(
          (m) => m.id == _currentStreamingMessageId,
        );
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(sources: sourcesList);
        }
      } else if (_messages.isNotEmpty && !_messages.last.isUser) {
        // Attach to the last AI message if no streaming message
        _messages[_messages.length - 1] = _messages.last.copyWith(
          sources: sourcesList,
        );
      }
    });
  }

  void _finalizeTurn() {
    if (mounted) {
      setState(() {
        _currentStreamingMessageId = null;
        _isTyping = false; // STOP LOADING
        _statusMessage = null;
      });
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

  void _clearPendingAttachment() {
    setState(() {
      _pendingPreviewData = null;
      _pendingFileUrl = null;

      _pendingFileName = null;
      _isUploading = false;
    });
  }

  Future<String?> _uploadToFirebase(
    Uint8List data,
    String fileName,
    String mimeType,
  ) async {
    try {
      setState(() => _isUploading = true);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userModel?.uid ?? 'guest';
      final uuid = const Uuid().v4();

      // Create a reference: uploads/{userId}/{uuid}_{filename}
      final ref = FirebaseStorage.instance.ref().child(
        'uploads/$userId/${uuid}_$fileName',
      );

      final metadata = SettableMetadata(contentType: mimeType);

      // Upload
      final snapshot = await ref.putData(data, metadata);

      // Get URL
      final url = await snapshot.ref.getDownloadURL();

      if (mounted) setState(() => _isUploading = false);
      return url;
    } catch (e) {
      developer.log('Upload Error: $e', name: 'ChatScreen');
      setState(() => _isUploading = false);
      return null;
    }
  }

  Future<void> _downloadImage(String url) async {
    try {
      if (kIsWeb) {
        // On Web, launch the URL to trigger browser download
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        return;
      }

      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Downloading image...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // Get temporary directory
        final tempDir = await getTemporaryDirectory();
        final fileName =
            'ai_tutor_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File('${tempDir.path}/$fileName');

        // Write bytes to file
        await file.writeAsBytes(response.bodyBytes);

        // Open Share sheet (allows "Save to Files" or "Save Image" on iOS/Android)
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Image from AI Tutor');
      } else {
        throw Exception('Failed to download');
      }
    } catch (e) {
      developer.log('Download Error: $e', name: 'ChatScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download image')),
        );
      }
    }
  }

  // NEW: Method to stop generation
  void _stopGeneration() {
    _typingTimer?.cancel();
    _tokenQueue.clear();
    setState(() {
      _isTyping = false;
      _currentStreamingMessageId = null;
      _statusMessage = null;
      _userStoppedGeneration = true; // Ignore subsequent chunks
    });
  }

  Future<void> _sendMessage({String? text, String? fileUrl}) async {
    String messageText = text ?? _textController.text;
    final fileUrlToSend = fileUrl ?? _pendingFileUrl;

    if (messageText.trim().isEmpty && fileUrlToSend != null) {
      messageText = "Analyze this image.";
    }

    if (messageText.trim().isEmpty && fileUrlToSend == null) return;

    setState(() {
      _messages.add(
        ChatMessage(
          id: const Uuid().v4(),
          text: messageText,
          isUser: true,
          timestamp: DateTime.now(),
          imageUrl: fileUrlToSend,
        ),
      );
      _isTyping = true;
      _statusMessage = "Connecting...";
      _textController.clear();
      _pendingFileUrl = null;
      _pendingPreviewData = null;
      _isUploading = false;
    });

    _scrollToBottom();

    // SAFETY TIMEOUT: Stop loading if no response for 30s
    Timer(const Duration(seconds: 30), () {
      if (mounted && _isTyping) {
        _finalizeTurn();
        // Optional: show a small toast or snackbar silently
      }
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _wsService.sendMessage(
        message: messageText,
        userId: authProvider.userModel?.uid ?? 'anon',
        fileUrl: fileUrlToSend,
        fileType: 'image',
        modelPreference: _selectedModelKey,
      );
    } catch (e) {
      _addSystemMessage("Failed to send: $e");
      _finalizeTurn();
    }
  }

  void _verifyResponse(ChatMessage message) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verifying facts...'),
        duration: Duration(seconds: 1),
      ),
    );

    String preview = message.text;
    if (preview.length > 50) {
      preview = "${preview.substring(0, 50)}...";
    }

    final prompt =
        "Double-check your previous answer regarding \"$preview\". Verify all facts and calculations.";
    _sendMessage(text: prompt);
  }

  Future<void> _pickFile(
    FileType type, {
    List<String>? allowedExtensions,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result != null) {
        final file = result.files.single;
        final path = file.path;
        final bytes =
            file.bytes ??
            (path != null ? await File(path).readAsBytes() : null);
        if (bytes == null) return;
        final extension = file.extension?.toLowerCase() ?? '';
        final isImage = [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
        ].contains(extension);

        // Preview Data
        final base64Data = base64Encode(bytes);
        final mimeType = isImage
            ? 'image/$extension'
            : 'application/octet-stream';
        final previewData = 'data:$mimeType;base64,$base64Data';

        if (!mounted) return;
        setState(() {
          _isUploading = true;
          _pendingPreviewData = previewData;
          _pendingFileName = file.name;
        });

        // Upload
        final url = await _uploadToFirebase(bytes, file.name, mimeType);

        if (mounted) {
          setState(() {
            _isUploading = false;
            if (url != null) {
              _pendingFileUrl = url;
            } else {
              _clearPendingAttachment();
            }
          });
        }
      }
    } catch (e) {
      developer.log('File Pick Error: $e', name: 'ChatScreen');
      setState(() => _isUploading = false);
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
        final extension = photo.path.split('.').last;
        final base64Image = base64Encode(bytes);
        final previewData = 'data:image/$extension;base64,$base64Image';

        if (!mounted) return;
        setState(() {
          _isUploading = true;
          _pendingPreviewData = previewData;
          _pendingFileName = "Camera Photo";
        });

        // Upload
        final url = await _uploadToFirebase(
          bytes,
          'camera_photo.$extension',
          'image/$extension',
        );

        if (mounted) {
          setState(() {
            _isUploading = false;
            if (url != null) {
              _pendingFileUrl = url;
            } else {
              _clearPendingAttachment();
            }
          });
        }
      }
    } catch (e) {
      developer.log('Error taking photo: $e', name: 'ChatScreen');
      setState(() => _isUploading = false);
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
      developer.log('Error starting record: $e', name: 'ChatScreen');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();

      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }

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
            developer.log('Error fetching blob: $e', name: 'ChatScreen');
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

          if (mounted) {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            final userId = authProvider.userModel?.uid ?? 'guest';

            _wsService.sendMessage(
              message: '',
              userId: userId,
              audioData: audioData,
            );
          }
          _scrollToBottom();
        }
      }
    } catch (e) {
      developer.log('Error stopping record: $e', name: 'ChatScreen');
    }
  }

  String _cleanMarkdown(String text) {
    // 1. Remove Images completely: ![Alt](url)
    var cleaned = text.replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '');

    // 2. Replace Links with text: [Link Text](url) -> Link Text
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\[(.*?)\]\(.*?\)'),
      (m) => m[1] ?? '',
    );

    // 3. Remove Headers: # Header -> Header
    cleaned = cleaned.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');

    // 4. Remove Bold/Italic: **text** or __text__ -> text
    cleaned = cleaned.replaceAll(RegExp(r'(\*\*|__)(.*?)\1'), r'$2');

    // 5. Remove Single Asterisk/Underscore: *text* or _text_ -> text
    cleaned = cleaned.replaceAll(RegExp(r'(\*|_)(.*?)\1'), r'$2');

    // 6. Remove Code Backticks: `text` -> text
    cleaned = cleaned.replaceAll('`', '');

    // 7. Remove Blockquotes: > text -> text
    cleaned = cleaned.replaceAll(RegExp(r'^>\s*', multiLine: true), '');

    // 8. Remove LaTeX delimiters: $$ or $ -> (empty)
    cleaned = cleaned.replaceAll(r'$$', '').replaceAll(r'$', '');

    return cleaned.trim();
  }

  Future<void> _speak(String text) async {
    // Clean the text before speaking
    final textToSpeak = _cleanMarkdown(text);
    if (textToSpeak.isNotEmpty) {
      await _flutterTts.speak(textToSpeak);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  Future<void> _handleImagePaste() async {
    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        // Validate Header (Prevent HTML pastes)
        if (imageBytes[0] == 0x3c) return;

        // 1. Show Preview Immediately
        final base64Image = base64Encode(imageBytes);

        setState(() {
          _pendingPreviewData = 'data:image/png;base64,$base64Image';
          _pendingFileName = "Pasted Image.png";
          _isUploading = true;
        });

        // 2. Upload in Background
        final url = await _uploadToFirebase(
          imageBytes,
          'pasted_image.png',
          'image/png',
        );

        if (mounted) {
          if (url != null) {
            setState(() => _pendingFileUrl = url);
          } else {
            _clearPendingAttachment(); // Upload failed
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Failed to upload image")),
            );
          }
        }
      }
    } catch (e) {
      developer.log('Paste Error: $e', name: 'ChatScreen');
    }
  }

  // Logic to handle "Edit and Send Back"
  void _handleUserEdit(ChatMessage message) {
    setState(() {
      _textController.text = message.text;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    });
    _messageFocusNode.requestFocus();
  }

  // --- NEW: Bookmark Logic ---
  Future<void> _toggleBookmark(ChatMessage message) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userModel?.uid;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to bookmark messages.'),
        ),
      );
      return;
    }

    final newState = !message.isBookmarked;
    final index = _messages.indexWhere((m) => m.id == message.id);

    if (index != -1) {
      setState(() {
        _messages[index] = _messages[index].copyWith(isBookmarked: newState);
      });
    }

    final ref = FirebaseDatabase.instance.ref(
      'users/$userId/bookmarks/${message.id}',
    );

    if (newState) {
      // Save full message details
      try {
        await ref.set({
          'text': message.text,
          'timestamp': message.timestamp.millisecondsSinceEpoch,
          'thread_id': _wsService.threadId,
          'role': message.isUser ? 'user' : 'ai',
          // Optional: save other metadata if needed
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saved to Library')));
        }
      } catch (e) {
        developer.log('Bookmark Error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save bookmark')),
          );
        }
      }
    } else {
      await ref.remove();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Removed from Library')));
      }
    }
  }
  // ---------------------------

  // Logic for Sharing
  void _shareMessage(String text) {
    Share.share(text);
  }

  // Regenerate response
  void _regenerateResponse(ChatMessage message) {
    // Find the user message that triggered this response
    final messageIndex = _messages.indexOf(message);
    if (messageIndex > 0) {
      final previousMessage = _messages[messageIndex - 1];
      if (previousMessage.isUser) {
        // Remove the current AI response
        setState(() {
          _messages.remove(message);
          _isTyping = true;
        });
        // Re-send the user's message
        _wsService.sendMessage(
          message: previousMessage.text,
          userId:
              Provider.of<AuthProvider>(
                context,
                listen: false,
              ).userModel?.uid ??
              'guest',
          modelPreference: _selectedModelKey,
        );
      }
    }
  }

  // Provide feedback (thumbs up/down)
  void _provideFeedback(ChatMessage message, int feedback) {
    final index = _messages.indexOf(message);
    if (index != -1) {
      setState(() {
        // Toggle off if same feedback, otherwise set new feedback
        final newFeedback = message.feedback == feedback ? null : feedback;
        _messages[index] = message.copyWith(feedback: newFeedback);
      });
      // Optionally send feedback to backend
      developer.log(
        'Feedback for message ${message.id}: $feedback',
        name: 'ChatScreen',
      );
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

  // ============ LIVE VOICE MODE ============

  Future<void> _toggleLiveVoice() async {
    if (_isVoiceMode) {
      _stopLiveVoice();
    } else {
      setState(() => _isVoiceMode = true);
      _showVoiceModeUI();
      // Small delay to allow UI to build
      Future.delayed(const Duration(milliseconds: 300), _startListening);
    }
  }

  void _showVoiceModeUI() {
    showDialog(
      // CHANGE: Use showDialog instead of showModalBottomSheet
      context: context,
      barrierDismissible: false, // Prevent clicking outside to close
      barrierColor: Colors.black.withValues(alpha: 0.8), // Darker background
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // We need to listen to the parent state to update the UI
            // but since we are inside a dialog, we might need a timer or listener
            // if _isAiSpeaking changes outside.
            // However, for simplicity, the parent setState calls will rebuild
            // the widget tree if we structure it correctly.
            // A better approach for the Dialog is to use a ValueListenable or
            // just rely on the fact that this is a simple overlay.

            return Center(
              child: Material(
                // Needed because Dialog children don't have default Material
                color: Colors.transparent,
                child: Container(
                  width: 320, // Fixed width for a clean look
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF1E1E1E,
                    ), // Dark background matching your theme
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Wrap content height
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Circle
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isAiSpeaking
                              ? AppColors.googleBlue.withValues(alpha: 0.2)
                              : AppColors.accentTeal.withValues(alpha: 0.2),
                          border: Border.all(
                            color: _isAiSpeaking
                                ? AppColors.googleBlue
                                : AppColors.accentTeal,
                            width: 4,
                          ),
                        ),
                        child: Icon(
                          _isAiSpeaking
                              ? Icons.volume_up_rounded
                              : Icons.mic_rounded,
                          size: 56,
                          color: _isAiSpeaking
                              ? AppColors.googleBlue
                              : AppColors.accentTeal,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Status Text
                      Text(
                        _isAiSpeaking ? 'AI is speaking...' : 'Listening...',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        _isAiSpeaking
                            ? 'Please wait...'
                            : 'Speak naturally, I\'ll respond when you pause',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Close Button
                      InkWell(
                        onTap: () {
                          _stopLiveVoice();
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.call_end,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "End Call",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // Ensure we clean up if the dialog is closed via back button
      if (_isVoiceMode) _stopLiveVoice();
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
    super.dispose();
  }

  Future<void> _startListening() async {
    if (!_isVoiceMode || _isAiSpeaking || _isRecording) return;

    try {
      if (await _audioRecorder.hasPermission()) {
        // 1. Prepare Path
        String path = '';
        if (!kIsWeb) {
          final tempDir = await getTemporaryDirectory();
          path =
              '${tempDir.path}/live_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        } else {
          path = 'live_audio.m4a'; // Web handles path internally
        }

        // 2. Start Recording
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _hasDetectedSpeech = false;
        });

        // 3. Start VAD Monitoring (Check volume every 100ms)
        _amplitudeTimer?.cancel();
        _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (
          timer,
        ) async {
          if (!_isRecording) {
            timer.cancel();
            return;
          }

          final amplitude = await _audioRecorder.getAmplitude();
          final currentDb = amplitude.current;

          // A. Speech Detected (User started talking)
          if (currentDb > _silenceThreshold) {
            _hasDetectedSpeech = true;
            _silenceTimer?.cancel(); // Cancel any pending stop
          }
          // B. Silence Detected (Only if they already spoke)
          else if (_hasDetectedSpeech && currentDb <= _silenceThreshold) {
            if (_silenceTimer == null || !_silenceTimer!.isActive) {
              _silenceTimer = Timer(_silenceDuration, () {
                _stopListeningAndSend(); // User finished sentence
              });
            }
          }
        });
      }
    } catch (e) {
      developer.log('Error starting VAD recording: $e', name: 'ChatScreen');
      _stopLiveVoice();
    }
  }

  Future<void> _stopListeningAndSend() async {
    _amplitudeTimer?.cancel();
    _silenceTimer?.cancel();

    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        // Read file and send to backend for Whisper
        String? base64Audio;
        if (kIsWeb) {
          final response = await http.get(Uri.parse(path));
          if (response.statusCode == 200) {
            base64Audio = base64Encode(response.bodyBytes);
          }
        } else {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            base64Audio = base64Encode(bytes);
          }
        }

        if (base64Audio != null) {
          // Send specially marked 'audio_input' for Whisper processing
          if (mounted) {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            final userId = authProvider.userModel?.uid ?? 'guest';

            _wsService.sendMessage(
              message: '', // No text, just audio
              userId: userId,
              audioData: 'data:audio/m4a;base64,$base64Audio',
              // Hint to backend to use Whisper
              modelPreference: 'whisper-mode',
            );
          }
        }
      }
    } catch (e) {
      developer.log('Error sending VAD audio: $e', name: 'ChatScreen');
    }
  }

  Future<void> _playAudioResponse(String url) async {
    if (!_isVoiceMode) return;

    setState(() => _isAiSpeaking = true);

    try {
      await _audioPlayer.play(UrlSource(url));

      // Listen for completion to restart listening
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted && _isVoiceMode) {
          setState(() => _isAiSpeaking = false);
          // Wait a moment before listening again to avoid echo
          Future.delayed(const Duration(milliseconds: 500), _startListening);
        }
      });
    } catch (e) {
      developer.log('Error playing HQ audio: $e', name: 'ChatScreen');
      setState(() => _isAiSpeaking = false);
    }
  }

  // NOTE: REMOVED _speakBuffer as it is no longer used for HQ Audio mode
  // Kept _speak for manual button clicks

  void _stopLiveVoice() {
    _amplitudeTimer?.cancel();
    _silenceTimer?.cancel();
    setState(() {
      _isVoiceMode = false;
      _isAiSpeaking = false;
      _isRecording = false; // Reset UI
    });
    _audioRecorder.stop();
    _audioPlayer.stop();
    // Removed: _speechToText.stop();
  }

  // 1. Logic to delete from Firebase and update UI
  Future<void> _deleteThread(String threadId) async {
    try {
      // Remove from Firebase Realtime Database
      // Note: Assuming 'chats/$threadId' is the correct path structure based on previous context.
      // If the path needs user ID, it might be 'users/$userId/chats/$threadId' or similar.
      // Using the user provided path 'chats/$threadId'.
      await FirebaseDatabase.instance.ref('chats/$threadId').remove();

      setState(() {
        // Remove from local list
        _threads.removeWhere((t) => t['thread_id'] == threadId);

        // If we deleted the active chat, start a new one
        if (_wsService.threadId == threadId) {
          _startNewChat(closeDrawer: false);
        }
      });
    } catch (e) {
      developer.log('Error deleting thread: $e', name: 'ChatScreen');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to delete chat')));
      }
    }
  }

  // 2. Confirmation Dialog
  void _confirmDeleteThread(String threadId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteThread(threadId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // 1. Update Firebase and Local State
  Future<void> _renameThread(String threadId, String newTitle) async {
    try {
      // Update Firebase Realtime Database
      // Note: We access 'metadata/title' directly
      await FirebaseDatabase.instance
          .ref('chats/$threadId/metadata/title')
          .set(newTitle);

      // Update Local UI immediately
      setState(() {
        final index = _threads.indexWhere((t) => t['thread_id'] == threadId);
        if (index != -1) {
          _threads[index]['title'] = newTitle;
        }
      });
    } catch (e) {
      developer.log('Error renaming thread: $e', name: 'ChatScreen');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to rename chat')));
      }
    }
  }

  // 2. Show Input Dialog
  void _showRenameDialog(String threadId, String currentTitle) {
    final TextEditingController renameController = TextEditingController(
      text: currentTitle,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: renameController,
          decoration: const InputDecoration(
            labelText: 'Chat Title',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) {
            if (renameController.text.trim().isNotEmpty) {
              Navigator.pop(ctx);
              _renameThread(threadId, renameController.text.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (renameController.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                _renameThread(threadId, renameController.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(ThemeData theme) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    Widget avatarContent;

    if (user != null) {
      final photoURL = user.photoURL;
      if (photoURL != null && photoURL.isNotEmpty) {
        avatarContent = SizedBox(
          width: 36,
          height: 36,
          child: ClipOval(
            child: NetworkAwareImage(
              imageUrl: photoURL,
              width: 36,
              height: 36,
              isProfilePicture: true,
              fit: BoxFit.cover,
            ),
          ),
        );
      } else {
        String initials = 'G';
        final displayName = user.displayName;
        final email = user.email;

        if (displayName.isNotEmpty) {
          final names = displayName.trim().split(' ');
          if (names.length >= 2) {
            initials = '${names[0][0]}${names[1][0]}'.toUpperCase();
          } else if (names.isNotEmpty) {
            initials = names[0][0].toUpperCase();
          }
        } else if (email.isNotEmpty) {
          initials = email[0].toUpperCase();
        }

        avatarContent = CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.googleBlue,
          child: Text(
            initials,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        );
      }
    } else {
      avatarContent = CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.googleBlue,
        child: Text(
          'G',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      offset: const Offset(0, 50),
      icon: avatarContent,
      tooltip: 'Account',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Text(
            user?.displayName ?? user?.email ?? 'Guest',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings, size: 20),
              SizedBox(width: 12),
              Text('Settings'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: Colors.redAccent),
              SizedBox(width: 12),
              Text('Log out', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        if (value == 'logout') {
          await authProvider.signOut();
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<AuthProvider>(context).userModel;
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
                  // TOP BAR
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
                        Text(
                          _appBarTitle, // Use dynamic title
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        _buildUserAvatar(theme),
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
                        : SelectionArea(
                            // <--- NEW: Enable Global Selection
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                return _buildMessageBubble(
                                  _messages[index],
                                  theme,
                                  user?.photoURL,
                                );
                              },
                            ),
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
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    // 1. Get User Name
    String greetingName = 'Learner';
    if (user != null) {
      final displayName = user.displayName;
      final email = user.email;
      if (displayName.isNotEmpty) {
        greetingName = displayName.split(' ')[0];
      } else if (email.isNotEmpty) {
        greetingName = email.split('@')[0];
      }
    }

    // 2. Time-Aware Logic
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFF4285F4),
                    Color(0xFF9B72CB),
                    Color(0xFFD96570),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  '$greeting, $greetingName',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 48,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 3. Dynamic Suggestions & Refresh
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'How can I help you today?',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      size: 18,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                    tooltip: 'Refresh suggestions',
                    onPressed: () {
                      setState(() {
                        _allSuggestions.shuffle();
                        _currentSuggestions = _allSuggestions.take(4).toList();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 600,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: _currentSuggestions.map((suggestion) {
                    return _buildSuggestionCard(
                      suggestion['title'],
                      suggestion['subtitle'],
                      suggestion['icon'],
                      isDark,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(
    String title,
    String subtitle,
    IconData icon,
    bool isDark,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _sendMessage(text: "$title $subtitle"),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 180,
          height: 120,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F4F9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.black26 : Colors.white,
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    ThemeData theme,
    String? userPhotoUrl,
  ) {
    final isUser = message.isUser;
    final isDark = theme.brightness == Brightness.dark;

    if (isUser) {
      // --- USER MESSAGE (Primary Color + White Text) ---
      // --- USER MESSAGE (Primary Color + White Text) ---
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      // CHANGE: Use Primary Color for User to make it distinct
                      color: theme.primaryColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (message.imageUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: NetworkAwareImage(
                                    imageUrl: message.imageUrl!,
                                    height: 150,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: InkWell(
                                    onTap: () =>
                                        _downloadImage(message.imageUrl!),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.download_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // CHANGE: White text on Blue background
                        Text(
                          message.text,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: Colors.white, // Always white for contrast
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Actions Row
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: theme.disabledColor,
                          ),
                          onPressed: () => _handleUserEdit(message),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.copy_all_outlined,
                            size: 16,
                            color: theme.disabledColor,
                          ),
                          onPressed: () => _copyToClipboard(message.text),
                          tooltip: 'Copy',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // USER AVATAR
            const SizedBox(width: 8),
            ClipOval(
              child: SizedBox(
                width: 32,
                height: 32,
                child: NetworkAwareImage(
                  imageUrl: userPhotoUrl,
                  isProfilePicture: true,
                  width: 32,
                  height: 32,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // --- AI MESSAGE (DM Sans Font + Styled Headers) ---
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.only(right: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 12, top: 4),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(
                  0xFF6C63FF,
                ).withValues(alpha: 0.1), // Or theme.primaryColor
                child: const FaIcon(
                  FontAwesomeIcons.robot,
                  color: Color(0xFF6C63FF),
                  size: 18,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Reasoning (System Font / Monospace)
                  if (message.reasoning != null &&
                      message.reasoning!.trim().isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          dense: true,
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          leading: const FaIcon(
                            FontAwesomeIcons.brain,
                            size: 14,
                            color: Colors.grey,
                          ),
                          title: Text(
                            "Reasoning Process",
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          children: [
                            MarkdownBody(
                              data: message.reasoning!,
                              styleSheet: MarkdownStyleSheet(
                                // CHANGE: Use a coding font for reasoning to verify logic
                                p: GoogleFonts.firaCode(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.8,
                                  ),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 2. Main Content (DM Sans for Reading)
                  MarkdownBody(
                    data: cleanContent(message.text), // Use cleanContent helper
                    // Removed selectable: true to let SelectionArea handle it
                    builders: {
                      'latex': LatexElementBuilder(), // Use our new builder
                      'mermaid': MermaidElementBuilder(),
                    },
                    extensionSet: md.ExtensionSet(
                      [
                        ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                        MermaidBlockSyntax(),
                      ],
                      [
                        md.EmojiSyntax(),
                        LatexSyntax(), // Correctly placed in inline syntaxes
                        ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                      ],
                    ),
                    // ignore: deprecated_member_use
                    imageBuilder: (uri, title, alt) {
                      // A. Check if it's a Data URI (Base64)
                      if (uri.scheme == 'data') {
                        try {
                          // Split 'data:image/png;base64,....' to get just the code
                          final base64String = uri.toString().split(',').last;

                          // Sanitize string (remove newlines/spaces if any)
                          final cleanBase64 = base64String.replaceAll(
                            RegExp(r'\s+'),
                            '',
                          );

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.3),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(cleanBase64),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text("⚠️ Image Decode Error"),
                                  );
                                },
                              ),
                            ),
                          );
                        } catch (e) {
                          return const Text("⚠️ Invalid Image Data");
                        }
                      }

                      // B. Fallback for standard URLs (like the Google Chart link)
                      return CachedNetworkImage(
                        imageUrl: uri.toString(),
                        placeholder: (context, url) => const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) =>
                            const SizedBox(), // Hide broken external links
                      );
                    },
                    styleSheet: MarkdownStyleSheet(
                      // CHANGE: Body text uses DM Sans (Better for long reading)
                      p: GoogleFonts.dmSans(
                        fontSize: 16,
                        height: 1.6,
                        color: theme.colorScheme.onSurface,
                      ),
                      // CHANGE: Headers use Outfit & Primary Color to pop
                      h1: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                      h2: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor.withValues(alpha: 0.8),
                      ),
                      h3: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      // CHANGE: Bold text is Darker/Stronger
                      strong: GoogleFonts.dmSans(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      // Code Blocks
                      code: GoogleFonts.firaCode(
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        color: isDark ? Colors.amberAccent : Colors.blue[800],
                        fontSize: 13,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      blockquote: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        fontStyle: FontStyle.italic,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: theme.primaryColor, width: 4),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3. --- NEW: Quiz Widget ---
                  if (message.quizData != null)
                    QuizWidget(
                      quizData: message.quizData!,
                      onComplete: (score) {
                        // Optional: Send score back to Agent
                        // _sendMessage(text: "I finished the quiz and scored $score points!");
                      },
                    ),

                  // ---------------------------
                  const SizedBox(height: 12),

                  // 4. --- NEW: Math Stepper ---
                  if (message.mathSteps != null &&
                      message.mathSteps!.isNotEmpty)
                    MathStepperWidget(
                      steps: message.mathSteps!,
                      finalAnswer: message.mathAnswer,
                    ),

                  // ----------------------------
                  const SizedBox(height: 12),

                  // 5. --- NEW: Video Carousel ---
                  if (message.videos != null && message.videos!.isNotEmpty)
                    VideoCarousel(videos: message.videos!),

                  const SizedBox(height: 12),

                  // 3. Sources
                  if (message.sources != null && message.sources!.isNotEmpty)
                    // ... [Existing Source Logic - no font changes needed] ...
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF252525)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 16,
                                color: theme.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Sources",
                                style: GoogleFonts.outfit(
                                  // Keep Headers consistent
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: message.sources!
                                .map((s) => _buildSourceChip(s, theme, isDark))
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                  // 4. Actions Row
                  Row(
                    children: [
                      _buildActionIcon(
                        Icons.volume_up_outlined,
                        () => _speak(message.text),
                        tooltip: 'Listen',
                      ),
                      _buildActionIcon(
                        Icons.fact_check_outlined,
                        () => _verifyResponse(message),
                        tooltip: 'Double Check',
                      ),
                      _buildActionIcon(
                        Icons.copy_all_outlined,
                        () => _copyToClipboard(message.text),
                        tooltip: 'Copy',
                      ),
                      // BOOKMARK ICON
                      _buildActionIcon(
                        message.isBookmarked
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        () => _toggleBookmark(message),
                        tooltip: message.isBookmarked
                            ? 'Remove from Library'
                            : 'Save to Library',
                        color: message.isBookmarked ? Colors.amber : null,
                      ),
                      _buildActionIcon(
                        Icons.share_outlined,
                        () => _shareMessage(message.text),
                        tooltip: 'Share',
                      ),
                      _buildActionIcon(
                        Icons.refresh_outlined,
                        () => _regenerateResponse(message),
                        tooltip: 'Regenerate',
                      ),
                      const Spacer(),
                      _buildActionIcon(
                        Icons.thumb_up_alt_outlined,
                        () => _provideFeedback(message, 1),
                        tooltip: 'Good',
                        isActive: message.feedback == 1,
                      ),
                      _buildActionIcon(
                        Icons.thumb_down_alt_outlined,
                        () => _provideFeedback(message, -1),
                        tooltip: 'Bad',
                        isActive: message.feedback == -1,
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
  }

  // Helper for consistent Action Icons
  Widget _buildActionIcon(
    IconData icon,
    VoidCallback onTap, {
    String? tooltip,
    bool isActive = false,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final finalColor =
        color ??
        (isActive
            ? AppColors.googleBlue
            : theme.colorScheme.onSurface.withValues(alpha: 0.6));

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        icon: Icon(icon, size: 18, color: finalColor),
        tooltip: tooltip,
        onPressed: onTap,
        splashRadius: 20,
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildSideBar(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: InkWell(
            onTap: () => _startNewChat(closeDrawer: false),
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
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: CircularProgressIndicator(strokeWidth: 2),
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
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal:
                                    12, // Reduced padding slightly for space
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  // Chat Title
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

                                  // --- NEW: Rename Button ---
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      size: 16, // Slightly smaller than delete
                                      color: theme.disabledColor.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    splashRadius: 20,
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    tooltip: 'Rename',
                                    onPressed: () {
                                      // Use the raw title from the map, not the cleaned displayTitle
                                      _showRenameDialog(
                                        thread['thread_id'],
                                        thread['title'] ?? '',
                                      );
                                    },
                                  ),

                                  // --------------------------
                                  const SizedBox(width: 4),

                                  // Existing Delete Button
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: theme.disabledColor.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    splashRadius: 20,
                                    constraints:
                                        const BoxConstraints(), // Removes default padding
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Delete Chat',
                                    onPressed: () {
                                      // Stop the tap from triggering _loadThread
                                      _confirmDeleteThread(thread['thread_id']);
                                    },
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
    final inputFillColor = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF0F4F9);

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: inputFillColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isTyping
                    ? Colors.transparent
                    : theme.dividerColor.withValues(alpha: 0.2),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_pendingPreviewData != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        // Thumbnail with Loading Overlay
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: MemoryImage(
                                    base64Decode(
                                      _pendingPreviewData!.split(',')[1],
                                    ),
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            if (_isUploading)
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Filename Text
                        Expanded(
                          child: Text(
                            _pendingFileName ?? 'Attachment',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Disable Close button while uploading
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: _isUploading
                              ? null
                              : _clearPendingAttachment,
                        ),
                      ],
                    ),
                  ),

                // 1. Top: Text Input
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: TextField(
                    focusNode: _messageFocusNode,
                    controller: _textController,
                    contextMenuBuilder: (context, editableTextState) {
                      final List<ContextMenuButtonItem> buttonItems =
                          editableTextState.contextMenuButtonItems;
                      // Insert "Paste Image" at the beginning
                      buttonItems.insert(
                        0,
                        ContextMenuButtonItem(
                          label: 'Paste Image',
                          onPressed: () {
                            editableTextState.hideToolbar();
                            _handleImagePaste();
                          },
                        ),
                      );
                      return AdaptiveTextSelectionToolbar.buttonItems(
                        anchors: editableTextState.contextMenuAnchors,
                        buttonItems: buttonItems,
                      );
                    },
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      height: 1.4,
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText:
                          Provider.of<AuthProvider>(
                                context,
                              ).userModel?.preferredLanguage ==
                              'sw'
                          ? 'Uliza chochote...'
                          : 'Ask Anything',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 4,
                      ),
                      isDense: true,
                    ),
                    // REMOVED onChanged: setState to fix double rendering
                    // FIX: Pass the value directly to ensure accuracy
                    onSubmitted: (value) => _sendMessage(text: value),
                  ),
                ),
                const SizedBox(height: 8),

                // 2. Bottom: Tools & Actions Row
                Row(
                  children: [
                    // Plus Button (Attachment)
                    Theme(
                      data: Theme.of(context).copyWith(
                        popupMenuTheme: PopupMenuThemeData(
                          color: theme.cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      child: PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add,
                            color: theme.colorScheme.onSurface,
                            size: 20,
                          ),
                        ),
                        tooltip: 'Add attachment',
                        offset: const Offset(0, -180),
                        itemBuilder: (context) => [
                          _buildPopupItem(
                            Icons.image_outlined,
                            'Upload Image',
                            'image',
                          ),
                          if (!kIsWeb)
                            _buildPopupItem(
                              Icons.camera_alt_outlined,
                              'Take Photo',
                              'camera',
                            ),
                          _buildPopupItem(
                            Icons.description_outlined,
                            'Upload Document',
                            'document',
                          ),
                        ],
                        onSelected: (value) {
                          switch (value) {
                            case 'image':
                              _pickFile(FileType.image);
                              break;
                            case 'camera':
                              _takePhoto();
                              break;
                            case 'document':
                              _pickFile(
                                FileType.custom,
                                allowedExtensions: [
                                  'pdf',
                                  'doc',
                                  'docx',
                                  'epub',
                                  'txt',
                                  'odt',
                                ],
                              );
                              break;
                          }
                        },
                      ),
                    ),

                    // --- NEW: ELI5 Toggle Button ---
                    IconButton(
                      icon: Icon(
                        _isEli5Mode
                            ? Icons.child_care
                            : Icons.child_care_outlined,
                        color: _isEli5Mode
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                      ),
                      tooltip: 'Explain Like I\'m 5',
                      onPressed: () {
                        setState(() {
                          _isEli5Mode = !_isEli5Mode;
                        });

                        if (_isEli5Mode) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "ELI5 Mode On: Answers will be simple and use analogies.",
                              ),
                              duration: Duration(milliseconds: 1500),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                    // -------------------------------

                    // Tools Button
                    PopupMenuButton<String>(
                      icon: Row(
                        children: [
                          Icon(
                            Icons.grid_view_rounded, // Or dedicated tools icon
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Tools",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      tooltip: 'Select Tool',
                      offset: const Offset(0, -180),
                      color: theme.cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      itemBuilder: (context) => _tools.map((tool) {
                        return PopupMenuItem<String>(
                          value: tool['id'] as String,
                          child: Row(
                            children: [
                              FaIcon(
                                tool['icon'] as IconData,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(tool['label'] as String),
                            ],
                          ),
                        );
                      }).toList(),
                      onSelected: (toolId) => _textController.text =
                          '@$toolId ${_textController.text}',
                    ),

                    const Spacer(),

                    // Model Selector
                    Theme(
                      data: Theme.of(context).copyWith(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedModelKey,
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          isDense: true,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.8,
                            ),
                          ),
                          dropdownColor: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          items: _availableModels.entries
                              .map(
                                (entry) => DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(
                                    entry.value.contains('(')
                                        ? entry.value.split('(').first.trim()
                                        : entry.value, // Shorten name for UI
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (newValue) {
                            if (newValue != null) {
                              setState(() => _selectedModelKey = newValue);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // --- NEW: Live Voice Button ---
                    IconButton(
                      icon: Icon(
                        Icons.graphic_eq_rounded,
                        color: _isVoiceMode
                            ? AppColors.googleBlue
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                      ),
                      tooltip: 'Live Voice Mode',
                      onPressed: _toggleLiveVoice,
                    ),

                    const SizedBox(width: 4),

                    // --- NEW: ValueListenableBuilder prevents whole-screen rebuilds ---
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _textController,
                      builder: (context, value, child) {
                        final hasText = value.text.isNotEmpty;

                        if (_isTyping) {
                          return GestureDetector(
                            onTap: _stopGeneration,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.stop_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          );
                        } else if (hasText || !_isRecording) {
                          return GestureDetector(
                            onTap: () {
                              if (hasText) {
                                _sendMessage();
                              } else {
                                _startRecording();
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: hasText
                                    ? theme.primaryColor
                                    : isDark
                                    ? Colors.white24
                                    : Colors.black12,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                hasText ? Icons.send_rounded : Icons.mic,
                                size: 20,
                                color: hasText
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          );
                        } else if (_isRecording) {
                          return IconButton(
                            icon: const Icon(Icons.stop_circle_outlined),
                            color: Colors.redAccent,
                            onPressed: _stopRecording,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_messages.isNotEmpty && !_isTyping)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'AI can make mistakes. Check important info.',
                style: TextStyle(fontSize: 10, color: theme.disabledColor),
              ),
            ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    IconData icon,
    String text,
    String value,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildSourceChip(SourceMetadata source, ThemeData theme, bool isDark) {
    final isBook = source.type == 'book';
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        if (source.url != null && source.url!.isNotEmpty) {
          final uri = Uri.tryParse(source.url!);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } else {
          // Show book details dialog
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(source.title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (source.author != null) Text('Author: ${source.author}'),
                  const SizedBox(height: 8),
                  Text('Type: ${source.type}'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isBook ? Icons.menu_book_rounded : Icons.link_rounded,
              size: 14,
              color: isDark ? Colors.white70 : theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                source.title,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : theme.colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
      )..repeat(reverse: true);
    });
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

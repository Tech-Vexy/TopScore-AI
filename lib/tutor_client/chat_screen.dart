import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:record/record.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Removed (Unused)
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../screens/auth/auth_screen.dart';
import '../screens/profile_screen.dart' as profile_page;
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../constants/colors.dart';
import '../models/video_result.dart';
import '../widgets/network_aware_image.dart';
import '../widgets/quiz_widget.dart';
import '../widgets/math_stepper_widget.dart';
import '../widgets/math_markdown.dart';
import '../widgets/virtual_lab/video_carousel.dart';
import '../widgets/youtube_embed_widget.dart';
import '../widgets/gemini_reasoning_view.dart';
import '../utils/markdown/mermaid_builder.dart';
import '../utils/paste_handler/paste_handler.dart';
import 'message_model.dart';
import 'websocket_service.dart';
import 'camera_screen.dart';

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

  // Voice message playback state
  String? _playingAudioMessageId;
  bool _isPlayingAudio = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  bool _isTyping = false;
  bool _isRecording = false;
  // Add this new variable to track cancellation
  bool _userStoppedGeneration = false;
  String? _currentStreamingMessageId;

  // Loading message type for dynamic status
  String _loadingMessageType =
      'thinking'; // 'thinking', 'analyzing', 'generating'

  // TTS state tracking
  bool _isTtsSpeaking = false;
  bool _isTtsPaused = false;
  String? _speakingMessageId;
  String? _statusMessage;

  // Streaming
  final List<String> _tokenQueue = [];
  Timer? _typingTimer;

  // WebSocket Subscriptions
  StreamSubscription? _wsMessageSub;
  StreamSubscription? _wsConnectionSub;

  // Firebase RTDB Listener Management
  Query? _messagesRef;
  StreamSubscription? _childAddedSub;
  StreamSubscription? _childChangedSub;
  StreamSubscription? _childRemovedSub;

  // History
  List<Map<String, dynamic>> _threads = [];
  Set<String> _bookmarkedMessageIds = {};
  bool _isLoadingHistory = false;
  bool _isLoadingMessages = false;

  // Sidebar Search
  String _historySearchQuery = '';
  final TextEditingController _historySearchController =
      TextEditingController();

  // Performance optimization: cache for fast title loading
  final Map<String, String> _titleCache = {};

  // Pagination
  static const int _initialMessageLimit = 50; // Load last 50 messages initially
  // bool _hasMoreMessages = false; // Reserved for future load-more feature

  // Settings

  // Settings - Managed by backend
  // Removed _availableModels, _selectedModelKey, _tools


  final FocusNode _messageFocusNode = FocusNode();
  bool _isSidebarOpen = false;

  // Live Voice Mode Variables (UPDATED)
  // Removed: stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isVoiceMode = false;
  bool _isAiSpeaking = false;
  bool _receivedServerAudio =
      false; // Tracks if server sent audio for current response
  StateSetter? _voiceDialogSetState; // For updating voice dialog UI

  // VAD (Voice Activity Detection) State - Smart Implementation
  Timer? _amplitudeTimer;
  Timer? _vadTimer; // Smart VAD timer
  bool _isSpeechDetected = false; // Tracks if user has started talking
  DateTime? _lastSpeechTime; // Last time we detected speech
  final double _speechThreshold =
      -20.0; // Sensitivity (Lower = more sensitive). -20 is safer for noisy rooms.
  final Duration _silenceTimeout = const Duration(
    milliseconds: 1200,
  ); // 1.2s pause = end of turn
  double _currentAmplitude = -50.0; // For visual feedback
  String _liveTranscription = ''; // Real-time user speech display

  // Attachment Staging
  String? _pendingPreviewData; // Base64 Data URI (For local display ONLY)
  String? _pendingFileUrl; // Firebase Storage URL (For sending to AI)
  String? _pendingFileType; // Type of file (image/jpeg, application/pdf, etc.)

  String? _pendingFileName; // Display name
  bool _isUploading = false; // To show spinner

  // Image Picker instance
  final ImagePicker _imagePicker = ImagePicker();

  // NEW: Track ELI5 mode
  bool _isEli5Mode = false;

  // Search functionality
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<ChatMessage> _filteredMessages = [];

  // Flashcard generation
  List<Map<String, String>> _flashcards = [];

  // Suggested question chips
  List<String> _suggestedQuestions = [];
  List<String> _displayedQuestions = [];

  // Chat folders/tags (TODO: implement folder filtering UI)
  // String? _currentFolder;
  // final List<String> _folders = [
  //   'All',
  //   'Math',
  //   'Science',
  //   'History',
  //   'Language',
  //   'Other'
  // ];

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
    // Swahili options
    {
      'title': 'Nifafanulie Dhana',
      'subtitle': 'kwa lugha rahisi',
      'icon': Icons.lightbulb_outline,
    },
    {
      'title': 'Nisaidie na Hesabu',
      'subtitle': 'hatua kwa hatua',
      'icon': Icons.calculate_outlined,
    },
    {
      'title': 'Tafsiri',
      'subtitle': 'kwa Kiswahili',
      'icon': Icons.translate_outlined,
    },
    {
      'title': 'Andika Insha',
      'subtitle': 'kuhusu teknolojia',
      'icon': Icons.edit_note_outlined,
    },
    {
      'title': 'Nipe Quiz',
      'subtitle': 'ya Biology',
      'icon': Icons.school_outlined,
    },
  ];

  late List<Map<String, dynamic>> _currentSuggestions;

  @override
  void initState() {
    super.initState();

    // 1. Initialize the Service (But do not connect yet)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId =
        authProvider.userModel?.uid ??
        FirebaseAuth.instance.currentUser?.uid ??
        'guest';
    _wsService = WebSocketService(userId: userId);

    // Initial check for guest limit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGuestAccess();
    });

    // 2. Shuffle Suggestions
    _allSuggestions.shuffle();
    _currentSuggestions = _allSuggestions.take(4).toList();

    // 3. Set up audio player listeners for voice message playback
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _audioDuration = duration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _audioPosition = position;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
          _playingAudioMessageId = null;
          _audioPosition = Duration.zero;
        });
      }
    });

    // Load suggested questions
    _loadSuggestedQuestions();

    // 3. Setup Initial UI State (Text/Images from other screens)
    if (widget.chatThread != null) {
      // Title loaded from widget.chatThread!['title']
    }

    if (widget.initialMessage != null) {
      _textController.text = widget.initialMessage!;
    }

    _initTts();

    // 4. DEFER CONNECTION & LOGIC UNTIL AFTER RENDER
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A. Handle Provider Data (Pending screenshots/messages)
      _checkProviderData();

      // B. Fetch Bookmarks
      _fetchBookmarks();

      // C. Connect to Backend
      // This ensures the widget tree is fully mounted and rendered before we start
      // receiving WebSocket events that might trigger setStates.
      _wsService.connect();
      _wsMessageSub = _wsService.messageStream.listen(_handleIncomingMessage);

      // D. Load History
      _fetchThreadList();

      // E. Handle Initial Auto-Send
      if (widget.initialImageFile != null || widget.initialImage != null) {
        _processInitialImage();
      } else if (widget.initialMessage != null) {
        // Delay slightly to look natural
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _sendMessage();
        });
      }

      // F. Load Thread if ID passed
      if (widget.chatThread != null) {
        _loadThread(widget.chatThread!['thread_id']);
      }
    });

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

  Future<void> _loadSuggestedQuestions() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/config/suggested_responses.json',
      );
      final data = json.decode(jsonString);
      setState(() {
        _suggestedQuestions = List<String>.from(data['suggestions'] ?? []);
        _shuffleQuestions();
      });
    } catch (e) {
      developer.log(
        'Error loading suggested questions: $e',
        name: 'ChatScreen',
      );
    }
  }

  void _shuffleQuestions() {
    final shuffled = List<String>.from(_suggestedQuestions)..shuffle();
    _displayedQuestions = shuffled.take(3).toList();
  }

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

      // 1. Immediately show preview (Paste)
      final base64Image = base64Encode(bytes);
      if (mounted) {
        setState(() {
          _pendingPreviewData = 'data:image/png;base64,$base64Image';
          _pendingFileName = "Screenshot.png";
          _isUploading = true;
        });
      }

      // 2. Upload in background
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
        // Removed _sendMessage() to allow user to edit/confirm before sending
      }
    } catch (e) {
      developer.log("Error processing provider image: $e");
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _fetchBookmarks() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId =
        authProvider.userModel?.uid ?? FirebaseAuth.instance.currentUser?.uid;
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
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // --- SMART RATE SETTING ---
    if (kIsWeb) {
      // Web: 1.3 for slightly faster, more engaging pace (Web Speech API scale: 0.1 to 10.0)
      await _flutterTts.setSpeechRate(1.3);
    } else {
      // Android/iOS: 0.5 is roughly "normal" conversational speed
      // (1.0 is often too fast on mobile engines)
      await _flutterTts.setSpeechRate(0.5);
    }

    // Set up TTS state handlers
    _flutterTts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _isTtsSpeaking = true;
          _isTtsPaused = false;
        });
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isTtsSpeaking = false;
          _isTtsPaused = false;
          _speakingMessageId = null;
        });
      }

      // If in Live Voice Mode, automatically restart listening after AI finishes speaking
      if (_isVoiceMode && mounted) {
        setState(() {
          _isAiSpeaking = false;
          _statusMessage = "Listening...";
        });
        _voiceDialogSetState?.call(() {});
        Future.delayed(const Duration(milliseconds: 500), _startListening);
      }
    });

    _flutterTts.setCancelHandler(() {
      if (mounted) {
        setState(() {
          _isTtsSpeaking = false;
          _isTtsPaused = false;
          _speakingMessageId = null;
        });
      }
    });

    _flutterTts.setPauseHandler(() {
      if (mounted) {
        setState(() {
          _isTtsPaused = true;
        });
      }
    });

    _flutterTts.setContinueHandler(() {
      if (mounted) {
        setState(() {
          _isTtsPaused = false;
        });
      }
    });
  }

  Future<void> _initLiveVoice() async {
    // TTS completion handler for loop-back logic in voice mode
    // This ensures continuous conversation: speak -> listen -> speak -> ...
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isAiSpeaking = false;
          _isTtsSpeaking = false;
          _statusMessage = null;
        });
        _voiceDialogSetState?.call(() {});
      }

      // If still in Voice Mode and AI finished speaking, auto-listen again
      if (_isVoiceMode && mounted) {
        setState(() => _statusMessage = "Listening...");
        _voiceDialogSetState?.call(() {});
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
      final userId =
          authProvider.userModel?.uid ??
          FirebaseAuth.instance.currentUser?.uid ??
          'guest';

      // --- OPTIMIZED: API CALL ---
      final response = await http.get(
        Uri.parse('$_backendUrl/api/history/$userId'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        final List<Map<String, dynamic>> loadedThreads = data.map((item) {
          final threadId = item['thread_id'];
          final title = item['title'];

          // Cache titles for instant display
          if (threadId != null && title != null) {
            _titleCache[threadId] = title;
          }

          return {
            'thread_id': threadId,
            'title': title,
            'updated_at': item['updated_at'],
            'model': item['model'],
          };
        }).toList();

        if (mounted) {
          setState(() {
            _threads = loadedThreads;
            _isLoadingHistory = false;
          });
        }
      } else {
        developer.log('API Error: ${response.statusCode}', name: 'ChatScreen');
        if (mounted) setState(() => _isLoadingHistory = false);
      }
    } catch (e) {
      developer.log('Error loading history: $e', name: 'ChatScreen');
      if (mounted) {
        setState(() {
          _threads = [];
          _isLoadingHistory = false;
        });
      }
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
    // Clean up previous RTDB listeners
    _childAddedSub?.cancel();
    _childChangedSub?.cancel();
    _childRemovedSub?.cancel();

    await _saveLastThreadId(threadId);

    if (mounted && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.pop(context);
    }

    // FAST: Set title from cache immediately if available
    final cachedTitle = _titleCache[threadId];

    setState(() {
      _isLoadingMessages = true;
      _messages.clear();
      _wsService.setThreadId(threadId);

      // Instant title update from cache
      if (cachedTitle != null) {
        // Title loaded from cache
      }
    });

    // OPTIMIZED: Set up RTDB listeners with pagination
    // Load only the last N messages initially for faster load
    _messagesRef = FirebaseDatabase.instance
        .ref('chats/$threadId/messages')
        .orderByChild('timestamp')
        .limitToLast(_initialMessageLimit); // Only load recent messages

    // OPTIMIZED: Batch message updates to reduce setState calls
    final List<ChatMessage> batchedMessages = [];

    // Listen for new messages (also fires for initial load)
    _childAddedSub = _messagesRef!.onChildAdded.listen((event) {
      final key = event.snapshot.key;
      if (key == null) return;

      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final msg = _parseMessageFromFirebase(key, data);

      // Batch updates during initial load
      if (_isLoadingMessages) {
        batchedMessages.add(msg);

        // Commit batch after short delay (reduces redraws)
        Future.delayed(const Duration(milliseconds: 50), () {
          if (!mounted || batchedMessages.isEmpty) return;

          setState(() {
            for (final message in batchedMessages) {
              final existingIdx = _messages.indexWhere(
                (m) => m.id == message.id,
              );
              if (existingIdx == -1) {
                _messages.add(message);
              }
            }
            batchedMessages.clear();
            _isLoadingMessages = false;
          });
          _scrollToBottom();
        });
      } else {
        // Real-time updates: HYBRID STREAMING RECONCILIATION
        setState(() {
          // Check if we already have a temporary version from WebSocket
          final tempIndex = _messages.indexWhere(
            (m) => m.id == key && m.isTemporary,
          );

          if (tempIndex != -1) {
            // REPLACE temporary WebSocket message with final Firebase version
            developer.log(
              '📍 Reconciling: Replacing temporary message $key with Firebase version',
              name: 'ChatScreen',
            );
            _messages[tempIndex] = msg; // msg has isTemporary=false by default
          } else {
            // Check if message already exists (non-temporary)
            final existsIndex = _messages.indexWhere((m) => m.id == key);

            if (existsIndex == -1) {
              // Truly new message - add it
              developer.log(
                '📍 Adding new message from Firebase: $key',
                name: 'ChatScreen',
              );
              _messages.add(msg);

              // Sort by timestamp to maintain order
              _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            } else {
              // Already exists - update it (e.g., edited message)
              developer.log(
                '📍 Updating existing message from Firebase: $key',
                name: 'ChatScreen',
              );
              _messages[existsIndex] = msg;
            }
          }

          // Replace pending user message if matching
          if (msg.isUser) {
            final pendingIdx = _messages.indexWhere(
              (m) => m.id.startsWith('pending-') && m.text == msg.text,
            );
            if (pendingIdx != -1) {
              _messages.removeAt(pendingIdx);
            }
          }

          // Stop typing indicator if this is an assistant message
          if (!msg.isUser) {
            _isTyping = false;
            _statusMessage = null;
          }
        });
      }
      _scrollToBottom();
    });

    // Listen for message updates (e.g., when backend finalizes assistant message)
    _childChangedSub = _messagesRef!.onChildChanged.listen((event) {
      final key = event.snapshot.key;
      if (key == null) return;

      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final updatedMsg = _parseMessageFromFirebase(key, data);

      final idx = _messages.indexWhere((m) => m.id == key);
      if (idx != -1) {
        // Always update with Firebase version (source of truth)
        developer.log(
          '📍 Firebase update for message: $key',
          name: 'ChatScreen',
        );

        setState(() {
          _messages[idx] = updatedMsg;
          if (!updatedMsg.isUser) {
            _isTyping = false;
            _statusMessage = null;
          }
        });
        _scrollToBottom();
      }
    });

    // Listen for message deletions
    _childRemovedSub = _messagesRef!.onChildRemoved.listen((event) {
      final key = event.snapshot.key;
      final idx = _messages.indexWhere((m) => m.id == key);
      if (idx != -1) {
        setState(() => _messages.removeAt(idx));
      }
    });

    setState(() => _isLoadingMessages = false);

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  /// Parse a Firebase RTDB snapshot into a ChatMessage
  ChatMessage _parseMessageFromFirebase(
    String key,
    Map<dynamic, dynamic> data,
  ) {
    // Parse Sources
    List<SourceMetadata>? sources;
    if (data['sources'] != null) {
      sources = (data['sources'] as List)
          .map((s) => SourceMetadata.fromJson(Map<String, dynamic>.from(s)))
          .toList();
    }

    // Parse Quiz Data
    Map<String, dynamic>? quizData;
    if (data['quiz_data'] != null) {
      quizData = Map<String, dynamic>.from(data['quiz_data']);
    }

    // Parse Math Data
    List<String>? mathSteps;
    String? mathAnswer;
    if (data['math_data'] != null) {
      final mData = data['math_data'];
      if (mData['steps'] != null) {
        mathSteps = List<String>.from(mData['steps']);
      }
      mathAnswer = mData['final_answer'];
    }

    // Parse Video Data
    List<VideoResult>? videoResults;
    if (data['video_results'] != null) {
      videoResults = (data['video_results'] as List)
          .map((v) => VideoResult.fromJson(Map<String, dynamic>.from(v)))
          .toList();
    }

    // Robust Role Check
    final role = data['role']?.toString().toLowerCase() ?? '';
    final isUser = role == 'user' || role == 'student' || role == 'human';

    return ChatMessage(
      id: key,
      text: data['content']?.toString() ?? '',
      isUser: isUser,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        data['timestamp'] is int
            ? data['timestamp']
            : DateTime.now().millisecondsSinceEpoch,
      ),
      imageUrl: data['file_url'],
      audioUrl: data['audio_url'],
      sources: sources,
      quizData: quizData,
      mathSteps: mathSteps,
      mathAnswer: mathAnswer,
      videos: videoResults,
      isBookmarked: _bookmarkedMessageIds.contains(key),
    );
  }

  void _startNewChat({bool closeDrawer = true}) {
    // Cancel previous RTDB listeners
    _childAddedSub?.cancel();
    _childChangedSub?.cancel();
    _childRemovedSub?.cancel();

    final newId = const Uuid().v4();
    _wsService.setThreadId(newId);
    _saveLastThreadId(newId);

    setState(() {
      _messages.clear();
      // Starting new chat
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

    // Skip chunks if user stopped generation
    if (_userStoppedGeneration &&
        (type == 'chunk' || type == 'reasoning_chunk')) {
      return;
    }

    switch (type) {
      case 'status':
        if (data['status'] != null) {
          setState(() {
            _isTyping = true;
            // Always show "Thinking..." regardless of backend status message
            // This hides technical messages like "No function needs to be called"
            _statusMessage = "Thinking...";
          });
        }
        break;

      case 'response_start':
        // Create temporary AI message placeholder
        if (messageId != null) {
          _currentStreamingMessageId = messageId;
          _receivedServerAudio = false; // Reset for new response

          // Check if we already have this message (temporary or permanent)
          final exists = _messages.any((m) => m.id == messageId);

          if (!exists) {
            setState(() {
              _messages.add(
                ChatMessage(
                  id: messageId,
                  text: "",
                  isUser: false,
                  timestamp: DateTime.now(),
                  isTemporary: true, // WebSocket message
                  isComplete: false, // Still streaming
                ),
              );
              _isTyping =
                  false; // Disable global indicator as we have a bubble now
              _statusMessage = "Thinking...";
            });
            _scrollToBottom();
          }
        }
        break;

      case 'tool_start':
        // Don't show technical "Using tools..." message to users
        break;

      case 'audio':
        // Server-generated TTS audio - use this instead of client-side TTS
        final audioUrl = data['url'] ?? data['audio_url'];
        if (audioUrl != null && _isVoiceMode) {
          _receivedServerAudio = true; // Mark that we received server audio
          _playAudioResponse(audioUrl);
        }
        break;

      case 'transcription':
        // --- VOICE LOOP FIX: User's speech has been transcribed ---
        final transcribedText = data['content'] as String? ?? '';
        if (transcribedText.isNotEmpty) {
          setState(() {
            _liveTranscription = transcribedText;
            _statusMessage = "Thinking...";
          });
          _voiceDialogSetState?.call(() {});

          // --- AUTO-SEND: Trigger AI response ---
          // This allows the AI to respond to what was just heard
          // _sendMessage already adds the user message bubble, so we don't add it here
          if (_isVoiceMode) {
            _sendMessage(text: transcribedText);
          }
        }
        break;

      case 'connected':
        developer.log(
          'WebSocket connected: ${data['session_id']}',
          name: 'ChatScreen',
        );
        // Check if this is a Gemini Native Audio connection
        if (data['mode'] == 'gemini_native_audio') {
          developer.log(
            'Connected to Gemini Native Audio: ${data['model']}',
            name: 'ChatScreen',
          );
        }
        break;

      // Gemini Native Audio: Speech-to-speech response with text AND audio
      case 'response':
        final responseText = data['text'] as String? ?? '';
        final responseAudio = data['audio'] as String?; // Base64 encoded audio
        final audioMimeType = data['audio_mime_type'] as String? ?? 'audio/wav';
        final latency = data['latency'];

        developer.log(
          'Gemini response: ${responseText.length} chars, audio: ${responseAudio != null}, latency: $latency',
          name: 'ChatScreen',
        );

        if (responseText.isNotEmpty && _isVoiceMode) {
          // Update transcription to show AI's text response
          setState(() {
            _liveTranscription = responseText;
            _statusMessage = 'Speaking...';
          });
          _voiceDialogSetState?.call(() {});

          // Play the audio response if available
          if (responseAudio != null && responseAudio.isNotEmpty) {
            _receivedServerAudio = true;
            await _playGeminiAudioResponse(responseAudio, audioMimeType);
          } else {
            // Fallback to client-side TTS if no audio in response
            _speakInVoiceMode(responseText);
          }
        }
        break;

      // Gemini Native Audio: TTS-only response
      case 'speech':
        final speechAudio = data['audio'] as String?;
        final speechMimeType = data['audio_mime_type'] as String? ?? 'audio/wav';

        if (speechAudio != null && _isVoiceMode) {
          _receivedServerAudio = true;
          await _playGeminiAudioResponse(speechAudio, speechMimeType);
        }
        break;

      case 'title_updated':
        final newTitle = data['title'];
        if (newTitle != null && newTitle.toString().isNotEmpty) {
          setState(() {
            // Title updated to newTitle
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
        // HYBRID STREAMING: Backend sends FULL accumulated text each time (not delta)
        // Update temporary message with streamed content
        final chunkContent = data['content'] as String? ?? '';

        setState(() {
          if (messageId != null) {
            // Find temporary message by ID
            final index = _messages.indexWhere(
              (m) => m.id == messageId && m.isTemporary,
            );

            if (index != -1) {
              // Update existing temporary message with FULL content (not appended)
              _messages[index] = _messages[index].copyWith(
                text: chunkContent, // FULL text (snapshot), not delta
              );
            } else {
              // Message doesn't exist yet - create temporary message
              // This shouldn't normally happen if response_start was sent
              _messages.add(
                ChatMessage(
                  id: messageId,
                  text: chunkContent,
                  isUser: false,
                  timestamp: DateTime.now(),
                  isTemporary: true,
                  isComplete: false,
                ),
              );
              _isTyping = false;
              _currentStreamingMessageId = messageId;
            }
          }
        });
        break;

      case 'reasoning_chunk':
        final rContent = data['content'] as String? ?? '';
        setState(() {
          if (messageId != null) {
            // Find the temp message or create it if missing
            final index = _messages.indexWhere((m) => m.id == messageId);

            if (index != -1) {
              final oldMsg = _messages[index];
              _messages[index] = oldMsg.copyWith(
                // Append new chunk to existing reasoning
                reasoning: (oldMsg.reasoning ?? "") + rContent,
                // Ensure we don't accidentally mark it as complete yet
                isTemporary: true,
              );
            } else {
              // First chunk of reasoning arrived -> Create placeholder
              _messages.add(
                ChatMessage(
                  id: messageId,
                  text: "", // Empty text triggers the "isThinking" state in UI
                  reasoning: rContent,
                  isUser: false,
                  timestamp: DateTime.now(),
                  isTemporary: true,
                ),
              );
              _isTyping = false; // Disable global indicator
              _currentStreamingMessageId = messageId;
            }
          }
        });
        break;

      case 'done':
      case 'complete':
      case 'end':
        // Mark temporary message as complete (streaming finished)
        // Firebase will have the final version soon
        String? completedMessageText;
        if (messageId != null) {
          setState(() {
            final index = _messages.indexWhere(
              (m) => m.id == messageId && m.isTemporary,
            );

            if (index != -1) {
              _messages[index] = _messages[index].copyWith(
                isComplete: true,
                isTemporary: false, // Mark as permanent when streaming ends
              );
              completedMessageText = _messages[index].text;
            }

            // Update with any final content if provided
            if (data.containsKey('content')) {
              final content = data['content'] as String? ?? '';
              if (content.isNotEmpty && index != -1) {
                _messages[index] = _messages[index].copyWith(
                  text: content,
                  isTemporary: false, // Mark as permanent
                );
                completedMessageText = content;
              }
            }
          });
        }

        // VOICE MODE: Speak the AI response aloud using TTS (fallback)
        // Only use client-side TTS if server didn't send pre-generated audio
        // This creates the full voice loop: user speaks -> AI responds -> speak response
        if (_isVoiceMode &&
            !_receivedServerAudio &&
            completedMessageText != null &&
            completedMessageText!.isNotEmpty) {
          _speakInVoiceMode(completedMessageText!);
        }

        _finalizeTurn();
        break;

      case 'message': // Legacy/Full message handling
        final content = data['content'] as String? ?? '';
        if (content.isNotEmpty && messageId != null) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == messageId);
            if (index != -1) {
              // Update existing message
              _messages[index] = _messages[index].copyWith(
                text: content,
                isComplete: true,
                isTemporary: false, // Mark as permanent
              );
            } else {
              // Add new message
              _messages.add(
                ChatMessage(
                  id: messageId,
                  text: content,
                  isUser: false,
                  timestamp: DateTime.now(),
                  isTemporary: false, // Mark as permanent
                  isComplete: true,
                ),
              );
            }
          });
        }
        _finalizeTurn();
        break;

      case 'error':
        final errorMsg = data['message'] ?? 'Unknown error';
        if (!_messages.any((m) => m.text.contains(errorMsg))) {
          _addSystemMessage('Error: $errorMsg');
        }
        _finalizeTurn();
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
        _loadingMessageType = 'thinking'; // Reset to default
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
      _pendingFileType = null;

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
      final userId =
          authProvider.userModel?.uid ??
          FirebaseAuth.instance.currentUser?.uid ??
          'guest';
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
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], text: 'Image from AI Tutor'),
        );
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

  void _showRegistrationPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Continue Learning?'),
        content: const Text(
          'You\'ve reached the free guest limit. Create an account to save your progress and unlock unlimited learning!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
            child: const Text('Sign Up / Login'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage({String? text, String? fileUrl}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.canSendMessage) {
      _showRegistrationPrompt();
      return;
    }

    String messageText = text ?? _textController.text;
    final fileUrlToSend = fileUrl ?? _pendingFileUrl;
    final fileTypeToSend =
        _pendingFileType ?? 'image'; // Default to image if null

    if (messageText.trim().isNotEmpty || fileUrlToSend != null) {
      if (authProvider.isGuest) {
        authProvider.incrementGuestMessage();
      }
    }

    // Validation: Require text when sending an image
    if (messageText.trim().isEmpty && fileUrlToSend != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a message to accompany your image'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (messageText.trim().isEmpty && fileUrlToSend == null) return;

    // Reset user-stopped flag for new turn
    _userStoppedGeneration = false;

    // Determine loading message type based on content
    String loadingType = 'thinking';
    final lowerCaseMessage = messageText.toLowerCase();

    // Check if this is a vision/analysis task
    if (fileUrlToSend != null ||
        lowerCaseMessage.contains('analyze') ||
        lowerCaseMessage.contains('analyse') ||
        lowerCaseMessage.contains('look at') ||
        lowerCaseMessage.contains('what\'s in') ||
        lowerCaseMessage.contains('describe') ||
        lowerCaseMessage.contains('identify') ||
        lowerCaseMessage.contains('recognize') ||
        lowerCaseMessage.contains('scan')) {
      loadingType = 'analyzing';
    }
    // Check if this is a generation task
    else if (lowerCaseMessage.contains('generate') ||
        lowerCaseMessage.contains('create') ||
        lowerCaseMessage.contains('draw') ||
        lowerCaseMessage.contains('make a') ||
        lowerCaseMessage.contains('design') ||
        lowerCaseMessage.contains('build') ||
        lowerCaseMessage.contains('produce') ||
        lowerCaseMessage.contains('graph') ||
        lowerCaseMessage.contains('chart') ||
        lowerCaseMessage.contains('diagram') ||
        lowerCaseMessage.contains('image') ||
        lowerCaseMessage.contains('picture')) {
      loadingType = 'generating';
    }

    // Generate pending ID for optimistic add (RTDB will replace with real ID)
    final pendingId = 'pending-${const Uuid().v4()}';

    setState(() {
      _messages.add(
        ChatMessage(
          id: pendingId,
          text: messageText,
          isUser: true,
          timestamp: DateTime.now(),
          imageUrl: fileUrlToSend,
        ),
      );
      _isTyping = true;
      _loadingMessageType = loadingType;
      _statusMessage = _isVoiceMode ? "Thinking..." : "Connecting...";
      if (_isVoiceMode) _voiceDialogSetState?.call(() {});

      _textController.clear();
      _pendingFileUrl = null;
      _pendingPreviewData = null;
      _pendingFileType = null;
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
        fileType: fileTypeToSend,
        modelPreference: 'auto',
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
        allowMultiple: false,
      );

      if (result != null) {
        final file = result.files.single;
        final path = file.path;
        final bytes =
            file.bytes ??
            (path != null ? await File(path).readAsBytes() : null);
        if (bytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to read file. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final extension = file.extension?.toLowerCase() ?? '';
        final isImage = [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
        ].contains(extension);

        final isDocument = [
          'pdf',
          'doc',
          'docx',
          'txt',
          'epub',
          'odt',
        ].contains(extension);

        // Determine MIME type
        String mimeType;
        if (isImage) {
          mimeType = 'image/$extension';
        } else if (isDocument) {
          switch (extension) {
            case 'pdf':
              mimeType = 'application/pdf';
              break;
            case 'doc':
              mimeType = 'application/msword';
              break;
            case 'docx':
              mimeType =
                  'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
              break;
            case 'txt':
              mimeType = 'text/plain';
              break;
            case 'epub':
              mimeType = 'application/epub+zip';
              break;
            case 'odt':
              mimeType = 'application/vnd.oasis.opendocument.text';
              break;
            default:
              mimeType = 'application/octet-stream';
          }
        } else {
          mimeType = 'application/octet-stream';
        }

        // Preview Data (only for images)
        String? previewData;
        if (isImage) {
          final base64Data = base64Encode(bytes);
          previewData = 'data:$mimeType;base64,$base64Data';
        }

        if (!mounted) return;
        setState(() {
          _isUploading = true;
          _pendingPreviewData = previewData;
          _pendingFileName = file.name;
          _pendingFileType = mimeType;
        });

        // Upload
        final url = await _uploadToFirebase(
          bytes,
          '${DateTime.now().millisecondsSinceEpoch}_${file.name}',
          mimeType,
        );

        if (mounted) {
          setState(() {
            _isUploading = false;
            if (url != null) {
              _pendingFileUrl = url;
            } else {
              _clearPendingAttachment();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to upload file. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      developer.log('File Pick Error: $e', name: 'ChatScreen');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      XFile? photo;

      // Use ImagePicker for web and mobile browsers (better compatibility)
      if (kIsWeb) {
        photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
      } else {
        // Use native camera for mobile apps
        photo = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CameraScreen()),
        );
      }

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final extension = photo.path.split('.').last.toLowerCase();
        final validExtension =
            ['jpg', 'jpeg', 'png', 'webp'].contains(extension)
            ? extension
            : 'jpg';
        final base64Image = base64Encode(bytes);
        final previewData = 'data:image/$validExtension;base64,$base64Image';

        if (!mounted) return;
        setState(() {
          _isUploading = true;
          _pendingPreviewData = previewData;
          _pendingFileName = "Camera Photo";
          _pendingFileType = 'image/$validExtension';
        });

        // Upload
        final url = await _uploadToFirebase(
          bytes,
          'camera_photo_${DateTime.now().millisecondsSinceEpoch}.$validExtension',
          'image/$validExtension',
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
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              kIsWeb
                  ? 'Camera access denied or not available. Please check browser permissions.'
                  : 'Failed to capture photo. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final extension = image.path.split('.').last.toLowerCase();
        final validExtension =
            ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)
            ? extension
            : 'jpg';
        final base64Image = base64Encode(bytes);
        final previewData = 'data:image/$validExtension;base64,$base64Image';

        if (!mounted) return;
        setState(() {
          _isUploading = true;
          _pendingPreviewData = previewData;
          _pendingFileName = image.name;
          _pendingFileType = 'image/$validExtension';
        });

        // Upload
        final url = await _uploadToFirebase(
          bytes,
          'gallery_image_${DateTime.now().millisecondsSinceEpoch}.$validExtension',
          'image/$validExtension',
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
      developer.log('Error picking image: $e', name: 'ChatScreen');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to select image. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            final userId =
                authProvider.userModel?.uid ??
                FirebaseAuth.instance.currentUser?.uid ??
                'guest';

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

  Future<void> _speak(String text, {String? messageId}) async {
    // Clean the text before speaking
    final textToSpeak = _cleanMarkdown(text);
    if (textToSpeak.isNotEmpty) {
      setState(() {
        _speakingMessageId = messageId;
      });
      await _flutterTts.speak(textToSpeak);
    }
  }

  /// Speak AI response aloud during live voice mode
  /// This is the key method that enables the voice conversation loop:
  /// user speaks -> transcribe -> AI response -> speak response -> listen again
  Future<void> _speakInVoiceMode(String text) async {
    if (!_isVoiceMode) return;

    // Clean markdown/formatting for natural speech
    final cleanedText = _cleanMarkdown(text);
    if (cleanedText.isEmpty) {
      // If nothing to speak, go back to listening
      Future.delayed(const Duration(milliseconds: 300), _startListening);
      return;
    }

    // Update UI to show AI is speaking
    setState(() {
      _isAiSpeaking = true;
      _isTtsSpeaking = true;
      _statusMessage = "Speaking...";
      _liveTranscription = ''; // Clear previous transcription
    });
    _voiceDialogSetState?.call(() {});

    // Haptic feedback to indicate AI is responding
    if (!kIsWeb) {
      HapticFeedback.lightImpact();
    }

    // Speak the response - the completion handler in _initLiveVoice
    // will automatically restart listening when TTS finishes
    await _flutterTts.speak(cleanedText);
  }

  Future<void> _pauseTts() async {
    await _flutterTts.pause();
  }

  Future<void> _resumeTts() async {
    await _flutterTts.speak(""); // Resume speaking
  }

  Future<void> _stopTts() async {
    await _flutterTts.stop();
    if (mounted) {
      setState(() {
        _isTtsSpeaking = false;
        _isTtsPaused = false;
        _speakingMessageId = null;
      });
    }
  }

  // Voice message playback controls
  Future<void> _playVoiceMessage(String messageId, String audioUrl) async {
    try {
      // Stop if already playing this message
      if (_playingAudioMessageId == messageId && _isPlayingAudio) {
        await _audioPlayer.pause();
        setState(() {
          _isPlayingAudio = false;
        });
        return;
      }

      // Stop any currently playing audio
      if (_playingAudioMessageId != null &&
          _playingAudioMessageId != messageId) {
        await _audioPlayer.stop();
      }

      setState(() {
        _playingAudioMessageId = messageId;
        _isPlayingAudio = true;
        _audioPosition = Duration.zero;
      });

      // Play from URL (works for both local paths and remote URLs)
      if (audioUrl.startsWith('http')) {
        await _audioPlayer.play(UrlSource(audioUrl));
      } else {
        await _audioPlayer.play(DeviceFileSource(audioUrl));
      }
    } catch (e) {
      developer.log('Error playing voice message: $e', name: 'ChatScreen');
      setState(() {
        _isPlayingAudio = false;
        _playingAudioMessageId = null;
      });
    }
  }

  Future<void> _resumeVoiceMessage() async {
    try {
      await _audioPlayer.resume();
      setState(() {
        _isPlayingAudio = true;
      });
    } catch (e) {
      developer.log('Error resuming voice message: $e', name: 'ChatScreen');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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

  // Logic to handle "Edit and Send Back" with dialog
  void _handleUserEdit(ChatMessage message) {
    final TextEditingController editController = TextEditingController(
      text: message.text,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Edit your message...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final editedText = editController.text.trim();
              if (editedText.isEmpty) {
                Navigator.pop(context);
                return;
              }

              Navigator.pop(context);
              await _editAndResend(message, editedText);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  // Delete old message pair and resend edited message
  Future<void> _editAndResend(
    ChatMessage userMessage,
    String editedText,
  ) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userModel?.uid;
      final threadId = _wsService.threadId;

      if (userId == null) return;

      // Find the AI response that came after this user message
      final userIndex = _messages.indexWhere((m) => m.id == userMessage.id);
      String? aiResponseId;

      if (userIndex != -1 && userIndex < _messages.length - 1) {
        final nextMessage = _messages[userIndex + 1];
        if (!nextMessage.isUser) {
          aiResponseId = nextMessage.id;
        }
      }

      // Delete from Firebase RTDB
      final messagesRef = FirebaseDatabase.instance.ref(
        'chats/$threadId/messages',
      );

      // Delete user message
      await messagesRef.child(userMessage.id).remove();

      // Delete AI response if exists
      if (aiResponseId != null) {
        await messagesRef.child(aiResponseId).remove();
      }

      // Remove from local state (RTDB listener will handle this, but do it immediately for UX)
      setState(() {
        _messages.removeWhere(
          (m) =>
              m.id == userMessage.id ||
              (aiResponseId != null && m.id == aiResponseId),
        );
      });

      // Send the edited message as a new message
      await _sendMessage(text: editedText, fileUrl: userMessage.imageUrl);
    } catch (e) {
      developer.log('Error editing message: $e', name: 'ChatScreen');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to edit message')));
      }
    }
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
    SharePlus.instance.share(ShareParams(text: text));
  }

  // Regenerate response
  Future<void> _regenerateResponse(ChatMessage message) async {
    // Stop any active TTS playback first
    await _stopTts();

    // Find the user message that triggered this response
    final messageIndex = _messages.indexOf(message);
    if (messageIndex > 0) {
      final previousMessage = _messages[messageIndex - 1];
      if (previousMessage.isUser) {
        // Remove the current AI response and clear streaming state
        setState(() {
          _messages.remove(message);
          _currentStreamingMessageId = null;
          _isTyping = true;
        });
        // Re-send the user's message
        if (mounted) {
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
    // Use Gemini Native Audio for speech-to-speech (recommended)
    _startGeminiVoice();
  }

  /// Start Gemini Native Audio voice mode (speech-to-speech)
  /// This uses gemini-2.5-flash-native-audio for end-to-end voice conversation
  Future<void> _startGeminiVoice() async {
    if (_isVoiceMode) {
      _stopLiveVoice();
    } else {
      // Haptic feedback
      if (!kIsWeb) {
        HapticFeedback.mediumImpact();
      }
      setState(() => _isVoiceMode = true);

      // Connect to Gemini Native Audio WebSocket endpoint
      // Always connect as it uses a separate channel
      _wsService.connectGeminiVoice();
      // Wait for connection
      await Future.delayed(const Duration(milliseconds: 500));

      _showVoiceModeUI();
      // Small delay to allow UI to build
      Future.delayed(const Duration(milliseconds: 300), _startListening);
    }
  }

  /// Start legacy WebSocket-based voice mode (STT -> LLM -> TTS)
  /// @deprecated Use _startGeminiVoice for better quality
  Future<void> _startLegacyVoice() async {
    if (_isVoiceMode) {
      _stopLiveVoice();
    } else {
      // Haptic feedback
      if (!kIsWeb) {
        HapticFeedback.mediumImpact();
      }
      setState(() => _isVoiceMode = true);

      // Connect to dedicated voice WebSocket endpoint for low-latency interactions
      if (!_wsService.isConnected) {
        _wsService.connectVoice();
        // Wait for connection
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _showVoiceModeUI();
      // Small delay to allow UI to build
      Future.delayed(const Duration(milliseconds: 300), _startListening);
    }
  }

  void _showVoiceModeUI() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Voice Mode",
      barrierColor: Colors.black, // Deep immersion
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Update dialog when state changes
            _voiceDialogSetState = setDialogState;
            return _VoiceSessionOverlay(
              isAiSpeaking: _isAiSpeaking,
              isRecording: _isRecording,
              statusText:
                  _statusMessage ??
                  (_isAiSpeaking ? "Speaking..." : "Listening..."),
              transcription: _liveTranscription,
              amplitude: _currentAmplitude,
              onClose: () {
                _stopLiveVoice();
                Navigator.pop(ctx);
              },
              onInterrupt: () {
                // "Barge-in" feature: Stop AI, Start Listening
                if (_isAiSpeaking) {
                  _audioPlayer.stop();
                  setState(() => _isAiSpeaking = false);
                  _startListening();
                }
              },
            );
          },
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: child);
      },
    ).then((_) {
      if (_isVoiceMode) _stopLiveVoice();
      _voiceDialogSetState = null;
    });
  }

  @override
  void dispose() {
    // Cancel RTDB listeners
    _childAddedSub?.cancel();
    _childChangedSub?.cancel();
    _childRemovedSub?.cancel();

    // Cancel WebSocket subscriptions
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

  /// Checks if guest user has exceeded their message limit
  void _checkGuestAccess() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isGuest && !authProvider.canSendMessage) {
      // Show dialog prompting user to sign up
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Free Limit Reached'),
          content: const Text(
            'You\'ve used all your free messages. Sign up for unlimited access!',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              },
              child: const Text('Sign Up'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _startListening() async {
    if (!_isVoiceMode || _isAiSpeaking || _isRecording) return;

    try {
      if (await _audioRecorder.hasPermission()) {
        // Reset VAD State
        _isSpeechDetected = false;
        _lastSpeechTime = null;
        _vadTimer?.cancel();

        // --- NEW: Safety Timer (Force stop after 10 seconds) ---
        // This prevents the "stuck in listening" bug if VAD fails.
        final startTime = DateTime.now();
        const maxDuration = Duration(seconds: 10);
        // -------------------------------------------------------

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
          _statusMessage = "Listening..."; // Initial state
        });
        _voiceDialogSetState?.call(() {});

        // Haptic feedback for recording start
        if (!kIsWeb) {
          HapticFeedback.selectionClick();
        }

        // 3. Start Smart VAD Monitoring (Check volume every 100ms)
        _amplitudeTimer?.cancel();
        _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (
          timer,
        ) async {
          if (!_isRecording) {
            timer.cancel();
            return;
          }

          // --- NEW: Check Safety Timeout ---
          if (DateTime.now().difference(startTime) > maxDuration) {
            developer.log(
              '⏱️ Max duration reached. Forcing stop.',
              name: 'ChatScreen',
            );
            timer.cancel();
            _stopListeningAndSend();
            return;
          }
          // ---------------------------------

          final amplitude = await _audioRecorder.getAmplitude();
          final currentDb = amplitude.current;

          // Debug Print: UNCOMMENT THIS to see your actual room noise level!
          // developer.log('🎤 dB: $currentDb | Threshold: $_speechThreshold', name: 'ChatScreen');

          // Update amplitude for visual feedback
          if (mounted) {
            setState(() => _currentAmplitude = currentDb);
            _voiceDialogSetState?.call(() => _currentAmplitude = currentDb);
          }

          // 1. Detect if user STARTED talking
          if (currentDb > _speechThreshold) {
            _lastSpeechTime = DateTime.now();
            if (!_isSpeechDetected) {
              if (mounted) {
                setState(() {
                  _isSpeechDetected = true;
                  _statusMessage = "I'm listening...";
                });
                _voiceDialogSetState?.call(() {});
              }
            }
          }

          // 2. Logic: Only stop IF we heard speech AND silence has passed
          if (_isSpeechDetected && _lastSpeechTime != null) {
            final timeSinceSpeech = DateTime.now().difference(_lastSpeechTime!);

            if (timeSinceSpeech > _silenceTimeout) {
              // User has stopped talking for 1.2 seconds -> SEND IT
              timer.cancel();
              _stopListeningAndSend();
            }
          }
        });
      } else {
        // Permission denied - show message and exit voice mode
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required for voice mode'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        _stopLiveVoice();
      }
    } catch (e) {
      developer.log('Error starting VAD recording: $e', name: 'ChatScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice mode error: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      _stopLiveVoice();
    }
  }

  Future<void> _stopListeningAndSend() async {
    // 1. Immediate UI Update (Latency hiding)
    setState(() {
      _isRecording = false; // Stop the orb pulsing
      _liveTranscription = 'Transcribing...';
      _statusMessage = "Thinking..."; // Show we heard them
    });
    _voiceDialogSetState?.call(() {});

    _amplitudeTimer?.cancel();

    if (!_isRecording && _isSpeechDetected) {
      // Already stopped, just exit
      return;
    }

    try {
      final path = await _audioRecorder.stop();

      if (path != null) {
        // Read file and encode as base64
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
          // Send to Gemini Native Audio WebSocket endpoint
          // This provides end-to-end speech-to-speech using gemini-2.5-flash-native-audio
          // The server will respond with both text AND audio
          _wsService.sendGeminiAudioMessage(
            base64Audio: base64Audio,
            mimeType: 'audio/aac', // m4a is AAC
          );

          developer.log(
            'Gemini voice audio sent (${base64Audio.length} chars)',
            name: 'ChatScreen',
          );
        }
      }
    } catch (e) {
      developer.log('Error sending VAD audio: $e', name: 'ChatScreen');
      // If error, reset to listening
      if (mounted && _isVoiceMode) {
        Future.delayed(const Duration(milliseconds: 500), _startListening);
      }
    }
  }

  Future<void> _playAudioResponse(String url) async {
    if (!_isVoiceMode) return;

    // Reset UI for Overlay to update
    setState(() {
      _isAiSpeaking = true;
      _statusMessage = "Speaking...";
      _liveTranscription = ''; // Clear transcription when AI speaks
    });
    _voiceDialogSetState?.call(() {});

    // Haptic feedback for engagement
    if (!kIsWeb) {
      HapticFeedback.lightImpact();
    }

    try {
      await _audioPlayer.play(UrlSource(url));

      // Ensure we catch the end
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted && _isVoiceMode) {
          setState(() {
            _isAiSpeaking = false;
            _statusMessage = "Listening...";
          });
          _voiceDialogSetState?.call(() {});
          // Auto-listen after AI finishes
          Future.delayed(const Duration(milliseconds: 300), _startListening);
        }
      });
    } catch (e) {
      developer.log("Audio play error: $e");
      setState(() {
        _isAiSpeaking = false;
        _statusMessage = "Error playing audio";
      });
      _voiceDialogSetState?.call(() {});
      // Retry listening after error
      Future.delayed(const Duration(milliseconds: 500), _startListening);
    }
  }

  /// Play base64-encoded audio from Gemini Native Audio response
  /// This is used for speech-to-speech conversation where server sends audio directly
  Future<void> _playGeminiAudioResponse(String base64Audio, String mimeType) async {
    if (!_isVoiceMode) return;

    // Reset UI for Overlay to update
    setState(() {
      _isAiSpeaking = true;
      _statusMessage = "Speaking...";
    });
    _voiceDialogSetState?.call(() {});

    // Haptic feedback for engagement
    if (!kIsWeb) {
      HapticFeedback.lightImpact();
    }

    try {
      // Decode base64 audio
      final audioBytes = base64Decode(base64Audio);
      
      // Write to temp file for playback
      String? tempPath;
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        final extension = mimeType.contains('wav') ? 'wav' : 
                         mimeType.contains('mp3') ? 'mp3' : 
                         mimeType.contains('aac') ? 'm4a' : 'wav';
        tempPath = '${tempDir.path}/gemini_response_${DateTime.now().millisecondsSinceEpoch}.$extension';
        final file = File(tempPath);
        await file.writeAsBytes(audioBytes);
        
        await _audioPlayer.play(DeviceFileSource(tempPath));
      } else {
        // For web, create a data URL
        final dataUrl = 'data:$mimeType;base64,$base64Audio';
        await _audioPlayer.play(UrlSource(dataUrl));
      }

      developer.log(
        'Playing Gemini audio response (${audioBytes.length} bytes, $mimeType)',
        name: 'ChatScreen',
      );

      // Ensure we catch the end
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted && _isVoiceMode) {
          setState(() {
            _isAiSpeaking = false;
            _statusMessage = "Listening...";
          });
          _voiceDialogSetState?.call(() {});
          // Auto-listen after AI finishes
          Future.delayed(const Duration(milliseconds: 300), _startListening);
        }
      });
    } catch (e) {
      developer.log("Gemini audio play error: $e", name: 'ChatScreen');
      setState(() {
        _isAiSpeaking = false;
        _statusMessage = "Error playing audio";
      });
      _voiceDialogSetState?.call(() {});
      // Retry listening after error
      Future.delayed(const Duration(milliseconds: 500), _startListening);
    }
  }

  // NOTE: REMOVED _speakBuffer as it is no longer used for HQ Audio mode
  // Kept _speak for manual button clicks

  void _stopLiveVoice() {
    // Cancel all timers
    _amplitudeTimer?.cancel();
    _vadTimer?.cancel();

    // Stop TTS if speaking
    _flutterTts.stop();

    // Stop audio recording and playback
    _audioRecorder.stop();
    _audioPlayer.stop();
    
    // Disconnect voice channel
    _wsService.disconnectVoice();

    // Reset all voice mode state
    setState(() {
      _isVoiceMode = false;
      _isAiSpeaking = false;
      _isRecording = false;
      _isSpeechDetected = false;
      _isTtsSpeaking = false;
      _isTtsPaused = false;
      _lastSpeechTime = null;
      _liveTranscription = '';
      _currentAmplitude = -50.0;
      _statusMessage = null;
    });
  }

  // Search Messages
  void _searchMessages(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredMessages = [];
      } else {
        _filteredMessages = _messages
            .where((msg) => msg.text.toLowerCase().contains(_searchQuery))
            .toList();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredMessages = [];
        _searchQuery = '';
      }
    });
  }

  // Generate Flashcards from Conversation
  void _generateFlashcards() {
    List<Map<String, String>> cards = [];

    for (var msg in _messages) {
      if (!msg.isUser && msg.text.length > 50) {
        // Extract key concepts using simple heuristics
        final lines = msg.text.split('\n');
        String? question;
        String? answer;

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          // Look for definition patterns
          if (line.contains(':') && line.length < 100) {
            final parts = line.split(':');
            if (parts.length == 2) {
              question = parts[0].trim();
              answer = parts[1].trim();
              if (question.isNotEmpty && answer.isNotEmpty) {
                cards.add({'question': question, 'answer': answer});
              }
            }
          }
          // Look for numbered lists
          else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
            if (i > 0) {
              question = lines[i - 1].trim();
              answer = line;
              if (question.isNotEmpty && answer.isNotEmpty) {
                cards.add({'question': question, 'answer': answer});
              }
            }
          }
        }
      }
    }

    setState(() => _flashcards = cards);

    if (cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No flashcards found. Try having a more detailed conversation.',
          ),
        ),
      );
    } else {
      _showFlashcardsDialog();
    }
  }

  void _showFlashcardsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.style, size: 24),
            const SizedBox(width: 12),
            Text('Flashcards (${_flashcards.length})'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: _flashcards.length,
            itemBuilder: (context, index) {
              final card = _flashcards[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(
                    card['question']!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(card['answer']!),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              // Export flashcards as text
              final flashcardText = _flashcards
                  .map((c) => 'Q: ${c['question']}\nA: ${c['answer']}\n')
                  .join('\n');
              Clipboard.setData(ClipboardData(text: flashcardText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Flashcards copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy All'),
          ),
        ],
      ),
    );
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
        if (value == 'settings') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const profile_page.ProfileScreen(),
            ),
          );
        } else if (value == 'logout') {
          await authProvider.signOut();
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
    );
  }

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
                        if (_isSearching)
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'Search messages...',
                                border: InputBorder.none,
                                prefixIcon: const Icon(Icons.search, size: 20),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 20),
                                        onPressed: () {
                                          _searchController.clear();
                                          _searchMessages('');
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: _searchMessages,
                            ),
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🎓', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(
                                'TopScore AI',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        const Spacer(),
                        // Search button
                        if (_messages.isNotEmpty)
                          IconButton(
                            icon: Icon(
                              _isSearching ? Icons.close : Icons.search,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            onPressed: _toggleSearch,
                            tooltip: _isSearching
                                ? 'Close search'
                                : 'Search messages',
                          ),
                        // Flashcard generation button
                        if (_messages.length > 3 && !_isSearching)
                          IconButton(
                            icon: Icon(
                              Icons.style_outlined,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            onPressed: _generateFlashcards,
                            tooltip: 'Generate Flashcards',
                          ),
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
                        : _isSearching && _searchQuery.isNotEmpty
                        ? _buildSearchResults(theme)
                        : _messages.isEmpty
                        ? _buildEmptyState(isDark)
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            // Performance: pre-render items beyond viewport for smoother scrolling
                            cacheExtent: 500,
                            // Add findChildIndexCallback to help Flutter track items better
                            findChildIndexCallback: (Key key) {
                              if (key is ValueKey<String>) {
                                return _messages.indexWhere(
                                  (m) => m.id == key.value,
                                );
                              }
                              return null;
                            },
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              return RepaintBoundary(
                                key: ValueKey(
                                  message.id,
                                ), // Add Key for stable identity
                                child: _buildMessageBubble(message, theme),
                              );
                            },
                          ),
                  ),
                  if (_isTyping)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Avatar with loading circle
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // Loading circle around avatar
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.accentTeal,
                                    ),
                                  ),
                                ),
                                // AI Avatar
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white,
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            // Thinking text with animated dots
                            _TypingIndicator(messageType: _loadingMessageType),
                          ],
                        ),
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
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎓', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 24),
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
                  'Hi! I\'m TopScore AI',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your academic wingman',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'What subject are we crushing today?',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
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
                      suggestion['title']!,
                      suggestion['subtitle']!,
                      suggestion['icon']!,
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

  Widget _buildSearchResults(ThemeData theme) {
    if (_filteredMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No messages found',
              style: TextStyle(
                fontSize: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _filteredMessages.length,
      cacheExtent: 500, // Performance: pre-render for smoother scrolling
      itemBuilder: (context, index) {
        final message = _filteredMessages[index];
        return RepaintBoundary(
          key: ValueKey('search_${message.id}'),
          child: _buildMessageBubble(
            message,
            theme,
            highlightQuery: _searchQuery,
          ),
        );
      },
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
    ThemeData theme, {
    String? highlightQuery,
  }) {
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
                        // Voice message player
                        if (message.audioUrl != null &&
                            message.text == '🎤 Audio Message')
                          Container(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Play/Pause button
                                IconButton(
                                  icon: Icon(
                                    _playingAudioMessageId == message.id &&
                                            _isPlayingAudio
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_filled,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  onPressed: () {
                                    if (_playingAudioMessageId == message.id &&
                                        _isPlayingAudio) {
                                      _audioPlayer.pause();
                                      setState(() => _isPlayingAudio = false);
                                    } else if (_playingAudioMessageId ==
                                            message.id &&
                                        !_isPlayingAudio) {
                                      _resumeVoiceMessage();
                                    } else {
                                      _playVoiceMessage(
                                        message.id,
                                        message.audioUrl!,
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                // Waveform placeholder / progress
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Progress bar
                                      Container(
                                        height: 3,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor:
                                              _playingAudioMessageId ==
                                                  message.id
                                              ? (_audioDuration.inMilliseconds >
                                                        0
                                                    ? _audioPosition
                                                              .inMilliseconds /
                                                          _audioDuration
                                                              .inMilliseconds
                                                    : 0.0)
                                              : 0.0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Duration text
                                      Text(
                                        _playingAudioMessageId == message.id
                                            ? '${_formatDuration(_audioPosition)} / ${_formatDuration(_audioDuration)}'
                                            : 'Voice message',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                        // CHANGE: White text on Blue background (hide for voice messages)
                        if (!(message.audioUrl != null &&
                            message.text == '🎤 Audio Message'))
                          SelectableText(
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
          ],
        ),
      );
    } else {
      // --- AI MESSAGE (DM Sans Font + Styled Headers) ---
      // Check if this specific message is currently streaming
      final isStreaming = _currentStreamingMessageId == message.id;

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.only(right: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 12, top: 4),
              child: isStreaming
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.accentTeal,
                            ),
                          ),
                        ),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    )
                  : CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. GEMINI REASONING BLOCK
                  // Replaced the old ExpansionTile with the new GeminiReasoningView
                  if (message.reasoning != null &&
                      message.reasoning!.isNotEmpty)
                    GeminiReasoningView(
                      content: message.reasoning!,
                      // It is "thinking" if the final answer hasn't started streaming yet
                      isThinking: message.text.isEmpty,
                    ),

                  // 2. MAIN ANSWER CONTENT
                  // Only show if there is actually content
                  if (message.text.isNotEmpty)
                    MarkdownBody(
                      data: cleanContent(
                        message.text,
                      ), // Use cleanContent helper
                      selectable:
                          true, // Enable text selection for AI responses
                      builders: {
                        'latex': LatexElementBuilder(), // Use our new builder
                        'mermaid': MermaidElementBuilder(),
                        'a': YouTubeLinkBuilder(
                          context,
                          isDark,
                          isStreaming: isStreaming,
                        ), // Inline YouTube videos - defer until streaming done
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
                            left: BorderSide(
                              color: theme.primaryColor,
                              width: 4,
                            ),
                          ),
                        ),
                      ),
                    )
                  // 3. FALLBACK LOADING (If absolutely nothing has arrived yet)
                  else if (message.text.isEmpty &&
                      (message.reasoning == null || message.reasoning!.isEmpty))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _TypingIndicator(
                        messageType: isStreaming
                            ? _loadingMessageType
                            : 'thinking',
                      ),
                    ),

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

                  // 4. Actions Row - Only show when message is complete and not streaming
                  if (!message.isTemporary && !isStreaming)
                    Wrap(
                      spacing: 0,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Main Actions Group
                        Wrap(
                          children: [
                            // TTS controls - show different icons based on state
                            if (_speakingMessageId == message.id &&
                                _isTtsSpeaking)
                              ..._buildTtsControls(message)
                            else
                              _buildActionIcon(
                                Icons.volume_up_outlined,
                                () =>
                                    _speak(message.text, messageId: message.id),
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
                          ],
                        ),
                        // Feedback Group
                        Wrap(
                          children: [
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
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  // Helper for consistent Action Icons
  List<Widget> _buildTtsControls(ChatMessage message) {
    return [
      if (_isTtsPaused)
        _buildActionIcon(
          Icons.play_arrow,
          _resumeTts,
          tooltip: 'Resume',
          isActive: true,
          color: AppColors.googleBlue,
        )
      else
        _buildActionIcon(
          Icons.pause,
          _pauseTts,
          tooltip: 'Pause',
          isActive: true,
          color: AppColors.googleBlue,
        ),
      _buildActionIcon(
        Icons.stop,
        _stopTts,
        tooltip: 'Stop',
        isActive: true,
        color: Colors.redAccent,
      ),
    ];
  }

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
    // Filter threads based on search query
    final filteredThreads = _threads.where((thread) {
      final title = (thread['title'] as String? ?? '').toLowerCase();
      final query = _historySearchQuery.toLowerCase();
      return title.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              IconButton(
                icon: Icon(
                  Icons.menu_open_rounded,
                  color: theme.colorScheme.onSurface,
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
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
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
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // --- NEW: Search Bar ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _historySearchController,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search chats...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                suffixIcon: _historySearchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          setState(() {
                            _historySearchQuery = '';
                            _historySearchController.clear();
                          });
                        },
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _historySearchQuery = value;
                });
              },
            ),
          ),
        ),

        // -----------------------
        const SizedBox(height: 8),
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
                    : filteredThreads.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _threads.isEmpty
                              ? "No chats yet"
                              : "No matches found",
                          style: TextStyle(color: theme.disabledColor),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredThreads.length,
                        itemBuilder: (context, index) {
                          final thread = filteredThreads[index];
                          final isSelected =
                              thread['thread_id'] == _wsService.threadId;
                          return InkWell(
                            onTap: () => _loadThread(thread['thread_id']),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.primaryColor.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
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

                                  // Rename Button
                                  if (isSelected)
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        size: 16,
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
                                        _showRenameDialog(
                                          thread['thread_id'],
                                          thread['title'] ?? '',
                                        );
                                      },
                                    ),

                                  const SizedBox(width: 4),

                                  // Delete Button (Only filter/delete on confirm)
                                  if (isSelected)
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: theme.disabledColor.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                      splashRadius: 20,
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      tooltip: 'Delete Chat',
                                      onPressed: () {
                                        _confirmDeleteThread(
                                          thread['thread_id'],
                                        );
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

    // Glassmorphism colors
    final glassColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.85);
    final glassBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.08);
    final accentGlow = theme.primaryColor.withValues(alpha: 0.4);

    return Container(
      decoration: BoxDecoration(
        // Subtle gradient background
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.scaffoldBackgroundColor.withValues(alpha: 0.0),
            theme.scaffoldBackgroundColor,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Suggested Question Chips (show when no messages)
          if (_messages.isEmpty && _displayedQuestions.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    ..._displayedQuestions.map((question) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _textController.text = question;
                              });
                              _messageFocusNode.requestFocus();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.primaryColor.withValues(alpha: 0.15),
                                    theme.primaryColor.withValues(alpha: 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.primaryColor.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 14,
                                    color: theme.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    question,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    // Refresh button with animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 300),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.8 + (0.2 * value),
                          child: IconButton(
                            icon: Icon(
                              Icons.refresh_rounded,
                              size: 20,
                              color: theme.primaryColor.withValues(alpha: 0.7),
                            ),
                            tooltip: 'More suggestions',
                            onPressed: () {
                              setState(() {
                                _shuffleQuestions();
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Main Input Container with Glassmorphism
          Focus(
            onFocusChange: (hasFocus) {
              setState(() {}); // Trigger rebuild for focus animation
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: glassColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _messageFocusNode.hasFocus
                      ? accentGlow
                      : glassBorderColor,
                  width: _messageFocusNode.hasFocus ? 1.5 : 1,
                ),
                boxShadow: [
                  if (_messageFocusNode.hasFocus)
                    BoxShadow(
                      color: theme.primaryColor.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Attachment Preview (Enhanced)
                    if (_pendingFileName != null)
                      _buildAttachmentPreview(theme, isDark),

                    // Input Field & Actions
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Text Input with improved styling
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 120),
                            child: TextField(
                              focusNode: _messageFocusNode,
                              controller: _textController,
                              contextMenuBuilder: (context, editableTextState) {
                                final List<ContextMenuButtonItem> buttonItems =
                                    editableTextState.contextMenuButtonItems;
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
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
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
                                    : 'Message TopScore AI...',
                                hintStyle: GoogleFonts.inter(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                              onSubmitted: (value) => _sendMessage(text: value),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Actions Row (Redesigned)
                          _buildActionsRow(theme, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Disclaimer text
          if (_messages.isNotEmpty && !_isTyping)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'AI can make mistakes. Check important info.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Enhanced attachment preview with larger thumbnail and animations
  Widget _buildAttachmentPreview(ThemeData theme, bool isDark) {
    final isImage = _pendingPreviewData != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          // Enhanced Thumbnail or File Icon
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isImage
                      ? null
                      : theme.primaryColor.withValues(alpha: 0.1),
                  border: isImage
                      ? null
                      : Border.all(
                          color: theme.primaryColor.withValues(alpha: 0.2),
                        ),
                  boxShadow: [
                    if (isImage)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                  image: isImage
                      ? DecorationImage(
                          image: MemoryImage(
                            base64Decode(_pendingPreviewData!.split(',')[1]),
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: !isImage
                    ? Icon(
                        Icons.description_outlined,
                        color: theme.primaryColor,
                        size: 28,
                      )
                    : null,
              ),
              if (_isUploading)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // File Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pendingFileName ?? 'Image',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _isUploading ? 'Uploading...' : 'Ready to send',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _isUploading
                        ? theme.primaryColor
                        : Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Remove Button (Animated)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isUploading ? null : _clearPendingAttachment,
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isUploading
                      ? Colors.transparent
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: _isUploading
                      ? theme.disabledColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Redesigned actions row with better spacing and animations
  Widget _buildActionsRow(ThemeData theme, bool isDark) {
    return Row(
      children: [
        // Attachment Button (Redesigned)
        _buildActionButton(
          icon: Icons.add_rounded,
          tooltip: 'Add attachment',
          theme: theme,
          isDark: isDark,
          onTap: () {
            _showAttachmentMenu(theme, isDark);
          },
        ),

        const SizedBox(width: 2),

        // ELI5 Mode Toggle
        _buildActionButton(
          icon: _isEli5Mode ? Icons.child_care : Icons.child_care_outlined,
          tooltip: 'Explain Like I\'m 5',
          theme: theme,
          isDark: isDark,
          isActive: _isEli5Mode,
          onTap: () {
            setState(() {
              _isEli5Mode = !_isEli5Mode;
            });
            if (_isEli5Mode) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.child_care, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      const Text("ELI5 Mode: Simpler answers enabled"),
                    ],
                  ),
                  duration: const Duration(milliseconds: 1500),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: theme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
          },
        ),

        // Tools Button Removed

        const Spacer(),

        // Model Selector Removed

        // Voice Mode Button
        _buildActionButton(
          icon: Icons.graphic_eq_rounded,
          tooltip: 'Live Voice Mode',
          theme: theme,
          isDark: isDark,
          isActive: _isVoiceMode,
          activeColor: AppColors.googleBlue,
          onTap: _toggleLiveVoice,
        ),

        const SizedBox(width: 4),

        // Send/Mic Button (Animated)
        _buildSendButton(theme, isDark),
      ],
    );
  }

  /// Reusable action button with hover effects
  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required ThemeData theme,
    required bool isDark,
    bool isActive = false,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    final color = isActive
        ? (activeColor ?? theme.primaryColor)
        : theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive
                  ? (activeColor ?? theme.primaryColor).withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }

  // _buildModelSelector removed

  /// Animated send button with state transitions
  Widget _buildSendButton(ThemeData theme, bool isDark) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _textController,
      builder: (context, value, child) {
        final hasText = value.text.trim().isNotEmpty;
        final hasAttachment = _pendingFileUrl != null;
        final canSend = hasText || hasAttachment;

        // Stop button when AI is generating
        if (_isTyping) {
          return _buildAnimatedButton(
            icon: Icons.stop_rounded,
            color: theme.colorScheme.error,
            onTap: _stopGeneration,
            size: 44,
          );
        }

        // Recording state
        if (_isRecording) {
          return _buildAnimatedButton(
            icon: Icons.stop_rounded,
            color: Colors.redAccent,
            onTap: _stopRecording,
            size: 44,
            isRecording: true,
          );
        }

        // Send or Mic button
        return _buildAnimatedButton(
          icon: canSend ? Icons.arrow_upward_rounded : Icons.mic_rounded,
          color: canSend
              ? theme.primaryColor
              : (isDark ? Colors.white24 : Colors.black12),
          iconColor: canSend
              ? Colors.white
              : theme.colorScheme.onSurface.withValues(alpha: 0.7),
          onTap: () {
            if (canSend) {
              _sendMessage();
            } else {
              _startRecording();
            }
          },
          size: 44,
        );
      },
    );
  }

  /// Premium animated button with scale and glow effects
  Widget _buildAnimatedButton({
    required IconData icon,
    required Color color,
    Color? iconColor,
    required VoidCallback onTap,
    required double size,
    bool isRecording = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Recording pulse animation
            if (isRecording)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.2),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
                onEnd: () {
                  // Trigger rebuild to continue animation
                  if (_isRecording) setState(() {});
                },
              ),
            Icon(icon, size: size * 0.5, color: iconColor ?? Colors.white),
          ],
        ),
      ),
    );
  }

  /// Show attachment menu as bottom sheet
  void _showAttachmentMenu(ThemeData theme, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _buildAttachmentOption(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              _buildAttachmentOption(
                icon: Icons.camera_alt_outlined,
                label: kIsWeb ? 'Capture Photo' : 'Take Photo',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              _buildAttachmentOption(
                icon: Icons.image_outlined,
                label: 'Upload Image File',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _pickFile(FileType.image);
                },
              ),
              _buildAttachmentOption(
                icon: Icons.description_outlined,
                label: 'Upload Document',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
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
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  // _showToolsMenu removed

  // _showModelMenu removed

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
  final String messageType; // 'thinking', 'analyzing', 'generating'

  const _TypingIndicator({this.messageType = 'thinking'});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get appropriate loading text
    String loadingText;
    switch (widget.messageType) {
      case 'analyzing':
        loadingText = 'Analysing...';
        break;
      case 'generating':
        loadingText = 'Generating...';
        break;
      case 'thinking':
      default:
        loadingText = 'Thinking...';
        break;
    }

    return FadeTransition(
      opacity: _opacity,
      child: Text(
        loadingText,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// --- NEW PRODUCTIVE VOICE UI ---

class _VoiceSessionOverlay extends StatefulWidget {
  final bool isAiSpeaking;
  final bool isRecording;
  final String statusText;
  final String transcription;
  final double amplitude;
  final VoidCallback onClose;
  final VoidCallback onInterrupt;

  const _VoiceSessionOverlay({
    required this.isAiSpeaking,
    required this.isRecording,
    required this.statusText,
    required this.transcription,
    required this.amplitude,
    required this.onClose,
    required this.onInterrupt,
  });

  @override
  State<_VoiceSessionOverlay> createState() => _VoiceSessionOverlayState();
}

class _VoiceSessionOverlayState extends State<_VoiceSessionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStateColor() {
    if (widget.isAiSpeaking) {
      return const Color(0xFF6C63FF); // AI Speaking (Brand)
    }
    if (widget.isRecording) {
      return const Color(0xFF00C853); // User Speaking (Green)
    }
    return Colors.grey; // Processing/Thinking
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStateColor();
    final normalizedAmplitude = ((widget.amplitude + 50) / 50).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Central Orb / Visualizer
            Center(
              child: GestureDetector(
                onTap: widget.onInterrupt, // Tap screen to interrupt
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final scale = widget.isRecording || widget.isAiSpeaking
                            ? 1.0 +
                                  (_pulseController.value * 0.2) +
                                  (normalizedAmplitude * 0.3)
                            : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withValues(alpha: 0.2),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(
                                    alpha: 0.6 * _pulseController.value,
                                  ),
                                  blurRadius: 50,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                ),
                                child: Icon(
                                  widget.isAiSpeaking
                                      ? Icons.graphic_eq
                                      : (widget.isRecording
                                            ? Icons.mic
                                            : Icons.more_horiz),
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    // Audio level bars
                    if (widget.isRecording)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final barHeight =
                              20.0 +
                              (normalizedAmplitude *
                                  40.0 *
                                  (index % 2 == 0 ? 1.0 : 0.7));
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 4,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                  ],
                ),
              ),
            ),

            // 2. Transcription Display
            if (widget.transcription.isNotEmpty)
              Positioned(
                top: 100,
                left: 30,
                right: 30,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    widget.transcription,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontStyle: widget.transcription == 'Transcribing...'
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),
              ),

            // 3. Status Text
            Positioned(
              bottom: 150,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    widget.statusText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (widget.isAiSpeaking)
                    Text(
                      "Tap anywhere to interrupt",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    )
                  else if (widget.isRecording)
                    Text(
                      "Speak naturally, I'm listening...",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),

            // 4. Controls
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Close Button
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

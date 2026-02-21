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
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../screens/auth/auth_screen.dart';

import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_input_area.dart';
import 'widgets/chat_history_sidebar.dart';
import 'widgets/collapsed_sidebar.dart';
import 'widgets/empty_state_widget.dart';
import 'widgets/voice_session_overlay.dart';
import 'widgets/session_rating_dialog.dart';
import '../config/app_theme.dart';

import '../models/video_result.dart';

import '../utils/paste_handler/paste_handler.dart';
import 'message_model.dart';
import 'enhanced_websocket_service.dart';
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
  late final EnhancedWebSocketService _wsService;
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

  // Settings
  final String _selectedModelKey = 'gemini-2.5-flash';

  // TTS state tracking
  bool _isTtsSpeaking = false;
  bool _isTtsPaused = false;
  String? _speakingMessageId;

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
  // Sidebar tri-state: 'expanded' (280px), 'collapsed' (60px icon-only), 'hidden' (0px)
  String _sidebarMode = 'collapsed';
  bool _isSidebarInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isSidebarInitialized) {
      final isDesktop = MediaQuery.of(context).size.width > 700;
      // On mobile, start hidden. On desktop, start expanded.
      _sidebarMode = isDesktop ? 'expanded' : 'hidden';
      _isSidebarInitialized = true;
    }
  }

  bool _showScrollDownButton = false;

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

  // Attachment Staging
  String? _pendingPreviewData; // Base64 Data URI (For local display ONLY)
  String? _pendingFileUrl; // Firebase Storage URL (For sending to AI)
  String? _pendingFileType; // Type of file (image/jpeg, application/pdf, etc.)

  String? _pendingFileName; // Display name
  bool _isUploading = false; // To show spinner

  // Image Picker instance
  final ImagePicker _imagePicker = ImagePicker();

  // Search functionality (Removed unused)

  List<Map<String, String>> _dynamicSuggestions = [];

  // Flashcards (Removed unused)

  // Dynamic placeholder messages

  // Dynamic placeholder messages
  final List<String> _placeholderMessages = [
    'Ask me anything...',
    'What would you like to learn today?',
    'Need help with homework?',
    'Ask a question...',
    'How can I help you?',
  ];
  int _currentPlaceholderIndex = 0;
  Timer? _placeholderTimer;

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
  /*
  final List<Map<String, dynamic>> _allSuggestions = [
    {
      'title': 'Explain Quantum Physics',
      'subtitle': 'in simple terms',
      'icon': Icons.science_outlined,
    },
    ...
  ];
  late List<Map<String, dynamic>> _currentSuggestions;
  */

  @override
  void initState() {
    super.initState();

    // 1. Initialize the Service (But do not connect yet)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId =
        authProvider.userModel?.uid ??
        FirebaseAuth.instance.currentUser?.uid ??
        'guest';
    _wsService = EnhancedWebSocketService(userId: userId);

    // Initial check for guest limit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGuestAccess();
    });

    // Start dynamic placeholder rotation
    _startPlaceholderRotation();

    // 2. Load suggestions (not shuffling anymore as strict list is gone from UI, but kept for logic)
    // _currentSuggestions = _allSuggestions.take(4).toList(); // REMOVED unused

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
    // _loadSuggestedQuestions();

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

    // Add scroll listener for smart scroll-to-bottom button
    _scrollController.addListener(_scrollListener);

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
        if (kIsWeb) return KeyEventResult.ignored; // Let browser handle it

        // Trigger image check (Mobile/Desktop)
        _handlePaste();
        return KeyEventResult.ignored; // Allow default text paste bubble
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

  // --- Scroll Listener for Smart Scroll Button ---
  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final showBtn =
        (maxScroll - currentScroll) > 400; // Show if scrolled up > 400px

    if (showBtn != _showScrollDownButton) {
      setState(() => _showScrollDownButton = showBtn);
    }
  }

  void _scrollToBottomForce() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    setState(() => _showScrollDownButton = false);
  }

  // --- Helper Methods (Data Loading) ---
  // Suggested questions removed - replaced by dynamic backend suggestions in Empty State

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
        // Auto-send if we also have a message (e.g. from PDF Viewer "Ask AI Tutor")
        _processProviderImage(
          navProvider.pendingImage!,
          autoSend: navProvider.pendingMessage != null,
        );
      } else if (navProvider.pendingMessage != null) {
        _sendMessage();
      }
      navProvider.clearPendingData();
    }
  }

  // REMOVED _loadSuggestedQuestions logic as we use dynamic backend suggestions now
  Future<void> _processProviderImage(
    XFile image, {
    bool autoSend = false,
  }) async {
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

        // 3. Auto-Send if requested (e.g., from PDF Viewer) and we have a message
        if (autoSend && _textController.text.isNotEmpty) {
          _sendMessage();
        }
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
          // _statusMessage = "Listening...";
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
          // _statusMessage = null;
        });
        _voiceDialogSetState?.call(() {});
      }

      // If still in Voice Mode and AI finished speaking, auto-listen again
      if (_isVoiceMode && mounted) {
        // setState(() => _statusMessage = "Listening...");
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
            // _statusMessage = null;
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
            // _statusMessage = null;
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

    // LOGIC: Extract Reasoning from Content or use Reasoning field
    String textContent = data['content']?.toString() ?? '';
    String? reasoningContent = data['reasoning']?.toString();

    // Check for <think> tags in content if reasoning is missing or to clean content
    final thinkRegex = RegExp(r'<think>(.*?)</think>', dotAll: true);
    final match = thinkRegex.firstMatch(textContent);

    if (match != null) {
      // Found thinking block in content
      final extractedThinking = match.group(1)?.trim();
      if (extractedThinking != null && extractedThinking.isNotEmpty) {
        // Prefer extracted thinking or append if reasoning already exists
        reasoningContent = (reasoningContent ?? '') + extractedThinking;
      }
      // Remove valid thinking block from displayed text
      textContent = textContent.replaceAll(thinkRegex, '').trim();
    }

    return ChatMessage(
      id: key,
      text: textContent,
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
      reasoning: reasoningContent,
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
      // Auto-close sidebar on mobile for better UX
      final isMobile = MediaQuery.of(context).size.width <= 700;
      if (isMobile) {
        _sidebarMode = 'hidden';
      }
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
            // _statusMessage = "Thinking...";
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
              // _statusMessage = "Thinking...";
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
            // _liveTranscription = transcribedText;
            // _statusMessage = "Thinking...";
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
            // _liveTranscription = responseText;
            // _statusMessage = 'Speaking...';
          });
          _voiceDialogSetState?.call(() {});

          // Play the audio response if available
          if (responseAudio != null && responseAudio.isNotEmpty) {
            _receivedServerAudio = true;
            _playGeminiAudioResponse(responseAudio, audioMimeType);
          } else {
            // Fallback to client-side TTS if no audio in response
            _speakInVoiceMode(responseText);
          }
        }
        break;

      // Gemini Native Audio: TTS-only response
      case 'speech':
        final speechAudio = data['audio'] as String?;
        final speechMimeType =
            data['audio_mime_type'] as String? ?? 'audio/wav';

        if (speechAudio != null && _isVoiceMode) {
          _receivedServerAudio = true;
          _playGeminiAudioResponse(speechAudio, speechMimeType);
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
        // Update temporary message with streamed content (Deltas)
        final chunkContent = data['content'] as String? ?? '';
        final targetId = messageId ?? _currentStreamingMessageId;

        if (targetId != null) {
          setState(() {
            // Find temporary message by ID
            final index = _messages.indexWhere(
              (m) => m.id == targetId && m.isTemporary,
            );

            if (index != -1) {
              // Append new chunk to existing text
              final currentText = _messages[index].text;
              _messages[index] = _messages[index].copyWith(
                text: currentText + chunkContent,
              );
            } else {
              // Message doesn't exist yet - create temporary message
              _messages.add(
                ChatMessage(
                  id: targetId,
                  text: chunkContent,
                  isUser: false,
                  timestamp: DateTime.now(),
                  isTemporary: true,
                  isComplete: false,
                ),
              );
              _isTyping = false;
              _currentStreamingMessageId = targetId;
              _scrollToBottom();
            }
          });
        }
        break;

      case 'reasoning_chunk':
        final rContent = data['content'] as String? ?? '';
        final targetId = messageId ?? _currentStreamingMessageId;

        if (targetId != null) {
          setState(() {
            // Find the temp message or create it if missing
            final index = _messages.indexWhere((m) => m.id == targetId);

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
                  id: targetId,
                  text: "", // Empty text triggers the "isThinking" state in UI
                  reasoning: rContent,
                  isUser: false,
                  timestamp: DateTime.now(),
                  isTemporary: true,
                ),
              );
              _isTyping = false; // Disable global indicator
              _currentStreamingMessageId = targetId;
              _scrollToBottom();
            }
          });
        }
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
        // This creates the full voice loop: user speaks -> AI responds -> speak response -> listen again
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

      case 'suggestions':
        if (data['suggestions'] != null && data['suggestions'] is List) {
          final rawList = data['suggestions'] as List;
          try {
            final parsedSuggestions = rawList.map((item) {
              final map = Map<String, dynamic>.from(item);
              return {
                'emoji': map['emoji']?.toString() ?? '✨',
                'title': map['title']?.toString() ?? '',
                'subtitle': map['subtitle']?.toString() ?? '',
              };
            }).toList();

            setState(() {
              _dynamicSuggestions = parsedSuggestions;
              // Clear chips below input area as requested
              // _displayedQuestions = []; // REMOVED
            });
            developer.log(
              "💡 Received dynamic suggestions: $parsedSuggestions",
            );
          } catch (e) {
            developer.log("Error parsing suggestions: $e");
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
        // _statusMessage = null;
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
      // _statusMessage = null;
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
      // _statusMessage = _isVoiceMode ? "Thinking..." : "Connecting...";
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

  void _handleDictation() {
    // Placeholder for simple dictation
    // In valid implementation, this would start speech-to-text for the input field
    debugPrint('Dictation triggered');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dictation feature coming soon!')),
    );
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
      // _statusMessage = ''; // Clear previous transcription
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

  Future<void> _pauseVoiceMessage() async {
    try {
      await _audioPlayer.pause();
      setState(() {
        _isPlayingAudio = false;
      });
    } catch (e) {
      developer.log('Error pausing voice message: $e', name: 'ChatScreen');
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  Future<void> _handlePaste() async {
    try {
      // 1. Try Image Paste (Mobile/Desktop ONLY)
      if (!kIsWeb) {
        final imageBytes = await Pasteboard.image;
        if (imageBytes != null && imageBytes.isNotEmpty) {
          // Validate Header (Prevent HTML pastes pretending to be images)
          if (imageBytes.length > 4 && imageBytes[0] == 0x3c) return;

          // Show Preview Immediately
          final base64Image = base64Encode(imageBytes);

          setState(() {
            _pendingPreviewData = 'data:image/png;base64,$base64Image';
            _pendingFileName = "Pasted Image.png";
            _isUploading = true;
          });

          // Upload in Background
          final url = await _uploadToFirebase(
            imageBytes,
            'pasted_image.png',
            'image/png',
          );

          if (mounted) {
            if (url != null) {
              setState(() => _pendingFileUrl = url);
            } else {
              _clearPendingAttachment();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Failed to upload image")),
              );
            }
          }
          return;
        }
      }

      // 2. Try Text Paste
      final ClipboardData? cbd = await Clipboard.getData(Clipboard.kTextPlain);
      if (cbd != null && cbd.text != null && cbd.text!.isNotEmpty) {
        final text = cbd.text!;
        final selection = _textController.selection;

        // Insert text at cursor position
        final newText = _textController.text.replaceRange(
          selection.start < 0 ? 0 : selection.start,
          selection.end < 0 ? 0 : selection.end,
          text,
        );

        // Update selection to end of pasted text
        final newSelectionIndex =
            (selection.start < 0 ? 0 : selection.start) + text.length;

        _textController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newSelectionIndex),
        );
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
    // Smart auto-scroll: Only scroll if user is already near bottom or it's a new user message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        final current = _scrollController.position.pixels;
        // Auto-scroll if within 200px of bottom OR the last message is from user
        if ((max - current) < 200 ||
            (_messages.isNotEmpty && _messages.last.isUser)) {
          _scrollController.animateTo(
            max,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  // ============ LIVE VOICE MODE ============

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
    _placeholderTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    removePasteHandler();
    super.dispose();
  }

  void _startPlaceholderRotation() {
    _placeholderTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _textController.text.isEmpty) {
        setState(() {
          _currentPlaceholderIndex =
              (_currentPlaceholderIndex + 1) % _placeholderMessages.length;
        });
      }
    });
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
          // _statusMessage = "Listening..."; // Initial state
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
            // setState(() => _currentAmplitude = currentDb);
            // _voiceDialogSetState?.call(() => _currentAmplitude = currentDb);
          }

          // 1. Detect if user STARTED talking
          if (currentDb > _speechThreshold) {
            _lastSpeechTime = DateTime.now();
            if (!_isSpeechDetected) {
              if (mounted) {
                setState(() {
                  _isSpeechDetected = true;
                  // _statusMessage = "I'm listening...";
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
      // _liveTranscription = 'Transcribing...';
      // _statusMessage = "Thinking..."; // Show we heard them
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
      // _statusMessage = "Speaking...";
      // _liveTranscription = ''; // Clear transcription when AI speaks
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
            // _statusMessage = "Listening...";
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
        // _statusMessage = "Error playing audio";
      });
      _voiceDialogSetState?.call(() {});
      // Retry listening after error
      Future.delayed(const Duration(milliseconds: 500), _startListening);
    }
  }

  /// Play base64-encoded audio from Gemini Native Audio response
  /// This is used for speech-to-speech conversation where server sends audio directly
  Future<void> _playGeminiAudioResponse(
    String base64Audio,
    String mimeType,
  ) async {
    if (!_isVoiceMode) return;

    // Reset UI for Overlay to update
    setState(() {
      _isAiSpeaking = true;
      // _statusMessage = "Speaking...";
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
        final extension = mimeType.contains('wav')
            ? 'wav'
            : mimeType.contains('mp3')
            ? 'mp3'
            : mimeType.contains('aac')
            ? 'm4a'
            : 'wav';
        tempPath =
            '${tempDir.path}/gemini_response_${DateTime.now().millisecondsSinceEpoch}.$extension';
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
            // _statusMessage = "Listening...";
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
        // _statusMessage = "Error playing audio";
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
      // _liveTranscription = '';
      // _currentAmplitude = -50.0;
      // _statusMessage = null;
    });
  }

  // Search Messages - Unused, cleanup
  // void _searchMessages(String query) { ... }
  // void _toggleSearch() { ... }

  // Generate Flashcards from Conversation - Unused, cleanup
  // void _generateFlashcards() { ... }
  // void _showFlashcardsDialog() { ... }

  // 1. Logic to delete from Firebase and update UI
  Future<void> _deleteThread(String threadId) async {
    try {
      // API CALL to delete thread
      final response = await http.delete(
        Uri.parse('$_backendUrl/threads/$threadId'),
      );

      if (response.statusCode == 200) {
        setState(() {
          // Remove from local list
          _threads.removeWhere((t) => t['thread_id'] == threadId);

          // If we deleted the active chat, start a new one
          if (_wsService.threadId == threadId) {
            _startNewChat(closeDrawer: false);
          }
        });
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
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
      // API CALL to rename thread
      final response = await http.patch(
        Uri.parse('$_backendUrl/threads/$threadId/title'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'title': newTitle}),
      );

      if (response.statusCode == 200) {
        // Update Local UI immediately
        setState(() {
          final index = _threads.indexWhere((t) => t['thread_id'] == threadId);
          if (index != -1) {
            _threads[index]['title'] = newTitle;
          }
          // Sync cache
          _titleCache[threadId] = newTitle;
        });
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
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

  void _showRatingDialog() {
    showDialog(
      context: context,
      builder: (context) => SessionRatingDialog(
        onSubmit: () {
          // Logic to handle rating submission (e.g., analytics)
          developer.log("Session Rated", name: "ChatScreen");
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use local constraints to decide layout mode
        final isDesktop = constraints.maxWidth > 700;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.transparent, // Transparent to show gradient
          extendBodyBehindAppBar: true,
          drawer: isDesktop ? null : _buildMobileDrawer(theme, isDark),
          appBar: isDesktop ? null : _buildMobileAppBar(theme, isDark),
          body: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF000000)
                  : theme.scaffoldBackgroundColor,
              gradient: isDark
                  ? const RadialGradient(
                      center: Alignment.topCenter,
                      radius: 2.5,
                      colors: [
                        Color(0xFF181835), // Deep Blue/Purple glow
                        Color(0xFF0A0A14), // Very Dark Blue (almost black)
                      ],
                      stops: [0.0, 1.0],
                    )
                  : null,
            ),
            child: SafeArea(
              child: isDesktop
                  ? Row(
                      children: [
                        _buildSidebar(theme, isDark),
                        Expanded(child: _buildMainChatArea(theme)),
                      ],
                    )
                  : _buildMainChatArea(theme),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildMobileAppBar(ThemeData theme, bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.menu, color: isDark ? Colors.white : Colors.black87),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Text(
        'TopScore AI',
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(ThemeData theme, bool isDark) {
    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: ChatHistorySidebar(
        isDark: isDark,
        threads: _threads,
        historySearchQuery: _historySearchQuery,
        historySearchController: _historySearchController,
        isLoadingHistory: _isLoadingHistory,
        currentThreadId: _wsService.threadId,
        onCloseSidebar: () => Navigator.pop(context),
        onStartNewChat: _startNewChat,
        onLoadThread: _loadThread,
        onRenameThread: _showRenameDialog,
        onDeleteThread: _confirmDeleteThread,
        onFinishLesson: _showRatingDialog,
        onSearchChanged: (value) {
          setState(() {
            _historySearchQuery = value;
            if (value.isEmpty) {
              _historySearchController.clear();
            }
          });
        },
      ),
    );
  }

  Widget _buildSidebar(ThemeData theme, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _sidebarMode == 'expanded'
          ? 280
          : _sidebarMode == 'collapsed'
          ? 60
          : 0,
      curve: Curves.easeInOut,
      child: _sidebarMode == 'hidden'
          ? const SizedBox.shrink()
          : _sidebarMode == 'collapsed'
          ? CollapsedSidebar(
              isDark: isDark,
              onModeChange: (mode) => setState(() => _sidebarMode = mode),
              onStartNewChat: () => _startNewChat(closeDrawer: false),
            )
          : AppTheme.buildGlassContainer(
              context,
              borderRadius: 0,
              opacity: isDark ? 0.3 : 0.5,
              blur: 20,
              border: Border(
                right: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
              child: ChatHistorySidebar(
                isDark: isDark,
                threads: _threads,
                historySearchQuery: _historySearchQuery,
                historySearchController: _historySearchController,
                isLoadingHistory: _isLoadingHistory,
                currentThreadId: _wsService.threadId,
                onCloseSidebar: () =>
                    setState(() => _sidebarMode = 'collapsed'),
                onStartNewChat: _startNewChat,
                onLoadThread: _loadThread,
                onRenameThread: _showRenameDialog,
                onDeleteThread: _confirmDeleteThread,
                onFinishLesson: _showRatingDialog,
                onSearchChanged: (value) {
                  setState(() {
                    _historySearchQuery = value;
                    if (value.isEmpty) {
                      _historySearchController.clear();
                    }
                  });
                },
              ),
            ),
    );
  }

  /* Widget _buildSearchResults(ThemeData theme) { ... } */

  // Widget _buildSuggestionCard(...) REMOVED

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
            borderRadius: const BorderRadius.all(Radius.circular(20)),
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
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
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
                    allowedExtensions: const [
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

  /// Helper widget for attachment options
  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      onTap: onTap,
    );
  }

  /// Start live voice mode - full conversation mode
  Future<void> _startLiveVoiceMode() async {
    if (!await _audioRecorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for voice mode'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _isVoiceMode = true;
    });

    // Show voice mode overlay
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            _voiceDialogSetState = setState;
            return VoiceSessionOverlay(
              isAiSpeaking: _isAiSpeaking,
              isRecording: _isRecording,
              statusText: _isAiSpeaking
                  ? 'Speaking...'
                  : _isRecording
                  ? 'Listening...'
                  : 'Thinking...',
              transcription: '',
              amplitude: -50.0,
              onClose: () {
                _stopLiveVoice();
                Navigator.pop(context);
              },
              onInterrupt: () {
                if (_isAiSpeaking) {
                  _flutterTts.stop();
                  _audioPlayer.stop();
                  setState(() {
                    _isAiSpeaking = false;
                  });
                  _startListening();
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMainChatArea(ThemeData theme) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Column(
      children: [
        const SizedBox(height: 8),
        // Messages area (takes all remaining space)
        Expanded(
          child: Stack(
            children: [
              _isLoadingMessages
                  ? Center(
                      child: CircularProgressIndicator(
                        color: theme.primaryColor,
                      ),
                    )
                  : _messages.isEmpty
                  ? EmptyStateWidget(
                      isDark: Theme.of(context).brightness == Brightness.dark,
                      theme: theme,
                      suggestions: _dynamicSuggestions,
                      onSuggestionTap: (prompt) {
                        _sendMessage(text: prompt);
                      },
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16,
                            bottom: 16,
                          ),
                          itemCount: _messages.length,
                          cacheExtent: 500,
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
                            final isStreaming =
                                _currentStreamingMessageId == message.id;
                            return ChatMessageBubble(
                              key: ValueKey(message.id),
                              message: message,
                              isStreaming: isStreaming,
                              playingAudioMessageId: _playingAudioMessageId,
                              isPlayingAudio: _isPlayingAudio,
                              audioDuration: _audioDuration,
                              audioPosition: _audioPosition,
                              speakingMessageId: _speakingMessageId,
                              isTtsSpeaking: _isTtsSpeaking,
                              isTtsPaused: _isTtsPaused,
                              onPlayVoice: () => _playVoiceMessage(
                                message.id,
                                message.audioUrl!,
                              ),
                              onPauseVoice: _pauseVoiceMessage,
                              onResumeVoice: _resumeVoiceMessage,
                              onSpeak: (text) =>
                                  _speak(text, messageId: message.id),
                              onStopTts: _stopTts,
                              onPauseTts: _pauseTts,
                              onResumeTts: _resumeTts,
                              onCopy: () => _copyToClipboard(message.text),
                              onToggleBookmark: () => _toggleBookmark(message),
                              onShare: () => _shareMessage(message.text),
                              onRegenerate: () => _regenerateResponse(message),
                              onFeedback: (feedback) =>
                                  _provideFeedback(message, feedback),
                              onEdit: () => _handleUserEdit(message),
                              onDownloadImage: () =>
                                  _downloadImage(message.imageUrl!),
                              user: authProvider.userModel,
                            );
                          },
                        ),
                      ),
                    ),

              // Scroll to Bottom Button
              if (_showScrollDownButton)
                Positioned(
                  bottom: 16,
                  right: 20,
                  child: FloatingActionButton.small(
                    backgroundColor: theme.primaryColor,
                    onPressed: _scrollToBottomForce,
                    elevation: 4,
                    child: const Icon(
                      Icons.arrow_downward,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Input Area (naturally below messages)
        Container(
          color: theme.scaffoldBackgroundColor,
          padding: const EdgeInsets.only(top: 4),
          child: _buildInputArea(
            theme,
            Theme.of(context).brightness == Brightness.dark,
          ),
        ),

        // AI Disclaimer — pinned to very bottom
        Container(
          width: double.infinity,
          color: theme.scaffoldBackgroundColor,
          padding: const EdgeInsets.only(bottom: 6, top: 2),
          child: Text(
            'AI can make mistakes. Double check information.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea(ThemeData theme, bool isDark) {
    return ChatInputArea(
      textController: _textController,
      messageFocusNode: _messageFocusNode,
      pendingFileName: _pendingFileName,
      pendingPreviewData: _pendingPreviewData,
      pendingFileUrl: _pendingFileUrl,
      isUploading: _isUploading,
      isTyping: _isTyping,
      isRecording: _isRecording,
      suggestions: _dynamicSuggestions,
      placeholderMessages: _placeholderMessages,
      onSendMessage: _sendMessage,
      onSendMessageWithText: _sendMessage,
      onShowAttachmentMenu: () => _showAttachmentMenu(theme, isDark),

      onPaste: _handlePaste, // New explicit handler for generic paste
      onStopGeneration: _stopGeneration,
      onStopListeningAndSend: _stopListeningAndSend,
      onStartLiveVoiceMode: _startLiveVoiceMode,
      onClearPendingAttachment: _clearPendingAttachment,
      onShuffleQuestions: () {}, // No-op as chips are removed
      onDictation: _handleDictation,
    );
  }
}

// ===========================================================================
// Typing Indicator Widget (moved outside _ChatScreenState)
// ===========================================================================

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

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
    return FadeTransition(
      opacity: _opacity,
      child: Text(
        'Thinking...',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

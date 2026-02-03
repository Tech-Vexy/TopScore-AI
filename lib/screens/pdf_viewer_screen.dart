import 'dart:async';
import 'package:universal_io/io.dart';
import 'dart:ui' as ui;

import 'package:clipboard/clipboard.dart';
import 'package:croppy/croppy.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; // Provides XFile
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../tutor_client/chat_screen.dart';

/// Enum for embedded chat panel state
enum _ChatPanelState { closed, minimized, expanded }

class PdfViewerScreen extends StatefulWidget {
  final String? storagePath; // Firebase path OR full URL
  final String? url; // Web URL
  final String? assetPath; // Local Asset
  final Uint8List? bytes; // Raw Data
  final File? file; // Local File
  final String title;

  const PdfViewerScreen({
    super.key,
    this.storagePath,
    this.url,
    this.assetPath,
    this.bytes,
    this.file,
    required this.title,
  }) : assert(
          storagePath != null ||
              url != null ||
              assetPath != null ||
              bytes != null ||
              file != null,
          'You must provide at least one PDF source',
        );

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final GlobalKey _pdfRepaintKey = GlobalKey(); // Key for screenshot capture
  final GlobalKey<_EmbeddedChatPanelState> _chatPanelKey = GlobalKey();

  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSubscriptionError = false;
  OverlayEntry? _overlayEntry;

  // Embedded chat panel state
  _ChatPanelState _chatPanelState = _ChatPanelState.closed;
  XFile? _pendingChatImage;
  String? _pendingChatMessage;

  // Store document URL for sharing
  String? _documentUrl;

  @override
  void dispose() {
    _checkAndCloseContextMenu();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPdfData();
  }

  void _checkAndCloseContextMenu() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  /// --- THEMED CONTEXT MENU ---
  void _showContextMenu(
      BuildContext context, PdfTextSelectionChangedDetails details) {
    _checkAndCloseContextMenu();

    final OverlayState overlayState = Overlay.of(context);
    if (details.globalSelectedRegion == null) return;

    // Theme Data extraction
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use "Inverse Surface" for high contrast against the PDF (usually white)
    // In Light Mode: Dark Gray background. In Dark Mode: Light Gray background.
    final backgroundColor = colorScheme.inverseSurface;
    final contentColor = colorScheme.onInverseSurface;

    final double top = details.globalSelectedRegion!.top - 60;
    final double left = details.globalSelectedRegion!.left;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: top < 0 ? 20 : top,
        left: left < 0 ? 0 : left,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  blurRadius: 8,
                  color: Colors.black.withValues(alpha: 0.2),
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () {
                    final selectedText = details.selectedText;
                    if (selectedText != null) {
                      Clipboard.setData(ClipboardData(text: selectedText));
                      _checkAndCloseContextMenu();
                      _pdfViewerController.clearSelection();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Copied to clipboard',
                              style: TextStyle(
                                  color: colorScheme.onInverseSurface),
                            ),
                            backgroundColor: colorScheme.inverseSurface,
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(Icons.copy, color: contentColor, size: 16),
                  label: Text(
                    'Copy',
                    style: TextStyle(color: contentColor, fontSize: 14),
                  ),
                ),
                // Separation Divider
                Container(
                  width: 1,
                  height: 20,
                  color: contentColor.withValues(alpha: 0.3),
                ),
                // "Explain" Button
                TextButton.icon(
                  onPressed: () {
                    final selectedText = details.selectedText;
                    if (selectedText != null) {
                      _checkAndCloseContextMenu();
                      _pdfViewerController.clearSelection();

                      // Navigate to AI Chat
                      Provider.of<NavigationProvider>(context, listen: false)
                          .navigateToChat(
                        message:
                            "Please explain this text:\n\n\"$selectedText\"",
                        context: context,
                      );
                    }
                  },
                  icon: FaIcon(FontAwesomeIcons.wandMagicSparkles,
                      color: contentColor, size: 14),
                  label: Text(
                    'Explain',
                    style: TextStyle(color: contentColor, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlayState.insert(_overlayEntry!);
  }

  /// --- 1. LOADING LOGIC ---
  Future<void> _loadPdfData() async {
    try {
      Uint8List? loadedBytes;

      if (widget.bytes != null) {
        loadedBytes = widget.bytes;
      } else if (widget.url != null) {
        _documentUrl = widget.url;
        loadedBytes = await _downloadFromUrl(widget.url!);
      } else if (widget.storagePath != null) {
        if (widget.storagePath!.startsWith('http')) {
          _documentUrl = widget.storagePath;
          loadedBytes = await _downloadFromUrl(widget.storagePath!);
        } else {
          try {
            // Get download URL for sharing
            _documentUrl = await FirebaseStorage.instance
                .ref(widget.storagePath!)
                .getDownloadURL();

            loadedBytes = await FirebaseStorage.instance
                .ref(widget.storagePath!)
                .getData(30 * 1024 * 1024);

            if (loadedBytes == null) throw Exception("File is empty");
          } on FirebaseException catch (e) {
            if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
              if (mounted) {
                setState(() {
                  _isSubscriptionError = true;
                  _isLoading = false;
                });
              }
              return;
            }
            rethrow;
          }
        }
      } else if (widget.assetPath != null) {
        final byteData = await rootBundle.load(widget.assetPath!);
        loadedBytes = byteData.buffer.asUint8List();
      } else if (widget.file != null) {
        loadedBytes = await widget.file!.readAsBytes();
      }

      if (mounted) {
        setState(() {
          _pdfBytes = loadedBytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading PDF: $e");
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<Uint8List> _downloadFromUrl(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception("Failed to download: ${response.statusCode}");
    }
  }

  /// --- 2. DOWNLOAD FILE FEATURE ---
  Future<void> _downloadFile() async {
    if (_pdfBytes == null) return;

    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download not supported on Web yet')),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final safeTitle = widget.title.replaceAll(RegExp(r'[^\w\s\.]'), '_');
      final fileName =
          safeTitle.endsWith('.pdf') ? safeTitle : '$safeTitle.pdf';
      final file = File('${tempDir.path}/$fileName');

      await file.writeAsBytes(_pdfBytes!);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Sharing $fileName',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  /// --- 3. CAPTURE & ACTIONS ---

  Future<Uint8List?> _captureVisibleArea() async {
    try {
      final boundary = _pdfRepaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) return null;

      // Capture at device pixel ratio for clarity
      final image = await boundary.toImage(
        pixelRatio: MediaQuery.of(context).devicePixelRatio,
      );

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Capture failed: $e');
      return null;
    }
  }

  Future<void> _captureAndAction() async {
    final fullBytes = await _captureVisibleArea();

    if (!mounted) return;
    if (fullBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not capture current view')),
      );
      return;
    }

    final cropResult = await showMaterialImageCropper(
      context,
      imageProvider: MemoryImage(fullBytes),
    );

    if (cropResult == null || !mounted) return;

    final croppedImage = cropResult.uiImage;
    final byteData = await croppedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final croppedBytes = byteData?.buffer.asUint8List();

    if (croppedBytes == null || !mounted) return;

    // THEMED BOTTOM SHEET
    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Selection Action",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.copy, color: theme.colorScheme.secondary),
                title: Text(
                  'Copy to Clipboard',
                  style: theme.textTheme.bodyLarge,
                ),
                subtitle: Text(
                  'Paste it into notes or other apps',
                  style: theme.textTheme.bodySmall,
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await FlutterClipboard.copyImage(croppedBytes);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard!')),
                    );
                  }
                },
              ),
              ListTile(
                leading: FaIcon(
                  FontAwesomeIcons.wandMagicSparkles,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  'Ask AI Tutor',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Get an explanation or solution instantly',
                  style: theme.textTheme.bodySmall,
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  _sendToAI(croppedBytes);
                },
              ),
              if (_documentUrl != null) ...[
                const Divider(),
                ListTile(
                  leading: FaIcon(
                    FontAwesomeIcons.share,
                    color: theme.colorScheme.tertiary,
                  ),
                  title: Text(
                    'Share Document with AI',
                    style: theme.textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    'Share the document link for AI to analyze',
                    style: theme.textTheme.bodySmall,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareDocumentWithAI();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.link, color: theme.colorScheme.secondary),
                  title: Text(
                    'Copy Document Link',
                    style: theme.textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    'Copy the document URL to share',
                    style: theme.textTheme.bodySmall,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _copyDocumentLink();
                  },
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  /// --- 4. AI SENDING LOGIC ---
  Future<void> _sendToAI(Uint8List imageBytes) async {
    try {
      XFile xFile;

      if (kIsWeb) {
        xFile = XFile.fromData(
          imageBytes,
          mimeType: 'image/png',
          name: 'screenshot.png',
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(imageBytes);
        xFile = XFile(file.path);
      }

      if (!mounted) return;

      // Open embedded chat panel with the image
      _openEmbeddedChat(
        image: xFile,
        message: "Help me understand this section from '${widget.title}'.",
      );
    } catch (e) {
      debugPrint("AI Send Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending to AI: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Opens embedded chat panel with optional image and message
  void _openEmbeddedChat({XFile? image, String? message}) {
    setState(() {
      _pendingChatImage = image;
      _pendingChatMessage = message;
      _chatPanelState = _ChatPanelState.expanded;
    });
    // Give feedback
    HapticFeedback.mediumImpact();
  }

  /// Minimizes the chat panel
  void _minimizeChatPanel() {
    setState(() {
      _chatPanelState = _ChatPanelState.minimized;
    });
  }

  /// Expands the chat panel from minimized state
  void _expandChatPanel() {
    setState(() {
      _chatPanelState = _ChatPanelState.expanded;
    });
  }

  /// Closes the chat panel completely
  void _closeChatPanel() {
    setState(() {
      _chatPanelState = _ChatPanelState.closed;
      _pendingChatImage = null;
      _pendingChatMessage = null;
    });
  }

  /// Share document link with AI Tutor
  void _shareDocumentWithAI() {
    final url = _documentUrl;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document link not available')),
      );
      return;
    }

    _openEmbeddedChat(
      message:
          "I'm reading '${widget.title}'. Here's the document link:\n$url\n\nCan you help me understand this document?",
    );
  }

  /// Copy document link to clipboard
  void _copyDocumentLink() {
    final url = _documentUrl;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document link not available')),
      );
      return;
    }

    Clipboard.setData(ClipboardData(text: url));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document link copied to clipboard!')),
    );
  }

  void _openAiTutorDialog() {
    // Opens embedded chat panel for general questions
    _openEmbeddedChat();
  }

  /// --- 6. UI BUILD ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          // Zoom Controls
          if (!_isLoading && _pdfBytes != null) ...[
            IconButton(
              icon: const Icon(Icons.zoom_out),
              tooltip: 'Zoom Out',
              onPressed: () {
                final newZoom = _pdfViewerController.zoomLevel - 0.25;
                if (newZoom >= 1.0) {
                  _pdfViewerController.zoomLevel = newZoom;
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in),
              tooltip: 'Zoom In',
              onPressed: () {
                final newZoom = _pdfViewerController.zoomLevel + 0.25;
                if (newZoom <= 50.0) {
                  _pdfViewerController.zoomLevel = newZoom;
                }
              },
            ),
          ],

          // More options menu
          if (!_isLoading && _pdfBytes != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (value) {
                switch (value) {
                  case 'download':
                    _downloadFile();
                    break;
                  case 'capture':
                    _captureAndAction();
                    break;
                  case 'share_ai':
                    _shareDocumentWithAI();
                    break;
                  case 'copy_link':
                    _copyDocumentLink();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'download',
                  child: ListTile(
                    leading: Icon(Icons.download_rounded),
                    title: Text('Download PDF'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'capture',
                  child: ListTile(
                    leading: Icon(Icons.crop),
                    title: Text('Capture & Ask AI'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (_documentUrl != null) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'share_ai',
                    child: ListTile(
                      leading: FaIcon(
                        FontAwesomeIcons.share,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Share with AI Tutor'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy_link',
                    child: ListTile(
                      leading: Icon(Icons.link),
                      title: Text('Copy Document Link'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
      body: Stack(
        children: [
          // PDF Viewer Body
          _buildBody(theme),

          // Embedded Chat Panel
          if (_chatPanelState != _ChatPanelState.closed)
            _EmbeddedChatPanel(
              key: _chatPanelKey,
              panelState: _chatPanelState,
              initialImage: _pendingChatImage,
              initialMessage: _pendingChatMessage,
              onMinimize: _minimizeChatPanel,
              onExpand: _expandChatPanel,
              onClose: _closeChatPanel,
              documentTitle: widget.title,
            ),

          // Minimized chat indicator
          if (_chatPanelState == _ChatPanelState.minimized)
            Positioned(
              bottom: 80,
              right: 16,
              child: GestureDetector(
                onTap: _expandChatPanel,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.wandMagicSparkles,
                        size: 16,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI Chat',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.expand_less,
                        size: 20,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      // Themed Floating Action Button - hidden when chat is expanded
      floatingActionButton: !_isLoading &&
              _pdfBytes != null &&
              _chatPanelState != _ChatPanelState.expanded
          ? FloatingActionButton.extended(
              onPressed: _openAiTutorDialog,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              icon: const FaIcon(
                FontAwesomeIcons.wandMagicSparkles,
                size: 20,
              ),
              label: const Text(
                'Ask AI',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }

    if (_isSubscriptionError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 48, color: colorScheme.secondary),
            const SizedBox(height: 16),
            Text(
              "Premium Content",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Please subscribe to access this document.",
              style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                "Could not load PDF",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.error),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfBytes == null) {
      return Center(
        child:
            Text("No PDF Data", style: TextStyle(color: colorScheme.onSurface)),
      );
    }

    // --- PDF VIEWER ---
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: RepaintBoundary(
          key: _pdfRepaintKey,
          child: SfPdfViewer.memory(
            _pdfBytes!,
            controller: _pdfViewerController,
            canShowPaginationDialog: true,
            canShowScrollStatus: true,
            enableDoubleTapZooming: true,
            enableTextSelection: true,
            // Styling the PDF background to match app scaffold might break readability
            // of standard white-page PDFs, so we usually keep the viewer default (gray/white).
            // However, we can style the Scroll Status:
            onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
              if (details.selectedText == null && _overlayEntry != null) {
                _checkAndCloseContextMenu();
              } else if (details.selectedText != null) {
                _showContextMenu(context, details);
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Embedded Chat Panel Widget
/// A resizable, minimizable chat panel that overlays the PDF viewer
class _EmbeddedChatPanel extends StatefulWidget {
  final _ChatPanelState panelState;
  final XFile? initialImage;
  final String? initialMessage;
  final VoidCallback onMinimize;
  final VoidCallback onExpand;
  final VoidCallback onClose;
  final String documentTitle;

  const _EmbeddedChatPanel({
    super.key,
    required this.panelState,
    this.initialImage,
    this.initialMessage,
    required this.onMinimize,
    required this.onExpand,
    required this.onClose,
    required this.documentTitle,
  });

  @override
  State<_EmbeddedChatPanel> createState() => _EmbeddedChatPanelState();
}

class _EmbeddedChatPanelState extends State<_EmbeddedChatPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;

  // Panel height percentage (0.4 = 40% of screen, 0.85 = 85%)
  double _panelHeightRatio = 0.5;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heightAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    if (widget.panelState == _ChatPanelState.expanded) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(_EmbeddedChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.panelState == _ChatPanelState.expanded &&
        oldWidget.panelState != _ChatPanelState.expanded) {
      _animationController.forward();
    } else if (widget.panelState == _ChatPanelState.minimized &&
        oldWidget.panelState == _ChatPanelState.expanded) {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 700;

    if (widget.panelState == _ChatPanelState.minimized) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _heightAnimation,
      builder: (context, child) {
        final panelHeight =
            screenHeight * _panelHeightRatio * _heightAnimation.value;

        return Positioned(
          bottom: 0,
          left: isWideScreen ? screenWidth * 0.15 : 0,
          right: isWideScreen ? screenWidth * 0.15 : 0,
          height: panelHeight.clamp(0.0, screenHeight * 0.85),
          child: Material(
            elevation: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            color: theme.scaffoldBackgroundColor,
            child: Column(
              children: [
                // Drag Handle & Header
                GestureDetector(
                  onVerticalDragStart: (_) => _isDragging = true,
                  onVerticalDragUpdate: (details) {
                    if (_isDragging) {
                      setState(() {
                        _panelHeightRatio -= details.delta.dy / screenHeight;
                        _panelHeightRatio = _panelHeightRatio.clamp(0.3, 0.85);
                      });
                    }
                  },
                  onVerticalDragEnd: (_) => _isDragging = false,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Drag handle
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Header bar
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 8),
                              FaIcon(
                                FontAwesomeIcons.wandMagicSparkles,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'AI Tutor',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              // Minimize button
                              IconButton(
                                icon: const Icon(Icons.minimize),
                                iconSize: 20,
                                tooltip: 'Minimize',
                                onPressed: widget.onMinimize,
                              ),
                              // Close button
                              IconButton(
                                icon: const Icon(Icons.close),
                                iconSize: 20,
                                tooltip: 'Close',
                                onPressed: widget.onClose,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Chat content
                Expanded(
                  child: ClipRRect(
                    child: ChatScreen(
                      initialImage: widget.initialImage,
                      initialMessage: widget.initialMessage,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

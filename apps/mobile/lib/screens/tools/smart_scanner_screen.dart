import 'package:flutter/foundation.dart'; // For kIsWeb, defaultTargetPlatform
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../tutor_client/chat_screen.dart';

class SmartScannerScreen extends StatefulWidget {
  const SmartScannerScreen({super.key});

  @override
  State<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends State<SmartScannerScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  String? _errorMessage;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Animation for the scanner box
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

  Future<void> _pickImage(ImageSource source) async {
    // 1. Permission Check (Mobile Only)
    final hasPermission = await _checkPermissions(source);
    if (!hasPermission) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo == null) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      if (!mounted) return;

      // 2. Navigate
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            initialImage: photo, // XFile is cross-platform friendly
            initialMessage:
                "Analyze this image and solve the problem step-by-step.",
          ),
        ),
      );
    } catch (e) {
      debugPrint("Scanner Error: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load image. Please try again.";
          _isProcessing = false;
        });
      }
    }
  }

  Future<bool> _checkPermissions(ImageSource source) async {
    if (kIsWeb) return true; // Web handles permissions via browser prompts

    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        if (mounted) _showPermissionDialog("Camera");
        return false;
      }
    }
    return true;
  }

  void _showPermissionDialog(String feature) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("$feature Permission Required"),
        content:
            Text("Please enable $feature access in settings to scan problems."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text("Settings"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          "Smart Scanner",
          style: GoogleFonts.nunito(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isProcessing
          ? _buildLoadingState()
          : SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 1),

                  // --- VISUALIZER ---
                  _buildScannerVisual(),

                  // --- ERROR ---
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const Spacer(flex: 1),

                  // --- TEXT ---
                  Text(
                    "Snap & Solve",
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "Capture math problems, science diagrams, or text to get instant AI help.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                          fontSize: 16, color: Colors.white54),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // --- CONTROLS ---
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildControlButton(
                          icon: Icons.photo_library_rounded,
                          label: "Gallery",
                          onTap: () => _pickImage(ImageSource.gallery),
                        ),
                        // Only show Camera button on mobile or allow it on web if preferred
                        _buildCaptureButton(),
                        _buildControlButton(
                          icon: Icons
                              .flash_on_rounded, // Placeholder for Flash toggle logic
                          label: "Flash",
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      "Flash toggled (Hardware dependent)")),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
                color: Color(0xFF6C63FF), strokeWidth: 4),
          ),
          const SizedBox(height: 24),
          Text(
            "Analyzing Image...",
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerVisual() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing Ring
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 300 + (_pulseController.value * 20),
              height: 300 + (_pulseController.value * 20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF6C63FF)
                      .withValues(alpha: 0.3 - (_pulseController.value * 0.3)),
                  width: 2,
                ),
              ),
            );
          },
        ),
        // Main Box
        Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.crop_free_rounded,
                  size: 60, color: Colors.white.withValues(alpha: 0.8)),
            ],
          ),
        ),
        // Corner Accents (The "Scanner" look)
        Positioned(top: 0, left: 0, child: _buildCorner(false, false)),
        Positioned(top: 0, right: 0, child: _buildCorner(true, false)),
        Positioned(bottom: 0, left: 0, child: _buildCorner(false, true)),
        Positioned(bottom: 0, right: 0, child: _buildCorner(true, true)),
      ],
    );
  }

  Widget _buildCorner(bool isRight, bool isBottom) {
    const double size = 30;
    const double thickness = 4;
    const color = Color(0xFF6C63FF);

    return Container(
      width:
          280, // Match container width to position corners correctly relative to stack
      height: 280,
      alignment: isBottom
          ? (isRight ? Alignment.bottomRight : Alignment.bottomLeft)
          : (isRight ? Alignment.topRight : Alignment.topLeft),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border(
            top: isBottom
                ? BorderSide.none
                : BorderSide(color: color, width: thickness),
            bottom: isBottom
                ? BorderSide(color: color, width: thickness)
                : BorderSide.none,
            left: isRight
                ? BorderSide.none
                : BorderSide(color: color, width: thickness),
            right: isRight
                ? BorderSide(color: color, width: thickness)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: () => _pickImage(ImageSource.camera),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300, width: 4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
        ),
        child:
            const Icon(Icons.camera_alt_rounded, size: 36, color: Colors.black),
      ),
    );
  }

  Widget _buildControlButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart'; // For platform detection
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Ensure you import your ChatScreen to show the AI results
import '../../tutor_client/chat_screen.dart';

class SmartScannerScreen extends StatefulWidget {
  const SmartScannerScreen({super.key});

  @override
  State<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends State<SmartScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  String? _errorMessage;

  /// Helper to determine if we are on a mobile device (Android/iOS).
  /// This works for both Native Apps and Mobile Web Browsers.
  bool get _isMobileDevice {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
  }

  /// The Core Logic: Pick Image -> Send to AI
  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // 1. CAPTURE IMAGE
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 85, // Good balance of speed/quality
        maxWidth: 1024, // AI doesn't need huge 4k images
      );

      if (photo == null) {
        // User cancelled
        setState(() => _isProcessing = false);
        return;
      }

      // 2. NAVIGATE TO AI TUTOR
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            initialImage: photo,
            initialMessage:
                "Analyze this image and solve the problem step-by-step.",
          ),
        ),
      );
    } catch (e) {
      debugPrint("Scanner Error: $e");
      setState(() {
        _errorMessage = "Could not access image source: $e";
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if camera should be enabled
    final bool isCameraEnabled = _isMobileDevice;

    return Scaffold(
      backgroundColor: Colors.black, // Sleek "Camera Mode" look
      appBar: AppBar(
        title: Text(
          "Smart Scanner",
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: _isProcessing
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  const SizedBox(height: 20),
                  Text(
                    "Processing Image...",
                    style: GoogleFonts.nunito(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- SCANNER VISUAL ---
                    Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        border: Border.all(
                          color: const Color(0xFF6C63FF),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.expand,
                            size: 50,
                            color: Color(0xFF6C63FF),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Tap to Scan",
                            style: GoogleFonts.nunito(
                              color: Colors.white54,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- ERROR MESSAGE ---
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),

                    const SizedBox(height: 50),

                    // --- INSTRUCTIONS ---
                    Text(
                      "Solve Homework Instantly",
                      style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Take a photo of any math problem, science question, or diagram.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- ACTION BUTTONS ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 1. GALLERY (Always Enabled)
                        _buildActionButton(
                          icon: Icons.photo_library,
                          label: "Gallery",
                          isEnabled: true,
                          isPrimary: false,
                          onTap: () => _pickImage(ImageSource.gallery),
                        ),
                        const SizedBox(width: 30),

                        // 2. CAMERA (Enabled only on Mobile/Tablets)
                        _buildActionButton(
                          icon: Icons.camera_alt,
                          label: "Camera",
                          isEnabled: isCameraEnabled,
                          isPrimary: true,
                          onTap: () {
                            if (isCameraEnabled) {
                              _pickImage(ImageSource.camera);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Please use 'Gallery' upload on desktops.",
                                  ),
                                  backgroundColor: Colors.grey,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isEnabled = true,
    bool isPrimary = false,
  }) {
    // Determine visual style based on enabled state
    final Color bgColor = isEnabled
        ? (isPrimary ? const Color(0xFF6C63FF) : Colors.white12)
        : Colors.white10; // Dimmer for disabled

    final Color iconColor = isEnabled ? Colors.white : Colors.white38;
    final Color textColor = isEnabled ? Colors.white : Colors.white38;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              boxShadow: (isEnabled && isPrimary)
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : [],
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.nunito(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../services/ai_service.dart';
import 'camera_screen.dart';

enum ScannerMode {
  homework,
  text,
  diagram,
}

class SmartScannerScreen extends StatefulWidget {
  final Uint8List? initialImage;
  const SmartScannerScreen({super.key, this.initialImage});

  @override
  State<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends State<SmartScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final AIService _aiService = AIService();
  
  XFile? _imageFile;
  Uint8List? _imageBytes;
  String? _result;
  bool _isAnalyzing = false;
  ScannerMode _selectedMode = ScannerMode.homework;

  @override
  void initState() {
    super.initState();
    if (widget.initialImage != null) {
      _imageBytes = widget.initialImage;
    }
  }

  Future<void> _openCamera() async {
    try {
      final XFile? pickedFile = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CameraScreen()),
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageFile = pickedFile;
          _imageBytes = bytes;
          _result = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening camera: $e')),
      );
    }
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
          _imageFile = pickedFile;
          _imageBytes = bytes;
          _result = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageBytes == null) return;

    setState(() {
      _isAnalyzing = true;
      _result = null;
    });

    try {
      String prompt;
      switch (_selectedMode) {
        case ScannerMode.text:
          prompt = """
Extract all the text from this image exactly as it appears. 
Do not summarize or solve. 
Preserve the formatting where possible.
If there is no text, say "No text found".
""";
          break;
        case ScannerMode.diagram:
          prompt = """
Analyze this diagram or image.
Explain what it represents in detail.
Identify key components and their relationships.
Use simple, educational language suitable for a student.
""";
          break;
        case ScannerMode.homework:
        default:
          prompt = """
Analyze this image for a student. 
If it's a homework question, solve it step-by-step.
If it's a diagram, explain it.
If it's text, summarize it.
Use simple, encouraging language.
""";
          break;
      }

      final response = await _aiService.analyzeImage(_imageBytes!, prompt);

      if (mounted) {
        setState(() {
          _result = response;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = "Error analyzing image. Please try again.";
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _clearImage() {
    setState(() {
      _imageFile = null;
      _imageBytes = null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Smart Scanner', style: TextStyle(color: theme.colorScheme.onSurface)),
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 1,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          if (_imageBytes != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearImage,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Preview Area
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _imageBytes != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(_imageBytes!, fit: BoxFit.cover),
                        if (_isAnalyzing)
                          Container(
                            color: Colors.black45,
                            child: const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Take a photo of your homework\nor upload an image',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _openCamera,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Camera'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.googleBlue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Gallery'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.googleBlue,
                                side: const BorderSide(color: AppColors.googleBlue),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 24),

            // Mode Selection
            if (_imageBytes != null && !_isAnalyzing)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: SegmentedButton<ScannerMode>(
                  segments: const [
                    ButtonSegment<ScannerMode>(
                      value: ScannerMode.homework,
                      label: Text('Homework'),
                      icon: Icon(Icons.school),
                    ),
                    ButtonSegment<ScannerMode>(
                      value: ScannerMode.text,
                      label: Text('Text'),
                      icon: Icon(Icons.text_fields),
                    ),
                    ButtonSegment<ScannerMode>(
                      value: ScannerMode.diagram,
                      label: Text('Diagram'),
                      icon: Icon(Icons.image),
                    ),
                  ],
                  selected: {_selectedMode},
                  onSelectionChanged: (Set<ScannerMode> newSelection) {
                    setState(() {
                      _selectedMode = newSelection.first;
                      _result = null; // Clear result when mode changes
                    });
                  },
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith<Color>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.selected)) {
                          return AppColors.googleBlue.withOpacity(0.2);
                        }
                        return Colors.transparent;
                      },
                    ),
                    foregroundColor: MaterialStateProperty.resolveWith<Color>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.selected)) {
                          return AppColors.googleBlue;
                        }
                        return theme.colorScheme.onSurface;
                      },
                    ),
                  ),
                ),
              ),

            // Analyze Button
            if (_imageBytes != null && !_isAnalyzing && _result == null)
              ElevatedButton.icon(
                onPressed: _analyzeImage,
                icon: Icon(_selectedMode == ScannerMode.text ? Icons.copy_all : Icons.auto_awesome),
                label: Text(_selectedMode == ScannerMode.text ? 'Extract Text' : 'Analyze with AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.googleBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

            // Result Area
            if (_result != null) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Analysis Result",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (_selectedMode == ScannerMode.text)
                    IconButton(
                      icon: const Icon(Icons.copy, color: AppColors.googleBlue),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _result!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Text copied to clipboard')),
                        );
                      },
                      tooltip: 'Copy Text',
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _selectedMode == ScannerMode.text
                    ? SelectableText(
                        _result!,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          height: 1.5,
                          color: theme.colorScheme.onSurface,
                        ),
                      )
                    : MarkdownBody(
                        data: _result!,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(fontSize: 16, height: 1.5, color: theme.colorScheme.onSurface),
                          h1: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                          h2: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                          code: GoogleFonts.firaCode(
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

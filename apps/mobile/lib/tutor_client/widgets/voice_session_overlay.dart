import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VoiceSessionOverlay extends StatefulWidget {
  final bool isAiSpeaking;
  final bool isRecording;
  final String statusText;
  final String transcription;
  final double amplitude;
  final VoidCallback onClose;
  final VoidCallback onInterrupt;

  const VoiceSessionOverlay({
    super.key,
    required this.isAiSpeaking,
    required this.isRecording,
    required this.statusText,
    required this.transcription,
    required this.amplitude,
    required this.onClose,
    required this.onInterrupt,
  });

  @override
  State<VoiceSessionOverlay> createState() => _VoiceSessionOverlayState();
}

class _VoiceSessionOverlayState extends State<VoiceSessionOverlay>
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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withValues(alpha: 0.85)),
            ),
          ),
          SafeArea(
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
                            final scale =
                                widget.isRecording || widget.isAiSpeaking
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
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
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
        ],
      ),
    );
  }
}

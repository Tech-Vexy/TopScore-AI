import 'package:flutter/material.dart';

/// Helper for scroll-to-bottom functionality
/// Extracted from duplicate implementations in chat screens
class ScrollHelper {
  static void scrollToBottom(ScrollController controller, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOut,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: duration,
          curve: curve,
        );
      }
    });
  }
}

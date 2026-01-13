import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FeatureCardData {
  final String title;
  final IconData icon;
  final Color color;
  final Color endColor; // For gradients
  final int routeIndex; // Using index navigation for HomeTab

  FeatureCardData({
    required this.title,
    required this.icon,
    required this.color,
    required this.endColor,
    required this.routeIndex,
  });
}

// Global list of features for the Home Screen
final List<FeatureCardData> homeFeatures = [
  FeatureCardData(
    title: "Snap & Solve",
    icon: Icons.camera_alt_outlined,
    color: const Color(0xFFFF6B6B),
    endColor: const Color(0xFFFF8E8E),
    routeIndex: 3, // Tools tab
  ),
  FeatureCardData(
    title: "Past Papers",
    icon: Icons.description_outlined,
    color: const Color(0xFF4ECDC4),
    endColor: const Color(0xFF76EBE4),
    routeIndex: 1, // Library tab
  ),
  FeatureCardData(
    title: "Quiz Battle",
    icon: Icons.emoji_events_outlined,
    color: const Color(0xFFFFD93D),
    endColor: const Color(0xFFFFE57A),
    routeIndex: -1, // Special case: Push BattleLobbyScreen
  ),
  FeatureCardData(
    title: "Progress",
    icon: Icons.bar_chart_rounded,
    color: const Color(0xFF6C63FF),
    endColor: const Color(0xFF8B80FF),
    routeIndex: -2, // Special case: Push CareerCompassScreen
  ),
  FeatureCardData(
    title: "Virtual Lab",
    icon: FontAwesomeIcons.flask,
    color: const Color(0xFF1B998B),
    endColor: const Color(0xFF45DECC),
    routeIndex: -3, // Special case: Push ScienceLabScreen
  ),
];

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InterestUpdateSheet extends StatefulWidget {
  final String userId;
  const InterestUpdateSheet({super.key, required this.userId});

  @override
  State<InterestUpdateSheet> createState() => _InterestUpdateSheetState();
}

class _InterestUpdateSheetState extends State<InterestUpdateSheet> {
  final List<String> _selectedInterests = [];
  bool _isSaving = false;

  final List<String> _interestOptions = [
    'Technology & Coding',
    'Medicine & Health',
    'Engineering',
    'Arts & Design',
    'Business & Finance',
    'Law & Justice',
    'Sports & Fitness',
    'Media & Writing',
    'Agriculture & Nature',
    'Teaching & Education',
    'Music & Performance',
    'Public Service',
  ];

  Future<void> _saveInterests() async {
    if (_selectedInterests.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      // Update Firestore directly
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
            'interests': _selectedInterests,
            'careerMode': 'interest_based', // Flag to switch UI mode
          });

      // Refresh local user model in provider
      if (mounted) {
        await Provider.of<AuthProvider>(context, listen: false).reloadUser();
        if (mounted) {
          Navigator.pop(context); // Close sheet
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Update Your Profile",
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We've updated Career Compass! Select your interests to get personalized career guidance.",
            style: GoogleFonts.nunito(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),

          // Flexible Grid for Interests
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _interestOptions.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return FilterChip(
                    label: Text(interest),
                    selected: isSelected,
                    selectedColor: const Color(
                      0xFF6C63FF,
                    ).withValues(alpha: 0.2),
                    checkmarkColor: const Color(0xFF6C63FF),
                    backgroundColor: Colors.grey[100],
                    labelStyle: GoogleFonts.nunito(
                      color: isSelected
                          ? const Color(0xFF6C63FF)
                          : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedInterests.add(interest);
                        } else {
                          _selectedInterests.remove(interest);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selectedInterests.isEmpty || _isSaving
                  ? null
                  : _saveInterests,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      "Save & Continue",
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

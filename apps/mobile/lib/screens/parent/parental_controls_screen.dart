import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Allows parents to set daily time limits and subject focus areas for linked children.
class ParentalControlsScreen extends StatefulWidget {
  final String childUid;
  final String childName;

  const ParentalControlsScreen({
    super.key,
    required this.childUid,
    required this.childName,
  });

  @override
  State<ParentalControlsScreen> createState() => _ParentalControlsScreenState();
}

class _ParentalControlsScreenState extends State<ParentalControlsScreen> {
  double _dailyLimitHours = 2.0;
  final List<String> _allSubjects = [
    'Mathematics',
    'English',
    'Science',
    'Kiswahili',
    'History',
    'Geography',
    'CRE',
    'Business',
    'Agriculture',
    'Art'
  ];
  final Set<String> _focusSubjects = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadControls();
  }

  Future<void> _loadControls() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.childUid)
          .collection('parental_controls')
          .doc('settings')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _dailyLimitHours =
              (data['dailyLimitHours'] as num?)?.toDouble() ?? 2.0;
          final subjects =
              (data['focusSubjects'] as List?)?.cast<String>() ?? [];
          _focusSubjects.addAll(subjects);
        });
      }
    } catch (e) {
      debugPrint('Error loading parental controls: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.childUid)
          .collection('parental_controls')
          .doc('settings')
          .set({
        'dailyLimitHours': _dailyLimitHours,
        'focusSubjects': _focusSubjects.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Controls saved'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limitLabel = _dailyLimitHours == 0.5
        ? '30 mins'
        : '${_dailyLimitHours.toStringAsFixed(0)} hour${_dailyLimitHours == 1 ? '' : 's'}';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '${widget.childName}\'s Controls',
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Daily Limit
                  _sectionHeader('⏱ Daily Screen Time Limit'),
                  const SizedBox(height: 8),
                  Text(
                    limitLabel,
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Slider(
                    value: _dailyLimitHours,
                    min: 0.5,
                    max: 8,
                    divisions: 15,
                    label: limitLabel,
                    onChanged: (v) => setState(() => _dailyLimitHours = v),
                  ),
                  Text(
                    'App will show a gentle reminder when limit is reached.',
                    style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey),
                  ),

                  const SizedBox(height: 32),

                  // Subject Focus
                  _sectionHeader('📚 Subject Focus Areas'),
                  const SizedBox(height: 4),
                  Text(
                    'Highlight these subjects on your child\'s home screen.',
                    style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allSubjects.map((subject) {
                      final selected = _focusSubjects.contains(subject);
                      return FilterChip(
                        label: Text(subject, style: GoogleFonts.nunito()),
                        selected: selected,
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _focusSubjects.add(subject);
                            } else {
                              _focusSubjects.remove(subject);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String text) => Text(
        text,
        style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.bold),
      );
}

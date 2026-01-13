import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../dashboard_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // --- Form State ---
  String selectedRole = 'Student';
  String? selectedCurriculum; // "CBC" or "8-4-4"
  String? selectedGrade;
  final TextEditingController _schoolController = TextEditingController();
  bool _isSaving = false;

  // --- Data Options ---
  final List<String> roles = ['Student', 'Teacher', 'Parent'];
  final List<String> curriculums = ['CBC', '8-4-4'];

  // Dynamic grades based on curriculum
  List<String> get _availableGrades {
    if (selectedCurriculum == 'CBC') {
      return List.generate(12, (index) => 'Grade ${index + 1}');
    } else if (selectedCurriculum == '8-4-4') {
      return ['Form 1', 'Form 2', 'Form 3', 'Form 4'];
    }
    return [];
  }

  // --- Logic ---
  Future<void> _saveAndContinue() async {
    // Validation
    if (_schoolController.text.trim().isEmpty) {
      _showError("Please enter your school name");
      return;
    }
    if ((selectedRole == 'Student' || selectedRole == 'Teacher') &&
        selectedCurriculum == null) {
      _showError("Please select a curriculum (CBC or 8-4-4)");
      return;
    }
    if ((selectedRole == 'Student' || selectedRole == 'Teacher') &&
        selectedGrade == null) {
      _showError("Please select your grade/form");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Combine Curriculum + Grade (e.g., "CBC - Grade 7" or just "Grade 7")
      // You might want to save them separately in your model, but for now we pass the grade.
      // Ideally, update updateUserRole to accept curriculum too.
      // For this implementation, we will append curriculum info if needed or just save the grade string.

      await authProvider.updateUserRole(
        selectedRole.toLowerCase(),
        selectedGrade ?? '', // Pass the specific grade (e.g. "Form 1")
        _schoolController.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError("Error: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header ---
              Text(
                "Complete Profile",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Help us tailor the content to your curriculum.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 30),

              // --- 1. Role Selection ---
              _buildLabel(theme, "I am a..."),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: selectedRole,
                dropdownColor: theme.cardColor,
                style: TextStyle(color: theme.colorScheme.onSurface),
                items: roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) => setState(() {
                  selectedRole = val!;
                  // Reset downstream fields if role changes (optional)
                }),
                decoration: _inputDecoration(theme),
              ),
              const SizedBox(height: 20),

              // --- 2. School Name ---
              _buildLabel(theme, "School Name"),
              TextField(
                controller: _schoolController,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: _inputDecoration(theme).copyWith(
                  hintText: "e.g., Nairobi School",
                  prefixIcon: Icon(
                    Icons.school_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- 3. Curriculum & Grade (Conditional) ---
              if (selectedRole == 'Student' || selectedRole == 'Teacher') ...[
                // Curriculum
                _buildLabel(theme, "Curriculum System"),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: selectedCurriculum,
                  dropdownColor: theme.cardColor,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  hint: Text(
                    "Select Curriculum",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  items: curriculums
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => setState(() {
                    selectedCurriculum = val;
                    selectedGrade = null; // Reset grade when curriculum changes
                  }),
                  decoration: _inputDecoration(theme),
                ),
                const SizedBox(height: 20),

                // Grade (Visible only if Curriculum is selected)
                if (selectedCurriculum != null) ...[
                  _buildLabel(
                    theme,
                    selectedRole == 'Teacher'
                        ? "Grade I Teach"
                        : "My Current Level",
                  ),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: selectedGrade,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    hint: Text(
                      "Select Level",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    items: _availableGrades
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) => setState(() => selectedGrade = val),
                    decoration: _inputDecoration(theme),
                  ),
                ],
              ],

              const SizedBox(height: 40),

              // --- Save Button ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Finish Setup",
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(ThemeData theme) {
    return InputDecoration(
      filled: true,
      fillColor: theme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

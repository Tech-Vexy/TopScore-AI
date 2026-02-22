import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../models/cbc_assessment_model.dart';
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

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();

  // Selections
  final List<String> _selectedSubjects = [];
  final List<String> _selectedInterests = [];

  bool _isSaving = false;

  // Parental consent (Kenya DPA 2019 Section 33)
  DateTime? _dateOfBirth;
  bool _parentalConsentGiven = false;

  bool get _isMinor {
    if (_dateOfBirth == null) return false;
    final now = DateTime.now();
    final age = now.year -
        _dateOfBirth!.year -
        ((now.month < _dateOfBirth!.month ||
                (now.month == _dateOfBirth!.month &&
                    now.day < _dateOfBirth!.day))
            ? 1
            : 0);
    return age < 18;
  }

  // --- Data Options ---
  final List<String> roles = ['Student']; // Only Student role available
  final List<String> curriculums = ['CBC', '8-4-4'];

  /// Returns curriculum-appropriate learning areas/subjects based on selection
  List<String> get _subjects {
    if (selectedCurriculum == 'CBC' && selectedGrade != null) {
      final gradeNum = int.tryParse(
        selectedGrade!.replaceAll(RegExp(r'[^0-9]'), ''),
      );
      return CbcLearningAreas.forGrade('CBC', gradeNum);
    }
    return CbcLearningAreas.kcseSubjects;
  }

  final List<String> _careerInterests = [
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

  // Dynamic grades based on curriculum
  List<String> get _availableGrades {
    if (selectedCurriculum == 'CBC') {
      return List.generate(12, (index) => 'Grade ${index + 1}');
    } else if (selectedCurriculum == '8-4-4') {
      return ['Form 1', 'Form 2', 'Form 3', 'Form 4'];
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill name if available from Google Auth
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).userModel;
      if (user != null) {
        if (user.displayName.isNotEmpty) {
          _nameController.text = user.displayName;
        }
      }
    });
  }

  // --- Logic ---
  Future<void> _saveAndContinue() async {
    // Validation
    if (_nameController.text.trim().isEmpty) {
      _showError("Please enter your name");
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showError("Please enter your phone number");
      return;
    }
    if (selectedRole != 'Parent' && _schoolController.text.trim().isEmpty) {
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

    // Custom Validations
    if (selectedRole == 'Teacher' && _selectedSubjects.isEmpty) {
      _showError("Select at least one subject");
      return;
    }
    if (selectedRole == 'Student' && _selectedInterests.isEmpty) {
      _showError("Select at least one interest/hobby");
      return;
    }

    // Kenya DPA 2019 Section 33: parental consent for minors
    if (selectedRole == 'Student' &&
        _dateOfBirth != null &&
        _isMinor &&
        !_parentalConsentGiven) {
      _showError("Parental/guardian consent is required for students under 18");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      await authProvider.updateUserRole(
        role: selectedRole.toLowerCase(),
        grade: selectedGrade ?? '',
        schoolName: _schoolController.text.trim(),
        displayName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        curriculum: selectedCurriculum,
        educationLevel:
            selectedCurriculum, // Now explicitly specifying as requested
        interests: selectedRole == 'Student' ? _selectedInterests : null,
        subjects: selectedRole == 'Teacher' ? _selectedSubjects : null,
        dateOfBirth: _dateOfBirth,
        parentalConsentGiven: _parentalConsentGiven,
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
                "Tell us more to specialize your experience.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 30),

              // --- 0. Basic Info ---
              _buildLabel(theme, "Full Name"),
              TextField(
                controller: _nameController,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: _inputDecoration(theme).copyWith(
                  hintText: "Your Name",
                  prefixIcon: Icon(Icons.person_outline,
                      color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 20),

              _buildLabel(theme, "Phone Number"),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: _inputDecoration(theme).copyWith(
                  hintText: "07...",
                  prefixIcon: Icon(Icons.phone_outlined,
                      color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 20),

              // --- 1. Role Selection ---
              _buildLabel(theme, "I am a..."),
              DropdownButtonFormField<String>(
                key: ValueKey(selectedRole),
                initialValue: selectedRole,
                dropdownColor: theme.cardColor,
                style: TextStyle(color: theme.colorScheme.onSurface),
                items: ['Student', 'Parent', 'Teacher'] // specific roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) => setState(() {
                  selectedRole = val!;
                }),
                decoration: _inputDecoration(theme),
              ),
              const SizedBox(height: 20),

              // --- 2. School Name (Hidden for Parents) ---
              if (selectedRole != 'Parent') ...[
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
              ],

              // --- 3. Curriculum & Grade (Conditional) ---
              if (selectedRole == 'Student' || selectedRole == 'Teacher') ...[
                // Curriculum
                _buildLabel(theme, "Curriculum System"),
                DropdownButtonFormField<String>(
                  key: ValueKey(selectedCurriculum),
                  initialValue: selectedCurriculum,
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
                    selectedGrade = null;
                    _selectedSubjects.clear();
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
                    key: ValueKey(selectedGrade),
                    initialValue: selectedGrade,
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
                    onChanged: (val) => setState(() {
                      selectedGrade = val;
                      _selectedSubjects.clear();
                    }),
                    decoration: _inputDecoration(theme),
                  ),
                  const SizedBox(height: 20),
                ],
              ],

              // --- 4. Interests (Student) ---
              if (selectedRole == 'Student') ...[
                _buildLabel(theme, "My Interests (Select all that apply)"),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _careerInterests.map((interest) {
                    final isSelected = _selectedInterests.contains(interest);
                    return FilterChip(
                      label: Text(interest),
                      selected: isSelected,
                      selectedColor:
                          const Color(0xFF6C63FF).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF6C63FF),
                      backgroundColor: theme.cardColor,
                      labelStyle: GoogleFonts.nunito(
                        color: isSelected
                            ? const Color(0xFF6C63FF)
                            : Colors.grey[700],
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13,
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
                const SizedBox(height: 30),
              ],

              // --- 5. Subjects (Teacher) ---
              if (selectedRole == 'Teacher') ...[
                _buildLabel(
                    theme,
                    selectedCurriculum == 'CBC'
                        ? "Learning Areas Taught"
                        : "Subjects Taught"),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _subjects.map((subject) {
                    final isSelected = _selectedSubjects.contains(subject);
                    return FilterChip(
                      label: Text(subject),
                      selected: isSelected,
                      selectedColor:
                          const Color(0xFF6C63FF).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF6C63FF),
                      labelStyle: GoogleFonts.nunito(
                        color: isSelected
                            ? const Color(0xFF6C63FF)
                            : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedSubjects.add(subject);
                          } else {
                            _selectedSubjects.remove(subject);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 30),
              ],

              // --- 6. Date of Birth & Parental Consent (Kenya DPA 2019) ---
              if (selectedRole == 'Student') ...[
                _buildLabel(theme, "Date of Birth"),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dateOfBirth ?? DateTime(2010, 1, 1),
                      firstDate: DateTime(1990),
                      lastDate: DateTime.now(),
                      helpText: "Select your date of birth",
                    );
                    if (picked != null) {
                      setState(() {
                        _dateOfBirth = picked;
                        if (!_isMinor) _parentalConsentGiven = false;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          _dateOfBirth != null
                              ? "${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}"
                              : "Select date of birth",
                          style: TextStyle(
                            color: _dateOfBirth != null
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Parental consent required for minors under Kenya DPA 2019 Section 33
                if (_isMinor) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined,
                                color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "Parental/Guardian Consent Required",
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Under the Kenya Data Protection Act 2019, students under 18 require parental or guardian consent to use this app. "
                          "By checking below, you confirm that a parent/guardian has reviewed and agreed to the Privacy Policy and Terms of Use.",
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            height: 1.5,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          value: _parentalConsentGiven,
                          onChanged: (val) => setState(
                              () => _parentalConsentGiven = val ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            "My parent/guardian has given consent",
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],

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

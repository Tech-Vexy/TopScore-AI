import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SignupScreen extends StatefulWidget {
  final String role; // 'student', 'teacher', or 'parent'

  const SignupScreen({super.key, required this.role});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  // Role Specific Variables
  String?
  _selectedClassLevel; // Changed from 'Grade' to 'Class Level' to avoid confusion
  String? _selectedChildClassLevel;

  // Selections
  final List<String> _selectedSubjects = []; // For teachers
  final List<String> _selectedInterests = []; // For students (New!)

  bool _isLoading = false;
  bool _obscurePassword = true;

  // --- DATA LISTS ---
  // Renamed to "Class Levels" to be distinct from "Performance Grades"
  final List<String> _classLevels = [
    'Grade 4',
    'Grade 5',
    'Grade 6',
    'Grade 7 (JSS)',
    'Grade 8 (JSS)',
    'Grade 9 (JSS)',
    'Form 1',
    'Form 2',
    'Form 3',
    'Form 4',
  ];

  final List<String> _subjects = [
    'Mathematics',
    'English',
    'Kiswahili',
    'Chemistry',
    'Biology',
    'Physics',
    'History',
    'Geography',
    'CRE',
    'Business Studies',
    'Computer Studies',
    'Agriculture',
  ];

  // NEW: Interest Categories for Career Compass
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Create ${widget.role.capitalize()} Account",
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Tell us about yourself so we can guide your journey.",
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 32),

                // --- COMMON FIELDS ---
                _buildTextField(
                  controller: _nameController,
                  label: "Full Name",
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: "Email Address",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _phoneController,
                  label: "Phone Number",
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),

                // --- DYNAMIC ROLE-BASED FIELDS ---
                const SizedBox(height: 24),
                _buildRoleSpecificFields(theme),
                const SizedBox(height: 24),

                // --- PASSWORD ---
                _buildTextField(
                  controller: _passwordController,
                  label: "Password",
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 32),

                // --- SUBMIT BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            "Sign Up",
                            style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildRoleSpecificFields(ThemeData theme) {
    // 1. STUDENT VIEW
    if (widget.role.toLowerCase() == 'student') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Education Level (Still needed for content, but distinct from performance)
          Text(
            "Current Class/Form",
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(
              _selectedClassLevel,
            ), // Force rebuild to update initialValue
            initialValue: _selectedClassLevel,
            decoration: _inputDecoration(
              "Select your Class",
              Icons.school_outlined,
            ),
            items: _classLevels.map((level) {
              return DropdownMenuItem(value: level, child: Text(level));
            }).toList(),
            onChanged: (val) => setState(() => _selectedClassLevel = val),
            validator: (val) => val == null ? "Please select your class" : null,
          ),

          const SizedBox(height: 24),

          // NEW: INTERESTS SECTION
          Row(
            children: [
              const Icon(
                Icons.explore_outlined,
                color: Color(0xFF6C63FF),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "My Interests & Hobbies",
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Select topics you enjoy. We'll use this for your Career Compass.",
            style: GoogleFonts.nunito(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _careerInterests.map((interest) {
              final isSelected = _selectedInterests.contains(interest);
              return FilterChip(
                label: Text(interest),
                selected: isSelected,
                selectedColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                checkmarkColor: const Color(0xFF6C63FF),
                backgroundColor: theme.cardColor,
                labelStyle: GoogleFonts.nunito(
                  color: isSelected
                      ? const Color(0xFF6C63FF)
                      : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF6C63FF)
                        : Colors.transparent,
                    width: 1,
                  ),
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
        ],
      );
    }
    // 2. PARENT VIEW
    else if (widget.role.toLowerCase() == 'parent') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Child's Class/Form",
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedChildClassLevel),
            initialValue: _selectedChildClassLevel,
            decoration: _inputDecoration(
              "Select Child's Class",
              Icons.child_care_outlined,
            ),
            items: _classLevels.map((level) {
              return DropdownMenuItem(value: level, child: Text(level));
            }).toList(),
            onChanged: (val) => setState(() => _selectedChildClassLevel = val),
            validator: (val) =>
                val == null ? "Please select child's class" : null,
          ),
        ],
      );
    }
    // 3. TEACHER VIEW
    else if (widget.role.toLowerCase() == 'teacher') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Subjects Taught",
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _subjects.map((subject) {
              final isSelected = _selectedSubjects.contains(subject);
              return FilterChip(
                label: Text(subject),
                selected: isSelected,
                selectedColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                checkmarkColor: const Color(0xFF6C63FF),
                labelStyle: GoogleFonts.nunito(
                  color: isSelected ? const Color(0xFF6C63FF) : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
        ],
      );
    }

    return const SizedBox.shrink();
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.nunito(color: theme.hintColor),
      prefixIcon: Icon(icon, color: const Color(0xFF6C63FF)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
      ),
      filled: true,
      fillColor: theme.cardColor,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.isEmpty) return "Required";
        if (label.contains("Email") && !value.contains("@")) {
          return "Invalid email";
        }
        if (label.contains("Password") && value.length < 6) {
          return "Min 6 chars";
        }
        return null;
      },
      decoration: _inputDecoration(label, icon).copyWith(
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
      ),
    );
  }

  // --- LOGIC ---

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    // Custom Validations
    if (widget.role == 'teacher' && _selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one subject")),
      );
      return;
    }
    if (widget.role == 'student' && _selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one interest/hobby")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> additionalData = {
        'role': widget.role,
        'phone': _phoneController.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      };

      if (widget.role == 'student') {
        additionalData['classLevel'] = _selectedClassLevel;
        // Key Update: Save interests for Career Compass
        additionalData['interests'] = _selectedInterests;
        additionalData['careerMode'] = 'interest_based';
      } else if (widget.role == 'parent') {
        additionalData['childClassLevel'] = _selectedChildClassLevel;
      } else if (widget.role == 'teacher') {
        additionalData['subjectsTaught'] = _selectedSubjects;
      }

      await Provider.of<AuthProvider>(context, listen: false).signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        additionalData: additionalData,
      );

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Signup Failed: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

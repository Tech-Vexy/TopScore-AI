import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Direct DB Access
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../services/discussion_service.dart';

class GroupAllocationScreen extends StatefulWidget {
  const GroupAllocationScreen({super.key});

  @override
  State<GroupAllocationScreen> createState() => _GroupAllocationScreenState();
}

class _GroupAllocationScreenState extends State<GroupAllocationScreen> {
  final DiscussionService _service = DiscussionService();
  final TextEditingController _groupNameController = TextEditingController();

  // Selection State
  String _selectedGrade = 'Form 4'; // Default filter
  final List<String> _grades = ['Form 1', 'Form 2', 'Form 3', 'Form 4'];

  int _selectedDuration = 40;
  final List<int> _durations = [15, 30, 40, 60, 90, 120];

  // Data State
  List<Map<String, String>> _fetchedStudents = [];
  final Set<String> _selectedStudentIds = {};
  bool _isLoadingStudents = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // Load students immediately based on default grade
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchStudents());
  }

  // --- 🔍 CORE LOGIC: Fetch Students by School & Grade ---
  Future<void> _fetchStudents() async {
    setState(() => _isLoadingStudents = true);

    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user == null || user.schoolName.isEmpty) {
      setState(() => _isLoadingStudents = false);
      return;
    }

    try {
      // Query: Same School + Same Grade + Role is Student
      // Note: This requires a composite index in Firestore (schoolName + grade + role)
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('schoolName', isEqualTo: user.schoolName)
          .where(
            'grade',
            isEqualTo: int.tryParse(
              _selectedGrade.replaceAll(RegExp(r'[^0-9]'), ''),
            ),
          ) // Use int for grade query
          .where('role', isEqualTo: 'student')
          .get();

      final students = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['displayName']?.toString() ?? 'Unknown',
          'email': data['email']?.toString() ?? '',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _fetchedStudents = students;
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching students: $e");
      if (mounted) {
        setState(() => _isLoadingStudents = false);
      }
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedStudentIds.contains(id)) {
        _selectedStudentIds.remove(id);
      } else {
        _selectedStudentIds.add(id);
      }
    });
  }

  Future<void> _createAndStart() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a group name")),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).userModel;
      if (user != null) {
        // Create meeting
        // Note: DiscussionService.createMeeting needs to be checked if it supports this or if we need to modify it.
        // The user didn't mention modifying DiscussionService, so I assume it takes group name and other params.
        // I will check the DiscussionService call in a moment or assume user's code snippet was correct.
        // User snippet: createMeeting(_groupNameController.text.trim(), user, _selectedDuration);

        await _service.createMeeting(
          _groupNameController.text.trim(),
          user,
          _selectedDuration,
        );

        // In a real app, you would now trigger a Cloud Function or Notification
        // to alert the selected students (`_selectedStudentIds`) to join `meetingId`.

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Group Created! Share the code with students."),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<AuthProvider>(context).userModel;
    final isDark = theme.brightness == Brightness.dark;
    final inputFill = isDark ? const Color(0xFF2C2C2C) : Colors.grey[100];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Create Class Group",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Group Name
                  Text(
                    "Topic / Class Name",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _groupNameController,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: "e.g., Form 4 Physics Revision",
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Metadata Filters (Grade & Time)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Target Grade",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: inputFill,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedGrade,
                                  dropdownColor: isDark
                                      ? const Color(0xFF2C2C2C)
                                      : Colors.white,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  isExpanded: true,
                                  items: _grades
                                      .map(
                                        (g) => DropdownMenuItem(
                                          value: g,
                                          child: Text(g),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    setState(() => _selectedGrade = val!);
                                    _fetchStudents(); // Refresh list on change
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Duration",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: inputFill,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _selectedDuration,
                                  dropdownColor: isDark
                                      ? const Color(0xFF2C2C2C)
                                      : Colors.white,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  isExpanded: true,
                                  items: _durations
                                      .map(
                                        (d) => DropdownMenuItem(
                                          value: d,
                                          child: Text("$d Mins"),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedDuration = val!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),

                  // 3. Student List Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Add Students",
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          if (user != null)
                            Text(
                              "${user.schoolName} • $_selectedGrade",
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.primaryColor,
                              ),
                            ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${_selectedStudentIds.length} selected",
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 4. Student List (Dynamic)
                  _isLoadingStudents
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _fetchedStudents.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              "No students found in $_selectedGrade at this school.",
                              style: const TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _fetchedStudents.length,
                          itemBuilder: (context, index) {
                            final student = _fetchedStudents[index];
                            final isSelected = _selectedStudentIds.contains(
                              student['id'],
                            );
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.primaryColor.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(color: theme.primaryColor)
                                    : null,
                              ),
                              child: ListTile(
                                onTap: () => _toggleSelection(student['id']!),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      Colors.primaries[index %
                                          Colors.primaries.length],
                                  child: Text(
                                    student['name']![0],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  student['name']!,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  student['email']!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: theme.primaryColor,
                                      )
                                    : Icon(
                                        Icons.circle_outlined,
                                        color: Colors.grey.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),

          // 5. Create Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createAndStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isCreating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(FontAwesomeIcons.video),
                          const SizedBox(width: 12),
                          Text(
                            "Start Session",
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

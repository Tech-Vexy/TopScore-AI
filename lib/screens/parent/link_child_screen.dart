import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';

class LinkChildScreen extends StatefulWidget {
  const LinkChildScreen({super.key});

  @override
  State<LinkChildScreen> createState() => _LinkChildScreenState();
}

class _LinkChildScreenState extends State<LinkChildScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _linkChild() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit code')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('link_parent_account')
          .call({'linkCode': code});

      final data = result.data as Map<dynamic, dynamic>;
      final studentName = data['studentName'];

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Success! Linked to $studentName'),
            backgroundColor: AppColors.googleGreen,
          ),
        );
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.googleRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Link Your Child",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Enter the Link Code",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Ask your child to find this 6-digit code in their Profile settings.",
              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: "Student Code",
                hintText: "e.g. K8J-2M9",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.link),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _linkChild,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        "Link Account",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

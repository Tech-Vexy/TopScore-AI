import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Privacy Policy",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Last Updated: December 2025",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              isDark,
              "1. Introduction",
              "Welcome to TopScore AI. We respect your privacy and are committed to protecting your personal data. This privacy policy will inform you as to how we look after your personal data when you visit our application/website and tell you about your privacy rights and how the law protects you.",
            ),
            _buildSection(
              isDark,
              "2. Data We Collect",
              "We may collect, use, store and transfer different kinds of personal data about you which we have grouped together follows:\n• Identity Data: includes first name, last name, username or similar identifier.\n• Contact Data: includes email address.\n• Usage Data: includes information about how you use our website and services.",
            ),
            _buildSection(
              isDark,
              "3. How We Use Your Data",
              "We will only use your personal data when the law allows us to. Most commonly, we will use your personal data in the following circumstances:\n• Where we need to perform the contract we are about to enter into or have entered into with you.\n• Where it is necessary for our legitimate interests (or those of a third party) and your interests and fundamental rights do not override those interests.\n• Where we need to comply with a legal or regulatory obligation.",
            ),
            _buildSection(
              isDark,
              "4. Data Security",
              "We have put in place appropriate security measures to prevent your personal data from being accidentally lost, used or accessed in an unauthorized way, altered or disclosed.",
            ),
            _buildSection(
              isDark,
              "5. Contact Us",
              "If you have any questions about this privacy policy or our privacy practices, please contact us at support@topscore.ai.",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(bool isDark, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textDark : AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.6,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

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
              "Last Updated: February 2026",
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
              "Welcome to TopScore AI (\"we\", \"us\", \"our\"). We are committed to protecting your personal data in accordance with the Kenya Data Protection Act, 2019 (DPA) and the regulations of the Office of the Data Protection Commissioner (ODPC). "
              "This Privacy Policy explains how we collect, use, store, and protect your personal information when you use our application and services.\n\n"
              "TopScore AI is an AI-powered education platform designed for students in Kenya following the CBC (Competency-Based Curriculum) and 8-4-4/KCSE curricula.",
            ),
            _buildSection(
              isDark,
              "2. Data Controller",
              "TopScore AI is the data controller responsible for your personal data. If you have questions about this policy or your data rights, contact us at:\n\n"
              "Email: privacy@topscore.ai\n"
              "Address: Nairobi, Kenya\n\n"
              "Governing Authority: Office of the Data Protection Commissioner (ODPC), Kenya\n"
              "Website: https://www.odpc.go.ke",
            ),
            _buildSection(
              isDark,
              "3. Data We Collect",
              "We collect only data that is necessary to provide our educational services (data minimization principle, DPA Section 25(b)):\n\n"
              "• Identity Data: Name, email address, profile photo, date of birth\n"
              "• Education Data: School name, grade/form, curriculum (CBC/8-4-4), subjects, learning progress, assessment records, competency scores\n"
              "• Contact Data: Phone number, parent/guardian contact details\n"
              "• Usage Data: App usage patterns, study time, features used, AI tutor interactions\n"
              "• Device Data: Device type, operating system, browser type (for technical support)\n"
              "• Payment Data: M-Pesa transaction references (we do not store full payment credentials)",
            ),
            _buildSection(
              isDark,
              "4. Purpose of Processing",
              "We process your data for the following purposes (DPA Section 25(a)):\n\n"
              "• Providing personalized AI tutoring aligned to KICD curriculum\n"
              "• Tracking learning progress and CBC competency development\n"
              "• Generating study materials (flashcards, quizzes) tailored to your grade and curriculum\n"
              "• Managing your subscription and processing payments\n"
              "• Communicating important updates about the service\n"
              "• Improving our educational content and AI models\n"
              "• Ensuring the safety of our platform for all users",
            ),
            _buildSection(
              isDark,
              "5. Children's Data (DPA Section 33)",
              "TopScore AI is primarily designed for students, many of whom are under 18 years of age. We take the protection of children's data very seriously:\n\n"
              "• For users under 18, we require verifiable parental or guardian consent before processing personal data, as required by Section 33 of the Kenya Data Protection Act, 2019.\n"
              "• We collect only the minimum data necessary to provide educational services.\n"
              "• We do not use children's data for marketing or advertising purposes.\n"
              "• AI tutor interactions are filtered for age-appropriate content.\n"
              "• Parents/guardians can request access to, correction of, or deletion of their child's data at any time.\n"
              "• We implement enhanced security measures for children's data.",
            ),
            _buildSection(
              isDark,
              "6. Lawful Basis for Processing",
              "We process your personal data on the following legal bases (DPA Section 30):\n\n"
              "• Consent: You provide explicit consent during registration. For minors, parental/guardian consent is obtained.\n"
              "• Contract Performance: Processing necessary to provide our educational services.\n"
              "• Legitimate Interest: Improving our platform and ensuring security, where your rights do not override these interests.\n"
              "• Legal Obligation: Complying with Kenyan law and regulatory requirements.",
            ),
            _buildSection(
              isDark,
              "7. Data Storage & Cross-Border Transfers",
              "Your data is stored on Google Cloud (Firebase) servers. As these servers may be located outside Kenya, this constitutes a cross-border data transfer (DPA Section 48).\n\n"
              "We ensure adequate safeguards for cross-border transfers through:\n"
              "• Google Cloud's compliance with international data protection standards\n"
              "• Encryption of data in transit and at rest\n"
              "• Contractual safeguards with our data processors\n\n"
              "We are working towards using regional data centers closer to Kenya as they become available.",
            ),
            _buildSection(
              isDark,
              "8. Data Security",
              "We implement appropriate technical and organizational measures to protect your data (DPA Section 41):\n\n"
              "• Encryption of data in transit (TLS/SSL) and at rest\n"
              "• Firebase Authentication with email verification\n"
              "• Firestore security rules restricting data access to authorized users\n"
              "• Regular security reviews of our platform\n"
              "• Access controls limiting staff access to personal data",
            ),
            _buildSection(
              isDark,
              "9. Your Rights",
              "Under the Kenya Data Protection Act, 2019, you have the following rights:\n\n"
              "• Right of Access (Section 26): Request a copy of your personal data\n"
              "• Right to Rectification (Section 26): Correct inaccurate data\n"
              "• Right to Erasure (Section 40): Request deletion of your data and account\n"
              "• Right to Object (Section 26): Object to processing of your data\n"
              "• Right to Data Portability: Receive your data in a structured format\n"
              "• Right to Withdraw Consent: Withdraw consent at any time\n\n"
              "To exercise any of these rights, contact us at privacy@topscore.ai or use the \"Delete Account\" option in your profile settings.\n\n"
              "You also have the right to lodge a complaint with the ODPC at https://www.odpc.go.ke.",
            ),
            _buildSection(
              isDark,
              "10. Data Retention",
              "We retain your personal data only for as long as necessary to fulfill the purposes for which it was collected:\n\n"
              "• Active account data: Retained while your account is active\n"
              "• Learning progress data: Retained for the duration of your educational journey\n"
              "• Payment records: Retained as required by Kenyan tax law\n"
              "• Deleted account data: Permanently erased within 30 days of deletion request",
            ),
            _buildSection(
              isDark,
              "11. Data Breach Notification",
              "In the event of a personal data breach, we will notify the ODPC within 72 hours as required by Section 43 of the DPA. If the breach is likely to result in high risk to your rights and freedoms, we will also notify you directly.",
            ),
            _buildSection(
              isDark,
              "12. Contact Us",
              "For any questions about this privacy policy, your personal data, or to exercise your rights:\n\n"
              "Email: privacy@topscore.ai\n"
              "Support: support@topscore.ai\n\n"
              "Supervisory Authority:\n"
              "Office of the Data Protection Commissioner (ODPC)\n"
              "P.O. Box 3469 - 00200, Nairobi, Kenya\n"
              "Website: https://www.odpc.go.ke",
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

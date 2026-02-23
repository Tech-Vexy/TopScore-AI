import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/mpesa_service.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_theme.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final MpesaService _mpesaService = MpesaService();
  bool _isLoading = false;
  String? _errorMessage;

  // Selected Plan
  final int _selectedAmount = 1000; // Default amount

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _initiatePayment() async {
    if (_phoneController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = context.read<AuthProvider>().userModel;
      // Prepend 254 if missing, simple validation
      String phone = _phoneController.text.trim();
      if (phone.startsWith('0')) {
        phone = '254${phone.substring(1)}';
      } else if (phone.startsWith('+')) {
        phone = phone.substring(1);
      }

      final result = await _mpesaService.initiateSTKPush(
        phoneNumber: phone,
        amount: _selectedAmount,
        accountReference: "TopScore Premium",
        transactionDesc: "Sub for ${user?.displayName ?? 'User'}",
      );

      // Check if ResponseCode is 0 (Success)
      if (result['ResponseCode'] == '0') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'STK Push sent! Please check your phone to complete payment.',
              ),
              backgroundColor: Colors.green,
            ),
          );
          // Ideally, poll or wait for callback confirmation here.
          // For now, we simulate success or just let user wait.
          Navigator.pop(context);
        }
      } else {
        setState(
          () => _errorMessage =
              'Payment failed: ${result['ResponseDescription']}',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Upgrade to Premium',
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Plan Card
            AppTheme.buildGlassContainer(
              context,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.star, size: 48, color: Colors.amber),
                  const SizedBox(height: 16),
                  Text(
                    'Monthly Access',
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'KES 1,000 / month',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('• Unlimited tool calling'),
                  const Text('• Web search'),
                  const Text('• Image Upload'),
                  const Text('• Graph Generation'),
                  const Text('• Standard document chat'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Phone Input
            Text(
              'Enter M-Pesa Number',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'e.g. 0712345678',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: _errorMessage,
              ),
            ),
            const SizedBox(height: 24),

            // Pay Button
            ElevatedButton(
              onPressed: _isLoading ? null : _initiatePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, // M-Pesa Green
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Pay KES $_selectedAmount with M-Pesa',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            const Text(
              'A prompt will be sent to your phone to complete the transaction.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

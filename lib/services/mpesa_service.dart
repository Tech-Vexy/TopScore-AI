import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MpesaService {
  // Hardcoded for now, but ideally from .env or config
  static const String _baseUrl = 'https://agent.topscoreapp.ai';

  Future<Map<String, dynamic>> initiateSTKPush({
    required String phoneNumber,
    required int amount,
    String accountReference = "TopScore Premium",
    String transactionDesc = "Subscription Payment",
  }) async {
    final url = Uri.parse('$_baseUrl/mpesa/stk_push');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phoneNumber,
          'amount': amount,
          'account_reference': accountReference,
          'transaction_desc': transactionDesc,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data; // Expected {ResponseCode: "0", ...}
      } else {
        throw Exception('Failed to initiate payment: ${response.body}');
      }
    } catch (e) {
      debugPrint('M-Pesa Service Error: $e');
      rethrow;
    }
  }
}

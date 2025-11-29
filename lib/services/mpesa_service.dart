class MpesaService {
  Future<Map<String, dynamic>> initiatePayment(String phoneNumber, double amount) async {
    // Simulate API call
    await Future.delayed(Duration(seconds: 2));
    return {
      'success': true,
      'message': 'STK Push sent to $phoneNumber',
      'checkoutRequestId': 'ws_CO_DMZ_123456789',
    };
  }
}

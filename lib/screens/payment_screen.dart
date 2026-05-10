import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../models/taxi.dart';
import '../services/ride_service.dart';
import '../utils/razorpay_web_checkout_stub.dart'
    if (dart.library.js) '../utils/razorpay_web_checkout_web.dart';
import 'ride_tracking_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Taxi taxi;
  final String taxiId;
  final int amount;
  final String origin;
  final String destination;
  final String vehicleNumber;
  final LatLng start;
  final LatLng end;
  final int durationMinutes;

  const PaymentScreen({
    super.key,
    required this.taxi,
    required this.taxiId,
    required this.amount,
    required this.origin,
    required this.destination,
    required this.vehicleNumber,
    required this.start,
    required this.end,
    required this.durationMinutes,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const Color _razorpayBlue = Color(0xFF0F4C81);
  static const Color _borderColor = Color(0xFFE4EAF2);
  static const Color _textMuted = Color(0xFF667085);
  static const String _razorpayKeyId = 'rzp_test_SfdojQwOOcbkUC';

  late final Razorpay _razorpay;
  final _rideService = RideService();

  bool _isProcessing = false;
  bool _isUpiSelected = true;
  int _checkoutAttempt = 0;

  int get _payableAmount => finalFare > 0 ? finalFare : widget.amount;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _handlePaymentSuccess([PaymentSuccessResponse? response]) async {
    if (!_isProcessing && mounted) {
      setState(() => _isProcessing = true);
    }
    if (response != null) {
      debugPrint(
        'Razorpay success callback received: '
        'paymentId=${response.paymentId}, '
        'orderId=${response.orderId}, '
        'signature=${response.signature}',
      );
    }
    await _completeSuccessfulPayment(paymentMethod: 'upi');
  }

  Future<void> _handlePayPressed() async {
    try {
      _openCheckout();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isProcessing = false);
      _showMessage('Could not start payment right now. Please try again.');
    }
  }

  Future<void> _handleSkipPaymentPressed() async {
    try {
      await _handlePaymentSuccess();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isProcessing = false);
      _showMessage('Could not continue to the live ride right now.');
    }
  }

  Future<void> _completeSuccessfulPayment({
    required String paymentMethod,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      final origin = widget.origin.trim();
      final destination = widget.destination.trim();
      if (user == null) {
        throw Exception('User not authenticated.');
      }

      finalFare = _payableAmount;

      final rideId = await _rideService.createRide(
        origin: origin,
        destination: destination,
        startLocationLat: widget.start.latitude,
        startLocationLng: widget.start.longitude,
        endLocationLat: widget.end.latitude,
        endLocationLng: widget.end.longitude,
        passengerId: user.id,
        fare: finalFare,
        paymentMethod: paymentMethod,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => TaxiMovingSimulation(
            rideId: rideId,
            start: widget.start,
            end: widget.end,
            taxi: widget.taxi,
            fare: finalFare,
            durationMinutes: widget.durationMinutes,
            origin: origin,
            destination: destination,
            paymentMethod: paymentMethod,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      debugPrint('Live ride start failed after payment: $error');
      setState(() => _isProcessing = false);
      _showMessage(
          'Payment succeeded, but the ride request could not be created.');
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) {
      return;
    }

    final message = response.message?.trim();
    final errorText = (message == null || message.isEmpty)
        ? 'Payment failed. Please try again.'
        : 'Payment failed: $message';

    setState(() => _isProcessing = false);
    _showMessage(errorText);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) {
      return;
    }

    setState(() => _isProcessing = false);
    final walletName = response.walletName?.trim();
    final message = (walletName == null || walletName.isEmpty)
        ? 'External wallet selected.'
        : 'External wallet selected: $walletName';
    _showMessage(message);
  }

  void _openCheckout() {
    if (_isProcessing) {
      return;
    }

    if (!_isUpiSelected) {
      _showMessage('Select UPI before continuing.');
      return;
    }

    if (_payableAmount <= 0) {
      _showMessage('Invalid fare amount.');
      return;
    }

    final origin =
        widget.origin.trim().isEmpty ? 'Pickup' : widget.origin.trim();
    final destination = widget.destination.trim().isEmpty
        ? 'Destination'
        : widget.destination.trim();
    final options = _buildCheckoutOptions(
      origin: origin,
      destination: destination,
    );
    final attempt = ++_checkoutAttempt;

    try {
      FocusScope.of(context).unfocus();
      setState(() => _isProcessing = true);
      if (kIsWeb) {
        openRazorpayWebCheckout(
          options: options,
          onSuccess: _handleWebPaymentSuccess,
          onError: _handleWebPaymentError,
          onDismiss: _handleWebCheckoutDismissed,
        );
      } else {
        _razorpay.open(options);
      }

      Future.delayed(const Duration(seconds: 10), () {
        if (!mounted || !_isProcessing || attempt != _checkoutAttempt) {
          return;
        }
        setState(() => _isProcessing = false);
      });
    } catch (error) {
      setState(() => _isProcessing = false);
      _showMessage('Could not open checkout right now.');
    }
  }

  Map<String, dynamic> _buildCheckoutOptions({
    required String origin,
    required String destination,
  }) {
    final estimatedFare = _payableAmount;

    return {
      'key': _razorpayKeyId,
      'amount': (estimatedFare * 100).toInt(),
      'name': 'Taxigo',
      'description': 'Ride Payment: $origin to $destination',
      'prefill': {
        'contact': '9876543210',
        'email': 'test@taxigo.com',
      },
      'notes': {
        'origin': origin,
        'destination': destination,
        'estimatedFare': estimatedFare.toString(),
        'taxiId': widget.taxiId,
      },
    };
  }

  Future<void> _handleWebPaymentSuccess(Map<String, dynamic> response) async {
    debugPrint(
      'Razorpay web success callback received: '
      'paymentId=${response['razorpay_payment_id']}, '
      'orderId=${response['razorpay_order_id']}, '
      'signature=${response['razorpay_signature']}',
    );
    await _handlePaymentSuccess();
  }

  void _handleWebPaymentError(String? message) {
    if (!mounted) {
      return;
    }

    setState(() => _isProcessing = false);
    final trimmedMessage = message?.trim();
    _showMessage(
      trimmedMessage == null || trimmedMessage.isEmpty
          ? 'Payment failed. Please try again.'
          : 'Payment failed: $trimmedMessage',
    );
  }

  void _handleWebCheckoutDismissed() {
    if (!mounted || !_isProcessing) {
      return;
    }

    setState(() => _isProcessing = false);
  }

  void _showMessage(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: backgroundColor,
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  TextStyle _fontStyle({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = Colors.black,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      fontFamilyFallback: const ['Inter', 'Poppins'],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      decoration: const BoxDecoration(
        color: _razorpayBlue,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(28),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Taxigo Razorpay Checkout',
                        style: _fontStyle(
                          size: 20,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Test gateway for ride payments',
                        style: _fontStyle(
                          size: 13,
                          color: Colors.white.withAlpha(220),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(22),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withAlpha(45)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'Secure',
                        style: _fontStyle(
                          size: 12,
                          weight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withAlpha(36)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount to pay',
                    style: _fontStyle(
                      size: 13,
                      weight: FontWeight.w500,
                      color: Colors.white.withAlpha(220),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rs $_payableAmount',
                    style: _fontStyle(
                      size: 32,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _infoChip(
                          icon: Icons.trip_origin,
                          text: widget.origin,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _infoChip(
                          icon: Icons.location_on_outlined,
                          text: widget.destination,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: _fontStyle(
                size: 12,
                weight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => setState(() => _isUpiSelected = true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isUpiSelected ? const Color(0xFFF4F9FF) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isUpiSelected ? _razorpayBlue : _borderColor,
                  width: _isUpiSelected ? 1.5 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C101828),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F2FB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: _razorpayBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pay via Razorpay UPI',
                          style: _fontStyle(
                            size: 16,
                            weight: FontWeight.w600,
                            color: _razorpayBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Opens Razorpay test checkout for this booking.',
                          style: _fontStyle(size: 13, color: _textMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isUpiSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: _isUpiSelected ? _razorpayBlue : Colors.black26,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ride summary',
                style: _fontStyle(
                  size: 16,
                  weight: FontWeight.w600,
                  color: _razorpayBlue,
                ),
              ),
              const SizedBox(height: 16),
              _detailRow('From', widget.origin),
              const SizedBox(height: 12),
              _detailRow('To', widget.destination),
              const SizedBox(height: 12),
              _detailRow('Vehicle', widget.vehicleNumber),
              const SizedBox(height: 12),
              _detailRow('Taxi', widget.taxi.driverName),
              const SizedBox(height: 12),
              _detailRow('Amount', 'Rs $_payableAmount'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _handlePayPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _razorpayBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Proceed to Pay',
                          style: _fontStyle(
                            size: 16,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isProcessing ? null : _handleSkipPaymentPressed,
                  child: Text(
                    'Skip Payment (Demo Only)',
                    style: _fontStyle(
                      size: 13,
                      weight: FontWeight.w600,
                      color: _razorpayBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.verified_user,
                  size: 16,
                  color: _razorpayBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This screen now uses Razorpay test checkout. After a successful payment, the ride is inserted into Supabase with status searching and the live ride screen opens immediately.',
                  style: _fontStyle(size: 13, color: _textMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: _fontStyle(
              size: 13,
              weight: FontWeight.w500,
              color: _textMuted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: _fontStyle(
              size: 14,
              weight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C101828),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: _buildSummaryView(),
            ),
          ),
        ],
      ),
    );
  }
}

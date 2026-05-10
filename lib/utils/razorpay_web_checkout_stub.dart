void openRazorpayWebCheckout({
  required Map<String, dynamic> options,
  required Future<void> Function(Map<String, dynamic> response) onSuccess,
  required void Function(String? message) onError,
  void Function()? onDismiss,
}) {
  throw UnsupportedError('Web Razorpay checkout is only available on web.');
}

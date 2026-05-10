// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:js' as js;

void openRazorpayWebCheckout({
  required Map<String, dynamic> options,
  required Future<void> Function(Map<String, dynamic> response) onSuccess,
  required void Function(String? message) onError,
  void Function()? onDismiss,
}) {
  final jsOptions = js.JsObject.jsify(options);
  jsOptions['handler'] = js.allowInterop((dynamic response) {
    onSuccess(_toDartMap(response));
  });
  jsOptions['modal'] = js.JsObject.jsify({
    'ondismiss': js.allowInterop(() {
      onDismiss?.call();
    }),
  });

  final razorpayConstructor = js.context['Razorpay'];
  if (razorpayConstructor == null) {
    throw StateError('Razorpay checkout.js is not loaded.');
  }

  final razorpay = js.JsObject(razorpayConstructor, [jsOptions]);
  razorpay.callMethod('on', [
    'payment.failed',
    js.allowInterop((dynamic response) {
      final error = _toDartMap(response)['error'];
      final errorMap =
          error is Map<String, dynamic> ? error : <String, dynamic>{};
      onError(
        errorMap['description']?.toString() ??
            errorMap['reason']?.toString() ??
            'Payment failed. Please try again.',
      );
    }),
  ]);
  razorpay.callMethod('open');
}

Map<String, dynamic> _toDartMap(dynamic value) {
  if (value == null) {
    return <String, dynamic>{};
  }

  final object = js.JsObject.fromBrowserObject(value);
  final keys = js.context['Object'].callMethod('keys', [object]) as List;
  final result = <String, dynamic>{};

  for (final key in keys) {
    final keyString = key.toString();
    final property = object[keyString];
    if (property == null) {
      result[keyString] = null;
      continue;
    }

    if (property is num ||
        property is String ||
        property is bool ||
        property is List ||
        property is Map) {
      result[keyString] = property;
      continue;
    }

    try {
      result[keyString] = _toDartMap(property);
    } catch (_) {
      result[keyString] = property.toString();
    }
  }

  return result;
}

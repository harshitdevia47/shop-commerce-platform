import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Signed result of a finished online payment; the server checks the signature.
@immutable
class OnlinePaymentResult {
  const OnlinePaymentResult({required this.orderId, required this.paymentId, required this.signature});

  final String orderId;
  final String paymentId;
  final String signature;
}

/// Opens the payment sheet. Returns null when the customer cancelled or it failed.
abstract interface class OnlineCheckout {
  Future<OnlinePaymentResult?> pay({
    required String keyId,
    required String orderId,
    required int amountPaise,
    required String shopName,
    String? phone,
  });
}

/// Razorpay Checkout (UPI apps, cards, netbanking inside one sheet).
class RazorpayOnlineCheckout implements OnlineCheckout {
  @override
  Future<OnlinePaymentResult?> pay({
    required String keyId,
    required String orderId,
    required int amountPaise,
    required String shopName,
    String? phone,
  }) {
    final razorpay = Razorpay();
    final done = Completer<OnlinePaymentResult?>();
    razorpay
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
        if (done.isCompleted) return;
        final ok = r.orderId != null && r.paymentId != null && r.signature != null;
        done.complete(ok ? OnlinePaymentResult(orderId: r.orderId!, paymentId: r.paymentId!, signature: r.signature!) : null);
      })
      ..on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
        debugPrint('Razorpay: ${r.code} ${r.message}');
        if (!done.isCompleted) done.complete(null);
      })
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, (Object _) {
        if (!done.isCompleted) done.complete(null);
      })
      ..open({
        'key': keyId,
        'order_id': orderId,
        'amount': amountPaise,
        'currency': 'INR',
        'name': shopName,
        'prefill': {'contact': ?phone},
        'retry': {'enabled': true, 'max_count': 2},
      });
    return done.future.whenComplete(razorpay.clear);
  }
}

final onlineCheckoutProvider = Provider<OnlineCheckout>((ref) => RazorpayOnlineCheckout());

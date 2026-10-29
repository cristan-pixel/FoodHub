// lib/services/payment_service.dart
//
// Online-payment layer for FoodHub. It is provider-agnostic at the call
// sites: checkout asks for a "checkout" (amount + order id + method) and
// gets back a hosted-payment URL to open in the browser.
//
// The important security rule: the payment gateway's SECRET key never
// lives in the app. All gateway calls happen inside the `createCheckout`
// Cloud Function (see functions/index.js), which reads the key from a
// Firebase secret. The app only ever holds a public checkout URL.
//
// Flow for an online method (GCash / Maya / card via Maya Checkout):
//   1. The order is created locally with PaymentStatus.pending.
//   2. createCheckout(orderId, amount) → Cloud Function → Maya
//      → returns { checkoutId, checkoutUrl, ... }.
//   3. The app opens checkoutUrl in the browser / wallet (url_launcher).
//   4. The customer pays on the hosted page.
//   5. Maya calls the `mayaWebhook` Cloud Function, which flips
//      orders/{id}.paymentStatus to "paid" in Firestore.
//   6. The app is already streaming that doc, so the order shows Paid
//      without any extra polling.
//
// If the function is not deployed / not configured, every call returns a
// clear, actionable message and the app keeps working (the order stays
// "Payment Pending" and can be paid cash on delivery) — it never crashes
// and never marks an order paid without a real charge.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:foodhub1/models/order_models.dart';

/// A gateway-created checkout session.
@immutable
class CheckoutSession {
  final String checkoutId;
  final String checkoutUrl;
  final String provider;

  const CheckoutSession({
    required this.checkoutId,
    required this.checkoutUrl,
    required this.provider,
  });
}

/// The outcome of [PaymentService.startCheckout].
enum CheckoutOutcome {
  /// Hosted checkout created and opened — waiting on the webhook.
  awaitingPayment,

  /// No online charge needed (cash on delivery).
  notRequired,

  /// The online provider is not configured on this build.
  notConfigured,

  /// The gateway/function returned an error.
  failed,
}

@immutable
class CheckoutResult {
  final CheckoutOutcome outcome;
  final CheckoutSession? session;
  final String? message;

  const CheckoutResult({required this.outcome, this.session, this.message});
}

class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  /// The callable Cloud Function defined in functions/index.js.
  static const String createCheckoutFn = 'createCheckout';

  /// Online payment methods the app offers. Anything in this set needs a
  /// real gateway charge; COD settles physically.
  static const Set<String> onlineMethods = {
    'GCash',
    'PayMaya',
    'Maya',
    'Apple Pay',
    'Credit / Debit Card',
  };

  bool get enabled {
    try {
      FirebaseFirestore.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// True when [method] requires an online charge.
  bool requiresOnlinePayment(String method) =>
      onlineMethods.contains(method.trim());

  /// The starting [PaymentStatus] for a freshly placed order.
  PaymentStatus initialStatusFor(String method) => requiresOnlinePayment(method)
      ? PaymentStatus.pending
      : PaymentStatus.cashOnDelivery;

  /// Creates a hosted checkout for [orderId] / [amount] via the
  /// `createCheckout` Cloud Function. Returns a [CheckoutResult] whose
  /// [session] the caller opens with url_launcher. Never throws.
  Future<CheckoutResult> startCheckout({
    required String orderId,
    required double amount,
    required String method,
    String? description,
  }) async {
    if (!requiresOnlinePayment(method)) {
      return const CheckoutResult(outcome: CheckoutOutcome.notRequired);
    }
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable(createCheckoutFn);
      final res = await callable.call<Map<String, dynamic>>({
        'orderId': orderId,
        'amount': amount,
        'method': method,
        'description': description ?? 'FoodHub order $orderId',
      });
      final data = res.data;
      final url = (data['checkoutUrl'] as String?) ??
          (data['redirectUrl'] as String?) ??
          '';
      if (url.isEmpty) {
        return const CheckoutResult(
          outcome: CheckoutOutcome.failed,
          message: 'The payment gateway did not return a checkout link.',
        );
      }
      return CheckoutResult(
        outcome: CheckoutOutcome.awaitingPayment,
        session: CheckoutSession(
          checkoutId: (data['checkoutId'] as String?) ?? '',
          checkoutUrl: url,
          provider: (data['provider'] as String?) ?? 'Maya Checkout',
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      final notConfigured = e.code == 'unimplemented' ||
          e.code == 'not-found' ||
          (e.code == 'failed-precondition' &&
              (e.message ?? '').toLowerCase().contains('not configured'));
      return CheckoutResult(
        outcome: notConfigured
            ? CheckoutOutcome.notConfigured
            : CheckoutOutcome.failed,
        message: notConfigured
            ? 'Online payments are not deployed/configured yet. Your order '
                'was saved as Payment Pending — you can pay cash on delivery.'
            : 'Payment error: ${e.message ?? e.code}',
      );
    } catch (e) {
      return CheckoutResult(
        outcome: CheckoutOutcome.notConfigured,
        message: 'Online payments are not set up on this build yet. Your '
            'order was saved as Payment Pending — you can pay cash on '
            'delivery instead. ($e)',
      );
    }
  }

  /// One-shot read of an order's payment status from Firestore, used as a
  /// fallback if the live stream hasn't delivered the webhook update yet.
  Future<PaymentStatus?> fetchPaymentStatus(String orderId) async {
    if (!enabled) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();
      return PaymentStatus.parse(doc.data()?['paymentStatus'] as String?);
    } catch (_) {
      return null;
    }
  }
}

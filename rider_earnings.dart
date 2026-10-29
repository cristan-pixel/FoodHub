import 'package:foodhub1/models/order_models.dart';

class RiderEarnings {
  RiderEarnings._();

  static const double commissionPercent = 20.0;

  static String get percentLabel {
    final p = commissionPercent;
    return p == p.roundToDouble()
        ? '${p.toInt()}%'
        : '${p.toStringAsFixed(1)}%';
  }

  static double foodSubtotal(DeliveryOrder order) {
    double sum = 0;
    for (final item in order.items) {
      final price = double.tryParse(item['price']?.toString() ?? '') ?? 0;
      final qty = (item['qty'] as num?)?.toInt() ?? 1;
      sum += price * qty;
    }
    return sum;
  }

  static double amountFor(DeliveryOrder order) =>
      foodSubtotal(order) * (commissionPercent / 100);

  static DateTime deliveredAt(DeliveryOrder order) {
    for (final entry in order.history.reversed) {
      if (entry.key == OrderStatus.delivered) return entry.value;
    }
    return order.placedAt;
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

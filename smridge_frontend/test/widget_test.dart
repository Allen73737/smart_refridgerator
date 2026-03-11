import 'package:flutter_test/flutter_test.dart';
import 'package:smridge_frontend/utils/expiry_estimator.dart';

void main() {
  // Helper: truncate to date only (no time-of-day) to avoid millisecond drift
  DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  group('ExpiryEstimator', () {
    test('matches known keywords correctly (milk = 3 days)', () {
      final result = dateOnly(ExpiryEstimator.estimateExpiryDate('Fresh Milk'));
      final expected = dateOnly(DateTime.now().add(const Duration(days: 3)));
      expect(result, expected);
    });

    test('matches keyword in multi-word product name (chicken = 1 day)', () {
      final result = dateOnly(ExpiryEstimator.estimateExpiryDate('Grilled Chicken Burger'));
      final expected = dateOnly(DateTime.now().add(const Duration(days: 1)));
      expect(result, expected);
    });

    test('returns default 5 days for completely unknown products', () {
      final result = dateOnly(ExpiryEstimator.estimateExpiryDate('ZZZ Unknown Xylophone'));
      final expected = dateOnly(DateTime.now().add(const Duration(days: 5)));
      expect(result, expected);
    });

    test('handles empty string gracefully with default 5 days', () {
      final result = dateOnly(ExpiryEstimator.estimateExpiryDate(''));
      final expected = dateOnly(DateTime.now().add(const Duration(days: 5)));
      expect(result, expected);
    });
  });
}

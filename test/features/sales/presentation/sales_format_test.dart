import 'package:drop/features/sales/presentation/sales_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sales money format', () {
    test('formats whole and fractional piastres as EGP', () {
      expect(formatEgp(5990000, withSuffix: true), '59,900 EGP');
      expect(formatEgp(5990050), '59,900.50');
    });

    test('parses valid EGP amounts into piastres', () {
      expect(parseEgpToPiastres('59,900.5'), 5990050);
      expect(parseEgpToPiastres('0'), 0);
    });

    test('rejects invalid and negative amounts', () {
      expect(parseEgpToPiastres('-1'), isNull);
      expect(parseEgpToPiastres('1.234'), isNull);
      expect(parseEgpToPiastres('nope'), isNull);
    });
  });
}

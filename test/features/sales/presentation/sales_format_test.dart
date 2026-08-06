import 'package:drop/features/sales/presentation/sales_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sales money format', () {
    test('formats whole and fractional piastres as EGP', () {
      expect(formatEgp(5990000, withSuffix: true), '59,900 EGP');
      expect(formatEgp(5990050), '59,900.50');
    });

    test('never emits a leading separator', () {
      // Regression: the old lookahead also matched at index 0 whenever the
      // digit count was an exact multiple of three, so these rendered as
      // ",945,000" and ",350" on screen.
      expect(formatEgp(94500000, withSuffix: true), '945,000 EGP');
      expect(formatEgp(35000), '350');
      expect(formatEgp(10000000), '100,000');
      expect(formatEgp(100000000000), '1,000,000,000');
    });

    test('groups every magnitude from the right', () {
      expect(formatEgp(0), '0');
      expect(formatEgp(100), '1');
      expect(formatEgp(1000), '10');
      expect(formatEgp(100000), '1,000');
      expect(formatEgp(170500000), '1,705,000');
      expect(formatEgp(-94500000, withSuffix: true), '-945,000 EGP');
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

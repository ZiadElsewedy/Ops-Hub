import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/schedule/domain/swap_policy.dart';

/// Pure verification of the branch-level shift-swap policy (role compatibility +
/// serialization + value equality). No Firebase needed.
void main() {
  group('SwapPolicy.positionsCompatible', () {
    test('permissive policy → any positions are compatible', () {
      expect(
          SwapPolicy.permissive.positionsCompatible('Cashier', 'Supervisor'),
          isTrue);
    });

    test('restrict on + matching positions (case-insensitive) → compatible', () {
      const p = SwapPolicy(restrictToSamePosition: true);
      expect(p.positionsCompatible('Cashier', 'cashier'), isTrue);
      expect(p.positionsCompatible(' Cashier ', 'Cashier'), isTrue);
    });

    test('restrict on + different positions → blocked', () {
      const p = SwapPolicy(restrictToSamePosition: true);
      expect(p.positionsCompatible('Cashier', 'Supervisor'), isFalse);
    });

    test('restrict on + an unset position → still compatible (permissive)', () {
      const p = SwapPolicy(restrictToSamePosition: true);
      expect(p.positionsCompatible(null, 'Supervisor'), isTrue);
      expect(p.positionsCompatible('Cashier', ''), isTrue);
      expect(p.positionsCompatible(null, null), isTrue);
    });
  });

  group('SwapPolicy serialization + equality', () {
    test('round-trips through a Firestore map', () {
      const p = SwapPolicy(restrictToSamePosition: true, minRestHours: 10);
      final back = SwapPolicy.fromMap(p.toMap());
      expect(back, p);
      expect(back.hasAnyRule, isTrue);
    });

    test('null map → permissive default', () {
      expect(SwapPolicy.fromMap(null), SwapPolicy.permissive);
      expect(SwapPolicy.permissive.hasAnyRule, isFalse);
    });

    test('zero / negative minRestHours is treated as off', () {
      expect(SwapPolicy.fromMap({'minRestHours': 0}).minRestHours, isNull);
      expect(SwapPolicy.fromMap({'minRestHours': -3}).minRestHours, isNull);
    });

    test('value equality (composes inside freezed BranchEntity)', () {
      expect(const SwapPolicy(minRestHours: 8),
          const SwapPolicy(minRestHours: 8));
      expect(const SwapPolicy(minRestHours: 8) == const SwapPolicy(minRestHours: 9),
          isFalse);
    });
  });
}

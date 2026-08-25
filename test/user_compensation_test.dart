import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/admin/domain/entities/user_compensation.dart';
import 'package:opshub/features/admin/presentation/widgets/compensation_fields.dart';
import 'package:opshub/features/auth/data/models/user_model.dart';
import 'package:opshub/features/profile/data/models/profile_model.dart';

/// C2 fix (2026-07-03): compensation lives in the PRIVATE subdocument
/// `users/{uid}/private/compensation` (see [UserCompensation]) — the
/// branch-readable public user fetch must never carry salary data.
void main() {
  group('UserCompensation (private subdocument record)', () {
    test('round-trips through fromMap → toMap', () {
      final c = UserCompensation.fromMap({
        'salaryAmount': 4500,
        'salaryType': 'monthly',
        'paymentMethod': 'wallet',
        'paymentNumber': '+201000000000',
      });
      expect(c.salaryAmount, 4500.0);
      expect(c.salaryType, 'monthly');
      expect(c.paymentMethod, 'wallet');
      expect(c.paymentNumber, '+201000000000');

      final map = c.toMap();
      expect(map['salaryAmount'], 4500.0);
      expect(map['salaryType'], 'monthly');
      expect(map['paymentMethod'], 'wallet');
      expect(map['paymentNumber'], '+201000000000');
    });

    test('toMap writes all four keys — null clears a stale value', () {
      final map = const UserCompensation(salaryAmount: 100).toMap();
      expect(
          map.keys,
          containsAll(
              ['salaryAmount', 'salaryType', 'paymentMethod', 'paymentNumber']));
      expect(map['salaryType'], isNull);
    });

    test('parses the same keys off a LEGACY user-doc map (migration window)',
        () {
      // Pre-migration docs still carry the fields top-level; the datasource
      // fallback feeds that whole doc map through this same factory.
      final c = UserCompensation.fromMap({
        'uid': 'u1',
        'email': 'a@b.com',
        'role': 'employee',
        'salaryAmount': 300.5,
        'paymentNumber': '+2010',
      });
      expect(c.salaryAmount, 300.5);
      expect(c.paymentNumber, '+2010');
      expect(c.isEmpty, isFalse);
    });

    test('null / empty map → empty record', () {
      expect(UserCompensation.fromMap(null).isEmpty, isTrue);
      expect(UserCompensation.fromMap(const {}).isEmpty, isTrue);
    });
  });

  group('public user fetch carries NO compensation (C2 guarantee)', () {
    test('UserModel ignores legacy salary keys — nothing echoes back out', () {
      final model = UserModel.fromMap({
        'uid': 'u1',
        'email': 'a@b.com',
        'salaryAmount': 4500,
        'salaryType': 'monthly',
        'paymentMethod': 'wallet',
        'paymentNumber': '+201000000000',
      });
      // The fields no longer exist on the model/entity; the serialized form
      // is the observable surface and must not echo the keys back.
      final map = model.toMap();
      expect(map.containsKey('salaryAmount'), isFalse);
      expect(map.containsKey('salaryType'), isFalse);
      expect(map.containsKey('paymentMethod'), isFalse);
      expect(map.containsKey('paymentNumber'), isFalse);
    });
  });

  group('ProfileModel self-service payroll field', () {
    test('editMap never writes paymentNumber to the public user doc', () {
      final map = ProfileModel.editMap(fullName: 'Ada');
      expect(map.containsKey('paymentNumber'), isFalse);
    });

    test('fromMap still reads paymentNumber (overlaid from the subdocument)',
        () {
      final entity = ProfileModel.fromMap({
        'uid': 'u1',
        'email': 'a@b.com',
        'paymentNumber': '+2010',
      }).toEntity();
      expect(entity.paymentNumber, '+2010');
    });
  });

  group('salarySummary', () {
    test('formats whole amounts without decimals + type label', () {
      expect(salarySummary(4500, 'monthly'), '4500 · Monthly');
      expect(salarySummary(120.5, 'daily'), '120.5 · Daily');
      expect(salarySummary(4500, null), '4500');
      expect(salarySummary(null, 'monthly'), isNull);
    });

    test('validateSalaryAmount accepts empty / numeric, rejects junk', () {
      expect(validateSalaryAmount(''), isNull);
      expect(validateSalaryAmount(null), isNull);
      expect(validateSalaryAmount('4500'), isNull);
      expect(validateSalaryAmount('120.5'), isNull);
      expect(validateSalaryAmount('12.3.4'), isNotNull);
      expect(validateSalaryAmount('-5'), isNotNull);
    });
  });
}

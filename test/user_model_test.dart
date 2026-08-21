import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/auth/data/models/user_model.dart';

/// Stability regression: `UserModel.fromMap` must never throw on a malformed or
/// partial `users/{uid}` document. A single bad doc used to crash an entire
/// user-list load (schedule team, assignee picker, admin lists) because `uid`
/// and `email` were cast to non-null `String`.
void main() {
  group('UserModel.fromMap is crash-proof', () {
    test('a phone-auth doc with no email parses (email → "")', () {
      final model = UserModel.fromMap({
        'uid': 'abc123',
        'phoneNumber': '+201000000000',
        'authProvider': 'phone',
      });
      expect(model.uid, 'abc123');
      expect(model.email, '');
    });

    test('an empty / totally malformed doc does not throw', () {
      expect(() => UserModel.fromMap(const {}), returnsNormally);
      final model = UserModel.fromMap(const {});
      expect(model.uid, '');
      expect(model.email, '');
      // Safe role default still applies so access can never escalate.
      expect(model.role, UserRole.employee);
      expect(model.isActive, isTrue);
      // Provisioning flags default to NOT forced so legacy docs aren't trapped.
      expect(model.mustChangePassword, isFalse);
      expect(model.isProfileCompleted, isTrue);
      expect(model.employmentStatus, 'active');
    });

    test('a well-formed doc still maps every field', () {
      final model = UserModel.fromMap({
        'uid': 'u1',
        'email': 'a@b.com',
        'displayName': 'Ada',
        'role': 'manager',
        'branchId': 'branch-1',
        'isActive': true,
        'position': 'Cashier',
      });
      expect(model.uid, 'u1');
      expect(model.email, 'a@b.com');
      expect(model.displayName, 'Ada');
      expect(model.role, UserRole.manager);
      expect(model.branchId, 'branch-1');
      // Job position (drives shift-swap role compatibility) round-trips.
      expect(model.position, 'Cashier');
      expect(model.toEntity().position, 'Cashier');
    });

    test('an admin-provisioned doc maps the first-login + audit fields', () {
      final model = UserModel.fromMap({
        'uid': 'u2',
        'email': 'new@b.com',
        'displayName': 'New Hire',
        'role': 'employee',
        'branchId': 'branch-2',
        'assignedShift': 'morning',
        'position': 'Stockist',
        'isActive': true,
        'mustChangePassword': true,
        'isProfileCompleted': false,
        'employmentStatus': 'active',
        'createdBy': 'admin-1',
      });
      expect(model.mustChangePassword, isTrue);
      expect(model.isProfileCompleted, isFalse);
      expect(model.employmentStatus, 'active');
      expect(model.createdBy, 'admin-1');
      // Access is gated solely by isActive now.
      final entity = model.toEntity();
      expect(entity.hasAppAccess, isTrue);
      expect(entity.mustChangePassword, isTrue);
      expect(entity.isProfileCompleted, isFalse);
      expect(entity.createdBy, 'admin-1');
    });

    test('name falls back to the legacy profile fullName key', () {
      final model = UserModel.fromMap({
        'uid': 'u3',
        'email': 'c@b.com',
        'fullName': 'Legacy Name',
      });
      expect(model.displayName, 'Legacy Name');
    });

    test('admin-editable contact details (phone/address/emergency) round-trip',
        () {
      final model = UserModel.fromMap({
        'uid': 'u4',
        'email': 'd@b.com',
        'phoneNumber': '+201000000000',
        'address': '12 Tahrir St, Cairo',
        'emergencyContact': 'Mona · +201111111111',
      });
      expect(model.phoneNumber, '+201000000000');
      expect(model.address, '12 Tahrir St, Cairo');
      expect(model.emergencyContact, 'Mona · +201111111111');
      final entity = model.toEntity();
      expect(entity.address, '12 Tahrir St, Cairo');
      expect(entity.emergencyContact, 'Mona · +201111111111');
      // Survives the entity → model → map round-trip.
      final map = UserModel.fromEntity(entity).toMap();
      expect(map['address'], '12 Tahrir St, Cairo');
      expect(map['emergencyContact'], 'Mona · +201111111111');
    });
  });

  group('hasCompletedOnboarding (one-time Welcome flag)', () {
    test('is absent on legacy docs → defaults true (never re-shows Welcome)', () {
      // No existing / pre-feature user carries the field, so they must read as
      // "already welcomed" and never be gated into the Welcome screen.
      expect(UserModel.fromMap(const {}).hasCompletedOnboarding, isTrue);
      final legacy = UserModel.fromMap({'uid': 'u', 'email': 'a@b.com'});
      expect(legacy.hasCompletedOnboarding, isTrue);
    });

    test('an explicit false (new employee, seeded at completion) round-trips',
        () {
      final model = UserModel.fromMap({
        'uid': 'e1',
        'email': 'new@b.com',
        'role': 'employee',
        'isProfileCompleted': true,
        'hasCompletedOnboarding': false,
      });
      expect(model.hasCompletedOnboarding, isFalse);
      // Survives model ⇄ entity both ways.
      expect(model.toEntity().hasCompletedOnboarding, isFalse);
      expect(
        UserModel.fromEntity(model.toEntity()).hasCompletedOnboarding,
        isFalse,
      );
    });
  });
}

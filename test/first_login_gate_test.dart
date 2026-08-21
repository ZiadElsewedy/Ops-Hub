import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/routes/app_router.dart';
import 'package:opshub/core/routes/route_names.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';

/// The pure first-login ordering that the router's redirect delegates to:
/// temp-password change → profile completion → (employees only) the one-time
/// Welcome. This is the gate that decides whether a user is confined to a
/// first-login screen, so it is unit-tested independently of GoRouter.
UserEntity _user({
  UserRole role = UserRole.employee,
  bool mustChangePassword = false,
  bool isProfileCompleted = true,
  bool hasCompletedOnboarding = true,
}) => UserEntity(
  uid: 'u1',
  email: 'u1@drop.app',
  authProvider: 'password',
  role: role,
  mustChangePassword: mustChangePassword,
  isProfileCompleted: isProfileCompleted,
  hasCompletedOnboarding: hasCompletedOnboarding,
);

void main() {
  group('firstLoginLocation', () {
    test('a fully-cleared employee is not confined anywhere', () {
      expect(firstLoginLocation(_user()), isNull);
    });

    test('mustChangePassword wins first, regardless of the later stages', () {
      final u = _user(
        mustChangePassword: true,
        isProfileCompleted: false,
        hasCompletedOnboarding: false,
      );
      expect(firstLoginLocation(u), RouteNames.forcePasswordChange);
    });

    test('an incomplete profile is confined to Profile Completion', () {
      expect(
        firstLoginLocation(_user(isProfileCompleted: false)),
        RouteNames.profileCompletion,
      );
    });

    test(
      'a NEW employee (profile done, onboarding not seen) goes to Welcome',
      () {
        expect(
          firstLoginLocation(_user(hasCompletedOnboarding: false)),
          RouteNames.welcome,
        );
      },
    );

    test('a returning employee (onboarding seen) is not sent to Welcome', () {
      expect(firstLoginLocation(_user()), isNull);
    });

    test('managers never see Welcome, even with the flag unset', () {
      expect(
        firstLoginLocation(
          _user(role: UserRole.manager, hasCompletedOnboarding: false),
        ),
        isNull,
      );
    });

    test('admins never see Welcome, even with the flag unset', () {
      expect(
        firstLoginLocation(
          _user(role: UserRole.admin, hasCompletedOnboarding: false),
        ),
        isNull,
      );
    });

    test(
      'profile completion is still required before Welcome for a new employee',
      () {
        // Both unset → profile completion comes first (Welcome only after it).
        final u = _user(
          isProfileCompleted: false,
          hasCompletedOnboarding: false,
        );
        expect(firstLoginLocation(u), RouteNames.profileCompletion);
      },
    );
  });
}

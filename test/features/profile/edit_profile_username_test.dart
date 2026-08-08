import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/utils/validators.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/features/profile/domain/entities/profile_entity.dart';
import 'package:drop/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:drop/features/profile/presentation/cubit/profile_state.dart';
import 'package:drop/features/profile/presentation/pages/edit_profile_page.dart';

/// The handle had **no input anywhere in the app** while
/// `ProfileEntity.isComplete` required it — so every account was permanently
/// "incomplete" and the profile's prompt could never be satisfied. These pin
/// the field that closes that loop.

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(UserRole role)
    : super(
        AuthState.authenticated(
          UserEntity(
            uid: 'u1',
            email: 'ziad@drop.test',
            authProvider: 'password',
            displayName: 'Ziad Elsewedy',
            role: role,
          ),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileCubit extends Cubit<ProfileState> implements ProfileCubit {
  _FakeProfileCubit(ProfileEntity profile) : super(ProfileState.loaded(profile));

  final saved = <String?>[];

  @override
  Future<void> save({
    required String uid,
    String? fullName,
    String? username,
    String? bio,
    String? phoneNumber,
    String? country,
    String? city,
    String? website,
    String? gender,
    DateTime? birthDate,
    File? avatarFile,
    File? coverFile,
    String? emergencyContact,
    String? address,
    String? paymentNumber,
  }) async {
    saved.add(username);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _profile = ProfileEntity(
  uid: 'u1',
  email: 'ziad@drop.test',
  authProvider: 'password',
  fullName: 'Ziad Elsewedy',
);

Widget _harness(_FakeAuthCubit auth, _FakeProfileCubit profile) =>
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: auth),
        BlocProvider<ProfileCubit>.value(value: profile),
      ],
      child: const MaterialApp(home: EditProfilePage()),
    );

void main() {
  group('the username validator', () {
    test('accepts a normal handle and rejects the shapes that break a link', () {
      expect(Validators.username('ziad'), isNull);
      expect(Validators.username('ziad_elsewedy'), isNull);
      expect(Validators.username('ziad.99'), isNull);

      expect(Validators.username('zi'), isNotNull); // too short
      expect(Validators.username('z' * 21), isNotNull); // too long
      expect(Validators.username('9ziad'), isNotNull); // leading digit
      expect(Validators.username('ziad elsewedy'), isNotNull); // space
      expect(Validators.username('ziad@drop'), isNotNull); // symbol
    });

    test('an empty value passes only when the field is optional', () {
      expect(Validators.username('', required: false), isNull);
      expect(Validators.username(''), isNotNull);
    });
  });

  testWidgets('Edit Profile has a username field, and saving sends it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = _FakeAuthCubit(UserRole.employee);
    final profile = _FakeProfileCubit(_profile);
    addTearDown(() async {
      await auth.close();
      await profile.close();
    });

    await tester.pumpWidget(_harness(auth, profile));
    await tester.pumpAndSettle();

    // The hint is what identifies the field — it renders until something is
    // typed, so the label is findable as ordinary text.
    expect(find.text('Username'), findsOneWidget);
    final field = find
        .ancestor(of: find.text('Username'), matching: find.byType(TextField))
        .first;

    await tester.enterText(field, 'ziad');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(profile.saved, ['ziad']);
  });
}

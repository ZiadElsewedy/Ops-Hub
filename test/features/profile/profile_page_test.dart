import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/routes/route_names.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_state.dart';
import 'package:opshub/features/profile/domain/entities/profile_entity.dart';
import 'package:opshub/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:opshub/features/profile/presentation/cubit/profile_state.dart';
import 'package:opshub/features/profile/presentation/pages/profile_page.dart';

const _branch = BranchEntity(
  id: 'branch-1',
  name: 'OpsHub | Arkan',
  location: 'Sheikh Zayed',
);

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(UserEntity user) : super(AuthState.authenticated(user));

  bool didSignOut = false;

  @override
  Future<void> signOut() async => didSignOut = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileCubit extends Cubit<ProfileState> implements ProfileCubit {
  _FakeProfileCubit(ProfileEntity profile) : super(ProfileState.loaded(profile));

  int loads = 0;
  int forcedLoads = 0;

  @override
  Future<void> loadProfile(String uid, {bool forceRefresh = false}) async {
    loads++;
    if (forceRefresh) forcedLoads++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBranchCubit extends Cubit<BranchState> implements BranchCubit {
  _FakeBranchCubit() : super(const BranchState.loaded([_branch]));

  @override
  Future<void> loadIfNeeded() async {}

  @override
  BranchEntity? branchById(String? id) => id == _branch.id ? _branch : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserEntity _user({
  UserRole role = UserRole.employee,
  String? branchId = 'branch-1',
  String? position = 'Cashier',
}) => UserEntity(
  uid: 'u1',
  email: 'ziad@drop.test',
  authProvider: 'password',
  displayName: 'Ziad Elsewedy',
  role: role,
  branchId: branchId,
  position: position,
  assignedShift: 'Morning',
);

ProfileEntity _profile({
  String? fullName = 'Ziad Elsewedy',
  String? username = 'ziad',
  String? phoneNumber = '01001234567',
  String? paymentNumber,
  String? bio = 'Front of house, Arkan branch.',
}) => ProfileEntity(
  uid: 'u1',
  email: 'ziad@drop.test',
  authProvider: 'password',
  fullName: fullName,
  username: username,
  phoneNumber: phoneNumber,
  paymentNumber: paymentNumber,
  bio: bio,
  createdAt: DateTime(2026, 3, 14),
);

Widget _harness({
  required _FakeAuthCubit auth,
  required _FakeProfileCubit profile,
  required _FakeBranchCubit branch,
}) {
  final router = GoRouter(
    initialLocation: RouteNames.profile,
    routes: [
      GoRoute(path: RouteNames.profile, builder: (_, _) => const ProfilePage()),
      GoRoute(
        path: RouteNames.editProfile,
        builder: (_, _) => const Scaffold(body: Text('EDIT DESTINATION')),
      ),
      GoRoute(
        path: RouteNames.settings,
        builder: (_, _) => const Scaffold(body: Text('SETTINGS DESTINATION')),
      ),
    ],
  );
  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthCubit>.value(value: auth),
      BlocProvider<ProfileCubit>.value(value: profile),
      BlocProvider<BranchCubit>.value(value: branch),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  late _FakeAuthCubit auth;
  late _FakeProfileCubit profileCubit;
  late _FakeBranchCubit branchCubit;

  void arrange({UserEntity? user, ProfileEntity? profile}) {
    auth = _FakeAuthCubit(user ?? _user());
    profileCubit = _FakeProfileCubit(profile ?? _profile());
    branchCubit = _FakeBranchCubit();
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _harness(auth: auth, profile: profileCubit, branch: branchCubit),
    );
    await tester.pumpAndSettle();
  }

  tearDown(() async {
    await auth.close();
    await profileCubit.close();
    await branchCubit.close();
  });

  testWidgets('leads with identity, role and the assigned branch', (
    tester,
  ) async {
    arrange();
    await pump(tester);

    expect(find.text('Ziad Elsewedy'), findsOneWidget);
    expect(find.text('@ziad'), findsOneWidget);
    // Position is a Workplace row — on the identity line it truncated both it
    // and the handle at 390pt.
    expect(find.text('Cashier'), findsOneWidget);
    expect(find.text('EMPLOYEE'), findsOneWidget);
    expect(find.text('Front of house, Arkan branch.'), findsOneWidget);
    expect(
      find.text('OpsHub | Arkan · Sheikh Zayed'),
      findsOneWidget,
    );
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('a complete profile is not nagged; a username-less one is', (
    tester,
  ) async {
    arrange(profile: _profile(username: null));
    await pump(tester);

    // The nag names what is actually missing — the name is set, so it must not
    // ask for it.
    expect(find.text('Pick a username to finish setting up.'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);

    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();
    expect(find.text('EDIT DESTINATION'), findsOneWidget);
  });

  testWidgets('a self-service detail opens the edit form when tapped', (
    tester,
  ) async {
    arrange();
    await pump(tester);

    await tester.tap(find.text('01001234567'));
    await tester.pumpAndSettle();
    expect(find.text('EDIT DESTINATION'), findsOneWidget);
  });

  testWidgets('copying a value is its own control, not the row tap', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    arrange();
    await pump(tester);

    await tester.tap(find.byTooltip('Copy Phone'));
    await tester.pump();

    expect(copied, ['01001234567']);
    expect(find.text('Phone copied'), findsOneWidget);
    // The copy did not also navigate — the two gestures are separate.
    expect(find.text('EDIT DESTINATION'), findsNothing);
  });

  testWidgets('an unset self-service detail offers the edit form', (
    tester,
  ) async {
    arrange(profile: _profile(phoneNumber: null));
    await pump(tester);

    expect(find.text('Not set'), findsWidgets);
    await tester.tap(
      find
          .ancestor(
            of: find.text('PHONE'),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('EDIT DESTINATION'), findsOneWidget);
  });

  testWidgets('no screen states salary — payroll is not a profile fact', (
    tester,
  ) async {
    arrange(profile: _profile(paymentNumber: '09998887776'));
    await pump(tester);

    expect(find.text('PAYROLL'), findsNothing);
    expect(find.text('SALARY SENT TO'), findsNothing);
    expect(find.text('09998887776'), findsNothing);
  });

  testWidgets('an admin gets no door to a field they cannot edit', (
    tester,
  ) async {
    arrange(
      user: _user(role: UserRole.admin, branchId: null, position: null),
      profile: _profile(phoneNumber: null),
    );
    await pump(tester);

    // The global admin's branch row states the truth instead of sitting empty.
    expect(find.text('All branches · organisation-wide'), findsOneWidget);
    // Contact rows are read-only for an admin — the row carries no InkWell at
    // all, so there is nothing to press and nowhere it could lead.
    expect(
      find.ancestor(of: find.text('ADDRESS'), matching: find.byType(InkWell)),
      findsNothing,
    );
    await tester.tap(find.text('ADDRESS'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('EDIT DESTINATION'), findsNothing);
  });

  testWidgets('pull to refresh forces a re-read', (tester) async {
    arrange();
    // A phone-sized window: the indicator's arm threshold is a quarter of the
    // viewport height, so the drag below must clear it.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _harness(auth: auth, profile: profileCubit, branch: branchCubit),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 400),
      touchSlopY: 0,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(profileCubit.forcedLoads, 1);
  });

  testWidgets('Profile is a leaf: no second hub, no duplicate sign out', (
    tester,
  ) async {
    arrange();
    await pump(tester);
    await tester.scrollUntilVisible(find.text('MEMBER SINCE'), 200);
    await tester.pumpAndSettle();

    // Settings → Profile → Settings was a closed loop, and Sign out existed on
    // two screens. Both belong to the hub; this screen must never grow them
    // back.
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Sign out'), findsNothing);
    expect(auth.didSignOut, isFalse);
  });
}

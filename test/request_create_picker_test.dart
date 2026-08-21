import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/requests/presentation/cubit/requests_list_cubit.dart';
import 'package:opshub/features/requests/presentation/cubit/requests_list_state.dart';
import 'package:opshub/features/requests/presentation/pages/create_request_screen.dart';

/// Guards the New Request type picker across tiers. Regression for the mobile
/// bug where every grid tile rendered "BOTTOM OVERFLOWED BY 5.7 PIXELS": the
/// picker used a fixed `childAspectRatio`, so on a phone the tile height came
/// out shorter than its content. The phone tier now uses content-sized
/// full-width rows (can't overflow); the desktop grid uses a fixed
/// `mainAxisExtent`. RenderFlex overflows throw in widget tests, so these
/// pumps failing-free IS the proof.

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(UserEntity user) : super(AuthState.authenticated(user));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequestsListCubit extends Cubit<RequestsListState>
    implements RequestsListCubit {
  _FakeRequestsListCubit() : super(const RequestsListState.initial());

  @override
  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserEntity _employee() => const UserEntity(
      uid: 'emp1',
      email: 'emp1@x.com',
      authProvider: 'password',
      displayName: 'Employee One',
      role: UserRole.employee,
      branchId: 'b1',
    );

Widget _app() => MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(create: (_) => _FakeAuthCubit(_employee())),
        BlocProvider<RequestsListCubit>(
            create: (_) => _FakeRequestsListCubit()),
      ],
      child: const MaterialApp(home: CreateRequestScreen()),
    );

void main() {
  Future<void> setSize(WidgetTester tester, Size logical) async {
    tester.view.physicalSize = logical * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('phone: the type picker renders as rows with NO overflow',
      (tester) async {
    await setSize(tester, const Size(390, 844)); // iPhone-class width
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // No RenderFlex/constraint exception anywhere in the pump.
    expect(tester.takeException(), isNull);
    expect(find.text('What do you need your manager to approve?'),
        findsOneWidget);
    expect(find.text('Employee Discount'), findsOneWidget);
    // Row blurbs render in full on the phone tier (no grid truncation).
    expect(find.text('Step out of the store during your shift'),
        findsOneWidget);
  });

  testWidgets('phone: tapping a type opens the single-message form',
      (tester) async {
    await setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Leave Store'));
    // Plain pumps (not pumpAndSettle): the form's autofocused TextField owns
    // a blinking-cursor timer that never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('Message to your manager'), findsOneWidget);
    expect(find.text('Submit request'), findsOneWidget);
  });

  testWidgets('desktop: the type picker renders as a grid with NO overflow',
      (tester) async {
    await setSize(tester, const Size(1440, 900));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Employee Discount'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/widgets/animated_drop_logo.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/features/auth/presentation/pages/onboarding_welcome_page.dart';

/// A stand-in AuthCubit that records the one dismiss call the page makes and
/// otherwise just holds an authenticated state.
class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(UserEntity user) : super(AuthState.authenticated(user));

  int completeOnboardingCalls = 0;

  @override
  Future<void> completeOnboarding() async => completeOnboardingCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  UserEntity employee({String? name}) => UserEntity(
    uid: 'e1',
    email: 'e1@drop.app',
    authProvider: 'password',
    role: UserRole.employee,
    displayName: name,
    isProfileCompleted: true,
    hasCompletedOnboarding: false,
  );

  Future<_FakeAuthCubit> pumpWelcome(
    WidgetTester tester, {
    String? name,
  }) async {
    // Phone width → the hero uses AnimatedDropLogo (no 13MB Lottie in tests).
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _FakeAuthCubit(employee(name: name));
    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: auth,
        child: const MaterialApp(home: OnboardingWelcomePage()),
      ),
    );
    // Run the staggered FadeSlideTransition delays (up to ~0.9s + 0.5s each).
    // Explicit pumps, never pumpAndSettle — AnimatedDropLogo repeats forever.
    await tester.pump(const Duration(milliseconds: 1600));
    return auth;
  }

  testWidgets('greets the employee by first name and states the expectations', (
    tester,
  ) async {
    await pumpWelcome(tester, name: 'Ahmed Ali');

    expect(find.text('Welcome to Drop Operations, Ahmed.'), findsOneWidget);
    expect(find.text("You're part of the team now."), findsOneWidget);
    // The three expectations — accountability · teamwork · clarity.
    expect(find.text('Own your shifts and tasks.'), findsOneWidget);
    expect(find.text('Back each other up.'), findsOneWidget);
    expect(find.text('One place for everything.'), findsOneWidget);
    // Phone hero is the animated light-sweep logo, not the Lottie.
    expect(find.byType(AnimatedDropLogo), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('falls back to a generic greeting when the name is missing', (
    tester,
  ) async {
    await pumpWelcome(tester);
    expect(find.text('Welcome to Drop Operations.'), findsOneWidget);
  });

  testWidgets('Get started dismisses onboarding via the cubit', (tester) async {
    final auth = await pumpWelcome(tester, name: 'Ahmed');

    expect(auth.completeOnboardingCalls, 0);
    await tester.tap(find.text('Get started'));
    await tester.pump();
    expect(auth.completeOnboardingCalls, 1);

    await tester.pump(const Duration(seconds: 1));
  });
}

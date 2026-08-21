import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/theme/app_theme.dart';
import 'package:opshub/core/widgets/premium_button.dart';
import 'package:opshub/features/admin/presentation/widgets/employee_card.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';

void main() {
  const activeUser = UserEntity(
    uid: 'employee-1',
    email: 'mohamed@drop.test',
    authProvider: 'password',
    displayName: 'Mohamed Khaled',
    role: UserRole.employee,
    branchId: 'arkan',
  );

  const inactiveUser = UserEntity(
    uid: 'employee-2',
    email: 'sara@drop.test',
    authProvider: 'password',
    displayName: 'Sara Ibrahim',
    role: UserRole.employee,
    isActive: false,
  );

  Widget host({
    required UserEntity user,
    required List<EmployeeOverflowAction> secondaryActions,
    String? branchLabel = 'Arkan',
    double width = 820,
  }) => MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: width,
          child: EmployeeCard(
            user: user,
            branchLabel: branchLabel,
            onTap: () {},
            actions: [
              PremiumButton(
                label: 'Details',
                icon: Icons.info_outline_rounded,
                onPressed: () {},
              ),
              PremiumButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                onPressed: () {},
              ),
              EmployeeOverflowMenu(
                employeeName: user.displayName!,
                actions: secondaryActions,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('shows name, branch, access state and the primary actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(user: activeUser, secondaryActions: const []),
    );

    expect(find.text('Mohamed Khaled'), findsOneWidget);
    expect(find.text('Arkan'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('leaves task performance to the Details inspector', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(user: activeUser, secondaryActions: const []),
    );

    expect(find.text('Completed'), findsNothing);
    expect(find.text('Pending'), findsNothing);
    expect(find.text('Rate'), findsNothing);
    expect(find.text('Late'), findsNothing);
  });

  testWidgets('names the gap when an employee has no branch', (tester) async {
    await tester.pumpWidget(
      host(user: inactiveUser, branchLabel: null, secondaryActions: const []),
    );

    expect(find.text('No branch'), findsOneWidget);
  });

  testWidgets('puts secondary actions behind the more menu', (tester) async {
    var branchChanged = false;
    await tester.pumpWidget(
      host(
        user: activeUser,
        secondaryActions: [
          EmployeeOverflowAction(
            label: 'Change Branch',
            icon: Icons.store_mall_directory_outlined,
            onSelected: () => branchChanged = true,
          ),
          const EmployeeOverflowAction(
            label: 'Position',
            icon: Icons.badge_outlined,
            onSelected: _noOp,
          ),
          const EmployeeOverflowAction(
            label: 'Reset Password',
            icon: Icons.lock_reset_rounded,
            onSelected: _noOp,
          ),
          const EmployeeOverflowAction(
            label: 'Deactivate',
            icon: Icons.block_rounded,
            destructive: true,
            onSelected: _noOp,
          ),
        ],
      ),
    );

    expect(find.text('Change Branch'), findsNothing);
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Change Branch'), findsOneWidget);
    expect(find.text('Position'), findsOneWidget);
    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.text('Deactivate'), findsOneWidget);

    await tester.tap(find.text('Change Branch'));
    await tester.pumpAndSettle();
    expect(branchChanged, isTrue);
  });

  testWidgets('preserves the inactive access action in the more menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        user: inactiveUser,
        secondaryActions: const [
          EmployeeOverflowAction(
            label: 'Activate',
            icon: Icons.check_circle_outline_rounded,
            onSelected: _noOp,
          ),
        ],
      ),
    );

    expect(find.text('Inactive'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Activate'), findsOneWidget);
  });

  testWidgets('drops the actions below identity at narrow card widths', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(user: activeUser, width: 280, secondaryActions: const []),
    );

    expect(find.text('Mohamed Khaled'), findsOneWidget);
    expect(find.text('Arkan'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noOp() {}

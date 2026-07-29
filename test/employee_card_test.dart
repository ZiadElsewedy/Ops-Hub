import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/core/widgets/premium_button.dart';
import 'package:drop/features/admin/presentation/employee_metrics.dart';
import 'package:drop/features/admin/presentation/widgets/employee_card.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';

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
    EmployeeMetrics metrics = const EmployeeMetrics(),
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
            branchLabel: 'Arkan',
            metrics: metrics,
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

  testWidgets('keeps identity, inline KPIs, and primary actions scannable', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        user: activeUser,
        metrics: const EmployeeMetrics(completed: 24, pending: 1),
        secondaryActions: const [],
      ),
    );

    expect(find.text('Mohamed Khaled'), findsOneWidget);
    expect(find.text('Employee · Arkan'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('96%'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Late'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
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

  testWidgets('wraps compact content at narrow card widths without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        user: activeUser,
        width: 280,
        metrics: const EmployeeMetrics(completed: 24, pending: 1, late: 2),
        secondaryActions: const [],
      ),
    );

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Late'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noOp() {}

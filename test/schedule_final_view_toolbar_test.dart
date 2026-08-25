import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/theme/app_theme.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/presentation/pages/schedule_final_view.dart';

/// The Final View is a **desktop PNG export preview** — a 1600px-wide landscape
/// print canvas — but it is reachable on a phone, where its toolbar used to lay
/// out three labelled buttons in 342pt of room and blow up with
/// "RIGHT OVERFLOWED BY 128 PIXELS" (reported on an iPhone, 2026-08-04).
///
/// This pins the fix at the width it actually broke on. It deliberately says
/// nothing about how the toolbar reads — only that a phone can open the screen
/// without a render overflow.
void main() {
  testWidgets('the toolbar does not overflow at iPhone width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final schedule = WeeklyScheduleEntity(
      id: 'arkan_week',
      branchId: 'arkan',
      weekStart: DateTime.now(),
      assignments: const {},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ScheduleFinalView(
          schedule: schedule,
          members: const [],
          branch: const BranchEntity(id: 'arkan', name: 'Arkan'),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/widgets/status_badge.dart';

void main() {
  test('missed parses as a closed, inactive task status', () {
    expect(TaskStatus.fromString('missed'), TaskStatus.missed);
    expect(TaskStatus.missed.value, 'missed');
    expect(TaskStatus.missed.isMissed, isTrue);
    expect(TaskStatus.missed.isTerminal, isTrue);
    expect(TaskStatus.missed.isActive, isFalse);
    expect(TaskStatus.missed.isReviewed, isFalse);
  });

  testWidgets('task status badge exposes Missed with the error semantic', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: StatusBadge.task(TaskStatus.missed))),
    );

    expect(find.text('Missed'), findsOneWidget);
    expect(taskStatusColor(TaskStatus.missed), AppColors.error);
  });
}

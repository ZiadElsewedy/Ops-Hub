import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/case_status.dart';
import 'package:opshub/features/cases/domain/entities/case_entity.dart';
import 'package:opshub/features/cases/presentation/widgets/case_list_tile.dart';

void main() {
  final caseItem = CaseEntity(
    id: 'c1',
    subject: 'Broken POS',
    status: CaseStatus.open,
    lastMessagePreview: 'The register froze',
    lastMessageAt: DateTime(2026, 7, 4, 10),
  );

  Widget host({required bool unread}) => MaterialApp(
        home: Scaffold(
          body: CaseListTile(
            caseItem: caseItem,
            unread: unread,
            onTap: () {},
          ),
        ),
      );

  FontWeight? subjectWeight(WidgetTester tester) =>
      tester.widget<Text>(find.text('Broken POS')).style?.fontWeight;

  testWidgets('unread emphasizes the subject (bold)', (tester) async {
    await tester.pumpWidget(host(unread: true));
    expect(subjectWeight(tester), FontWeight.w700);
  });

  testWidgets('read subject uses the normal weight', (tester) async {
    await tester.pumpWidget(host(unread: false));
    expect(subjectWeight(tester), FontWeight.w600);
  });
}

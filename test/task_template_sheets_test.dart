import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/task_type.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/features/task/domain/entities/checklist_item.dart';
import 'package:drop/features/task/domain/entities/task_template_entity.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/widgets/task_action_sheets.dart'
    show SheetHandle;
import 'package:drop/features/task/presentation/widgets/task_template_sheets.dart';

/// The 2026-08-01 fullscreen conversion of Templates (section A) + "more
/// detailed" fixes (section B). `_save`'s business logic must be
/// byte-for-byte unchanged from the sheet version — these tests exercise it
/// through the new fullscreen chrome to prove that.
class _SavedCall {
  _SavedCall({
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.branchId,
    required this.checklistItems,
  });
  final String title;
  final String? description;
  final TaskType type;
  final TaskPriority priority;
  final String? branchId;
  final List<ChecklistItemTemplate> checklistItems;
}

class _FakeTaskCubit extends Cubit<TaskState> implements TaskCubit {
  _FakeTaskCubit({List<TaskTemplateEntity> seedTemplates = const []})
    : _templates = seedTemplates,
      super(const TaskState.initial());

  final List<TaskTemplateEntity> _templates;
  final List<_SavedCall> savedCalls = [];

  @override
  Future<List<TaskTemplateEntity>> templates({String? branchId}) async =>
      _templates;

  @override
  Future<void> saveTemplate({
    required String title,
    String? description,
    required TaskType type,
    required TaskPriority priority,
    String? branchId,
    List<ChecklistItemTemplate> checklistItems = const [],
  }) async {
    savedCalls.add(
      _SavedCall(
        title: title,
        description: description,
        type: type,
        priority: priority,
        branchId: branchId,
        checklistItems: checklistItems,
      ),
    );
  }

  @override
  Future<void> deleteTemplate(String templateId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(_FakeTaskCubit cubit, {required bool isAdmin, required String defaultBranchId}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showManageTemplatesSheet(
              context: context,
              cubit: cubit,
              isAdmin: isAdmin,
              defaultBranchId: defaultBranchId,
            ),
            child: const Text('open templates'),
          ),
        ),
      ),
    ),
  );
}

/// Route pushes need a bare `pump()` to start the transition *before* the
/// clock advances, or the pushed screen is never found — then `pumpAndSettle`
/// to let the (finite) transition finish.
Future<void> _openManageTemplates(
  WidgetTester tester,
  _FakeTaskCubit cubit, {
  bool isAdmin = true,
  String defaultBranchId = 'branch1',
}) async {
  await tester.pumpWidget(
    _host(cubit, isAdmin: isAdmin, defaultBranchId: defaultBranchId),
  );
  await tester.tap(find.text('open templates'));
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _openAddTemplateForm(WidgetTester tester) async {
  await tester.tap(find.text('Add Template'));
  await tester.pump();
  await tester.pumpAndSettle();
}

/// The checklist step's raw `TextField` — targeted through the row's stable
/// key (`_StepTile`'s `ValueKey(row.id)`) rather than `find.byType(TextField)`
/// alone, because `TextFormField` (Title/Description) also builds an internal
/// `TextField` that a bare type-finder would match too.
Finder _stepField(String rowId) => find.descendant(
  of: find.byKey(ValueKey(rowId)),
  matching: find.byType(TextField),
);

void main() {
  group('fullscreen presentation — not a bottom sheet', () {
    testWidgets(
      'showManageTemplatesSheet pushes a fullscreen page, not a modal sheet',
      (tester) async {
        final cubit = _FakeTaskCubit();
        addTearDown(cubit.close);

        await _openManageTemplates(tester, cubit);

        expect(find.text('Checklist Templates'), findsOneWidget);
        expect(find.text('Add Template'), findsOneWidget);
        // Not the old showModalBottomSheet chrome.
        expect(find.byType(SheetHandle), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'Add Template opens the form fullscreen, not nested inside another sheet',
      (tester) async {
        final cubit = _FakeTaskCubit();
        addTearDown(cubit.close);

        await _openManageTemplates(tester, cubit);
        await _openAddTemplateForm(tester);

        expect(find.text('New Checklist Template'), findsOneWidget);
        expect(find.text('Save Template'), findsOneWidget);
        expect(find.byType(SheetHandle), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );
  });

  group('_save is behaviourally unchanged', () {
    testWidgets(
      'still enforces title-required and never calls saveTemplate',
      (tester) async {
        final cubit = _FakeTaskCubit();
        addTearDown(cubit.close);

        await _openManageTemplates(tester, cubit);
        await _openAddTemplateForm(tester);

        await tester.tap(find.text('Save Template'));
        await tester.pumpAndSettle();

        expect(find.text('Title is required.'), findsOneWidget);
        expect(cubit.savedCalls, isEmpty);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets('drops blank checklist rows, keeps only the filled one', (
      tester,
    ) async {
      final cubit = _FakeTaskCubit();
      addTearDown(cubit.close);

      await _openManageTemplates(tester, cubit);
      await _openAddTemplateForm(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Open Shop');
      // The form always seeds two rows 'c0'/'c1' fresh (idSeq starts at 0).
      await tester.enterText(_stepField('c0'), 'Unlock the front door');
      // 'c1' stays blank — must be dropped, not saved as an empty step.

      await tester.tap(find.text('Save Template'));
      await tester.pumpAndSettle();

      expect(cubit.savedCalls, hasLength(1));
      final saved = cubit.savedCalls.single;
      expect(saved.title, 'Open Shop');
      expect(saved.checklistItems, hasLength(1));
      expect(saved.checklistItems.single.title, 'Unlock the front door');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('sends "" as branchId for an admin (global template)', (
      tester,
    ) async {
      final cubit = _FakeTaskCubit();
      addTearDown(cubit.close);

      await _openManageTemplates(tester, cubit, isAdmin: true);
      await _openAddTemplateForm(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Open Shop');
      await tester.tap(find.text('Save Template'));
      await tester.pumpAndSettle();

      expect(cubit.savedCalls, hasLength(1));
      expect(cubit.savedCalls.single.branchId, '');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets(
      "sends the manager's own branch id (not global) for a manager",
      (tester) async {
        final cubit = _FakeTaskCubit();
        addTearDown(cubit.close);

        await _openManageTemplates(
          tester,
          cubit,
          isAdmin: false,
          defaultBranchId: 'branch-42',
        );
        await _openAddTemplateForm(tester);

        await tester.enterText(
          find.byType(TextFormField).first,
          'Night Checklist',
        );
        await tester.tap(find.text('Save Template'));
        await tester.pumpAndSettle();

        expect(cubit.savedCalls, hasLength(1));
        expect(cubit.savedCalls.single.branchId, 'branch-42');

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );
  });

  group('required/optional step toggle', () {
    testWidgets('a step is required by default and can be toggled optional', (
      tester,
    ) async {
      final cubit = _FakeTaskCubit();
      addTearDown(cubit.close);

      await _openManageTemplates(tester, cubit);
      await _openAddTemplateForm(tester);

      // isRequired defaults to true — now legible as a label, not a bare icon.
      expect(find.text('Required'), findsWidgets);

      await tester.enterText(find.byType(TextFormField).first, 'Open Shop');
      await tester.enterText(_stepField('c0'), 'Unlock the front door');
      // The step rows sit below the fold in the default test viewport, so the
      // tap would otherwise land on nothing (hit-test warning, no toggle).
      await tester.ensureVisible(find.text('Required').first);
      await tester.pump();
      await tester.tap(find.text('Required').first);
      await tester.pump();

      expect(find.text('Optional'), findsOneWidget);

      await tester.tap(find.text('Save Template'));
      await tester.pumpAndSettle();

      expect(cubit.savedCalls.single.checklistItems.single.isRequired, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}

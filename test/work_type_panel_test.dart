import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/task/domain/entities/checklist_item.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/work_types/definitions/inventory_count_work_type.dart';
import 'package:opshub/features/task/domain/work_types/definitions/purchase_errand_work_type.dart';
import 'package:opshub/features/task/domain/work_types/definitions/transfer_work_type.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/widgets/work_type_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Render-only — the cubit is touched lazily on tap, so a [Fake] suffices.
class _FakeTaskCubit extends Fake implements TaskCubit {}

Widget _host({
  required TaskEntity task,
  bool interactive = false,
  bool showReviewHint = false,
}) =>
    MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 520,
            child: WorkTypePanel(
              task: task,
              cubit: _FakeTaskCubit(),
              interactive: interactive,
              showReviewHint: showReviewHint,
            ),
          ),
        ),
      ),
    );

void main() {
  test('hasContentFor is false for a general task', () {
    expect(
      WorkTypePanel.hasContentFor(const TaskEntity(id: 't', title: 'x')),
      isFalse,
    );
    expect(
      WorkTypePanel.hasContentFor(
          const TaskEntity(id: 't', title: 'x', workType: 'transfer')),
      isTrue,
    );
  });

  testWidgets('purchase: budget card shows budget/spent/remaining + progress',
      (tester) async {
    final task = TaskEntity(
      id: 'p1',
      title: 'Buy supplies',
      workType: 'purchaseErrand',
      status: TaskStatus.waitingReview,
      data: const {
        PurchaseErrandWorkType.kItem: 'Pens and paper',
        PurchaseErrandWorkType.kBudget: 100,
        PurchaseErrandWorkType.kSpent: 40,
      },
    );
    await tester.pumpWidget(_host(task: task));
    await tester.pumpAndSettle();

    // The signature budget card and its three metrics.
    expect(find.text('BUDGET'), findsOneWidget);
    expect(find.text('SPENT'), findsOneWidget);
    expect(find.text('REMAINING'), findsOneWidget);
    // 100 − 40 = 60 remaining; within budget.
    expect(find.text('60'), findsOneWidget);
    expect(find.text('Within budget'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget); // spent of budget
    // The item is presented as content, not a table row.
    expect(find.text('Pens and paper'), findsOneWidget);
  });

  testWidgets('purchase: over-budget spend reads as attention', (tester) async {
    final task = TaskEntity(
      id: 'p2',
      title: 'Buy supplies',
      workType: 'purchaseErrand',
      status: TaskStatus.waitingReview,
      data: const {
        PurchaseErrandWorkType.kBudget: 100,
        PurchaseErrandWorkType.kSpent: 130,
      },
    );
    await tester.pumpWidget(_host(task: task));
    await tester.pumpAndSettle();

    expect(find.text('Over budget'), findsOneWidget);
    // Remaining goes negative, rendered with a real minus sign.
    expect(find.text('−30'), findsOneWidget);
  });

  testWidgets('inspection: score card + segment summary + markable points',
      (tester) async {
    final task = TaskEntity(
      id: 'i1',
      title: 'Morning inspection',
      workType: 'inspection',
      status: TaskStatus.started,
      checklist: const [
        ChecklistItem(id: 'p1', title: 'Floor clean'),
        ChecklistItem(id: 'p2', title: 'Fridge temp'),
      ],
      data: const {
        'results': {'p1': 'pass', 'p2': 'fail'},
      },
    );
    await tester.pumpWidget(_host(task: task, interactive: true));

    // Hero summary line (from the definition).
    expect(find.text('1 pass · 0 warning · 1 fail'), findsOneWidget);
    // Score card.
    expect(find.text('INSPECTION SCORE'), findsOneWidget);
    expect(find.text('of 2 points passed'), findsOneWidget);
    // Points card + each point with its pass/warn/fail chips.
    expect(find.text('INSPECTION POINTS'), findsOneWidget);
    expect(find.text('Floor clean'), findsOneWidget);
    expect(find.text('Fridge temp'), findsOneWidget);
    expect(find.text('Pass'), findsNWidgets(2));
    expect(find.text('Fail'), findsNWidgets(2));
  });

  testWidgets('transfer: route card + timeline + next-step log button',
      (tester) async {
    final task = TaskEntity(
      id: 'tr1',
      title: 'Move stock',
      workType: 'transfer',
      status: TaskStatus.started,
      data: const {
        TransferWorkType.kGoods: 'Jackets',
        TransferWorkType.kDestination: 'Downtown',
      },
    );
    await tester.pumpWidget(_host(task: task, interactive: true));

    expect(find.text('Jackets → Downtown'), findsOneWidget); // summary
    expect(find.text('TRANSFER'), findsOneWidget);
    expect(find.text('Jackets'), findsOneWidget); // goods headline
    expect(find.text('TIMELINE'), findsOneWidget);
    expect(find.text('Dispatched'), findsOneWidget);
    expect(find.text('Received'), findsOneWidget);
    // The next pending milestone (only) offers a log action.
    expect(find.text('Log'), findsOneWidget);
  });

  testWidgets('manager view of a reconciled count shows the fast-path hint',
      (tester) async {
    final task = TaskEntity(
      id: 'inv1',
      title: 'Count stock',
      workType: 'inventoryCount',
      status: TaskStatus.waitingReview,
      data: const {
        InventoryCountWorkType.kArea: 'Stockroom',
        InventoryCountWorkType.kExpectedQty: 20,
        InventoryCountWorkType.kCountedQty: 20,
      },
    );
    await tester.pumpWidget(_host(task: task, showReviewHint: true));

    // Manager fast-path hint on a reconciled count.
    expect(find.text('Auto-approvable'), findsOneWidget);
    // The count card and its metrics (read-only for a viewer).
    expect(find.text('STOCK COUNT'), findsOneWidget);
    expect(find.text('EXPECTED'), findsOneWidget);
    expect(find.text('DIFFERENCE'), findsOneWidget);
    expect(find.text('Reconciled'), findsOneWidget);
  });
}

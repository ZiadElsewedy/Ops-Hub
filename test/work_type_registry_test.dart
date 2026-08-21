import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/task/domain/work_types/definitions/general_work_type.dart';
import 'package:opshub/features/task/domain/work_types/definitions/inspection_work_type.dart';
import 'package:opshub/features/task/domain/work_types/definitions/inventory_count_work_type.dart';
import 'package:opshub/features/task/domain/work_types/definitions/purchase_errand_work_type.dart';
import 'package:opshub/features/task/domain/work_types/definitions/transfer_work_type.dart';
import 'package:opshub/features/task/domain/work_types/work_context.dart';
import 'package:opshub/features/task/domain/work_types/work_draft.dart';
import 'package:opshub/features/task/domain/work_types/work_review.dart';
import 'package:opshub/features/task/domain/work_types/work_type_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final registry = WorkTypeRegistry.instance;

  group('WorkTypeRegistry resolution', () {
    test('resolves each shipped id to its definition', () {
      expect(registry.byId('general'), isA<GeneralWorkType>());
      expect(registry.byId('transfer'), isA<TransferWorkType>());
      expect(registry.byId('purchaseErrand'), isA<PurchaseErrandWorkType>());
      expect(registry.byId('inventoryCount'), isA<InventoryCountWorkType>());
      expect(registry.byId('inspection'), isA<InspectionWorkType>());
    });

    test('unknown / legacy / null id falls back to general (no crash, no migration)', () {
      expect(registry.byId('someTypeShippedInV9'), isA<GeneralWorkType>());
      expect(registry.byId(null), isA<GeneralWorkType>());
      expect(registry.isKnown('nope'), isFalse);
    });

    test('ids are unique and general is present (registry asserts hold)', () {
      final ids = registry.all.map((d) => d.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids, contains('general'));
    });
  });

  // The OCP guarantee: every type drives its own behaviour with no caller
  // branching on the type — a screen only ever asks the definition.
  group('General (baseline parity)', () {
    const t = GeneralWorkType();
    test('always standard review, no proof, checklist progress', () {
      expect(t.reviewDisposition(const WorkContext()), ReviewDisposition.standard);
      expect(t.requiresProof(const WorkContext()), isFalse);
      expect(t.progress(_ctx(checklistTotal: 4, checklistDone: 1)), 0.25);
    });
    test('no extra fields, no milestones', () {
      expect(t.fields, isEmpty);
      expect(t.timeline, isEmpty);
    });
  });

  group('Transfer (custom timeline + peer confirmation)', () {
    const t = TransferWorkType();

    test('two-milestone handshake drives progress', () {
      expect(t.timeline.map((e) => e.id),
          [TransferWorkType.eventDispatched, TransferWorkType.eventReceived]);
      expect(t.progress(_ctx()), 0.0);
      expect(t.progress(_ctx(events: {TransferWorkType.eventDispatched})), 0.5);
      expect(
        t.progress(_ctx(events: {
          TransferWorkType.eventDispatched,
          TransferWorkType.eventReceived,
        })),
        1.0,
      );
    });

    test('dispatch requires a handover photo', () {
      expect(t.validateSubmission(_ctx()).ok, isFalse);
      expect(t.validateSubmission(_ctx(proofCount: 1)).ok, isTrue);
    });

    test('review fast-tracks only after the receiver confirms', () {
      expect(t.reviewDisposition(_ctx(proofCount: 1)), ReviewDisposition.standard);
      expect(
        t.reviewDisposition(_ctx(events: {TransferWorkType.eventReceived})),
        ReviewDisposition.fastTrack,
      );
    });

    test('summary reads goods → destination', () {
      expect(
        t.summarize(_ctx(data: {
          TransferWorkType.kGoods: 'Winter jackets',
          TransferWorkType.kDestination: 'Downtown',
        })),
        'Winter jackets → Downtown',
      );
    });
  });

  group('Purchase / Errand (budget check drives review)', () {
    const t = PurchaseErrandWorkType();

    test('submission needs amount spent + receipt', () {
      expect(t.validateSubmission(_ctx()).ok, isFalse); // no spend
      expect(
        t.validateSubmission(_ctx(data: {PurchaseErrandWorkType.kSpent: 40})).ok,
        isFalse, // no receipt
      );
      expect(
        t
            .validateSubmission(_ctx(
                data: {PurchaseErrandWorkType.kSpent: 40}, proofCount: 1))
            .ok,
        isTrue,
      );
    });

    test('within budget fast-tracks; over budget stays standard', () {
      final within = _ctx(data: {
        PurchaseErrandWorkType.kBudget: 100,
        PurchaseErrandWorkType.kSpent: 90,
      });
      final over = _ctx(data: {
        PurchaseErrandWorkType.kBudget: 100,
        PurchaseErrandWorkType.kSpent: 130,
      });
      expect(t.reviewDisposition(within), ReviewDisposition.fastTrack);
      expect(t.reviewDisposition(over), ReviewDisposition.standard);
      expect(t.overBudget(over), isTrue);
    });

    test('a reimbursement request keeps it standard even within budget', () {
      final reimb = _ctx(data: {
        PurchaseErrandWorkType.kBudget: 100,
        PurchaseErrandWorkType.kSpent: 90,
        PurchaseErrandWorkType.kReimbursement: true,
      });
      expect(t.reviewDisposition(reimb), ReviewDisposition.standard);
    });

    test('analytics report spend + budget breach', () {
      final over = _ctx(data: {
        PurchaseErrandWorkType.kBudget: 100,
        PurchaseErrandWorkType.kSpent: 130,
      });
      expect(t.analytics(over)['overBudget'], 'true');
      expect(t.analytics(over)['spent'], '130');
    });
  });

  group('Inventory Count (variance + discrepancy gate)', () {
    const t = InventoryCountWorkType();

    test('variance computes counted − expected', () {
      expect(t.variance(_ctx(data: {
        InventoryCountWorkType.kExpectedQty: 20,
        InventoryCountWorkType.kCountedQty: 17,
      })), -3);
    });

    test('a mismatch must be explained before submitting', () {
      final mismatch = _ctx(data: {
        InventoryCountWorkType.kExpectedQty: 20,
        InventoryCountWorkType.kCountedQty: 17,
      });
      final r = t.validateSubmission(mismatch);
      expect(r.ok, isFalse);
      expect(r.fieldErrors.containsKey(InventoryCountWorkType.kDiscrepancyReason), isTrue);

      final explained = _ctx(data: {
        InventoryCountWorkType.kExpectedQty: 20,
        InventoryCountWorkType.kCountedQty: 17,
        InventoryCountWorkType.kDiscrepancyReason: 'Damaged units pulled',
      });
      expect(t.validateSubmission(explained).ok, isTrue);
    });

    test('reconciled fast-tracks; variance stays standard', () {
      expect(
        t.reviewDisposition(_ctx(data: {
          InventoryCountWorkType.kExpectedQty: 20,
          InventoryCountWorkType.kCountedQty: 20,
        })),
        ReviewDisposition.fastTrack,
      );
      expect(
        t.reviewDisposition(_ctx(data: {
          InventoryCountWorkType.kExpectedQty: 20,
          InventoryCountWorkType.kCountedQty: 17,
        })),
        ReviewDisposition.standard,
      );
    });

    test('declares no timeline (coarse-lifecycle only)', () {
      expect(t.timeline, isEmpty);
    });
  });

  group('Inspection (structured pass/warning/fail over the checklist)', () {
    const t = InspectionWorkType();
    final points = ['p1', 'p2', 'p3'];

    test('setup requires at least one point', () {
      expect(t.validateSetup(const WorkDraft()).ok, isFalse);
      expect(t.validateSetup(const WorkDraft(checklistCount: 2)).ok, isTrue);
    });

    test('progress = fraction of points marked', () {
      expect(t.progress(_ctx(checklistItemIds: points)), 0.0);
      expect(
        t.progress(_ctx(checklistItemIds: points, data: {
          InspectionWorkType.kResults: {'p1': 'pass'},
        })),
        closeTo(1 / 3, 1e-9),
      );
    });

    test('submission blocked until every point is marked', () {
      final partial = _ctx(checklistItemIds: points, data: {
        InspectionWorkType.kResults: {'p1': 'pass', 'p2': 'warning'},
      });
      expect(t.validateSubmission(partial).ok, isFalse);

      final full = _ctx(checklistItemIds: points, data: {
        InspectionWorkType.kResults: {'p1': 'pass', 'p2': 'warning', 'p3': 'pass'},
      });
      expect(t.validateSubmission(full).ok, isTrue);
    });

    test('any fail demands review; all pass/warning fast-tracks', () {
      final clean = _ctx(checklistItemIds: points, data: {
        InspectionWorkType.kResults: {'p1': 'pass', 'p2': 'warning', 'p3': 'pass'},
      });
      final failed = _ctx(checklistItemIds: points, data: {
        InspectionWorkType.kResults: {'p1': 'pass', 'p2': 'fail', 'p3': 'pass'},
      });
      expect(t.reviewDisposition(clean), ReviewDisposition.fastTrack);
      expect(t.reviewDisposition(failed), ReviewDisposition.standard);
    });

    test('summary + analytics report the result mix', () {
      final ctx = _ctx(checklistItemIds: points, data: {
        InspectionWorkType.kResults: {'p1': 'pass', 'p2': 'warning', 'p3': 'fail'},
      });
      expect(t.summarize(ctx), '1 pass · 1 warning · 1 fail');
      expect(t.analytics(ctx), {'pass': '1', 'warning': '1', 'fail': '1'});
    });
  });
}

WorkContext _ctx({
  Map<String, dynamic> data = const {},
  int checklistTotal = 0,
  int checklistDone = 0,
  int checklistRequired = 0,
  int checklistRequiredDone = 0,
  List<String> checklistItemIds = const [],
  Set<String> events = const {},
  int proofCount = 0,
  TaskStatus status = TaskStatus.started,
}) =>
    WorkContext(
      data: data,
      status: status,
      checklistTotal: checklistTotal,
      checklistDone: checklistDone,
      checklistRequired: checklistRequired,
      checklistRequiredDone: checklistRequiredDone,
      checklistItemIds: checklistItemIds,
      loggedEvents: events,
      proofCount: proofCount,
    );

import 'package:opshub/features/task/domain/work_types/definitions/general_work_type.dart';
import 'package:opshub/features/task/domain/work_types/definitions/inventory_count_work_type.dart';
import 'package:opshub/features/task/domain/work_types/definitions/transfer_work_type.dart';
import 'package:opshub/features/task/presentation/widgets/dynamic_work_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('DynamicWorkForm', () {
    testWidgets('renders only SETUP fields by default (completion excluded)',
        (tester) async {
      await tester.pumpWidget(_host(DynamicWorkForm(
        definition: const InventoryCountWorkType(),
        onChanged: (_) {},
      )));

      expect(find.text('Area / section'), findsOneWidget);
      expect(find.text('System quantity'), findsOneWidget);
      // Employee-captured completion fields do NOT appear on the create form.
      expect(find.text('Counted quantity (optional)'), findsNothing);
      expect(find.text('Discrepancy note (optional)'), findsNothing);
    });

    testWidgets('renders completion fields when explicitly asked',
        (tester) async {
      const def = InventoryCountWorkType();
      await tester.pumpWidget(_host(DynamicWorkForm(
        definition: def,
        fields: def.completionFields,
        onChanged: (_) {},
      )));
      expect(find.text('Counted quantity (optional)'), findsOneWidget);
      expect(find.text('Area / section'), findsNothing);
    });

    testWidgets('a general task renders no dynamic fields', (tester) async {
      await tester.pumpWidget(_host(DynamicWorkForm(
        definition: const GeneralWorkType(),
        onChanged: (_) {},
      )));
      // No dynamic field labels, collapses to nothing.
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('switching the type swaps the field set', (tester) async {
      await tester.pumpWidget(_host(DynamicWorkForm(
        definition: const InventoryCountWorkType(),
        onChanged: (_) {},
      )));
      expect(find.text('Area / section'), findsOneWidget);

      // Re-pump with a different type (as the picker would drive).
      await tester.pumpWidget(_host(DynamicWorkForm(
        definition: const TransferWorkType(),
        onChanged: (_) {},
      )));
      await tester.pump();
      expect(find.text('Area / section'), findsNothing);
      expect(find.text('Goods'), findsOneWidget);
      expect(find.text('To (person / branch)'), findsOneWidget);
    });

    testWidgets('reports typed values up through onChanged', (tester) async {
      Map<String, dynamic> latest = const {};
      await tester.pumpWidget(_host(DynamicWorkForm(
        definition: const InventoryCountWorkType(),
        onChanged: (d) => latest = d,
      )));

      // First field is the free-text area.
      await tester.enterText(find.byType(TextFormField).first, 'Stockroom');
      expect(latest[InventoryCountWorkType.kArea], 'Stockroom');

      // The system-quantity integer field is the second.
      await tester.enterText(find.byType(TextFormField).at(1), '20');
      expect(latest[InventoryCountWorkType.kExpectedQty], 20);
      expect(latest[InventoryCountWorkType.kExpectedQty], isA<int>());
    });

    testWidgets('shows inline error for a field', (tester) async {
      await tester.pumpWidget(_host(DynamicWorkForm(
        definition: const InventoryCountWorkType(),
        onChanged: (_) {},
        errors: const {InventoryCountWorkType.kExpectedQty: 'System quantity is required.'},
      )));
      expect(find.text('System quantity is required.'), findsOneWidget);
    });
  });

  group('WorkTypePicker', () {
    testWidgets('renders every type inline and reports a selection',
        (tester) async {
      String? picked;
      await tester.pumpWidget(_host(WorkTypePicker(
        value: 'general',
        onChanged: (id) => picked = id,
      )));

      // Small catalogue (≤ threshold) → every type is shown inline as a
      // selectable card, with no "page → bottom sheet" step.
      expect(find.text('General Task'), findsOneWidget);
      expect(find.text('Transfer / Handover'), findsOneWidget);
      expect(find.text('Inventory Count'), findsOneWidget);

      // Tapping a type reports it immediately (no chooser step).
      await tester.tap(find.text('Inventory Count'));
      await tester.pump();
      expect(picked, 'inventoryCount');
    });

    testWidgets('locked (edit mode) shows only the current type, no chooser',
        (tester) async {
      await tester.pumpWidget(_host(WorkTypePicker(
        value: 'transfer',
        enabled: false,
        onChanged: (_) {},
      )));
      expect(find.text('Transfer / Handover'), findsOneWidget);
      expect(find.text('Inventory Count'), findsNothing);

      // The card is inert when locked — tapping opens nothing.
      await tester.tap(find.text('Transfer / Handover'));
      await tester.pumpAndSettle();
      expect(find.text('Inventory Count'), findsNothing);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:opshub/features/task/domain/work_types/work_field_spec.dart';

/// Presentation-side mapping for work types + their fields — the seam that keeps
/// the domain Flutter-free (mirrors `request_format.dart`). Icons are keyed by
/// the work-type / field-kind id and **fall back to a neutral default**, so a
/// newly-registered type renders correctly (with a generic icon) even before
/// anyone adds a bespoke one here. That fallback is deliberate: it preserves the
/// "adding a type = 1 file + 1 line" promise — the presentation layer never
/// *forces* an edit, it only lets you opt into a nicer icon.
class WorkTypePresenter {
  const WorkTypePresenter._();

  static const IconData _fallbackType = Icons.task_alt_rounded;

  static const Map<String, IconData> _typeIcons = {
    'general': Icons.check_circle_outline_rounded,
    'transfer': Icons.swap_horiz_rounded,
    'purchaseErrand': Icons.shopping_bag_outlined,
    'inventoryCount': Icons.inventory_2_outlined,
    'inspection': Icons.fact_check_outlined,
  };

  static IconData iconFor(String workTypeId) =>
      _typeIcons[workTypeId] ?? _fallbackType;

  static IconData iconForField(WorkFieldKind kind) => switch (kind) {
        WorkFieldKind.text => Icons.short_text_rounded,
        WorkFieldKind.multiline => Icons.notes_rounded,
        WorkFieldKind.number => Icons.tag_rounded,
        WorkFieldKind.integer => Icons.pin_outlined,
        WorkFieldKind.currency => Icons.payments_outlined,
        WorkFieldKind.date => Icons.event_outlined,
        WorkFieldKind.time => Icons.schedule_outlined,
        WorkFieldKind.toggle => Icons.toggle_on_outlined,
        WorkFieldKind.select => Icons.checklist_rtl_rounded,
      };
}

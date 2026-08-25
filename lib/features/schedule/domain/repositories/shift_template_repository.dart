import 'package:opshub/features/schedule/domain/shift_template.dart';

/// Branch-scoped shift-template store (Schedule V2 · Pillar 5), collection
/// `shift_templates/{id}`. Manager + admin own their branch's templates
/// (enforced in `firestore.rules`, mirroring `weekly_schedules`).
abstract class ShiftTemplateRepository {
  /// Realtime template library for [branchId].
  Stream<List<ShiftTemplate>> watchTemplates(String branchId);

  /// One-shot read of [branchId]'s templates.
  Future<List<ShiftTemplate>> getTemplates(String branchId);

  /// The branch's current [ShiftTemplateSet] — a convenience read for building
  /// the [ShiftPlan] snapshot at week creation.
  Future<ShiftTemplateSet> getSet(String branchId);

  /// Creates or updates a template (id-addressed).
  Future<void> upsertTemplate(ShiftTemplate template);

  Future<void> deleteTemplate(String id);

  /// Seeds the three standing templates (Morning / Weekday night / Weekend
  /// night, matching the standard hours) **only if the branch has none** — a
  /// no-op otherwise. Returns the resulting set.
  Future<ShiftTemplateSet> ensureDefaults(String branchId);
}

import 'package:opshub/features/schedule/domain/repositories/shift_template_repository.dart';
import 'package:opshub/features/schedule/domain/shift_template.dart';

/// A no-op [ShiftTemplateRepository] for schedule-cubit tests — the branch has
/// no templates, so schedules snapshot nothing (the legacy standard-hours path).
class FakeShiftTemplateRepository implements ShiftTemplateRepository {
  @override
  Future<ShiftTemplateSet> getSet(String branchId) async =>
      const ShiftTemplateSet([]);
  @override
  Future<ShiftTemplateSet> ensureDefaults(String branchId) async =>
      const ShiftTemplateSet([]);
  @override
  Stream<List<ShiftTemplate>> watchTemplates(String branchId) =>
      const Stream.empty();
  @override
  Future<List<ShiftTemplate>> getTemplates(String branchId) async => const [];
  @override
  Future<void> upsertTemplate(ShiftTemplate template) async {}
  @override
  Future<void> deleteTemplate(String id) async {}
}

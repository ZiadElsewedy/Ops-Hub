import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/features/schedule/domain/repositories/shift_template_repository.dart';
import 'package:opshub/features/schedule/domain/shift_template.dart';
import 'shift_template_state.dart';

/// Drives the shift-template manager (Schedule V2 · Pillar 5) — a realtime view
/// of a branch's template library. Hours edits with a *"this week / future /
/// global"* scope flow through `ScheduleCubit.applyShiftHours` (which owns the
/// schedule side); this cubit owns the library itself: seed-if-empty, watch, and
/// validated rename / save.
class ShiftTemplateCubit extends Cubit<ShiftTemplateState> {
  final ShiftTemplateRepository _repository;

  ShiftTemplateCubit(this._repository)
      : super(const ShiftTemplateState.initial());

  StreamSubscription<List<ShiftTemplate>>? _sub;

  ShiftTemplateSet? get _current =>
      state.maybeWhen(loaded: (set, _) => set, orElse: () => null);

  Future<void> load(String branchId) async {
    if (branchId.isEmpty) return;
    emit(const ShiftTemplateState.loading());
    // Seed the three standing templates if the branch has none — best-effort, so
    // a blocked write still lets the (empty) stream render.
    try {
      await _repository.ensureDefaults(branchId);
    } catch (_) {}
    await _sub?.cancel();
    _sub = _repository.watchTemplates(branchId).listen(
      (templates) =>
          emit(ShiftTemplateState.loaded(ShiftTemplateSet(templates))),
      onError: (Object e) {
        if (_current == null) {
          emit(ShiftTemplateState.error(
              e is Failure ? e.message : 'Failed to load shift templates.'));
        }
      },
    );
  }

  /// Validates then persists a template edit (rename / hours). Returns the
  /// validation error, or null when accepted (the realtime stream reflects the
  /// change). A server failure surfaces as an error state, not a return value.
  Future<ShiftTemplateError?> save(ShiftTemplate template) async {
    final set = _current ?? const ShiftTemplateSet([]);
    final invalid = set.validate(template.name, excludingId: template.id);
    if (invalid != null) return invalid;
    emit(ShiftTemplateState.loaded(set, busy: true));
    try {
      await _repository.upsertTemplate(template);
    } on Failure catch (e) {
      emit(ShiftTemplateState.error(e.message));
      emit(ShiftTemplateState.loaded(set));
    }
    return null;
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}

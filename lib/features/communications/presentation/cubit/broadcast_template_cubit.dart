import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/features/communications/domain/entities/broadcast_template_entity.dart';
import 'package:opshub/features/communications/domain/repositories/broadcast_template_repository.dart';
import 'broadcast_template_state.dart';

/// Broadcast templates (Communications Center — Phase 2). Repo-direct (no
/// use-case layer), mirroring `BranchCubit`: keeps the list visible during
/// mutations and restores it on error.
class BroadcastTemplateCubit extends Cubit<BroadcastTemplateState> {
  final BroadcastTemplateRepository _repository;

  BroadcastTemplateCubit(this._repository)
      : super(const BroadcastTemplateState.initial());

  List<BroadcastTemplateEntity> get _templates =>
      state.maybeWhen(loaded: (t, _) => t, orElse: () => const []);

  bool get _busy => state.maybeWhen(
        loaded: (_, busy) => busy,
        loading: () => true,
        orElse: () => false,
      );

  Future<void> load() async {
    emit(const BroadcastTemplateState.loading());
    try {
      emit(BroadcastTemplateState.loaded(await _repository.getTemplates()));
    } on Failure catch (e) {
      emit(BroadcastTemplateState.error(e.message));
    } catch (_) {
      emit(const BroadcastTemplateState.error('Failed to load templates.'));
    }
  }

  Future<void> saveTemplate(BroadcastTemplateEntity template) =>
      _mutate(() => _repository.create(template));

  Future<void> updateTemplate(BroadcastTemplateEntity template) =>
      _mutate(() => _repository.update(template));

  Future<void> toggleFavorite(BroadcastTemplateEntity template) =>
      _mutate(() => _repository.setFavorite(template.id, !template.isFavorite));

  Future<void> deleteTemplate(String id) =>
      _mutate(() => _repository.delete(id));

  /// Records a use (best-effort; never disrupts the list/send flow).
  Future<void> markUsed(String id) async {
    try {
      await _repository.incrementUsage(id);
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy) return;
    final prev = _templates;
    emit(BroadcastTemplateState.loaded(prev, busy: true));
    try {
      await action();
      emit(BroadcastTemplateState.loaded(await _repository.getTemplates()));
    } on Failure catch (e) {
      emit(BroadcastTemplateState.error(e.message));
      emit(BroadcastTemplateState.loaded(prev));
    } catch (_) {
      emit(const BroadcastTemplateState.error(
          'Something went wrong. Please try again.'));
      emit(BroadcastTemplateState.loaded(prev));
    }
  }
}

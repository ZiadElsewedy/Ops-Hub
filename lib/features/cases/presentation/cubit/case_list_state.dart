import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/cases/domain/entities/case_entity.dart';

part 'case_list_state.freezed.dart';

@freezed
class CaseListState with _$CaseListState {
  const factory CaseListState.initial() = _Initial;

  /// First load (full-screen spinner).
  const factory CaseListState.loading() = _Loading;

  /// Cases loaded. [busy] marks an in-flight mutation (open / delete) while the
  /// list stays visible. [directory] resolves uids → users for name display; it
  /// fills in asynchronously after the cases arrive. [selectedId] is the case
  /// open in the desktop split-pane's right side (null on mobile / none picked).
  const factory CaseListState.loaded(
    List<CaseEntity> cases, {
    @Default(false) bool busy,
    @Default(<String, UserEntity>{}) Map<String, UserEntity> directory,
    String? selectedId,
    /// Ids of cases with activity newer than the last time the viewer opened
    /// them — drives the inbox "unread" treatment (see `CaseSeenStore`). Held in
    /// state so opening a case (which advances seen-state) reactively clears it.
    @Default(<String>{}) Set<String> unreadIds,
  }) = _Loaded;

  /// Transient — surfaced as a snackbar; the cubit immediately re-emits the
  /// last-known [loaded] list so the UI never loses its data.
  const factory CaseListState.error(String message) = _Error;
}

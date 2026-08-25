import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/requests/domain/entities/request_entity.dart';

part 'requests_list_state.freezed.dart';

@freezed
class RequestsListState with _$RequestsListState {
  const factory RequestsListState.initial() = _Initial;

  /// First load (full-screen skeleton).
  const factory RequestsListState.loading() = _Loading;

  /// Requests loaded (already inbox-ordered + soft-delete-filtered by the
  /// repository). [branchNames] resolves branchId → name for the cards (fills
  /// in async).
  const factory RequestsListState.loaded(
    List<RequestEntity> requests, {
    @Default(<String, String>{}) Map<String, String> branchNames,
  }) = _Loaded;

  /// Transient — surfaced as a snackbar; the cubit immediately re-emits the
  /// last-known [loaded] list so the UI never loses its data.
  const factory RequestsListState.error(String message) = _Error;
}

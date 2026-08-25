import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/requests/domain/entities/request_entity.dart';
import 'package:opshub/features/requests/domain/entities/request_event.dart';

part 'request_detail_state.freezed.dart';

@freezed
class RequestDetailState with _$RequestDetailState {
  /// Waiting for the first request-doc snapshot.
  const factory RequestDetailState.loading() = _Loading;

  /// The request + its timeline events. [busy] marks an in-flight decision /
  /// comment while the detail stays on screen.
  const factory RequestDetailState.loaded(
    RequestEntity request,
    List<RequestEvent> events, {
    @Default(false) bool busy,
  }) = _Loaded;

  /// The request doc doesn't exist / isn't readable (deleted, or a bad deep-link).
  const factory RequestDetailState.unavailable() = _Unavailable;

  /// Transient — surfaced as a snackbar; the cubit immediately re-emits the
  /// last-known [loaded] state so the UI never loses the timeline.
  const factory RequestDetailState.error(String message) = _Error;
}

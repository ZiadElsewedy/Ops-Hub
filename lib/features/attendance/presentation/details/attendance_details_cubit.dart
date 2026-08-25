import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/utils/app_logger.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_correction.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_event.dart';
import 'package:opshub/features/attendance/domain/repositories/attendance_repository.dart';
import 'attendance_details_state.dart';

/// Drives one attendance record's Details screen by merging three realtime
/// streams — the record itself ([AttendanceRepository.watchRecord]), its
/// server-derived audit trail ([AttendanceRepository.watchEvents] → the timeline)
/// and any corrections filed against it
/// ([AttendanceRepository.watchRecordCorrections]).
///
/// When the caller hands over the record it was tapped from ([seed]), the cubit
/// paints [loaded] immediately, then lets the streams refresh in place. Access is
/// enforced by `firestore.rules`; a denied read surfaces as [error].
class AttendanceDetailsCubit extends Cubit<AttendanceDetailsState> {
  final AttendanceRepository _repository;
  final String recordId;

  AttendanceEntity? _record;
  List<AttendanceEvent> _events = const [];
  List<AttendanceCorrectionEntity> _corrections = const [];

  StreamSubscription<AttendanceEntity?>? _recordSub;
  StreamSubscription<List<AttendanceEvent>>? _eventsSub;
  StreamSubscription<List<AttendanceCorrectionEntity>>? _correctionsSub;

  AttendanceDetailsCubit({
    required AttendanceRepository repository,
    required this.recordId,
    AttendanceEntity? seed,
  })  : _repository = repository,
        _record = seed,
        super(seed == null
            ? const AttendanceDetailsState.loading()
            : AttendanceDetailsState.loaded(record: seed));
  // The repository is assigned explicitly (a `repository:` named arg reads
  // better at the call site than a `_`-prefixed initializing formal).
  // ignore_for_file: prefer_initializing_formals

  void load() {
    _recordSub?.cancel();
    _recordSub = _repository.watchRecord(recordId).listen(
      (record) {
        if (record != null) {
          _record = record;
          _emit();
        } else if (_record == null) {
          // No seed and the doc is absent/soft-deleted → nothing to show.
          if (!isClosed) {
            emit(const AttendanceDetailsState.error(
                'This attendance record is no longer available.'));
          }
        }
        // record == null but we have a seed → keep the seed on screen.
      },
      onError: (Object e, StackTrace st) {
        AppLog.error('attendance', 'details record stream error', e, st);
        if (_record == null && !isClosed) {
          emit(const AttendanceDetailsState.error(
              'Couldn\'t open this attendance record.'));
        }
      },
    );

    // The timeline + corrections are supplementary — a failure there must not
    // blank out the record, so their errors are logged and swallowed.
    _eventsSub = _repository.watchEvents(recordId).listen(
      (events) {
        _events = events;
        _emit();
      },
      onError: (Object e, StackTrace st) =>
          AppLog.error('attendance', 'details events stream error', e, st),
    );

    _correctionsSub = _repository.watchRecordCorrections(recordId).listen(
      (corrections) {
        _corrections = corrections;
        _emit();
      },
      onError: (Object e, StackTrace st) =>
          AppLog.error('attendance', 'details corrections stream error', e, st),
    );
  }

  void _emit() {
    if (isClosed) return;
    final record = _record;
    if (record == null) return;
    emit(AttendanceDetailsState.loaded(
      record: record,
      events: _events,
      corrections: _corrections,
    ));
  }

  @override
  Future<void> close() {
    _recordSub?.cancel();
    _eventsSub?.cancel();
    _correctionsSub?.cancel();
    return super.close();
  }
}

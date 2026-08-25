import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attendance_correction_kind.dart';
import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/core/network/network_guard.dart';
import 'package:opshub/features/attendance/data/datasources/attendance_remote_datasource.dart';
import 'package:opshub/features/attendance/data/models/attendance_correction_model.dart';
import 'package:opshub/features/attendance/data/models/attendance_model.dart';
import 'package:opshub/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_correction.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';

/// **The offline write rule**, at the layer that enforces it.
///
/// Firestore's cache accepts a write with no connection, reports success, and
/// replays it whenever the connection returns — so the user is told it worked,
/// nobody receives it, and it lands an hour later. `NetworkGuard` is what turns
/// that into an honest refusal.
///
/// **Every write is guarded, including clock in / out** — they were once the
/// one exemption, but an offline clock-in is the worst offender of all: the
/// server-timestamped `clockIn` resolves to the RECONNECT time, silently
/// corrupting pay data while the UI says "clocked in". Failing fast tells the
/// person to reconnect instead.
class _RecordingDataSource implements AttendanceRemoteDataSource {
  final calls = <String>[];

  @override
  Future<void> clockIn(AttendanceModel record) async => calls.add('clockIn');

  @override
  Future<void> requestCorrection(AttendanceCorrectionModel c) async =>
      calls.add('requestCorrection');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AttendanceEntity _record() => AttendanceEntity(
      id: 'u1_20260803_morning',
      userId: 'u1',
      branchId: 'b1',
      shift: ScheduleShift.morning,
      date: DateTime(2026, 8, 3),
      status: AttendanceStatus.inProgress,
    );

AttendanceCorrectionEntity _correction() => AttendanceCorrectionEntity(
      id: 'c1',
      attendanceId: 'u1_20260803_morning',
      userId: 'u1',
      branchId: 'b1',
      requestedBy: 'u1',
      kind: AttendanceCorrectionKind.missingClockOut,
      reason: 'Forgot to clock out',
    );

void main() {
  setUp(NetworkGuard.reset);
  tearDown(NetworkGuard.reset);

  test('defaults to online so nothing that skips the wire-up breaks', () {
    // Failing closed would turn a missing wire-up into "every write in the app
    // is broken", which is worse than the bug being prevented.
    expect(NetworkGuard.isOnline, isTrue);
    expect(NetworkGuard.ensureWritable, returnsNormally);
  });

  test('offline, a guarded write throws OfflineFailure instead of queueing',
      () async {
    NetworkGuard.setOnline(false);
    final remote = _RecordingDataSource();
    final repo = AttendanceRepositoryImpl(remote);

    await expectLater(
      repo.requestCorrection(_correction()),
      throwsA(isA<OfflineFailure>()),
    );

    // The point: it never reached the datasource, so Firestore never cached it.
    expect(remote.calls, isEmpty);
  });

  test('clock-in fails fast offline — no silent replay of pay data', () async {
    NetworkGuard.setOnline(false);
    final remote = _RecordingDataSource();
    final repo = AttendanceRepositoryImpl(remote);

    await expectLater(
      repo.clockIn(_record()),
      throwsA(isA<OfflineFailure>()),
    );

    // The point: it never reached the datasource, so nothing can replay later
    // with a reconnect-time server timestamp.
    expect(remote.calls, isEmpty);
  });

  test('back online, the guarded write goes through again', () async {
    NetworkGuard.setOnline(true);
    final remote = _RecordingDataSource();
    final repo = AttendanceRepositoryImpl(remote);

    await repo.requestCorrection(_correction());

    expect(remote.calls, ['requestCorrection']);
  });
}

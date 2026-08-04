// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'attendance_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AttendanceEntity {
  /// Deterministic id `{uid}_{yyyyMMdd}_{shift}` (see [attendanceDocId]).
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;

  /// Denormalized for list/board rows (avoids a user fetch per row).
  String? get userName => throw _privateConstructorUsedError;
  String? get branchId => throw _privateConstructorUsedError;

  /// Which rostered slot this record is for.
  ScheduleShift get shift => throw _privateConstructorUsedError;

  /// The calendar day of the shift (local midnight). Pairs with [dayKey].
  DateTime get date => throw _privateConstructorUsedError;

  /// The scheduled start / end **instants**, snapshotted at clock-in from the
  /// resolved `ShiftHours` so history stays stable even if the roster is later
  /// edited. Null for an unscheduled clock-in, and always null when
  /// [presenceOnly].
  DateTime? get scheduledStart => throw _privateConstructorUsedError;
  DateTime? get scheduledEnd => throw _privateConstructorUsedError;

  /// **Presence tracking, by policy** — this record is not measured against a
  /// roster at all. Set for managers, whose attendance answers "were they
  /// here" rather than "did they work their shift": worked minutes run
  /// clock-in → clock-out, and late / early-leave / overtime are meaningless
  /// and stay 0.
  ///
  /// This exists because a missing [scheduledStart] alone is ambiguous. It
  /// otherwise reads as `unscheduledWork` — an **exception**, meaning someone
  /// worked a shift nobody rostered — which reporting excludes from
  /// present/absent counts. Without this flag every manager day would be
  /// filed as an anomaly and managers would vanish from attendance stats.
  bool get presenceOnly => throw _privateConstructorUsedError;
  DateTime? get clockIn => throw _privateConstructorUsedError;
  DateTime? get clockOut => throw _privateConstructorUsedError;

  /// Breaks taken this shift. **Dormant internal extension point** — the MVP has
  /// no break flow (no clock UI, use case, or write path), so this stays empty
  /// and the calculator nets 0; the field + [AttendanceBreak] value object are
  /// kept so break support can return without a migration. Not exposed.
  List<AttendanceBreak> get breaks => throw _privateConstructorUsedError;
  AttendanceStatus get status =>
      throw _privateConstructorUsedError; // ── Snapshot totals (written at clock-out / auto-close) ──
  int get workedMinutes => throw _privateConstructorUsedError;
  int get lateMinutes => throw _privateConstructorUsedError;
  int get earlyLeaveMinutes => throw _privateConstructorUsedError;
  int get overtimeMinutes => throw _privateConstructorUsedError;
  int get breakMinutes => throw _privateConstructorUsedError;

  /// The GPS verification captured **at clock-in** — the device location, its
  /// distance from the branch, the accuracy, and whether it passed the branch
  /// geofence. Null on a record created without a fix (shouldn't happen once
  /// GPS is required, but stays null-safe for legacy/manual records).
  AttendanceVerification? get clockInVerification =>
      throw _privateConstructorUsedError;

  /// The GPS verification captured **at clock-out** (stored separately from
  /// [clockInVerification]).
  AttendanceVerification? get clockOutVerification =>
      throw _privateConstructorUsedError;

  /// Optional clock-in selfie (Storage URL). Dormant extension point for future
  /// face verification — stored, never analysed here.
  String? get photoUrl => throw _privateConstructorUsedError;
  String? get deviceId => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  AttendanceSource get source =>
      throw _privateConstructorUsedError; // ── Resolution (who closed out a pendingReview record, via a correction or
  //    a manager edit). NOT an "approval" of the record — approve/reject is a
  //    property of the Attendance Correction Request, never of attendance
  //    itself. These are denormalized stamps for the card + audit.
  String? get resolvedBy => throw _privateConstructorUsedError;
  String? get resolvedByName => throw _privateConstructorUsedError;
  DateTime? get resolvedAt => throw _privateConstructorUsedError;

  /// Additive version tag so the shape can evolve without a migration.
  int get schemaVersion => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Soft delete (admin) — the record stays as history, lists filter it out.
  DateTime? get deletedAt => throw _privateConstructorUsedError;

  /// Create a copy of AttendanceEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AttendanceEntityCopyWith<AttendanceEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttendanceEntityCopyWith<$Res> {
  factory $AttendanceEntityCopyWith(
    AttendanceEntity value,
    $Res Function(AttendanceEntity) then,
  ) = _$AttendanceEntityCopyWithImpl<$Res, AttendanceEntity>;
  @useResult
  $Res call({
    String id,
    String userId,
    String? userName,
    String? branchId,
    ScheduleShift shift,
    DateTime date,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    bool presenceOnly,
    DateTime? clockIn,
    DateTime? clockOut,
    List<AttendanceBreak> breaks,
    AttendanceStatus status,
    int workedMinutes,
    int lateMinutes,
    int earlyLeaveMinutes,
    int overtimeMinutes,
    int breakMinutes,
    AttendanceVerification? clockInVerification,
    AttendanceVerification? clockOutVerification,
    String? photoUrl,
    String? deviceId,
    String? notes,
    AttendanceSource source,
    String? resolvedBy,
    String? resolvedByName,
    DateTime? resolvedAt,
    int schemaVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  });
}

/// @nodoc
class _$AttendanceEntityCopyWithImpl<$Res, $Val extends AttendanceEntity>
    implements $AttendanceEntityCopyWith<$Res> {
  _$AttendanceEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AttendanceEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? userName = freezed,
    Object? branchId = freezed,
    Object? shift = null,
    Object? date = null,
    Object? scheduledStart = freezed,
    Object? scheduledEnd = freezed,
    Object? presenceOnly = null,
    Object? clockIn = freezed,
    Object? clockOut = freezed,
    Object? breaks = null,
    Object? status = null,
    Object? workedMinutes = null,
    Object? lateMinutes = null,
    Object? earlyLeaveMinutes = null,
    Object? overtimeMinutes = null,
    Object? breakMinutes = null,
    Object? clockInVerification = freezed,
    Object? clockOutVerification = freezed,
    Object? photoUrl = freezed,
    Object? deviceId = freezed,
    Object? notes = freezed,
    Object? source = null,
    Object? resolvedBy = freezed,
    Object? resolvedByName = freezed,
    Object? resolvedAt = freezed,
    Object? schemaVersion = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? deletedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            userName: freezed == userName
                ? _value.userName
                : userName // ignore: cast_nullable_to_non_nullable
                      as String?,
            branchId: freezed == branchId
                ? _value.branchId
                : branchId // ignore: cast_nullable_to_non_nullable
                      as String?,
            shift: null == shift
                ? _value.shift
                : shift // ignore: cast_nullable_to_non_nullable
                      as ScheduleShift,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            scheduledStart: freezed == scheduledStart
                ? _value.scheduledStart
                : scheduledStart // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            scheduledEnd: freezed == scheduledEnd
                ? _value.scheduledEnd
                : scheduledEnd // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            presenceOnly: null == presenceOnly
                ? _value.presenceOnly
                : presenceOnly // ignore: cast_nullable_to_non_nullable
                      as bool,
            clockIn: freezed == clockIn
                ? _value.clockIn
                : clockIn // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            clockOut: freezed == clockOut
                ? _value.clockOut
                : clockOut // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            breaks: null == breaks
                ? _value.breaks
                : breaks // ignore: cast_nullable_to_non_nullable
                      as List<AttendanceBreak>,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as AttendanceStatus,
            workedMinutes: null == workedMinutes
                ? _value.workedMinutes
                : workedMinutes // ignore: cast_nullable_to_non_nullable
                      as int,
            lateMinutes: null == lateMinutes
                ? _value.lateMinutes
                : lateMinutes // ignore: cast_nullable_to_non_nullable
                      as int,
            earlyLeaveMinutes: null == earlyLeaveMinutes
                ? _value.earlyLeaveMinutes
                : earlyLeaveMinutes // ignore: cast_nullable_to_non_nullable
                      as int,
            overtimeMinutes: null == overtimeMinutes
                ? _value.overtimeMinutes
                : overtimeMinutes // ignore: cast_nullable_to_non_nullable
                      as int,
            breakMinutes: null == breakMinutes
                ? _value.breakMinutes
                : breakMinutes // ignore: cast_nullable_to_non_nullable
                      as int,
            clockInVerification: freezed == clockInVerification
                ? _value.clockInVerification
                : clockInVerification // ignore: cast_nullable_to_non_nullable
                      as AttendanceVerification?,
            clockOutVerification: freezed == clockOutVerification
                ? _value.clockOutVerification
                : clockOutVerification // ignore: cast_nullable_to_non_nullable
                      as AttendanceVerification?,
            photoUrl: freezed == photoUrl
                ? _value.photoUrl
                : photoUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            deviceId: freezed == deviceId
                ? _value.deviceId
                : deviceId // ignore: cast_nullable_to_non_nullable
                      as String?,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
            source: null == source
                ? _value.source
                : source // ignore: cast_nullable_to_non_nullable
                      as AttendanceSource,
            resolvedBy: freezed == resolvedBy
                ? _value.resolvedBy
                : resolvedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            resolvedByName: freezed == resolvedByName
                ? _value.resolvedByName
                : resolvedByName // ignore: cast_nullable_to_non_nullable
                      as String?,
            resolvedAt: freezed == resolvedAt
                ? _value.resolvedAt
                : resolvedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            schemaVersion: null == schemaVersion
                ? _value.schemaVersion
                : schemaVersion // ignore: cast_nullable_to_non_nullable
                      as int,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            deletedAt: freezed == deletedAt
                ? _value.deletedAt
                : deletedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AttendanceEntityImplCopyWith<$Res>
    implements $AttendanceEntityCopyWith<$Res> {
  factory _$$AttendanceEntityImplCopyWith(
    _$AttendanceEntityImpl value,
    $Res Function(_$AttendanceEntityImpl) then,
  ) = __$$AttendanceEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String? userName,
    String? branchId,
    ScheduleShift shift,
    DateTime date,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    bool presenceOnly,
    DateTime? clockIn,
    DateTime? clockOut,
    List<AttendanceBreak> breaks,
    AttendanceStatus status,
    int workedMinutes,
    int lateMinutes,
    int earlyLeaveMinutes,
    int overtimeMinutes,
    int breakMinutes,
    AttendanceVerification? clockInVerification,
    AttendanceVerification? clockOutVerification,
    String? photoUrl,
    String? deviceId,
    String? notes,
    AttendanceSource source,
    String? resolvedBy,
    String? resolvedByName,
    DateTime? resolvedAt,
    int schemaVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  });
}

/// @nodoc
class __$$AttendanceEntityImplCopyWithImpl<$Res>
    extends _$AttendanceEntityCopyWithImpl<$Res, _$AttendanceEntityImpl>
    implements _$$AttendanceEntityImplCopyWith<$Res> {
  __$$AttendanceEntityImplCopyWithImpl(
    _$AttendanceEntityImpl _value,
    $Res Function(_$AttendanceEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AttendanceEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? userName = freezed,
    Object? branchId = freezed,
    Object? shift = null,
    Object? date = null,
    Object? scheduledStart = freezed,
    Object? scheduledEnd = freezed,
    Object? presenceOnly = null,
    Object? clockIn = freezed,
    Object? clockOut = freezed,
    Object? breaks = null,
    Object? status = null,
    Object? workedMinutes = null,
    Object? lateMinutes = null,
    Object? earlyLeaveMinutes = null,
    Object? overtimeMinutes = null,
    Object? breakMinutes = null,
    Object? clockInVerification = freezed,
    Object? clockOutVerification = freezed,
    Object? photoUrl = freezed,
    Object? deviceId = freezed,
    Object? notes = freezed,
    Object? source = null,
    Object? resolvedBy = freezed,
    Object? resolvedByName = freezed,
    Object? resolvedAt = freezed,
    Object? schemaVersion = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? deletedAt = freezed,
  }) {
    return _then(
      _$AttendanceEntityImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        userName: freezed == userName
            ? _value.userName
            : userName // ignore: cast_nullable_to_non_nullable
                  as String?,
        branchId: freezed == branchId
            ? _value.branchId
            : branchId // ignore: cast_nullable_to_non_nullable
                  as String?,
        shift: null == shift
            ? _value.shift
            : shift // ignore: cast_nullable_to_non_nullable
                  as ScheduleShift,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        scheduledStart: freezed == scheduledStart
            ? _value.scheduledStart
            : scheduledStart // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        scheduledEnd: freezed == scheduledEnd
            ? _value.scheduledEnd
            : scheduledEnd // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        presenceOnly: null == presenceOnly
            ? _value.presenceOnly
            : presenceOnly // ignore: cast_nullable_to_non_nullable
                  as bool,
        clockIn: freezed == clockIn
            ? _value.clockIn
            : clockIn // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        clockOut: freezed == clockOut
            ? _value.clockOut
            : clockOut // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        breaks: null == breaks
            ? _value._breaks
            : breaks // ignore: cast_nullable_to_non_nullable
                  as List<AttendanceBreak>,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as AttendanceStatus,
        workedMinutes: null == workedMinutes
            ? _value.workedMinutes
            : workedMinutes // ignore: cast_nullable_to_non_nullable
                  as int,
        lateMinutes: null == lateMinutes
            ? _value.lateMinutes
            : lateMinutes // ignore: cast_nullable_to_non_nullable
                  as int,
        earlyLeaveMinutes: null == earlyLeaveMinutes
            ? _value.earlyLeaveMinutes
            : earlyLeaveMinutes // ignore: cast_nullable_to_non_nullable
                  as int,
        overtimeMinutes: null == overtimeMinutes
            ? _value.overtimeMinutes
            : overtimeMinutes // ignore: cast_nullable_to_non_nullable
                  as int,
        breakMinutes: null == breakMinutes
            ? _value.breakMinutes
            : breakMinutes // ignore: cast_nullable_to_non_nullable
                  as int,
        clockInVerification: freezed == clockInVerification
            ? _value.clockInVerification
            : clockInVerification // ignore: cast_nullable_to_non_nullable
                  as AttendanceVerification?,
        clockOutVerification: freezed == clockOutVerification
            ? _value.clockOutVerification
            : clockOutVerification // ignore: cast_nullable_to_non_nullable
                  as AttendanceVerification?,
        photoUrl: freezed == photoUrl
            ? _value.photoUrl
            : photoUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        deviceId: freezed == deviceId
            ? _value.deviceId
            : deviceId // ignore: cast_nullable_to_non_nullable
                  as String?,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
        source: null == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as AttendanceSource,
        resolvedBy: freezed == resolvedBy
            ? _value.resolvedBy
            : resolvedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        resolvedByName: freezed == resolvedByName
            ? _value.resolvedByName
            : resolvedByName // ignore: cast_nullable_to_non_nullable
                  as String?,
        resolvedAt: freezed == resolvedAt
            ? _value.resolvedAt
            : resolvedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        schemaVersion: null == schemaVersion
            ? _value.schemaVersion
            : schemaVersion // ignore: cast_nullable_to_non_nullable
                  as int,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        deletedAt: freezed == deletedAt
            ? _value.deletedAt
            : deletedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$AttendanceEntityImpl extends _AttendanceEntity {
  const _$AttendanceEntityImpl({
    required this.id,
    required this.userId,
    this.userName,
    this.branchId,
    required this.shift,
    required this.date,
    this.scheduledStart,
    this.scheduledEnd,
    this.presenceOnly = false,
    this.clockIn,
    this.clockOut,
    final List<AttendanceBreak> breaks = const <AttendanceBreak>[],
    this.status = AttendanceStatus.inProgress,
    this.workedMinutes = 0,
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.overtimeMinutes = 0,
    this.breakMinutes = 0,
    this.clockInVerification,
    this.clockOutVerification,
    this.photoUrl,
    this.deviceId,
    this.notes,
    this.source = AttendanceSource.clock,
    this.resolvedBy,
    this.resolvedByName,
    this.resolvedAt,
    this.schemaVersion = 1,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  }) : _breaks = breaks,
       super._();

  /// Deterministic id `{uid}_{yyyyMMdd}_{shift}` (see [attendanceDocId]).
  @override
  final String id;
  @override
  final String userId;

  /// Denormalized for list/board rows (avoids a user fetch per row).
  @override
  final String? userName;
  @override
  final String? branchId;

  /// Which rostered slot this record is for.
  @override
  final ScheduleShift shift;

  /// The calendar day of the shift (local midnight). Pairs with [dayKey].
  @override
  final DateTime date;

  /// The scheduled start / end **instants**, snapshotted at clock-in from the
  /// resolved `ShiftHours` so history stays stable even if the roster is later
  /// edited. Null for an unscheduled clock-in, and always null when
  /// [presenceOnly].
  @override
  final DateTime? scheduledStart;
  @override
  final DateTime? scheduledEnd;

  /// **Presence tracking, by policy** — this record is not measured against a
  /// roster at all. Set for managers, whose attendance answers "were they
  /// here" rather than "did they work their shift": worked minutes run
  /// clock-in → clock-out, and late / early-leave / overtime are meaningless
  /// and stay 0.
  ///
  /// This exists because a missing [scheduledStart] alone is ambiguous. It
  /// otherwise reads as `unscheduledWork` — an **exception**, meaning someone
  /// worked a shift nobody rostered — which reporting excludes from
  /// present/absent counts. Without this flag every manager day would be
  /// filed as an anomaly and managers would vanish from attendance stats.
  @override
  @JsonKey()
  final bool presenceOnly;
  @override
  final DateTime? clockIn;
  @override
  final DateTime? clockOut;

  /// Breaks taken this shift. **Dormant internal extension point** — the MVP has
  /// no break flow (no clock UI, use case, or write path), so this stays empty
  /// and the calculator nets 0; the field + [AttendanceBreak] value object are
  /// kept so break support can return without a migration. Not exposed.
  final List<AttendanceBreak> _breaks;

  /// Breaks taken this shift. **Dormant internal extension point** — the MVP has
  /// no break flow (no clock UI, use case, or write path), so this stays empty
  /// and the calculator nets 0; the field + [AttendanceBreak] value object are
  /// kept so break support can return without a migration. Not exposed.
  @override
  @JsonKey()
  List<AttendanceBreak> get breaks {
    if (_breaks is EqualUnmodifiableListView) return _breaks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_breaks);
  }

  @override
  @JsonKey()
  final AttendanceStatus status;
  // ── Snapshot totals (written at clock-out / auto-close) ──
  @override
  @JsonKey()
  final int workedMinutes;
  @override
  @JsonKey()
  final int lateMinutes;
  @override
  @JsonKey()
  final int earlyLeaveMinutes;
  @override
  @JsonKey()
  final int overtimeMinutes;
  @override
  @JsonKey()
  final int breakMinutes;

  /// The GPS verification captured **at clock-in** — the device location, its
  /// distance from the branch, the accuracy, and whether it passed the branch
  /// geofence. Null on a record created without a fix (shouldn't happen once
  /// GPS is required, but stays null-safe for legacy/manual records).
  @override
  final AttendanceVerification? clockInVerification;

  /// The GPS verification captured **at clock-out** (stored separately from
  /// [clockInVerification]).
  @override
  final AttendanceVerification? clockOutVerification;

  /// Optional clock-in selfie (Storage URL). Dormant extension point for future
  /// face verification — stored, never analysed here.
  @override
  final String? photoUrl;
  @override
  final String? deviceId;
  @override
  final String? notes;
  @override
  @JsonKey()
  final AttendanceSource source;
  // ── Resolution (who closed out a pendingReview record, via a correction or
  //    a manager edit). NOT an "approval" of the record — approve/reject is a
  //    property of the Attendance Correction Request, never of attendance
  //    itself. These are denormalized stamps for the card + audit.
  @override
  final String? resolvedBy;
  @override
  final String? resolvedByName;
  @override
  final DateTime? resolvedAt;

  /// Additive version tag so the shape can evolve without a migration.
  @override
  @JsonKey()
  final int schemaVersion;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  /// Soft delete (admin) — the record stays as history, lists filter it out.
  @override
  final DateTime? deletedAt;

  @override
  String toString() {
    return 'AttendanceEntity(id: $id, userId: $userId, userName: $userName, branchId: $branchId, shift: $shift, date: $date, scheduledStart: $scheduledStart, scheduledEnd: $scheduledEnd, presenceOnly: $presenceOnly, clockIn: $clockIn, clockOut: $clockOut, breaks: $breaks, status: $status, workedMinutes: $workedMinutes, lateMinutes: $lateMinutes, earlyLeaveMinutes: $earlyLeaveMinutes, overtimeMinutes: $overtimeMinutes, breakMinutes: $breakMinutes, clockInVerification: $clockInVerification, clockOutVerification: $clockOutVerification, photoUrl: $photoUrl, deviceId: $deviceId, notes: $notes, source: $source, resolvedBy: $resolvedBy, resolvedByName: $resolvedByName, resolvedAt: $resolvedAt, schemaVersion: $schemaVersion, createdAt: $createdAt, updatedAt: $updatedAt, deletedAt: $deletedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttendanceEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.userName, userName) ||
                other.userName == userName) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            (identical(other.shift, shift) || other.shift == shift) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.scheduledStart, scheduledStart) ||
                other.scheduledStart == scheduledStart) &&
            (identical(other.scheduledEnd, scheduledEnd) ||
                other.scheduledEnd == scheduledEnd) &&
            (identical(other.presenceOnly, presenceOnly) ||
                other.presenceOnly == presenceOnly) &&
            (identical(other.clockIn, clockIn) || other.clockIn == clockIn) &&
            (identical(other.clockOut, clockOut) ||
                other.clockOut == clockOut) &&
            const DeepCollectionEquality().equals(other._breaks, _breaks) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.workedMinutes, workedMinutes) ||
                other.workedMinutes == workedMinutes) &&
            (identical(other.lateMinutes, lateMinutes) ||
                other.lateMinutes == lateMinutes) &&
            (identical(other.earlyLeaveMinutes, earlyLeaveMinutes) ||
                other.earlyLeaveMinutes == earlyLeaveMinutes) &&
            (identical(other.overtimeMinutes, overtimeMinutes) ||
                other.overtimeMinutes == overtimeMinutes) &&
            (identical(other.breakMinutes, breakMinutes) ||
                other.breakMinutes == breakMinutes) &&
            (identical(other.clockInVerification, clockInVerification) ||
                other.clockInVerification == clockInVerification) &&
            (identical(other.clockOutVerification, clockOutVerification) ||
                other.clockOutVerification == clockOutVerification) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.resolvedBy, resolvedBy) ||
                other.resolvedBy == resolvedBy) &&
            (identical(other.resolvedByName, resolvedByName) ||
                other.resolvedByName == resolvedByName) &&
            (identical(other.resolvedAt, resolvedAt) ||
                other.resolvedAt == resolvedAt) &&
            (identical(other.schemaVersion, schemaVersion) ||
                other.schemaVersion == schemaVersion) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    userId,
    userName,
    branchId,
    shift,
    date,
    scheduledStart,
    scheduledEnd,
    presenceOnly,
    clockIn,
    clockOut,
    const DeepCollectionEquality().hash(_breaks),
    status,
    workedMinutes,
    lateMinutes,
    earlyLeaveMinutes,
    overtimeMinutes,
    breakMinutes,
    clockInVerification,
    clockOutVerification,
    photoUrl,
    deviceId,
    notes,
    source,
    resolvedBy,
    resolvedByName,
    resolvedAt,
    schemaVersion,
    createdAt,
    updatedAt,
    deletedAt,
  ]);

  /// Create a copy of AttendanceEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AttendanceEntityImplCopyWith<_$AttendanceEntityImpl> get copyWith =>
      __$$AttendanceEntityImplCopyWithImpl<_$AttendanceEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _AttendanceEntity extends AttendanceEntity {
  const factory _AttendanceEntity({
    required final String id,
    required final String userId,
    final String? userName,
    final String? branchId,
    required final ScheduleShift shift,
    required final DateTime date,
    final DateTime? scheduledStart,
    final DateTime? scheduledEnd,
    final bool presenceOnly,
    final DateTime? clockIn,
    final DateTime? clockOut,
    final List<AttendanceBreak> breaks,
    final AttendanceStatus status,
    final int workedMinutes,
    final int lateMinutes,
    final int earlyLeaveMinutes,
    final int overtimeMinutes,
    final int breakMinutes,
    final AttendanceVerification? clockInVerification,
    final AttendanceVerification? clockOutVerification,
    final String? photoUrl,
    final String? deviceId,
    final String? notes,
    final AttendanceSource source,
    final String? resolvedBy,
    final String? resolvedByName,
    final DateTime? resolvedAt,
    final int schemaVersion,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final DateTime? deletedAt,
  }) = _$AttendanceEntityImpl;
  const _AttendanceEntity._() : super._();

  /// Deterministic id `{uid}_{yyyyMMdd}_{shift}` (see [attendanceDocId]).
  @override
  String get id;
  @override
  String get userId;

  /// Denormalized for list/board rows (avoids a user fetch per row).
  @override
  String? get userName;
  @override
  String? get branchId;

  /// Which rostered slot this record is for.
  @override
  ScheduleShift get shift;

  /// The calendar day of the shift (local midnight). Pairs with [dayKey].
  @override
  DateTime get date;

  /// The scheduled start / end **instants**, snapshotted at clock-in from the
  /// resolved `ShiftHours` so history stays stable even if the roster is later
  /// edited. Null for an unscheduled clock-in, and always null when
  /// [presenceOnly].
  @override
  DateTime? get scheduledStart;
  @override
  DateTime? get scheduledEnd;

  /// **Presence tracking, by policy** — this record is not measured against a
  /// roster at all. Set for managers, whose attendance answers "were they
  /// here" rather than "did they work their shift": worked minutes run
  /// clock-in → clock-out, and late / early-leave / overtime are meaningless
  /// and stay 0.
  ///
  /// This exists because a missing [scheduledStart] alone is ambiguous. It
  /// otherwise reads as `unscheduledWork` — an **exception**, meaning someone
  /// worked a shift nobody rostered — which reporting excludes from
  /// present/absent counts. Without this flag every manager day would be
  /// filed as an anomaly and managers would vanish from attendance stats.
  @override
  bool get presenceOnly;
  @override
  DateTime? get clockIn;
  @override
  DateTime? get clockOut;

  /// Breaks taken this shift. **Dormant internal extension point** — the MVP has
  /// no break flow (no clock UI, use case, or write path), so this stays empty
  /// and the calculator nets 0; the field + [AttendanceBreak] value object are
  /// kept so break support can return without a migration. Not exposed.
  @override
  List<AttendanceBreak> get breaks;
  @override
  AttendanceStatus get status; // ── Snapshot totals (written at clock-out / auto-close) ──
  @override
  int get workedMinutes;
  @override
  int get lateMinutes;
  @override
  int get earlyLeaveMinutes;
  @override
  int get overtimeMinutes;
  @override
  int get breakMinutes;

  /// The GPS verification captured **at clock-in** — the device location, its
  /// distance from the branch, the accuracy, and whether it passed the branch
  /// geofence. Null on a record created without a fix (shouldn't happen once
  /// GPS is required, but stays null-safe for legacy/manual records).
  @override
  AttendanceVerification? get clockInVerification;

  /// The GPS verification captured **at clock-out** (stored separately from
  /// [clockInVerification]).
  @override
  AttendanceVerification? get clockOutVerification;

  /// Optional clock-in selfie (Storage URL). Dormant extension point for future
  /// face verification — stored, never analysed here.
  @override
  String? get photoUrl;
  @override
  String? get deviceId;
  @override
  String? get notes;
  @override
  AttendanceSource get source; // ── Resolution (who closed out a pendingReview record, via a correction or
  //    a manager edit). NOT an "approval" of the record — approve/reject is a
  //    property of the Attendance Correction Request, never of attendance
  //    itself. These are denormalized stamps for the card + audit.
  @override
  String? get resolvedBy;
  @override
  String? get resolvedByName;
  @override
  DateTime? get resolvedAt;

  /// Additive version tag so the shape can evolve without a migration.
  @override
  int get schemaVersion;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Soft delete (admin) — the record stays as history, lists filter it out.
  @override
  DateTime? get deletedAt;

  /// Create a copy of AttendanceEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AttendanceEntityImplCopyWith<_$AttendanceEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

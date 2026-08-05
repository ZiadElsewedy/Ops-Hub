// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shift_swap_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ShiftSwapEntity {
  String get id => throw _privateConstructorUsedError;
  String get branchId => throw _privateConstructorUsedError;

  /// The week the slot belongs to (Sunday 00:00) — used to address the
  /// schedule document the swap mutates on approval.
  DateTime get weekStart => throw _privateConstructorUsedError;
  ScheduleDay get day => throw _privateConstructorUsedError;
  ScheduleShift get shift => throw _privateConstructorUsedError;

  /// The employee giving up the slot.
  String get requesterId => throw _privateConstructorUsedError;
  String? get requesterName => throw _privateConstructorUsedError;

  /// The coworker asked to take the slot.
  String get targetId => throw _privateConstructorUsedError;
  String? get targetName => throw _privateConstructorUsedError;
  SwapStatus get status => throw _privateConstructorUsedError;

  /// Optional free-text note from the requester.
  String? get note => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// The manager/admin who atomically approved the exchange. Written only by
  /// the server-authoritative `approveSwap` Cloud Function.
  String? get managerApprovedById => throw _privateConstructorUsedError;
  String? get managerApprovedByName => throw _privateConstructorUsedError;
  DateTime? get managerApprovedAt => throw _privateConstructorUsedError;

  /// Create a copy of ShiftSwapEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShiftSwapEntityCopyWith<ShiftSwapEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShiftSwapEntityCopyWith<$Res> {
  factory $ShiftSwapEntityCopyWith(
    ShiftSwapEntity value,
    $Res Function(ShiftSwapEntity) then,
  ) = _$ShiftSwapEntityCopyWithImpl<$Res, ShiftSwapEntity>;
  @useResult
  $Res call({
    String id,
    String branchId,
    DateTime weekStart,
    ScheduleDay day,
    ScheduleShift shift,
    String requesterId,
    String? requesterName,
    String targetId,
    String? targetName,
    SwapStatus status,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? managerApprovedById,
    String? managerApprovedByName,
    DateTime? managerApprovedAt,
  });
}

/// @nodoc
class _$ShiftSwapEntityCopyWithImpl<$Res, $Val extends ShiftSwapEntity>
    implements $ShiftSwapEntityCopyWith<$Res> {
  _$ShiftSwapEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ShiftSwapEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? branchId = null,
    Object? weekStart = null,
    Object? day = null,
    Object? shift = null,
    Object? requesterId = null,
    Object? requesterName = freezed,
    Object? targetId = null,
    Object? targetName = freezed,
    Object? status = null,
    Object? note = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? managerApprovedById = freezed,
    Object? managerApprovedByName = freezed,
    Object? managerApprovedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            branchId: null == branchId
                ? _value.branchId
                : branchId // ignore: cast_nullable_to_non_nullable
                      as String,
            weekStart: null == weekStart
                ? _value.weekStart
                : weekStart // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            day: null == day
                ? _value.day
                : day // ignore: cast_nullable_to_non_nullable
                      as ScheduleDay,
            shift: null == shift
                ? _value.shift
                : shift // ignore: cast_nullable_to_non_nullable
                      as ScheduleShift,
            requesterId: null == requesterId
                ? _value.requesterId
                : requesterId // ignore: cast_nullable_to_non_nullable
                      as String,
            requesterName: freezed == requesterName
                ? _value.requesterName
                : requesterName // ignore: cast_nullable_to_non_nullable
                      as String?,
            targetId: null == targetId
                ? _value.targetId
                : targetId // ignore: cast_nullable_to_non_nullable
                      as String,
            targetName: freezed == targetName
                ? _value.targetName
                : targetName // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as SwapStatus,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            managerApprovedById: freezed == managerApprovedById
                ? _value.managerApprovedById
                : managerApprovedById // ignore: cast_nullable_to_non_nullable
                      as String?,
            managerApprovedByName: freezed == managerApprovedByName
                ? _value.managerApprovedByName
                : managerApprovedByName // ignore: cast_nullable_to_non_nullable
                      as String?,
            managerApprovedAt: freezed == managerApprovedAt
                ? _value.managerApprovedAt
                : managerApprovedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ShiftSwapEntityImplCopyWith<$Res>
    implements $ShiftSwapEntityCopyWith<$Res> {
  factory _$$ShiftSwapEntityImplCopyWith(
    _$ShiftSwapEntityImpl value,
    $Res Function(_$ShiftSwapEntityImpl) then,
  ) = __$$ShiftSwapEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String branchId,
    DateTime weekStart,
    ScheduleDay day,
    ScheduleShift shift,
    String requesterId,
    String? requesterName,
    String targetId,
    String? targetName,
    SwapStatus status,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? managerApprovedById,
    String? managerApprovedByName,
    DateTime? managerApprovedAt,
  });
}

/// @nodoc
class __$$ShiftSwapEntityImplCopyWithImpl<$Res>
    extends _$ShiftSwapEntityCopyWithImpl<$Res, _$ShiftSwapEntityImpl>
    implements _$$ShiftSwapEntityImplCopyWith<$Res> {
  __$$ShiftSwapEntityImplCopyWithImpl(
    _$ShiftSwapEntityImpl _value,
    $Res Function(_$ShiftSwapEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ShiftSwapEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? branchId = null,
    Object? weekStart = null,
    Object? day = null,
    Object? shift = null,
    Object? requesterId = null,
    Object? requesterName = freezed,
    Object? targetId = null,
    Object? targetName = freezed,
    Object? status = null,
    Object? note = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? managerApprovedById = freezed,
    Object? managerApprovedByName = freezed,
    Object? managerApprovedAt = freezed,
  }) {
    return _then(
      _$ShiftSwapEntityImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        branchId: null == branchId
            ? _value.branchId
            : branchId // ignore: cast_nullable_to_non_nullable
                  as String,
        weekStart: null == weekStart
            ? _value.weekStart
            : weekStart // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        day: null == day
            ? _value.day
            : day // ignore: cast_nullable_to_non_nullable
                  as ScheduleDay,
        shift: null == shift
            ? _value.shift
            : shift // ignore: cast_nullable_to_non_nullable
                  as ScheduleShift,
        requesterId: null == requesterId
            ? _value.requesterId
            : requesterId // ignore: cast_nullable_to_non_nullable
                  as String,
        requesterName: freezed == requesterName
            ? _value.requesterName
            : requesterName // ignore: cast_nullable_to_non_nullable
                  as String?,
        targetId: null == targetId
            ? _value.targetId
            : targetId // ignore: cast_nullable_to_non_nullable
                  as String,
        targetName: freezed == targetName
            ? _value.targetName
            : targetName // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as SwapStatus,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        managerApprovedById: freezed == managerApprovedById
            ? _value.managerApprovedById
            : managerApprovedById // ignore: cast_nullable_to_non_nullable
                  as String?,
        managerApprovedByName: freezed == managerApprovedByName
            ? _value.managerApprovedByName
            : managerApprovedByName // ignore: cast_nullable_to_non_nullable
                  as String?,
        managerApprovedAt: freezed == managerApprovedAt
            ? _value.managerApprovedAt
            : managerApprovedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$ShiftSwapEntityImpl implements _ShiftSwapEntity {
  const _$ShiftSwapEntityImpl({
    required this.id,
    required this.branchId,
    required this.weekStart,
    required this.day,
    required this.shift,
    required this.requesterId,
    this.requesterName,
    required this.targetId,
    this.targetName,
    this.status = SwapStatus.pending,
    this.note,
    this.createdAt,
    this.updatedAt,
    this.managerApprovedById,
    this.managerApprovedByName,
    this.managerApprovedAt,
  });

  @override
  final String id;
  @override
  final String branchId;

  /// The week the slot belongs to (Sunday 00:00) — used to address the
  /// schedule document the swap mutates on approval.
  @override
  final DateTime weekStart;
  @override
  final ScheduleDay day;
  @override
  final ScheduleShift shift;

  /// The employee giving up the slot.
  @override
  final String requesterId;
  @override
  final String? requesterName;

  /// The coworker asked to take the slot.
  @override
  final String targetId;
  @override
  final String? targetName;
  @override
  @JsonKey()
  final SwapStatus status;

  /// Optional free-text note from the requester.
  @override
  final String? note;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  /// The manager/admin who atomically approved the exchange. Written only by
  /// the server-authoritative `approveSwap` Cloud Function.
  @override
  final String? managerApprovedById;
  @override
  final String? managerApprovedByName;
  @override
  final DateTime? managerApprovedAt;

  @override
  String toString() {
    return 'ShiftSwapEntity(id: $id, branchId: $branchId, weekStart: $weekStart, day: $day, shift: $shift, requesterId: $requesterId, requesterName: $requesterName, targetId: $targetId, targetName: $targetName, status: $status, note: $note, createdAt: $createdAt, updatedAt: $updatedAt, managerApprovedById: $managerApprovedById, managerApprovedByName: $managerApprovedByName, managerApprovedAt: $managerApprovedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShiftSwapEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            (identical(other.weekStart, weekStart) ||
                other.weekStart == weekStart) &&
            (identical(other.day, day) || other.day == day) &&
            (identical(other.shift, shift) || other.shift == shift) &&
            (identical(other.requesterId, requesterId) ||
                other.requesterId == requesterId) &&
            (identical(other.requesterName, requesterName) ||
                other.requesterName == requesterName) &&
            (identical(other.targetId, targetId) ||
                other.targetId == targetId) &&
            (identical(other.targetName, targetName) ||
                other.targetName == targetName) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.managerApprovedById, managerApprovedById) ||
                other.managerApprovedById == managerApprovedById) &&
            (identical(other.managerApprovedByName, managerApprovedByName) ||
                other.managerApprovedByName == managerApprovedByName) &&
            (identical(other.managerApprovedAt, managerApprovedAt) ||
                other.managerApprovedAt == managerApprovedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    branchId,
    weekStart,
    day,
    shift,
    requesterId,
    requesterName,
    targetId,
    targetName,
    status,
    note,
    createdAt,
    updatedAt,
    managerApprovedById,
    managerApprovedByName,
    managerApprovedAt,
  );

  /// Create a copy of ShiftSwapEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShiftSwapEntityImplCopyWith<_$ShiftSwapEntityImpl> get copyWith =>
      __$$ShiftSwapEntityImplCopyWithImpl<_$ShiftSwapEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _ShiftSwapEntity implements ShiftSwapEntity {
  const factory _ShiftSwapEntity({
    required final String id,
    required final String branchId,
    required final DateTime weekStart,
    required final ScheduleDay day,
    required final ScheduleShift shift,
    required final String requesterId,
    final String? requesterName,
    required final String targetId,
    final String? targetName,
    final SwapStatus status,
    final String? note,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final String? managerApprovedById,
    final String? managerApprovedByName,
    final DateTime? managerApprovedAt,
  }) = _$ShiftSwapEntityImpl;

  @override
  String get id;
  @override
  String get branchId;

  /// The week the slot belongs to (Sunday 00:00) — used to address the
  /// schedule document the swap mutates on approval.
  @override
  DateTime get weekStart;
  @override
  ScheduleDay get day;
  @override
  ScheduleShift get shift;

  /// The employee giving up the slot.
  @override
  String get requesterId;
  @override
  String? get requesterName;

  /// The coworker asked to take the slot.
  @override
  String get targetId;
  @override
  String? get targetName;
  @override
  SwapStatus get status;

  /// Optional free-text note from the requester.
  @override
  String? get note;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// The manager/admin who atomically approved the exchange. Written only by
  /// the server-authoritative `approveSwap` Cloud Function.
  @override
  String? get managerApprovedById;
  @override
  String? get managerApprovedByName;
  @override
  DateTime? get managerApprovedAt;

  /// Create a copy of ShiftSwapEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShiftSwapEntityImplCopyWith<_$ShiftSwapEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

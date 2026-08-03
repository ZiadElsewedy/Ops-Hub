// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'broadcast_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$BroadcastEntity {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;

  /// Who sent it.
  String get senderId => throw _privateConstructorUsedError;
  String get senderName => throw _privateConstructorUsedError;
  UserRole get senderRole => throw _privateConstructorUsedError;
  BroadcastAudience get audience => throw _privateConstructorUsedError;

  /// Target branch when [audience] is [BroadcastAudience.branch]; null for an
  /// all-branches or individual broadcast.
  String? get branchId => throw _privateConstructorUsedError;

  /// The individual recipient when [audience] is [BroadcastAudience.user].
  String? get targetUserId => throw _privateConstructorUsedError;

  /// Notification category (announcement / reminder / emergency). Emergency
  /// retains high FCM priority; delivery is the independent [sendsPush] axis.
  String get category => throw _privateConstructorUsedError;

  /// Explicit delivery choice. `true` = Push + Inbox; `false` = Inbox only.
  bool get sendsPush => throw _privateConstructorUsedError;

  /// How many users the send engine resolved as recipients (set by the
  /// function on send; null on an unsent/legacy doc).
  int? get recipientCount => throw _privateConstructorUsedError;

  /// How many devices the push was actually delivered to (set by the function
  /// after the FCM multicast completes; null until then / legacy).
  int? get deliveredCount => throw _privateConstructorUsedError;

  /// When this broadcast was archived (hidden from the default feed but kept
  /// for history). Null = active.
  DateTime? get archivedAt => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Create a copy of BroadcastEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BroadcastEntityCopyWith<BroadcastEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BroadcastEntityCopyWith<$Res> {
  factory $BroadcastEntityCopyWith(
    BroadcastEntity value,
    $Res Function(BroadcastEntity) then,
  ) = _$BroadcastEntityCopyWithImpl<$Res, BroadcastEntity>;
  @useResult
  $Res call({
    String id,
    String title,
    String message,
    String senderId,
    String senderName,
    UserRole senderRole,
    BroadcastAudience audience,
    String? branchId,
    String? targetUserId,
    String category,
    bool sendsPush,
    int? recipientCount,
    int? deliveredCount,
    DateTime? archivedAt,
    DateTime? createdAt,
  });
}

/// @nodoc
class _$BroadcastEntityCopyWithImpl<$Res, $Val extends BroadcastEntity>
    implements $BroadcastEntityCopyWith<$Res> {
  _$BroadcastEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BroadcastEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? message = null,
    Object? senderId = null,
    Object? senderName = null,
    Object? senderRole = null,
    Object? audience = null,
    Object? branchId = freezed,
    Object? targetUserId = freezed,
    Object? category = null,
    Object? sendsPush = null,
    Object? recipientCount = freezed,
    Object? deliveredCount = freezed,
    Object? archivedAt = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
            senderId: null == senderId
                ? _value.senderId
                : senderId // ignore: cast_nullable_to_non_nullable
                      as String,
            senderName: null == senderName
                ? _value.senderName
                : senderName // ignore: cast_nullable_to_non_nullable
                      as String,
            senderRole: null == senderRole
                ? _value.senderRole
                : senderRole // ignore: cast_nullable_to_non_nullable
                      as UserRole,
            audience: null == audience
                ? _value.audience
                : audience // ignore: cast_nullable_to_non_nullable
                      as BroadcastAudience,
            branchId: freezed == branchId
                ? _value.branchId
                : branchId // ignore: cast_nullable_to_non_nullable
                      as String?,
            targetUserId: freezed == targetUserId
                ? _value.targetUserId
                : targetUserId // ignore: cast_nullable_to_non_nullable
                      as String?,
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as String,
            sendsPush: null == sendsPush
                ? _value.sendsPush
                : sendsPush // ignore: cast_nullable_to_non_nullable
                      as bool,
            recipientCount: freezed == recipientCount
                ? _value.recipientCount
                : recipientCount // ignore: cast_nullable_to_non_nullable
                      as int?,
            deliveredCount: freezed == deliveredCount
                ? _value.deliveredCount
                : deliveredCount // ignore: cast_nullable_to_non_nullable
                      as int?,
            archivedAt: freezed == archivedAt
                ? _value.archivedAt
                : archivedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BroadcastEntityImplCopyWith<$Res>
    implements $BroadcastEntityCopyWith<$Res> {
  factory _$$BroadcastEntityImplCopyWith(
    _$BroadcastEntityImpl value,
    $Res Function(_$BroadcastEntityImpl) then,
  ) = __$$BroadcastEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String message,
    String senderId,
    String senderName,
    UserRole senderRole,
    BroadcastAudience audience,
    String? branchId,
    String? targetUserId,
    String category,
    bool sendsPush,
    int? recipientCount,
    int? deliveredCount,
    DateTime? archivedAt,
    DateTime? createdAt,
  });
}

/// @nodoc
class __$$BroadcastEntityImplCopyWithImpl<$Res>
    extends _$BroadcastEntityCopyWithImpl<$Res, _$BroadcastEntityImpl>
    implements _$$BroadcastEntityImplCopyWith<$Res> {
  __$$BroadcastEntityImplCopyWithImpl(
    _$BroadcastEntityImpl _value,
    $Res Function(_$BroadcastEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BroadcastEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? message = null,
    Object? senderId = null,
    Object? senderName = null,
    Object? senderRole = null,
    Object? audience = null,
    Object? branchId = freezed,
    Object? targetUserId = freezed,
    Object? category = null,
    Object? sendsPush = null,
    Object? recipientCount = freezed,
    Object? deliveredCount = freezed,
    Object? archivedAt = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$BroadcastEntityImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
        senderId: null == senderId
            ? _value.senderId
            : senderId // ignore: cast_nullable_to_non_nullable
                  as String,
        senderName: null == senderName
            ? _value.senderName
            : senderName // ignore: cast_nullable_to_non_nullable
                  as String,
        senderRole: null == senderRole
            ? _value.senderRole
            : senderRole // ignore: cast_nullable_to_non_nullable
                  as UserRole,
        audience: null == audience
            ? _value.audience
            : audience // ignore: cast_nullable_to_non_nullable
                  as BroadcastAudience,
        branchId: freezed == branchId
            ? _value.branchId
            : branchId // ignore: cast_nullable_to_non_nullable
                  as String?,
        targetUserId: freezed == targetUserId
            ? _value.targetUserId
            : targetUserId // ignore: cast_nullable_to_non_nullable
                  as String?,
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as String,
        sendsPush: null == sendsPush
            ? _value.sendsPush
            : sendsPush // ignore: cast_nullable_to_non_nullable
                  as bool,
        recipientCount: freezed == recipientCount
            ? _value.recipientCount
            : recipientCount // ignore: cast_nullable_to_non_nullable
                  as int?,
        deliveredCount: freezed == deliveredCount
            ? _value.deliveredCount
            : deliveredCount // ignore: cast_nullable_to_non_nullable
                  as int?,
        archivedAt: freezed == archivedAt
            ? _value.archivedAt
            : archivedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$BroadcastEntityImpl extends _BroadcastEntity {
  const _$BroadcastEntityImpl({
    required this.id,
    required this.title,
    required this.message,
    required this.senderId,
    required this.senderName,
    this.senderRole = UserRole.manager,
    this.audience = BroadcastAudience.allBranches,
    this.branchId,
    this.targetUserId,
    this.category = 'general',
    this.sendsPush = true,
    this.recipientCount,
    this.deliveredCount,
    this.archivedAt,
    this.createdAt,
  }) : super._();

  @override
  final String id;
  @override
  final String title;
  @override
  final String message;

  /// Who sent it.
  @override
  final String senderId;
  @override
  final String senderName;
  @override
  @JsonKey()
  final UserRole senderRole;
  @override
  @JsonKey()
  final BroadcastAudience audience;

  /// Target branch when [audience] is [BroadcastAudience.branch]; null for an
  /// all-branches or individual broadcast.
  @override
  final String? branchId;

  /// The individual recipient when [audience] is [BroadcastAudience.user].
  @override
  final String? targetUserId;

  /// Notification category (announcement / reminder / emergency). Emergency
  /// retains high FCM priority; delivery is the independent [sendsPush] axis.
  @override
  @JsonKey()
  final String category;

  /// Explicit delivery choice. `true` = Push + Inbox; `false` = Inbox only.
  @override
  @JsonKey()
  final bool sendsPush;

  /// How many users the send engine resolved as recipients (set by the
  /// function on send; null on an unsent/legacy doc).
  @override
  final int? recipientCount;

  /// How many devices the push was actually delivered to (set by the function
  /// after the FCM multicast completes; null until then / legacy).
  @override
  final int? deliveredCount;

  /// When this broadcast was archived (hidden from the default feed but kept
  /// for history). Null = active.
  @override
  final DateTime? archivedAt;
  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'BroadcastEntity(id: $id, title: $title, message: $message, senderId: $senderId, senderName: $senderName, senderRole: $senderRole, audience: $audience, branchId: $branchId, targetUserId: $targetUserId, category: $category, sendsPush: $sendsPush, recipientCount: $recipientCount, deliveredCount: $deliveredCount, archivedAt: $archivedAt, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BroadcastEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.senderId, senderId) ||
                other.senderId == senderId) &&
            (identical(other.senderName, senderName) ||
                other.senderName == senderName) &&
            (identical(other.senderRole, senderRole) ||
                other.senderRole == senderRole) &&
            (identical(other.audience, audience) ||
                other.audience == audience) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            (identical(other.targetUserId, targetUserId) ||
                other.targetUserId == targetUserId) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.sendsPush, sendsPush) ||
                other.sendsPush == sendsPush) &&
            (identical(other.recipientCount, recipientCount) ||
                other.recipientCount == recipientCount) &&
            (identical(other.deliveredCount, deliveredCount) ||
                other.deliveredCount == deliveredCount) &&
            (identical(other.archivedAt, archivedAt) ||
                other.archivedAt == archivedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    message,
    senderId,
    senderName,
    senderRole,
    audience,
    branchId,
    targetUserId,
    category,
    sendsPush,
    recipientCount,
    deliveredCount,
    archivedAt,
    createdAt,
  );

  /// Create a copy of BroadcastEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BroadcastEntityImplCopyWith<_$BroadcastEntityImpl> get copyWith =>
      __$$BroadcastEntityImplCopyWithImpl<_$BroadcastEntityImpl>(
        this,
        _$identity,
      );
}

abstract class _BroadcastEntity extends BroadcastEntity {
  const factory _BroadcastEntity({
    required final String id,
    required final String title,
    required final String message,
    required final String senderId,
    required final String senderName,
    final UserRole senderRole,
    final BroadcastAudience audience,
    final String? branchId,
    final String? targetUserId,
    final String category,
    final bool sendsPush,
    final int? recipientCount,
    final int? deliveredCount,
    final DateTime? archivedAt,
    final DateTime? createdAt,
  }) = _$BroadcastEntityImpl;
  const _BroadcastEntity._() : super._();

  @override
  String get id;
  @override
  String get title;
  @override
  String get message;

  /// Who sent it.
  @override
  String get senderId;
  @override
  String get senderName;
  @override
  UserRole get senderRole;
  @override
  BroadcastAudience get audience;

  /// Target branch when [audience] is [BroadcastAudience.branch]; null for an
  /// all-branches or individual broadcast.
  @override
  String? get branchId;

  /// The individual recipient when [audience] is [BroadcastAudience.user].
  @override
  String? get targetUserId;

  /// Notification category (announcement / reminder / emergency). Emergency
  /// retains high FCM priority; delivery is the independent [sendsPush] axis.
  @override
  String get category;

  /// Explicit delivery choice. `true` = Push + Inbox; `false` = Inbox only.
  @override
  bool get sendsPush;

  /// How many users the send engine resolved as recipients (set by the
  /// function on send; null on an unsent/legacy doc).
  @override
  int? get recipientCount;

  /// How many devices the push was actually delivered to (set by the function
  /// after the FCM multicast completes; null until then / legacy).
  @override
  int? get deliveredCount;

  /// When this broadcast was archived (hidden from the default feed but kept
  /// for history). Null = active.
  @override
  DateTime? get archivedAt;
  @override
  DateTime? get createdAt;

  /// Create a copy of BroadcastEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BroadcastEntityImplCopyWith<_$BroadcastEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

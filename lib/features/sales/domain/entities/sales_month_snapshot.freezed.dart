// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sales_month_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SalesMonthSnapshot {
  BranchSalesMonthEntity? get target => throw _privateConstructorUsedError;
  List<DailySalesSubmissionEntity> get submissions =>
      throw _privateConstructorUsedError;

  /// Create a copy of SalesMonthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SalesMonthSnapshotCopyWith<SalesMonthSnapshot> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SalesMonthSnapshotCopyWith<$Res> {
  factory $SalesMonthSnapshotCopyWith(
    SalesMonthSnapshot value,
    $Res Function(SalesMonthSnapshot) then,
  ) = _$SalesMonthSnapshotCopyWithImpl<$Res, SalesMonthSnapshot>;
  @useResult
  $Res call({
    BranchSalesMonthEntity? target,
    List<DailySalesSubmissionEntity> submissions,
  });

  $BranchSalesMonthEntityCopyWith<$Res>? get target;
}

/// @nodoc
class _$SalesMonthSnapshotCopyWithImpl<$Res, $Val extends SalesMonthSnapshot>
    implements $SalesMonthSnapshotCopyWith<$Res> {
  _$SalesMonthSnapshotCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SalesMonthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? target = freezed, Object? submissions = null}) {
    return _then(
      _value.copyWith(
            target: freezed == target
                ? _value.target
                : target // ignore: cast_nullable_to_non_nullable
                      as BranchSalesMonthEntity?,
            submissions: null == submissions
                ? _value.submissions
                : submissions // ignore: cast_nullable_to_non_nullable
                      as List<DailySalesSubmissionEntity>,
          )
          as $Val,
    );
  }

  /// Create a copy of SalesMonthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BranchSalesMonthEntityCopyWith<$Res>? get target {
    if (_value.target == null) {
      return null;
    }

    return $BranchSalesMonthEntityCopyWith<$Res>(_value.target!, (value) {
      return _then(_value.copyWith(target: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SalesMonthSnapshotImplCopyWith<$Res>
    implements $SalesMonthSnapshotCopyWith<$Res> {
  factory _$$SalesMonthSnapshotImplCopyWith(
    _$SalesMonthSnapshotImpl value,
    $Res Function(_$SalesMonthSnapshotImpl) then,
  ) = __$$SalesMonthSnapshotImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    BranchSalesMonthEntity? target,
    List<DailySalesSubmissionEntity> submissions,
  });

  @override
  $BranchSalesMonthEntityCopyWith<$Res>? get target;
}

/// @nodoc
class __$$SalesMonthSnapshotImplCopyWithImpl<$Res>
    extends _$SalesMonthSnapshotCopyWithImpl<$Res, _$SalesMonthSnapshotImpl>
    implements _$$SalesMonthSnapshotImplCopyWith<$Res> {
  __$$SalesMonthSnapshotImplCopyWithImpl(
    _$SalesMonthSnapshotImpl _value,
    $Res Function(_$SalesMonthSnapshotImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SalesMonthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? target = freezed, Object? submissions = null}) {
    return _then(
      _$SalesMonthSnapshotImpl(
        target: freezed == target
            ? _value.target
            : target // ignore: cast_nullable_to_non_nullable
                  as BranchSalesMonthEntity?,
        submissions: null == submissions
            ? _value._submissions
            : submissions // ignore: cast_nullable_to_non_nullable
                  as List<DailySalesSubmissionEntity>,
      ),
    );
  }
}

/// @nodoc

class _$SalesMonthSnapshotImpl extends _SalesMonthSnapshot {
  const _$SalesMonthSnapshotImpl({
    this.target,
    final List<DailySalesSubmissionEntity> submissions =
        const <DailySalesSubmissionEntity>[],
  }) : _submissions = submissions,
       super._();

  @override
  final BranchSalesMonthEntity? target;
  final List<DailySalesSubmissionEntity> _submissions;
  @override
  @JsonKey()
  List<DailySalesSubmissionEntity> get submissions {
    if (_submissions is EqualUnmodifiableListView) return _submissions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_submissions);
  }

  @override
  String toString() {
    return 'SalesMonthSnapshot(target: $target, submissions: $submissions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SalesMonthSnapshotImpl &&
            (identical(other.target, target) || other.target == target) &&
            const DeepCollectionEquality().equals(
              other._submissions,
              _submissions,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    target,
    const DeepCollectionEquality().hash(_submissions),
  );

  /// Create a copy of SalesMonthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SalesMonthSnapshotImplCopyWith<_$SalesMonthSnapshotImpl> get copyWith =>
      __$$SalesMonthSnapshotImplCopyWithImpl<_$SalesMonthSnapshotImpl>(
        this,
        _$identity,
      );
}

abstract class _SalesMonthSnapshot extends SalesMonthSnapshot {
  const factory _SalesMonthSnapshot({
    final BranchSalesMonthEntity? target,
    final List<DailySalesSubmissionEntity> submissions,
  }) = _$SalesMonthSnapshotImpl;
  const _SalesMonthSnapshot._() : super._();

  @override
  BranchSalesMonthEntity? get target;
  @override
  List<DailySalesSubmissionEntity> get submissions;

  /// Create a copy of SalesMonthSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SalesMonthSnapshotImplCopyWith<_$SalesMonthSnapshotImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

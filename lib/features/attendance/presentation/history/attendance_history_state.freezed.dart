// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'attendance_history_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AttendanceHistoryState {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(
      List<AttendanceEntity> records,
      AttendanceStats stats,
      AttendanceHistoryQuery query,
      String? branchId,
      bool offline,
      bool syncing,
      List<AttendanceDirectoryEntry> directory,
    )
    loaded,
    required TResult Function(String message) error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(
      List<AttendanceEntity> records,
      AttendanceStats stats,
      AttendanceHistoryQuery query,
      String? branchId,
      bool offline,
      bool syncing,
      List<AttendanceDirectoryEntry> directory,
    )?
    loaded,
    TResult? Function(String message)? error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(
      List<AttendanceEntity> records,
      AttendanceStats stats,
      AttendanceHistoryQuery query,
      String? branchId,
      bool offline,
      bool syncing,
      List<AttendanceDirectoryEntry> directory,
    )?
    loaded,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Loaded value) loaded,
    required TResult Function(_Error value) error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Loaded value)? loaded,
    TResult? Function(_Error value)? error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Loaded value)? loaded,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttendanceHistoryStateCopyWith<$Res> {
  factory $AttendanceHistoryStateCopyWith(
    AttendanceHistoryState value,
    $Res Function(AttendanceHistoryState) then,
  ) = _$AttendanceHistoryStateCopyWithImpl<$Res, AttendanceHistoryState>;
}

/// @nodoc
class _$AttendanceHistoryStateCopyWithImpl<
  $Res,
  $Val extends AttendanceHistoryState
>
    implements $AttendanceHistoryStateCopyWith<$Res> {
  _$AttendanceHistoryStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AttendanceHistoryState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$InitialImplCopyWith<$Res> {
  factory _$$InitialImplCopyWith(
    _$InitialImpl value,
    $Res Function(_$InitialImpl) then,
  ) = __$$InitialImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$InitialImplCopyWithImpl<$Res>
    extends _$AttendanceHistoryStateCopyWithImpl<$Res, _$InitialImpl>
    implements _$$InitialImplCopyWith<$Res> {
  __$$InitialImplCopyWithImpl(
    _$InitialImpl _value,
    $Res Function(_$InitialImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AttendanceHistoryState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$InitialImpl implements _Initial {
  const _$InitialImpl();

  @override
  String toString() {
    return 'AttendanceHistoryState.initial()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$InitialImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(
      List<AttendanceEntity> records,
      AttendanceStats stats,
      AttendanceHistoryQuery query,
      String? branchId,
      bool offline,
      bool syncing,
      List<AttendanceDirectoryEntry> directory,
    )
    loaded,
    required TResult Function(String message) error,
  }) {
    return initial();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(
      List<AttendanceEntity> records,
      AttendanceStats stats,
      AttendanceHistoryQuery query,
      String? branchId,
      bool offline,
      bool syncing,
      List<AttendanceDirectoryEntry> directory,
    )?
    loaded,
    TResult? Function(String message)? error,
  }) {
    return initial?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(
      List<AttendanceEntity> records,
      AttendanceStats stats,
      AttendanceHistoryQuery query,
      String? branchId,
      bool offline,
      bool syncing,
      List<AttendanceDirectoryEntry> directory,
    )?
    loaded,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (initial != null) {
      return initial();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Loaded value) loaded,
    required TResult Function(_Error value) error,
  }) {
    return initial(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Loaded value)? loaded,
    TResult? Function(_Error value)? error,
  }) {
    return initial?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Loaded value)? loaded,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    if (initial != null) {
      return initial(this);
    }
    return orElse();
  }
}

abstract class _Initial implements AttendanceHistoryState {
  const factory _Initial() = _$InitialImpl;
}

/// @nodoc
abstract class _$$LoadingImplCopyWith<$Res> {
  factory _$$LoadingImplCopyWith(
    _$LoadingImpl value,
    $Res Function(_$LoadingImpl) then,
  ) = __$$LoadingImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$LoadingImplCopyWithImpl<$Res>
    extends _$AttendanceHistoryStateCopyWithImpl<$Res, _$LoadingImpl>
    implements _$$LoadingImplCopyWith<$Res> {
  __$$LoadingImplCopyWithImpl(
    _$LoadingImpl _value,
    $Res Function(_$LoadingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AttendanceHistoryState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$LoadingImpl implements _Loading {
  const _$LoadingImpl();

  @override
  String toString() {
    return 'AttendanceHistoryState.loading()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$LoadingImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(
      List<AttendanceEntity> records,
      AttendanceStats stats,
      AttendanceHistoryQuery query,
      String? branchId,
      bool offline,
      bool syncing,
      List<AttendanceDirectoryEntry> directory,
    )
    loaded,
    required TResult Function(String message) error,
  }) {
    return loading();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(
      List<AttendanceEntity> records,
      AttendanceStats stats,
      AttendanceHistoryQuery query,
      String? branchId,
      bool offline,
      bool syncing,
      List<AttendanceDirectoryEntry> directory,
    )?
    loaded,
    TResult? Function(String message)? error,
  }) {
    return loading?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(
      List<AttendanceEntity> records,
      AttendanceStats stats,
      AttendanceHistoryQuery query,
      String? branchId,
      bool offline,
      bool syncing,
      List<AttendanceDirectoryEntry> directory,
    )?
    loaded,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Loaded value) loaded,
    required TResult Function(_Error value) error,
  }) {
    return loading(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Loaded value)? loaded,
    TResult? Function(_Error value)? error,
  }) {
    return loading?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Loaded value)? loaded,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading(this);
    }
    return orElse();
  }
}

abstract class _Loading implements AttendanceHistoryState {
  const factory _Loading() = _$LoadingImpl;
}

/// @nodoc
abstract class _$$LoadedImplCopyWith<$Res> {
  factory _$$LoadedImplCopyWith(
    _$LoadedImpl value,
    $Res Function(_$LoadedImpl) then,
  ) = __$$LoadedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({
    List<AttendanceEntity> records,
    AttendanceStats stats,
    AttendanceHistoryQuery query,
    String? branchId,
    bool offline,
    bool syncing,
    List<AttendanceDirectoryEntry> directory,
  });
}

/// @nodoc
class __$$LoadedImplCopyWithImpl<$Res>
    extends _$AttendanceHistoryStateCopyWithImpl<$Res, _$LoadedImpl>
    implements _$$LoadedImplCopyWith<$Res> {
  __$$LoadedImplCopyWithImpl(
    _$LoadedImpl _value,
    $Res Function(_$LoadedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AttendanceHistoryState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? records = null,
    Object? stats = null,
    Object? query = null,
    Object? branchId = freezed,
    Object? offline = null,
    Object? syncing = null,
    Object? directory = null,
  }) {
    return _then(
      _$LoadedImpl(
        records: null == records
            ? _value._records
            : records // ignore: cast_nullable_to_non_nullable
                  as List<AttendanceEntity>,
        stats: null == stats
            ? _value.stats
            : stats // ignore: cast_nullable_to_non_nullable
                  as AttendanceStats,
        query: null == query
            ? _value.query
            : query // ignore: cast_nullable_to_non_nullable
                  as AttendanceHistoryQuery,
        branchId: freezed == branchId
            ? _value.branchId
            : branchId // ignore: cast_nullable_to_non_nullable
                  as String?,
        offline: null == offline
            ? _value.offline
            : offline // ignore: cast_nullable_to_non_nullable
                  as bool,
        syncing: null == syncing
            ? _value.syncing
            : syncing // ignore: cast_nullable_to_non_nullable
                  as bool,
        directory: null == directory
            ? _value._directory
            : directory // ignore: cast_nullable_to_non_nullable
                  as List<AttendanceDirectoryEntry>,
      ),
    );
  }
}

/// @nodoc

class _$LoadedImpl implements _Loaded {
  const _$LoadedImpl({
    required final List<AttendanceEntity> records,
    required this.stats,
    required this.query,
    this.branchId,
    this.offline = false,
    this.syncing = false,
    final List<AttendanceDirectoryEntry> directory =
        const <AttendanceDirectoryEntry>[],
  }) : _records = records,
       _directory = directory;

  /// The filtered records, newest day first.
  final List<AttendanceEntity> _records;

  /// The filtered records, newest day first.
  @override
  List<AttendanceEntity> get records {
    if (_records is EqualUnmodifiableListView) return _records;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_records);
  }

  /// Summary metrics over [records] (present/late/absent/rate/arrival/worked…).
  @override
  final AttendanceStats stats;

  /// The active filter facets driving [records].
  @override
  final AttendanceHistoryQuery query;

  /// The branch being reviewed (review mode only; null for self-history).
  @override
  final String? branchId;

  /// The snapshot came purely from Firestore's offline cache (device offline).
  @override
  @JsonKey()
  final bool offline;

  /// A local write hasn't been acknowledged by the backend yet ("syncing…").
  @override
  @JsonKey()
  final bool syncing;

  /// The active branch's employee directory (review mode only), so a name
  /// search resolves against everyone — not just the days that produced a
  /// record. Empty in self mode and until the directory loads.
  final List<AttendanceDirectoryEntry> _directory;

  /// The active branch's employee directory (review mode only), so a name
  /// search resolves against everyone — not just the days that produced a
  /// record. Empty in self mode and until the directory loads.
  @override
  @JsonKey()
  List<AttendanceDirectoryEntry> get directory {
    if (_directory is EqualUnmodifiableListView) return _directory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_directory);
  }

  @override
  String toString() {
    return 'AttendanceHistoryState.loaded(records: $records, stats: $stats, query: $query, branchId: $branchId, offline: $offline, syncing: $syncing, directory: $directory)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LoadedImpl &&
            const DeepCollectionEquality().equals(other._records, _records) &&
            (identical(other.stats, stats) || other.stats == stats) &&
            (identical(other.query, query) || other.query == query) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            (identical(other.offline, offline) || other.offline == offline) &&
            (identical(other.syncing, syncing) || other.syncing == syncing) &&
            const DeepCollectionEquality().equals(
              other._directory,
              _directory,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_records),
    stats,
    query,
    branchId,
    offline,
    syncing,
    const DeepCollectionEquality().hash(_directory),
  );

  /// Create a copy of AttendanceHistoryState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LoadedImplCopyWith<_$LoadedImpl> get copyWith =>
      __$$LoadedImplCopyWithImpl<_$LoadedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(
      List<AttendanceEntity> records,
      AttendanceStats stats,
      AttendanceHistoryQuery query,
      String? branchId,
      bool offline,
      bool syncing,
      List<AttendanceDirectoryEntry> directory,
    )
    loaded,
    required TResult Function(String message) error,
  }) {
    return loaded(records, stats, query, branchId, offline, syncing, directory);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(
      List<AttendanceEntity> records,
      AttendanceStats stats,
      AttendanceHistoryQuery query,
      String? branchId,
      bool offline,
      bool syncing,
      List<AttendanceDirectoryEntry> directory,
    )?
    loaded,
    TResult? Function(String message)? error,
  }) {
    return loaded?.call(
      records,
      stats,
      query,
      branchId,
      offline,
      syncing,
      directory,
    );
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(
      List<AttendanceEntity> records,
      AttendanceStats stats,
      AttendanceHistoryQuery query,
      String? branchId,
      bool offline,
      bool syncing,
      List<AttendanceDirectoryEntry> directory,
    )?
    loaded,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (loaded != null) {
      return loaded(
        records,
        stats,
        query,
        branchId,
        offline,
        syncing,
        directory,
      );
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Loaded value) loaded,
    required TResult Function(_Error value) error,
  }) {
    return loaded(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Loaded value)? loaded,
    TResult? Function(_Error value)? error,
  }) {
    return loaded?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Loaded value)? loaded,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    if (loaded != null) {
      return loaded(this);
    }
    return orElse();
  }
}

abstract class _Loaded implements AttendanceHistoryState {
  const factory _Loaded({
    required final List<AttendanceEntity> records,
    required final AttendanceStats stats,
    required final AttendanceHistoryQuery query,
    final String? branchId,
    final bool offline,
    final bool syncing,
    final List<AttendanceDirectoryEntry> directory,
  }) = _$LoadedImpl;

  /// The filtered records, newest day first.
  List<AttendanceEntity> get records;

  /// Summary metrics over [records] (present/late/absent/rate/arrival/worked…).
  AttendanceStats get stats;

  /// The active filter facets driving [records].
  AttendanceHistoryQuery get query;

  /// The branch being reviewed (review mode only; null for self-history).
  String? get branchId;

  /// The snapshot came purely from Firestore's offline cache (device offline).
  bool get offline;

  /// A local write hasn't been acknowledged by the backend yet ("syncing…").
  bool get syncing;

  /// The active branch's employee directory (review mode only), so a name
  /// search resolves against everyone — not just the days that produced a
  /// record. Empty in self mode and until the directory loads.
  List<AttendanceDirectoryEntry> get directory;

  /// Create a copy of AttendanceHistoryState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LoadedImplCopyWith<_$LoadedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ErrorImplCopyWith<$Res> {
  factory _$$ErrorImplCopyWith(
    _$ErrorImpl value,
    $Res Function(_$ErrorImpl) then,
  ) = __$$ErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$ErrorImplCopyWithImpl<$Res>
    extends _$AttendanceHistoryStateCopyWithImpl<$Res, _$ErrorImpl>
    implements _$$ErrorImplCopyWith<$Res> {
  __$$ErrorImplCopyWithImpl(
    _$ErrorImpl _value,
    $Res Function(_$ErrorImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AttendanceHistoryState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? message = null}) {
    return _then(
      _$ErrorImpl(
        null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ErrorImpl implements _Error {
  const _$ErrorImpl(this.message);

  @override
  final String message;

  @override
  String toString() {
    return 'AttendanceHistoryState.error(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ErrorImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of AttendanceHistoryState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ErrorImplCopyWith<_$ErrorImpl> get copyWith =>
      __$$ErrorImplCopyWithImpl<_$ErrorImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(
      List<AttendanceEntity> records,
      AttendanceStats stats,
      AttendanceHistoryQuery query,
      String? branchId,
      bool offline,
      bool syncing,
      List<AttendanceDirectoryEntry> directory,
    )
    loaded,
    required TResult Function(String message) error,
  }) {
    return error(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(
      List<AttendanceEntity> records,
      AttendanceStats stats,
      AttendanceHistoryQuery query,
      String? branchId,
      bool offline,
      bool syncing,
      List<AttendanceDirectoryEntry> directory,
    )?
    loaded,
    TResult? Function(String message)? error,
  }) {
    return error?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(
      List<AttendanceEntity> records,
      AttendanceStats stats,
      AttendanceHistoryQuery query,
      String? branchId,
      bool offline,
      bool syncing,
      List<AttendanceDirectoryEntry> directory,
    )?
    loaded,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Loaded value) loaded,
    required TResult Function(_Error value) error,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Loaded value)? loaded,
    TResult? Function(_Error value)? error,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Loaded value)? loaded,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this);
    }
    return orElse();
  }
}

abstract class _Error implements AttendanceHistoryState {
  const factory _Error(final String message) = _$ErrorImpl;

  String get message;

  /// Create a copy of AttendanceHistoryState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ErrorImplCopyWith<_$ErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

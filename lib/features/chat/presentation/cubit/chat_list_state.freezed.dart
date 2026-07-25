// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_list_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ChatListState {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function() loading,
    required TResult Function(
      List<ChatConversationSummary> conversations,
      bool refreshing,
      bool loadingMore,
      bool hasMore,
      bool starting,
      Map<String, String> previews,
      Map<String, int> unreadCounts,
    )
    loaded,
    required TResult Function(String message) error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(
      List<ChatConversationSummary> conversations,
      bool refreshing,
      bool loadingMore,
      bool hasMore,
      bool starting,
      Map<String, String> previews,
      Map<String, int> unreadCounts,
    )?
    loaded,
    TResult? Function(String message)? error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(
      List<ChatConversationSummary> conversations,
      bool refreshing,
      bool loadingMore,
      bool hasMore,
      bool starting,
      Map<String, String> previews,
      Map<String, int> unreadCounts,
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
abstract class $ChatListStateCopyWith<$Res> {
  factory $ChatListStateCopyWith(
    ChatListState value,
    $Res Function(ChatListState) then,
  ) = _$ChatListStateCopyWithImpl<$Res, ChatListState>;
}

/// @nodoc
class _$ChatListStateCopyWithImpl<$Res, $Val extends ChatListState>
    implements $ChatListStateCopyWith<$Res> {
  _$ChatListStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatListState
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
    extends _$ChatListStateCopyWithImpl<$Res, _$InitialImpl>
    implements _$$InitialImplCopyWith<$Res> {
  __$$InitialImplCopyWithImpl(
    _$InitialImpl _value,
    $Res Function(_$InitialImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChatListState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$InitialImpl implements _Initial {
  const _$InitialImpl();

  @override
  String toString() {
    return 'ChatListState.initial()';
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
      List<ChatConversationSummary> conversations,
      bool refreshing,
      bool loadingMore,
      bool hasMore,
      bool starting,
      Map<String, String> previews,
      Map<String, int> unreadCounts,
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
      List<ChatConversationSummary> conversations,
      bool refreshing,
      bool loadingMore,
      bool hasMore,
      bool starting,
      Map<String, String> previews,
      Map<String, int> unreadCounts,
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
      List<ChatConversationSummary> conversations,
      bool refreshing,
      bool loadingMore,
      bool hasMore,
      bool starting,
      Map<String, String> previews,
      Map<String, int> unreadCounts,
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

abstract class _Initial implements ChatListState {
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
    extends _$ChatListStateCopyWithImpl<$Res, _$LoadingImpl>
    implements _$$LoadingImplCopyWith<$Res> {
  __$$LoadingImplCopyWithImpl(
    _$LoadingImpl _value,
    $Res Function(_$LoadingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChatListState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$LoadingImpl implements _Loading {
  const _$LoadingImpl();

  @override
  String toString() {
    return 'ChatListState.loading()';
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
      List<ChatConversationSummary> conversations,
      bool refreshing,
      bool loadingMore,
      bool hasMore,
      bool starting,
      Map<String, String> previews,
      Map<String, int> unreadCounts,
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
      List<ChatConversationSummary> conversations,
      bool refreshing,
      bool loadingMore,
      bool hasMore,
      bool starting,
      Map<String, String> previews,
      Map<String, int> unreadCounts,
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
      List<ChatConversationSummary> conversations,
      bool refreshing,
      bool loadingMore,
      bool hasMore,
      bool starting,
      Map<String, String> previews,
      Map<String, int> unreadCounts,
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

abstract class _Loading implements ChatListState {
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
    List<ChatConversationSummary> conversations,
    bool refreshing,
    bool loadingMore,
    bool hasMore,
    bool starting,
    Map<String, String> previews,
    Map<String, int> unreadCounts,
  });
}

/// @nodoc
class __$$LoadedImplCopyWithImpl<$Res>
    extends _$ChatListStateCopyWithImpl<$Res, _$LoadedImpl>
    implements _$$LoadedImplCopyWith<$Res> {
  __$$LoadedImplCopyWithImpl(
    _$LoadedImpl _value,
    $Res Function(_$LoadedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChatListState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? conversations = null,
    Object? refreshing = null,
    Object? loadingMore = null,
    Object? hasMore = null,
    Object? starting = null,
    Object? previews = null,
    Object? unreadCounts = null,
  }) {
    return _then(
      _$LoadedImpl(
        null == conversations
            ? _value._conversations
            : conversations // ignore: cast_nullable_to_non_nullable
                  as List<ChatConversationSummary>,
        refreshing: null == refreshing
            ? _value.refreshing
            : refreshing // ignore: cast_nullable_to_non_nullable
                  as bool,
        loadingMore: null == loadingMore
            ? _value.loadingMore
            : loadingMore // ignore: cast_nullable_to_non_nullable
                  as bool,
        hasMore: null == hasMore
            ? _value.hasMore
            : hasMore // ignore: cast_nullable_to_non_nullable
                  as bool,
        starting: null == starting
            ? _value.starting
            : starting // ignore: cast_nullable_to_non_nullable
                  as bool,
        previews: null == previews
            ? _value._previews
            : previews // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>,
        unreadCounts: null == unreadCounts
            ? _value._unreadCounts
            : unreadCounts // ignore: cast_nullable_to_non_nullable
                  as Map<String, int>,
      ),
    );
  }
}

/// @nodoc

class _$LoadedImpl implements _Loaded {
  const _$LoadedImpl(
    final List<ChatConversationSummary> conversations, {
    this.refreshing = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.starting = false,
    final Map<String, String> previews = const <String, String>{},
    final Map<String, int> unreadCounts = const <String, int>{},
  }) : _conversations = conversations,
       _previews = previews,
       _unreadCounts = unreadCounts;

  final List<ChatConversationSummary> _conversations;
  @override
  List<ChatConversationSummary> get conversations {
    if (_conversations is EqualUnmodifiableListView) return _conversations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_conversations);
  }

  @override
  @JsonKey()
  final bool refreshing;
  @override
  @JsonKey()
  final bool loadingMore;
  @override
  @JsonKey()
  final bool hasMore;
  @override
  @JsonKey()
  final bool starting;
  final Map<String, String> _previews;
  @override
  @JsonKey()
  Map<String, String> get previews {
    if (_previews is EqualUnmodifiableMapView) return _previews;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_previews);
  }

  final Map<String, int> _unreadCounts;
  @override
  @JsonKey()
  Map<String, int> get unreadCounts {
    if (_unreadCounts is EqualUnmodifiableMapView) return _unreadCounts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_unreadCounts);
  }

  @override
  String toString() {
    return 'ChatListState.loaded(conversations: $conversations, refreshing: $refreshing, loadingMore: $loadingMore, hasMore: $hasMore, starting: $starting, previews: $previews, unreadCounts: $unreadCounts)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LoadedImpl &&
            const DeepCollectionEquality().equals(
              other._conversations,
              _conversations,
            ) &&
            (identical(other.refreshing, refreshing) ||
                other.refreshing == refreshing) &&
            (identical(other.loadingMore, loadingMore) ||
                other.loadingMore == loadingMore) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore) &&
            (identical(other.starting, starting) ||
                other.starting == starting) &&
            const DeepCollectionEquality().equals(other._previews, _previews) &&
            const DeepCollectionEquality().equals(
              other._unreadCounts,
              _unreadCounts,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_conversations),
    refreshing,
    loadingMore,
    hasMore,
    starting,
    const DeepCollectionEquality().hash(_previews),
    const DeepCollectionEquality().hash(_unreadCounts),
  );

  /// Create a copy of ChatListState
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
      List<ChatConversationSummary> conversations,
      bool refreshing,
      bool loadingMore,
      bool hasMore,
      bool starting,
      Map<String, String> previews,
      Map<String, int> unreadCounts,
    )
    loaded,
    required TResult Function(String message) error,
  }) {
    return loaded(
      conversations,
      refreshing,
      loadingMore,
      hasMore,
      starting,
      previews,
      unreadCounts,
    );
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function()? loading,
    TResult? Function(
      List<ChatConversationSummary> conversations,
      bool refreshing,
      bool loadingMore,
      bool hasMore,
      bool starting,
      Map<String, String> previews,
      Map<String, int> unreadCounts,
    )?
    loaded,
    TResult? Function(String message)? error,
  }) {
    return loaded?.call(
      conversations,
      refreshing,
      loadingMore,
      hasMore,
      starting,
      previews,
      unreadCounts,
    );
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function()? loading,
    TResult Function(
      List<ChatConversationSummary> conversations,
      bool refreshing,
      bool loadingMore,
      bool hasMore,
      bool starting,
      Map<String, String> previews,
      Map<String, int> unreadCounts,
    )?
    loaded,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (loaded != null) {
      return loaded(
        conversations,
        refreshing,
        loadingMore,
        hasMore,
        starting,
        previews,
        unreadCounts,
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

abstract class _Loaded implements ChatListState {
  const factory _Loaded(
    final List<ChatConversationSummary> conversations, {
    final bool refreshing,
    final bool loadingMore,
    final bool hasMore,
    final bool starting,
    final Map<String, String> previews,
    final Map<String, int> unreadCounts,
  }) = _$LoadedImpl;

  List<ChatConversationSummary> get conversations;
  bool get refreshing;
  bool get loadingMore;
  bool get hasMore;
  bool get starting;
  Map<String, String> get previews;
  Map<String, int> get unreadCounts;

  /// Create a copy of ChatListState
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
    extends _$ChatListStateCopyWithImpl<$Res, _$ErrorImpl>
    implements _$$ErrorImplCopyWith<$Res> {
  __$$ErrorImplCopyWithImpl(
    _$ErrorImpl _value,
    $Res Function(_$ErrorImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChatListState
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
    return 'ChatListState.error(message: $message)';
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

  /// Create a copy of ChatListState
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
      List<ChatConversationSummary> conversations,
      bool refreshing,
      bool loadingMore,
      bool hasMore,
      bool starting,
      Map<String, String> previews,
      Map<String, int> unreadCounts,
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
      List<ChatConversationSummary> conversations,
      bool refreshing,
      bool loadingMore,
      bool hasMore,
      bool starting,
      Map<String, String> previews,
      Map<String, int> unreadCounts,
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
      List<ChatConversationSummary> conversations,
      bool refreshing,
      bool loadingMore,
      bool hasMore,
      bool starting,
      Map<String, String> previews,
      Map<String, int> unreadCounts,
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

abstract class _Error implements ChatListState {
  const factory _Error(final String message) = _$ErrorImpl;

  String get message;

  /// Create a copy of ChatListState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ErrorImplCopyWith<_$ErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

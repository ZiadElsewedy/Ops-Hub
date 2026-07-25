// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_conversation_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ChatConversationState {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() loading,
    required TResult Function(
      ChatConversation conversation,
      List<ChatMessage> messages,
      String? myUserId,
      bool sending,
      bool loadingOlder,
      bool hasMore,
      String? deletingMessageId,
    )
    loaded,
    required TResult Function(String message) error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? loading,
    TResult? Function(
      ChatConversation conversation,
      List<ChatMessage> messages,
      String? myUserId,
      bool sending,
      bool loadingOlder,
      bool hasMore,
      String? deletingMessageId,
    )?
    loaded,
    TResult? Function(String message)? error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? loading,
    TResult Function(
      ChatConversation conversation,
      List<ChatMessage> messages,
      String? myUserId,
      bool sending,
      bool loadingOlder,
      bool hasMore,
      String? deletingMessageId,
    )?
    loaded,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Loading value) loading,
    required TResult Function(_Loaded value) loaded,
    required TResult Function(_Error value) error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Loaded value)? loaded,
    TResult? Function(_Error value)? error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Loading value)? loading,
    TResult Function(_Loaded value)? loaded,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatConversationStateCopyWith<$Res> {
  factory $ChatConversationStateCopyWith(
    ChatConversationState value,
    $Res Function(ChatConversationState) then,
  ) = _$ChatConversationStateCopyWithImpl<$Res, ChatConversationState>;
}

/// @nodoc
class _$ChatConversationStateCopyWithImpl<
  $Res,
  $Val extends ChatConversationState
>
    implements $ChatConversationStateCopyWith<$Res> {
  _$ChatConversationStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatConversationState
  /// with the given fields replaced by the non-null parameter values.
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
    extends _$ChatConversationStateCopyWithImpl<$Res, _$LoadingImpl>
    implements _$$LoadingImplCopyWith<$Res> {
  __$$LoadingImplCopyWithImpl(
    _$LoadingImpl _value,
    $Res Function(_$LoadingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChatConversationState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$LoadingImpl implements _Loading {
  const _$LoadingImpl();

  @override
  String toString() {
    return 'ChatConversationState.loading()';
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
    required TResult Function() loading,
    required TResult Function(
      ChatConversation conversation,
      List<ChatMessage> messages,
      String? myUserId,
      bool sending,
      bool loadingOlder,
      bool hasMore,
      String? deletingMessageId,
    )
    loaded,
    required TResult Function(String message) error,
  }) {
    return loading();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? loading,
    TResult? Function(
      ChatConversation conversation,
      List<ChatMessage> messages,
      String? myUserId,
      bool sending,
      bool loadingOlder,
      bool hasMore,
      String? deletingMessageId,
    )?
    loaded,
    TResult? Function(String message)? error,
  }) {
    return loading?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? loading,
    TResult Function(
      ChatConversation conversation,
      List<ChatMessage> messages,
      String? myUserId,
      bool sending,
      bool loadingOlder,
      bool hasMore,
      String? deletingMessageId,
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
    required TResult Function(_Loading value) loading,
    required TResult Function(_Loaded value) loaded,
    required TResult Function(_Error value) error,
  }) {
    return loading(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Loaded value)? loaded,
    TResult? Function(_Error value)? error,
  }) {
    return loading?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
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

abstract class _Loading implements ChatConversationState {
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
    ChatConversation conversation,
    List<ChatMessage> messages,
    String? myUserId,
    bool sending,
    bool loadingOlder,
    bool hasMore,
    String? deletingMessageId,
  });
}

/// @nodoc
class __$$LoadedImplCopyWithImpl<$Res>
    extends _$ChatConversationStateCopyWithImpl<$Res, _$LoadedImpl>
    implements _$$LoadedImplCopyWith<$Res> {
  __$$LoadedImplCopyWithImpl(
    _$LoadedImpl _value,
    $Res Function(_$LoadedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChatConversationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? conversation = null,
    Object? messages = null,
    Object? myUserId = freezed,
    Object? sending = null,
    Object? loadingOlder = null,
    Object? hasMore = null,
    Object? deletingMessageId = freezed,
  }) {
    return _then(
      _$LoadedImpl(
        null == conversation
            ? _value.conversation
            : conversation // ignore: cast_nullable_to_non_nullable
                  as ChatConversation,
        null == messages
            ? _value._messages
            : messages // ignore: cast_nullable_to_non_nullable
                  as List<ChatMessage>,
        myUserId: freezed == myUserId
            ? _value.myUserId
            : myUserId // ignore: cast_nullable_to_non_nullable
                  as String?,
        sending: null == sending
            ? _value.sending
            : sending // ignore: cast_nullable_to_non_nullable
                  as bool,
        loadingOlder: null == loadingOlder
            ? _value.loadingOlder
            : loadingOlder // ignore: cast_nullable_to_non_nullable
                  as bool,
        hasMore: null == hasMore
            ? _value.hasMore
            : hasMore // ignore: cast_nullable_to_non_nullable
                  as bool,
        deletingMessageId: freezed == deletingMessageId
            ? _value.deletingMessageId
            : deletingMessageId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$LoadedImpl implements _Loaded {
  const _$LoadedImpl(
    this.conversation,
    final List<ChatMessage> messages, {
    this.myUserId,
    this.sending = false,
    this.loadingOlder = false,
    this.hasMore = false,
    this.deletingMessageId,
  }) : _messages = messages;

  @override
  final ChatConversation conversation;
  final List<ChatMessage> _messages;
  @override
  List<ChatMessage> get messages {
    if (_messages is EqualUnmodifiableListView) return _messages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_messages);
  }

  @override
  final String? myUserId;
  @override
  @JsonKey()
  final bool sending;
  @override
  @JsonKey()
  final bool loadingOlder;
  @override
  @JsonKey()
  final bool hasMore;
  @override
  final String? deletingMessageId;

  @override
  String toString() {
    return 'ChatConversationState.loaded(conversation: $conversation, messages: $messages, myUserId: $myUserId, sending: $sending, loadingOlder: $loadingOlder, hasMore: $hasMore, deletingMessageId: $deletingMessageId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LoadedImpl &&
            (identical(other.conversation, conversation) ||
                other.conversation == conversation) &&
            const DeepCollectionEquality().equals(other._messages, _messages) &&
            (identical(other.myUserId, myUserId) ||
                other.myUserId == myUserId) &&
            (identical(other.sending, sending) || other.sending == sending) &&
            (identical(other.loadingOlder, loadingOlder) ||
                other.loadingOlder == loadingOlder) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore) &&
            (identical(other.deletingMessageId, deletingMessageId) ||
                other.deletingMessageId == deletingMessageId));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    conversation,
    const DeepCollectionEquality().hash(_messages),
    myUserId,
    sending,
    loadingOlder,
    hasMore,
    deletingMessageId,
  );

  /// Create a copy of ChatConversationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LoadedImplCopyWith<_$LoadedImpl> get copyWith =>
      __$$LoadedImplCopyWithImpl<_$LoadedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() loading,
    required TResult Function(
      ChatConversation conversation,
      List<ChatMessage> messages,
      String? myUserId,
      bool sending,
      bool loadingOlder,
      bool hasMore,
      String? deletingMessageId,
    )
    loaded,
    required TResult Function(String message) error,
  }) {
    return loaded(
      conversation,
      messages,
      myUserId,
      sending,
      loadingOlder,
      hasMore,
      deletingMessageId,
    );
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? loading,
    TResult? Function(
      ChatConversation conversation,
      List<ChatMessage> messages,
      String? myUserId,
      bool sending,
      bool loadingOlder,
      bool hasMore,
      String? deletingMessageId,
    )?
    loaded,
    TResult? Function(String message)? error,
  }) {
    return loaded?.call(
      conversation,
      messages,
      myUserId,
      sending,
      loadingOlder,
      hasMore,
      deletingMessageId,
    );
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? loading,
    TResult Function(
      ChatConversation conversation,
      List<ChatMessage> messages,
      String? myUserId,
      bool sending,
      bool loadingOlder,
      bool hasMore,
      String? deletingMessageId,
    )?
    loaded,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (loaded != null) {
      return loaded(
        conversation,
        messages,
        myUserId,
        sending,
        loadingOlder,
        hasMore,
        deletingMessageId,
      );
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Loading value) loading,
    required TResult Function(_Loaded value) loaded,
    required TResult Function(_Error value) error,
  }) {
    return loaded(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Loaded value)? loaded,
    TResult? Function(_Error value)? error,
  }) {
    return loaded?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
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

abstract class _Loaded implements ChatConversationState {
  const factory _Loaded(
    final ChatConversation conversation,
    final List<ChatMessage> messages, {
    final String? myUserId,
    final bool sending,
    final bool loadingOlder,
    final bool hasMore,
    final String? deletingMessageId,
  }) = _$LoadedImpl;

  ChatConversation get conversation;
  List<ChatMessage> get messages;
  String? get myUserId;
  bool get sending;
  bool get loadingOlder;
  bool get hasMore;
  String? get deletingMessageId;

  /// Create a copy of ChatConversationState
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
    extends _$ChatConversationStateCopyWithImpl<$Res, _$ErrorImpl>
    implements _$$ErrorImplCopyWith<$Res> {
  __$$ErrorImplCopyWithImpl(
    _$ErrorImpl _value,
    $Res Function(_$ErrorImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChatConversationState
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
    return 'ChatConversationState.error(message: $message)';
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

  /// Create a copy of ChatConversationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ErrorImplCopyWith<_$ErrorImpl> get copyWith =>
      __$$ErrorImplCopyWithImpl<_$ErrorImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() loading,
    required TResult Function(
      ChatConversation conversation,
      List<ChatMessage> messages,
      String? myUserId,
      bool sending,
      bool loadingOlder,
      bool hasMore,
      String? deletingMessageId,
    )
    loaded,
    required TResult Function(String message) error,
  }) {
    return error(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? loading,
    TResult? Function(
      ChatConversation conversation,
      List<ChatMessage> messages,
      String? myUserId,
      bool sending,
      bool loadingOlder,
      bool hasMore,
      String? deletingMessageId,
    )?
    loaded,
    TResult? Function(String message)? error,
  }) {
    return error?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? loading,
    TResult Function(
      ChatConversation conversation,
      List<ChatMessage> messages,
      String? myUserId,
      bool sending,
      bool loadingOlder,
      bool hasMore,
      String? deletingMessageId,
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
    required TResult Function(_Loading value) loading,
    required TResult Function(_Loaded value) loaded,
    required TResult Function(_Error value) error,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Loaded value)? loaded,
    TResult? Function(_Error value)? error,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
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

abstract class _Error implements ChatConversationState {
  const factory _Error(final String message) = _$ErrorImpl;

  String get message;

  /// Create a copy of ChatConversationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ErrorImplCopyWith<_$ErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

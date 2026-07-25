import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/chat/domain/usecases/get_chat_directory.dart';
import 'new_chat_state.dart';

/// Loads the teammate directory for the new-conversation picker. Read-only:
/// starting the conversation is [ChatListCubit.startChatWith] (the inbox owns
/// that, so the new thread lands in the list). Built per-open via
/// [AppDependencies.createNewChatCubit].
///
/// Scope is decided ENTIRELY by [GetChatDirectory] (every active user but the
/// caller — no branch, no role). This cubit adds no filtering of its own; the
/// only other filter in the feature is the view's search box.
class NewChatCubit extends Cubit<NewChatState> {
  final GetChatDirectory _getChatDirectory;
  final UserEntity? _currentUser;

  NewChatCubit({
    required this._getChatDirectory,
    required this._currentUser,
  }) : super(const NewChatLoading()) {
    load();
  }

  Future<void> load() async {
    if (!isClosed) emit(const NewChatLoading());
    try {
      final teammates = await _getChatDirectory(_currentUser);
      if (!isClosed) emit(NewChatLoaded(teammates));
    } on Failure catch (e) {
      if (!isClosed) emit(NewChatError(e.message));
    } catch (e) {
      AppLog.warning('chat', 'teammate directory load failed: $e');
      if (!isClosed) {
        emit(const NewChatError('Failed to load teammates. Please try again.'));
      }
    }
  }
}

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/enums/case_category.dart';
import 'package:opshub/core/utils/app_logger.dart';
import 'package:opshub/core/enums/case_privacy.dart';
import 'package:opshub/core/enums/case_recipient.dart';
import 'package:opshub/core/enums/case_status.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/core/services/case_seen_store.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:opshub/features/branch/domain/repositories/branch_repository.dart';
import 'package:opshub/features/cases/domain/entities/case_entity.dart';
import 'package:opshub/features/cases/domain/entities/case_identity.dart';
import 'package:opshub/features/cases/domain/repositories/case_repository.dart';
import 'package:opshub/features/cases/domain/usecases/create_case.dart';
import 'package:opshub/features/cases/domain/usecases/upload_case_attachment.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';
import 'package:opshub/core/media/picked_attachment.dart';
import 'case_list_state.dart';

/// Drives the Case inbox (the list) for all three roles. The list is scoped by
/// role:
///   admin    → every case (realtime stream);
///   manager  → own-branch, non-admin-routed cases (realtime) + any case they
///              filed themselves;
///   employee → their own cases (one-shot fetch via the private `reporter`
///              collectionGroup; the case doc carries no creator uid).
///
/// Conversation + status live in [CaseConversationCubit]; this cubit only
/// handles the list, opening a case, deleting, revealing a sender, and the
/// desktop split-pane selection. Notifications are produced **server-side**.
class CaseListCubit extends Cubit<CaseListState> {
  final CaseRepository _repository;
  final BranchRepository _branchRepository;
  final CreateCase _createCase;
  final UploadCaseAttachment _uploadCaseAttachment;
  final GetUsersByBranch _getUsersByBranch;
  final CaseSeenStore _seenStore;

  UserEntity? _user;
  StreamSubscription<List<CaseEntity>>? _scopeSub;
  List<CaseEntity> _scopeCases = const [];
  List<CaseEntity> _mineCases = const [];
  bool _mutating = false;
  String? _selectedId;

  final Map<String, UserEntity> _directory = {};
  final Set<String> _fetchedBranches = {};
  final Map<String, String> _branchNames = {};

  Map<String, UserEntity> get directory => Map.unmodifiable(_directory);
  Map<String, String> get branchNames => Map.unmodifiable(_branchNames);
  String? get selectedId => _selectedId;

  CaseListCubit({
    required this._repository,
    required this._branchRepository,
    required this._createCase,
    required this._uploadCaseAttachment,
    required this._getUsersByBranch,
    required this._seenStore,
  }) : super(const CaseListState.initial());

  List<CaseEntity> get _cases =>
      state.maybeWhen(loaded: (c, _, _, _, _) => c, orElse: () => const []);

  /// Ids of cases with activity newer than the viewer last opened them.
  Set<String> _computeUnread(List<CaseEntity> list) => {
        for (final c in list)
          if (_seenStore.isUnread(c.id, c.lastActivityAt)) c.id,
      };

  CaseEntity? caseById(String id) {
    for (final c in _cases) {
      if (c.id == id) return c;
    }
    return null;
  }

  static String _scopeKey(UserEntity u) =>
      '${u.uid}:${u.role.value}:${u.branchId ?? ''}';

  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {
    // Scope the inbox unread-tracking to this user (idempotent after the first
    // load; always refreshes the active uid so an account switch is clean).
    await _seenStore.load(user.uid);
    final inError = state.maybeWhen(error: (_) => true, orElse: () => false);
    final sameScope = _user != null && _scopeKey(_user!) == _scopeKey(user);
    if (!forceRefresh && !inError && _scopeSubActive && sameScope) return;

    if (!sameScope) {
      _directory.clear();
      _fetchedBranches.clear();
      _branchNames.clear();
      _scopeCases = const [];
      _mineCases = const [];
      _selectedId = null;
    }
    _user = user;
    _loadBranchNames();

    final hasCases =
        state.maybeWhen(loaded: (_, _, _, _, _) => true, orElse: () => false);
    if (!hasCases) emit(const CaseListState.loading());

    await _scopeSub?.cancel();
    _scopeSub = null;

    AppLog.call('cases', 'load', meta: {
      'role': user.role.value,
      'uid': user.uid,
      'branch': user.branchId ?? '-',
    });
    if (user.role.isAdmin) {
      _subscribeScope(_repository.watchAllCases());
    } else if (user.role.isManager) {
      _subscribeScope(_repository.watchBranchCases(user.branchId ?? ''));
      await _loadMine(user); // + any admin-routed case they filed
    } else {
      await _loadMine(user); // employee: own cases only (no stream)
    }
  }

  bool get _scopeSubActive =>
      _scopeSub != null || _user?.role.isEmployee == true;

  void _subscribeScope(Stream<List<CaseEntity>> stream) {
    _scopeSub = stream.listen(
      (cases) {
        _scopeCases = cases;
        _emitMerged();
      },
      onError: (Object error, StackTrace st) {
        AppLog.error('cases', 'stream exception', error, st);
        emit(const CaseListState.error('Failed to load cases. Please try again.'));
      },
    );
  }

  Future<void> _loadMine(UserEntity user) async {
    try {
      _mineCases = await _repository.getMyCases(user.uid);
      _emitMerged();
    } catch (e, st) {
      AppLog.error('cases', 'getMyCases failed', e, st);
      if (user.role.isEmployee && _mineCases.isEmpty) {
        emit(const CaseListState.error('Failed to load your cases.'));
      }
    }
  }

  Future<void> refresh() async {
    final user = _user;
    if (user != null) await load(user, forceRefresh: true);
  }

  /// Select a case for the desktop split-pane's right side. Opening a case marks
  /// it seen, so its unread flag clears immediately.
  void select(String? caseId) {
    _selectedId = caseId;
    if (caseId != null) {
      _seenStore.markSeen(caseId, caseById(caseId)?.lastActivityAt);
    }
    _emitMerged();
  }

  /// Marks a case seen (mobile opens it via a pushed route, not [select]). Only
  /// re-emits when the seen-state actually advanced.
  void markSeen(String caseId) {
    if (_seenStore.markSeen(caseId, caseById(caseId)?.lastActivityAt)) {
      _emitMerged();
    }
  }

  /// Merges the role stream + the caller's own cases (deduped by id) and emits
  /// the inbox-ordered list, preserving any in-flight busy flag + selection.
  void _emitMerged() {
    if (isClosed) return;
    final merged = <String, CaseEntity>{};
    for (final c in _scopeCases) {
      merged[c.id] = c;
    }
    for (final c in _mineCases) {
      merged.putIfAbsent(c.id, () => c);
    }
    // The repository already ordered each source; re-order the merged set.
    final list = merged.values.toList()
      ..sort((a, b) {
        // active before closed, urgent first, latest activity desc.
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        if (a.isActive && a.urgent != b.urgent) return a.urgent ? -1 : 1;
        final at = a.lastActivityAt, bt = b.lastActivityAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
    // The desktop-open case is on screen — keep it read as new replies land, so
    // it never re-flags itself unread while you're looking at it.
    final sel = _selectedId;
    if (sel != null) {
      final c = merged[sel];
      if (c != null) _seenStore.markSeen(sel, c.lastActivityAt);
    }
    emit(CaseListState.loaded(list,
        busy: _mutating,
        directory: Map.of(_directory),
        selectedId: _selectedId,
        unreadIds: _computeUnread(list)));
    _ensureDirectory(list);
  }

  Future<void> _loadBranchNames() async {
    try {
      final list = await _branchRepository.getBranches();
      for (final b in list) {
        _branchNames[b.id] = b.name;
      }
    } catch (e) {
      AppLog.warning('cases', 'branch-name enrichment failed: $e');
    }
  }

  Future<void> _ensureDirectory(List<CaseEntity> cases) async {
    final branchIds = <String>{
      for (final c in cases)
        if ((c.branchId ?? '').isNotEmpty) c.branchId!,
    }..removeAll(_fetchedBranches);
    if (branchIds.isEmpty) return;

    var changed = false;
    for (final branchId in branchIds) {
      _fetchedBranches.add(branchId);
      try {
        final users = await _getUsersByBranch(branchId);
        for (final u in users) {
          _directory[u.uid] = u;
          changed = true;
        }
      } catch (e) {
        AppLog.warning('cases', 'member-directory enrichment failed: $e');
      }
    }
    if (changed && !isClosed) {
      state.mapOrNull(
        loaded: (s) => emit(s.copyWith(directory: Map.of(_directory))),
      );
    }
  }

  // ─── Opening a case (any non-admin role) ───────────────────────
  Future<CaseEntity?> openCase({
    required String subject,
    String? description,
    required CaseCategory category,
    required CaseRecipient recipient,
    required CasePrivacy privacy,
    bool urgent = false,
    List<PickedAttachment> attachments = const [],
  }) async {
    final user = _user;
    if (user == null || _mutating) return null;
    _mutating = true;
    emit(CaseListState.loaded(_cases,
        busy: true,
        directory: Map.of(_directory),
        selectedId: _selectedId,
        unreadIds: _computeUnread(_cases)));

    CaseEntity? created;
    try {
      // Pre-generate the id so opening media uploads under it BEFORE the doc is
      // written (so `onCaseCreated` sees the attachments).
      final caseId = _repository.newCaseId();
      final normal = privacy.isNormal;
      final uploaded = <TaskAttachment>[];
      if (attachments.isNotEmpty) {
        uploaded.addAll(await Future.wait([
          for (final a in attachments)
            _uploadCaseAttachment(
              caseId: caseId,
              file: a.file,
              type: a.type,
              uploadedBy: normal ? user.uid : '',
              uploadedByName: normal ? user.displayName : 'Confidential Sender',
              durationMs: a.durationMs,
            ),
        ]));
      }
      final desc = description?.trim();
      final entity = CaseEntity(
        id: caseId,
        branchId: user.branchId,
        subject: subject.trim(),
        description: (desc == null || desc.isEmpty) ? null : desc,
        category: category,
        recipient: recipient,
        privacy: privacy,
        urgent: urgent,
        status: CaseStatus.open,
        reporterDisplayName: normal ? user.displayName : null,
        attachments: uploaded,
        // Optimistic preview so the reporter's one-shot list shows something
        // before `onCaseCreated` bumps it.
        lastMessagePreview: (desc != null && desc.isNotEmpty)
            ? desc
            : (uploaded.isNotEmpty ? '📎 Attachment' : null),
      );
      final identity = CaseIdentity(
        caseId: caseId,
        createdByUserId: user.uid,
        createdByName: user.displayName,
        privacy: privacy,
        branchId: user.branchId,
      );
      created = await _createCase(entity, identity);
      _mutating = false;
      // Re-pull the one-shot "mine" list so the freshly-opened case appears
      // (the admin stream self-updates; non-admins read from `mine`).
      if (!user.role.isAdmin) await _loadMine(user);
      _emitMerged();
      return created;
    } on Failure catch (e) {
      _mutating = false;
      emit(CaseListState.error(e.message));
      _emitMerged();
      return null;
    } catch (_) {
      _mutating = false;
      emit(const CaseListState.error('Something went wrong. Please try again.'));
      _emitMerged();
      return null;
    }
  }

  /// Fetches a single case by id (a deep-link not in the current scoped list).
  Future<CaseEntity?> fetchCase(String caseId) async {
    try {
      return await _repository.getCase(caseId);
    } catch (_) {
      return null;
    }
  }

  /// Reads the private reporter identity — an admin revealing a confidential
  /// sender (or the owner reading their own). Returns null on failure/absence.
  Future<CaseIdentity?> revealReporter(String caseId) async {
    try {
      return await _repository.revealReporter(caseId);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteCase(String caseId) async {
    if (_user == null || _mutating) return;
    _mutating = true;
    emit(CaseListState.loaded(_cases,
        busy: true,
        directory: Map.of(_directory),
        selectedId: _selectedId,
        unreadIds: _computeUnread(_cases)));
    try {
      await _repository.deleteCase(caseId);
      if (_selectedId == caseId) _selectedId = null;
    } on Failure catch (e) {
      emit(CaseListState.error(e.message));
    } catch (_) {
      emit(const CaseListState.error('Failed to delete the case.'));
    } finally {
      _mutating = false;
      final user = _user;
      if (user != null && !user.role.isAdmin) await _loadMine(user);
      _emitMerged();
    }
  }

  Future<List<UserEntity>> branchMembers(String branchId) async {
    try {
      return await _getUsersByBranch(branchId);
    } catch (_) {
      return const [];
    }
  }

  /// Drops the user-scoped stream and every cached list, returning the cubit to
  /// [CaseListState.initial]. Called on sign-out and on single-active-session
  /// eviction — this cubit is app-wide, so its stream and its cached
  /// conversations would otherwise outlive the session that was allowed to read
  /// them. Cases are confidential, which makes the leak worse here than most.
  void reset() {
    _scopeSub?.cancel();
    _scopeSub = null;
    _scopeCases = const [];
    _mineCases = const [];
    _selectedId = null;
    _mutating = false;
    _directory.clear();
    _fetchedBranches.clear();
    _branchNames.clear();
    _user = null;
    if (!isClosed) emit(const CaseListState.initial());
  }

  @override
  Future<void> close() {
    _scopeSub?.cancel();
    return super.close();
  }
}

/// The **global task feed** engine (Home Dashboard redesign, P2). Pure Dart —
/// no Flutter, no Firestore — so filtering / searching / sorting / grouping the
/// homepage feed is unit-testable and runs over the already-in-memory
/// `TaskCubit` stream (zero new reads). Archived tasks are already dropped
/// upstream (`TaskRepositoryImpl`); this engine works on the active set.
///
/// Filtering is O(n) over the small live set — no index, offline-capable,
/// instant. The urgency-ranked "Smart" sort is P3; P2 ships due-date / priority
/// / newest.
library;

import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/task_assignment_type.dart';
import 'package:opshub/core/enums/task_priority.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/task/domain/active_window.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';

/// One-tap compound filters pinned as chips. (A user-defined saved-view builder
/// is deliberately NOT built — see the redesign doc.)
enum FeedPreset { overdue, needsReview, dueToday, unassigned }

/// How the feed is bucketed into collapsible sections.
enum FeedGrouping { dueTime, branch, employee, priority }

/// Ordering applied within the flat list / within each group. [smart] is the
/// lightweight "Smart Queue" ranking (see [smartRank]) — the default.
enum FeedSort { smart, dueDate, priority, newest }

extension FeedPresetX on FeedPreset {
  String get label => switch (this) {
    FeedPreset.overdue => 'Late',
    FeedPreset.needsReview => 'Needs review',
    FeedPreset.dueToday => 'Due today',
    FeedPreset.unassigned => 'Unassigned',
  };
}

extension FeedGroupingX on FeedGrouping {
  String get label => switch (this) {
    FeedGrouping.dueTime => 'Due',
    FeedGrouping.branch => 'Branch',
    FeedGrouping.employee => 'Employee',
    FeedGrouping.priority => 'Priority',
  };
}

extension FeedSortX on FeedSort {
  String get label => switch (this) {
    FeedSort.smart => 'Smart Queue',
    FeedSort.dueDate => 'Due date',
    FeedSort.priority => 'Priority',
    FeedSort.newest => 'Newest',
  };
}

/// Sentinel so [TaskFeedFilter.copyWith] can distinguish "leave unchanged" from
/// "clear to null" for the nullable fields.
const Object _unset = Object();

/// The immutable feed query. Screen-local + ephemeral (no cubit) — the feed
/// section owns one and rebuilds the list on change.
class TaskFeedFilter {
  const TaskFeedFilter({
    this.branchId,
    this.assigneeUid,
    this.shift,
    this.priority,
    this.status,
    this.statuses,
    this.query = '',
    this.preset,
    this.grouping = FeedGrouping.dueTime,
    // Default = Due Date (grouped). Smart Queue is an explicit opt-in sort until
    // its ranking heuristic is validated against real usage.
    this.sort = FeedSort.dueDate,
    // Default true = today's behaviour (the homepage feed only ever wants the
    // active window). A drill-down onto a **closed** record set (Missed,
    // Cancelled, Done) opts out — see [isTaskInActiveWindow], which otherwise
    // excludes exactly those statuses and would render an empty page.
    this.activeWindowOnly = true,
  });

  final String? branchId;
  final String? assigneeUid;
  final ScheduleShift? shift;
  final TaskPriority? priority;
  final TaskStatus? status;

  /// A wider status match than [status] — a task counts when its status is a
  /// member of this set. Composes (AND) with [status]. Exists for filters that
  /// are a *group* of statuses (e.g. "Active" = pending/started/completed/
  /// rejected) rather than one — [status] stays a single value so every
  /// existing single-status call site is untouched.
  final Set<TaskStatus>? statuses;
  final String query;
  final FeedPreset? preset;
  final FeedGrouping grouping;
  final FeedSort sort;

  /// Scope switch, not a user filter — deliberately excluded from
  /// [hasActiveFilters] (it decides *which record set* is being browsed, not
  /// whether the browsing user has narrowed it).
  final bool activeWindowOnly;

  bool get hasActiveFilters =>
      branchId != null ||
      assigneeUid != null ||
      shift != null ||
      priority != null ||
      status != null ||
      statuses != null ||
      preset != null ||
      query.trim().isNotEmpty;

  TaskFeedFilter copyWith({
    Object? branchId = _unset,
    Object? assigneeUid = _unset,
    Object? shift = _unset,
    Object? priority = _unset,
    Object? status = _unset,
    Object? statuses = _unset,
    String? query,
    Object? preset = _unset,
    FeedGrouping? grouping,
    FeedSort? sort,
    bool? activeWindowOnly,
  }) => TaskFeedFilter(
    branchId: branchId == _unset ? this.branchId : branchId as String?,
    assigneeUid: assigneeUid == _unset
        ? this.assigneeUid
        : assigneeUid as String?,
    shift: shift == _unset ? this.shift : shift as ScheduleShift?,
    priority: priority == _unset ? this.priority : priority as TaskPriority?,
    status: status == _unset ? this.status : status as TaskStatus?,
    statuses: statuses == _unset
        ? this.statuses
        : statuses as Set<TaskStatus>?,
    query: query ?? this.query,
    preset: preset == _unset ? this.preset : preset as FeedPreset?,
    grouping: grouping ?? this.grouping,
    sort: sort ?? this.sort,
    activeWindowOnly: activeWindowOnly ?? this.activeWindowOnly,
  );

  /// Toggles [p] on/off (tapping the active preset clears it).
  TaskFeedFilter togglePreset(FeedPreset p) =>
      copyWith(preset: preset == p ? null : p);
}

/// A collapsible section of the feed (bucket header + its tasks).
class FeedGroup {
  const FeedGroup({
    required this.key,
    required this.label,
    required this.tasks,
    required this.order,
  });

  /// Stable id for a `PageStorageKey` (collapse state) + list keys.
  final String key;
  final String label;
  final List<TaskEntity> tasks;

  /// Lower sorts first (see [groupFeed]).
  final int order;
}

/// Whether [t] is past its [TaskEntity.deadline] and still needs work. Terminal
/// states (approved / completed / submitted-for-review / missed) are never
/// "overdue".
/// The one shared definition — the row, the KPI, and the preset all use it.
bool isTaskOverdue(TaskEntity t, DateTime now) {
  final d = t.deadline;
  if (d == null) return false;
  final terminal =
      t.status.isTerminal ||
      t.status == TaskStatus.completed ||
      t.status == TaskStatus.waitingReview;
  return !terminal && d.isBefore(now);
}

/// Filters [tasks] to the feed's **active set** (active work + work approved
/// today — [isTaskInActiveWindow]) narrowed by [filter], then sorts. The scope
/// filters (branch/assignee/shift/priority/status), the [FeedPreset], and the
/// text query all compose (AND).
List<TaskEntity> applyFeed(
  List<TaskEntity> tasks,
  TaskFeedFilter filter,
  DateTime now, {
  Map<String, UserEntity> directory = const {},
  Map<String, String> branchNames = const {},
}) {
  final q = filter.query.trim().toLowerCase();
  final result = <TaskEntity>[];
  for (final t in tasks) {
    // Base: only active work + done-today (keeps stale-approved out of the feed
    // even before the retention pass archives them). [activeWindowOnly] lets a
    // caller opt out for a drill-down onto a closed record set.
    if (filter.activeWindowOnly && !isTaskInActiveWindow(t, now)) continue;
    if (filter.branchId != null && t.branchId != filter.branchId) continue;
    if (filter.assigneeUid != null &&
        !t.assigneeIds.contains(filter.assigneeUid)) {
      continue;
    }
    if (filter.shift != null && t.shift != filter.shift) continue;
    if (filter.priority != null && t.priority != filter.priority) continue;
    if (filter.status != null && t.status != filter.status) continue;
    if (filter.statuses != null && !filter.statuses!.contains(t.status)) {
      continue;
    }
    if (filter.preset != null && !_matchesPreset(t, filter.preset!, now)) {
      continue;
    }
    if (q.isNotEmpty && !_matchesQuery(t, q, directory, branchNames)) {
      continue;
    }
    result.add(t);
  }
  _sortFeed(result, filter.sort, now);
  return result;
}

/// Lightweight **Smart Queue** ranking — a stepping stone to the full urgency
/// engine (validate this before building that). Lower = more urgent:
///
///   0 · overdue + high priority   3 · due today
///   1 · pending review            4 · everything else
///   2 · overdue (any priority)
int smartRank(TaskEntity t, DateTime now) {
  final overdue = isTaskOverdue(t, now);
  if (overdue && t.priority == TaskPriority.high) return 0;
  if (t.status == TaskStatus.waitingReview) return 1;
  if (overdue) return 2;
  final d = t.deadline;
  if (d != null && _sameDay(d, now) && !_isDone(t)) return 3;
  return 4;
}

/// Buckets [tasks] (already filtered/sorted by [applyFeed]) into ordered,
/// collapsible [FeedGroup]s. Task order within a group is preserved.
List<FeedGroup> groupFeed(
  List<TaskEntity> tasks,
  FeedGrouping grouping,
  DateTime now, {
  Map<String, UserEntity> directory = const {},
  Map<String, String> branchNames = const {},
}) {
  final acc = <String, _Acc>{};
  for (final t in tasks) {
    final b = _bucketFor(t, grouping, now, directory, branchNames);
    (acc[b.key] ??= _Acc(b.label, b.order)).tasks.add(t);
  }
  final groups = [
    for (final e in acc.entries)
      FeedGroup(
        key: e.key,
        label: e.value.label,
        order: e.value.order,
        tasks: e.value.tasks,
      ),
  ];
  groups.sort((a, b) {
    final c = a.order.compareTo(b.order);
    return c != 0 ? c : a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });
  return groups;
}

// ─── internals ──────────────────────────────────────────────────────

class _Acc {
  _Acc(this.label, this.order);
  final String label;
  final int order;
  final List<TaskEntity> tasks = [];
}

bool _isDone(TaskEntity t) =>
    t.status.isTerminal || t.status == TaskStatus.completed;

bool _matchesPreset(TaskEntity t, FeedPreset p, DateTime now) => switch (p) {
  FeedPreset.overdue => isTaskOverdue(t, now),
  FeedPreset.needsReview => t.status == TaskStatus.waitingReview,
  FeedPreset.dueToday =>
    t.deadline != null && _sameDay(t.deadline!, now) && !_isDone(t),
  // Shift tasks target a shift (never "unassigned"); only individual/team
  // tasks with no assignee count.
  FeedPreset.unassigned =>
    t.assignmentType != TaskAssignmentType.shift && t.assigneeIds.isEmpty,
};

bool _matchesQuery(
  TaskEntity t,
  String q,
  Map<String, UserEntity> directory,
  Map<String, String> branchNames,
) {
  if (t.title.toLowerCase().contains(q)) return true;
  final desc = t.description;
  if (desc != null && desc.toLowerCase().contains(q)) return true;
  final bn = branchNames[t.branchId];
  if (bn != null && bn.toLowerCase().contains(q)) return true;
  for (final uid in t.assigneeIds) {
    final u = directory[uid];
    if (u == null) continue;
    final name =
        ((u.displayName?.isNotEmpty ?? false) ? u.displayName! : u.email)
            .toLowerCase();
    if (name.contains(q)) return true;
  }
  return false;
}

void _sortFeed(List<TaskEntity> list, FeedSort sort, DateTime now) {
  switch (sort) {
    case FeedSort.smart:
      list.sort((a, b) {
        final c = smartRank(a, now).compareTo(smartRank(b, now));
        return c != 0 ? c : _compareDue(a, b);
      });
    case FeedSort.dueDate:
      list.sort(_compareDue);
    case FeedSort.priority:
      list.sort((a, b) {
        final c = _prioRank(b.priority).compareTo(_prioRank(a.priority));
        return c != 0 ? c : _compareDue(a, b);
      });
    case FeedSort.newest:
      list.sort((a, b) => _epoch(b.createdAt).compareTo(_epoch(a.createdAt)));
  }
}

/// Done last; then dated-before-undated; then earliest deadline first (overdue
/// floats up). Stable and total so sorts never throw on nulls.
int _compareDue(TaskEntity a, TaskEntity b) {
  final ad = _isDone(a), bd = _isDone(b);
  if (ad != bd) return ad ? 1 : -1;
  final x = a.deadline, y = b.deadline;
  if (x == null && y == null) return 0;
  if (x == null) return 1;
  if (y == null) return -1;
  return x.compareTo(y);
}

int _prioRank(TaskPriority p) => switch (p) {
  TaskPriority.high => 2,
  TaskPriority.normal => 1,
  TaskPriority.low => 0,
};

int _epoch(DateTime? d) => d?.millisecondsSinceEpoch ?? 0;

({String key, String label, int order}) _bucketFor(
  TaskEntity t,
  FeedGrouping g,
  DateTime now,
  Map<String, UserEntity> directory,
  Map<String, String> branchNames,
) {
  switch (g) {
    case FeedGrouping.dueTime:
      if (_isDone(t)) return (key: 'done', label: 'Done today', order: 5);
      if (isTaskOverdue(t, now)) {
        return (key: 'overdue', label: 'Late', order: 0);
      }
      final d = t.deadline;
      if (d == null) return (key: 'nodate', label: 'No due date', order: 4);
      if (_sameDay(d, now)) return (key: 'today', label: 'Today', order: 1);
      final weekEnd = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 7));
      if (d.isBefore(weekEnd)) {
        return (key: 'week', label: 'This week', order: 2);
      }
      return (key: 'later', label: 'Later', order: 3);

    case FeedGrouping.branch:
      final id = t.branchId ?? '';
      final name = branchNames[id];
      if (name == null || name.isEmpty) {
        return (key: 'b:none', label: 'Unknown branch', order: 1);
      }
      return (key: 'b:$id', label: name, order: 0);

    case FeedGrouping.employee:
      if (t.assignmentType == TaskAssignmentType.shift) {
        final s = t.shift;
        final label = s == null ? 'Shift task' : '${s.label} shift';
        return (key: 's:${s?.value ?? "any"}', label: label, order: 1);
      }
      if (t.assigneeIds.isEmpty) {
        return (key: 'u:none', label: 'Unassigned', order: 2);
      }
      final uid = t.assigneeIds.first;
      final u = directory[uid];
      final name = u == null
          ? 'Someone'
          : ((u.displayName?.isNotEmpty ?? false) ? u.displayName! : u.email);
      return (key: 'u:$uid', label: name, order: 0);

    case FeedGrouping.priority:
      return switch (t.priority) {
        TaskPriority.high => (key: 'p:high', label: 'High', order: 0),
        TaskPriority.normal => (key: 'p:normal', label: 'Normal', order: 1),
        TaskPriority.low => (key: 'p:low', label: 'Low', order: 2),
      };
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

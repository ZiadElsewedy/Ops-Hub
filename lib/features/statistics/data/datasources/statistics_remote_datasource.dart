import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/constants/app_constants.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/features/schedule/domain/schedule_week.dart';
import 'package:opshub/features/statistics/data/models/statistics_model.dart';

typedef _Doc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Computes operational statistics by aggregating the branch-scoped collections
/// (users / tasks / weekly_schedules / branches). Uses single-field queries +
/// client-side counting to stay branch-scoped without composite indexes;
/// `count()` aggregate queries are a future optimization if data volume grows.
///
/// Phase 7: the "today's shift" / morning-night / coverage figures now come from
/// the **weekly schedule** (`weekly_schedules`), the production roster, rather
/// than the Phase 2 `shifts` placeholder collection.
abstract class StatisticsRemoteDataSource {
  Future<StatisticsModel> adminStats();
  Future<StatisticsModel> managerStats(String branchId);
  Future<StatisticsModel> employeeStats(String uid, String? branchId);
}

class StatisticsRemoteDataSourceImpl implements StatisticsRemoteDataSource {
  final FirebaseFirestore _firestore;

  StatisticsRemoteDataSourceImpl(this._firestore);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(AppConstants.usersCollection);
  CollectionReference<Map<String, dynamic>> get _tasks =>
      _firestore.collection(AppConstants.tasksCollection);
  CollectionReference<Map<String, dynamic>> get _branches =>
      _firestore.collection(AppConstants.branchesCollection);
  CollectionReference<Map<String, dynamic>> get _schedules =>
      _firestore.collection(AppConstants.weeklySchedulesCollection);

  static int _count(List<_Doc> docs, bool Function(Map<String, dynamic>) test) =>
      docs.where((d) => test(d.data())).length;

  /// Count for [query]. Online it uses server-side **aggregation** — no document
  /// downloads (one read unit per ~1000 index entries instead of N doc reads).
  ///
  /// Aggregation queries are **server-only** (no offline cache support), so when
  /// the client is offline `count().get()` throws `unavailable`. In that case we
  /// fall back to counting the **same query's** documents from the local cache
  /// (`Source.cache`) — last-known values, no network, no hard failure. The
  /// fallback only ever reads the already-filtered query's cached docs (offline
  /// only); the online path never downloads documents. Non-offline errors
  /// (e.g. `permission-denied`) are rethrown so genuine failures still surface.
  static Future<int> _aggCount(Query<Map<String, dynamic>> query) async {
    try {
      return (await query.count().get()).count ?? 0;
    } on FirebaseException catch (e) {
      if (e.code != 'unavailable') rethrow;
      final cached = await query.get(const GetOptions(source: Source.cache));
      return cached.docs.length;
    }
  }

  static bool _isToday(dynamic ts, DateTime startOfToday) =>
      ts is Timestamp && !ts.toDate().isBefore(startOfToday);

  /// Employee uids assigned to a (day, shift) slot in a schedule doc's map.
  static List<String> _slot(
      Map<String, dynamic>? schedule, String day, String shift) {
    final assignments = schedule?['assignments'] as Map<String, dynamic>?;
    final dayMap = assignments?[day] as Map<String, dynamic>?;
    final list = dayMap?[shift] as List?;
    return list?.whereType<String>().toList() ?? const [];
  }

  bool _isActive(Map<String, dynamic> t) {
    final s = t['status'] as String? ?? 'pending';
    return s != 'approved' && s != 'rejected';
  }

  @override
  Future<StatisticsModel> adminStats() async {
    try {
      final now = DateTime.now();
      final startToday = DateTime(now.year, now.month, now.day);
      final weekStart = ScheduleWeek.currentWeekStart();

      // Branches are few (one doc per branch) and we need their ids for the
      // cross-referenced coverage metrics below — read them in full.
      final branches = (await _branches.get())
          .docs
          .where((d) => d.data()['deletedAt'] == null)
          .toList();

      // Managers are few — read them (not all users) so we get both the count
      // and their branchIds for `branchesWithoutManagers`.
      final managers =
          (await _users.where('role', isEqualTo: 'manager').get()).docs;
      final managerBranchIds = <String>{
        for (final m in managers)
          if ((m.data()['branchId'] as String?)?.isNotEmpty ?? false)
            m.data()['branchId'] as String,
      };

      // Only this week's (and future) schedules — bounded by a single-field
      // range (automatic index), then narrowed to the current week in-memory.
      // Avoids scanning every schedule doc ever written.
      final schedules = (await _schedules
              .where('weekStart',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
              .get())
          .docs;
      final scheduledBranchIds = <String>{
        for (final s in schedules)
          if (_isCurrentWeek(s.data()['weekStart'], weekStart) &&
              (s.data()['branchId'] as String?) != null)
            s.data()['branchId'] as String,
      };

      // Only today's rejections — single-field range (automatic index); count
      // the still-rejected ones in-memory (a re-worked task isn't 'rejected').
      final rejectedToday = (await _tasks
              .where('rejectedAt',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(startToday))
              .get())
          .docs;

      // Pure counts via server-side aggregation — no document downloads. All
      // are single-field filters (automatic indexes; no composite index).
      // (The old user-approval `pendingApprovals` count was removed — OpsHub is
      // admin-provisioned, so there is no approval queue.)
      final counts = await Future.wait([
        _aggCount(_users.where('role', isEqualTo: 'employee')),
        _aggCount(_tasks),
        _aggCount(_tasks.where('status', isEqualTo: 'approved')),
        _aggCount(_tasks.where('status', isEqualTo: 'waitingReview')),
        _aggCount(_tasks.where('status', isEqualTo: 'rejected')),
      ]);
      final totalEmployees = counts[0];
      final totalTasks = counts[1];
      final approvedTasks = counts[2];
      final waitingReviews = counts[3];
      final rejectedTasks = counts[4];

      return StatisticsModel(
        totalBranches: branches.length,
        totalManagers: managers.length,
        totalEmployees: totalEmployees,
        branchesWithoutManagers:
            branches.where((b) => !managerBranchIds.contains(b.id)).length,
        branchesWithSchedule:
            branches.where((b) => scheduledBranchIds.contains(b.id)).length,
        // Active = everything not in a terminal state (matches `_isActive`).
        activeTasks: totalTasks - approvedTasks - rejectedTasks,
        completedTasks: approvedTasks,
        waitingReviews: waitingReviews,
        rejectedTasksToday:
            rejectedToday.where((t) => t.data()['status'] == 'rejected').length,
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load statistics.');
    }
  }

  @override
  Future<StatisticsModel> managerStats(String branchId) async {
    try {
      final now = DateTime.now();
      final startToday = DateTime(now.year, now.month, now.day);

      final users =
          (await _users.where('branchId', isEqualTo: branchId).get()).docs;
      final tasks =
          (await _tasks.where('branchId', isEqualTo: branchId).get()).docs;
      final schedule =
          (await _schedules.doc(ScheduleWeek.docId(branchId, now)).get())
              .data();

      // Today's shift staffing from this week's weekly schedule.
      final todayKey = ScheduleDay.today().value;
      final morning = _slot(schedule, todayKey, 'morning');
      final night = _slot(schedule, todayKey, 'night');

      return StatisticsModel(
        employeesInBranch: _count(users, (u) => u['role'] == 'employee'),
        scheduledToday: {...morning, ...night}.length,
        morningShiftEmployees: morning.length,
        nightShiftEmployees: night.length,
        activeTasks: _count(tasks, _isActive),
        waitingReviews: _count(tasks, (t) => t['status'] == 'waitingReview'),
        completedTasksToday: _count(
            tasks,
            (t) =>
                t['status'] == 'approved' &&
                _isToday(t['approvedAt'], startToday)),
        rejectedTasks: _count(tasks, (t) => t['status'] == 'rejected'),
        dailyTasks: _count(tasks, (t) => t['type'] == 'daily'),
        specialTasks: _count(tasks, (t) => t['type'] == 'special'),
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load statistics.');
    }
  }

  @override
  Future<StatisticsModel> employeeStats(String uid, String? branchId) async {
    try {
      final now = DateTime.now();
      // Multi-assignee (Phase 9): a task counts for this employee if their uid
      // is in `assigneeIds`.
      final tasks =
          (await _tasks.where('assigneeIds', arrayContains: uid).get()).docs;

      String? currentShiftName;
      String? upcomingShiftName;
      if (branchId != null && branchId.isNotEmpty) {
        final schedule =
            (await _schedules.doc(ScheduleWeek.docId(branchId, now)).get())
                .data();
        if (schedule != null) {
          const days = ScheduleDay.values;
          final todayIdx = ScheduleDay.today().index;

          // Current: today's shift that includes this employee.
          for (final shift in const ['morning', 'night']) {
            if (_slot(schedule, days[todayIdx].value, shift).contains(uid)) {
              currentShiftName = shift;
              break;
            }
          }

          // Upcoming: the next slot later this week that includes them.
          search:
          for (var i = todayIdx + 1; i < days.length; i++) {
            for (final shift in const ['morning', 'night']) {
              if (_slot(schedule, days[i].value, shift).contains(uid)) {
                final shiftLabel =
                    '${shift[0].toUpperCase()}${shift.substring(1)}';
                upcomingShiftName = '${days[i].shortLabel} · $shiftLabel';
                break search;
              }
            }
          }
        }
      }

      return StatisticsModel(
        assignedTasks: tasks.length,
        completedTasks: _count(tasks, (t) => t['status'] == 'approved'),
        pendingTasks: _count(tasks, (t) => t['status'] == 'pending'),
        waitingReviews: _count(tasks, (t) => t['status'] == 'waitingReview'),
        currentShiftName: currentShiftName,
        upcomingShiftName: upcomingShiftName,
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load statistics.');
    }
  }

  static bool _isCurrentWeek(dynamic ts, DateTime weekStart) =>
      ts is Timestamp && ScheduleWeek.startOf(ts.toDate()) == weekStart;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/features/notifications/domain/notification_deep_link.dart';

/// The single deep-link resolver shared by the in-app inbox tap and the FCM push
/// tap (Notifications V2). Every notification must resolve to the SAME safe
/// destination however it's opened, and an unresolvable one must return `null`
/// (a guarded no-op) so navigation never crashes.
void main() {
  group('resolveNotificationRoute — task', () {
    test('with a taskId opens the exact task, for any role', () {
      for (final role in UserRole.values) {
        expect(
          resolveNotificationRoute(
            route: NotificationRoute.task,
            payload: const {'taskId': 't1'},
            role: role,
          ),
          RouteNames.taskDetail('t1'),
          reason: role.name,
        );
      }
    });

    test('without a taskId falls back to the role task list', () {
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.task,
            payload: const {},
            role: UserRole.employee),
        RouteNames.myTasks,
      );
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.task,
            payload: const {},
            role: UserRole.admin),
        RouteNames.adminTasks,
      );
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.task,
            payload: const {},
            role: UserRole.manager),
        RouteNames.managerTasks,
      );
    });

    test('without a taskId AND no known role → null (guarded)', () {
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.task, payload: const {}, role: null),
        isNull,
      );
    });

    test('an empty-string id (FCM data map) is treated as missing', () {
      // FCM data values are all strings; a missing id arrives as "".
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.task,
            payload: const {'taskId': ''},
            role: UserRole.employee),
        RouteNames.myTasks,
      );
    });
  });

  group('resolveNotificationRoute — broadcast', () {
    test('admin / manager with an id open the broadcast detail', () {
      for (final role in [UserRole.admin, UserRole.manager]) {
        expect(
          resolveNotificationRoute(
            route: NotificationRoute.broadcast,
            payload: const {'broadcastId': 'b1'},
            role: role,
          ),
          RouteNames.communicationsDetail('b1'),
          reason: role.name,
        );
      }
    });

    test('an employee has no broadcast destination → null (guarded)', () {
      expect(
        resolveNotificationRoute(
          route: NotificationRoute.broadcast,
          payload: const {'broadcastId': 'b1'},
          role: UserRole.employee,
        ),
        isNull,
      );
    });

    test('admin without an id → null (nothing to open)', () {
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.broadcast,
            payload: const {},
            role: UserRole.admin),
        isNull,
      );
    });
  });

  group('resolveNotificationRoute — schedule (shift swap)', () {
    test('opens the role schedule; null role → null', () {
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.schedule,
            payload: const {'swapId': 's1'},
            role: UserRole.employee),
        RouteNames.mySchedule,
      );
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.schedule,
            payload: const {},
            role: UserRole.manager),
        RouteNames.managerSchedule,
      );
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.schedule, payload: const {}, role: null),
        isNull,
      );
    });
  });

  group('resolveNotificationRoute — case', () {
    test('with a caseId opens the thread; without → the case list', () {
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.caseThread,
            payload: const {'caseId': 'c1'},
            role: UserRole.employee),
        RouteNames.caseDetail('c1'),
      );
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.caseThread,
            payload: const {},
            role: UserRole.employee),
        RouteNames.cases,
      );
    });
  });

  group('resolveNotificationRoute — request', () {
    test('with a requestId opens it; without → the request list', () {
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.request,
            payload: const {'requestId': 'r1'},
            role: UserRole.manager),
        RouteNames.requestDetail('r1'),
      );
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.request,
            payload: const {},
            role: UserRole.manager),
        RouteNames.requests,
      );
    });
  });

  group('resolveNotificationRoute — attendance', () {
    // Regression: `writeAttendanceNotifications` has always stamped
    // `route: "attendance"`, but the resolver had no case for it — so every
    // correction / auto-close notification was a DEAD TAP in the inbox.
    test('with a recordId opens the exact record, for any role', () {
      for (final role in UserRole.values) {
        expect(
          resolveNotificationRoute(
            route: NotificationRoute.attendance,
            payload: const {'recordId': 'a1', 'correctionId': 'c1'},
            role: role,
          ),
          RouteNames.attendanceRecord('a1'),
          reason: role.name,
        );
      }
    });

    test('without a recordId falls back to the ledger the role may open', () {
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.attendance,
            payload: const {},
            role: UserRole.admin),
        RouteNames.attendanceReview,
      );
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.attendance,
            payload: const {},
            role: UserRole.manager),
        RouteNames.attendanceReview,
      );
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.attendance,
            payload: const {},
            role: UserRole.employee),
        RouteNames.attendanceHistory,
      );
    });

    test('an empty-string recordId (FCM data map) is treated as missing', () {
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.attendance,
            payload: const {'recordId': ''},
            role: UserRole.employee),
        RouteNames.attendanceHistory,
      );
    });

    test('an unknown role has no destination', () {
      expect(
        resolveNotificationRoute(
            route: NotificationRoute.attendance,
            payload: const {},
            role: null),
        isNull,
      );
    });
  });

  group('resolveNotificationRoute — unknown / missing route', () {
    test('an unknown route → null (safe fallback handled by the caller)', () {
      expect(
        resolveNotificationRoute(
            route: 'something_new',
            payload: const {'taskId': 't1'},
            role: UserRole.admin),
        isNull,
      );
    });

    test('a null route → null', () {
      expect(
        resolveNotificationRoute(
            route: null, payload: const {}, role: UserRole.admin),
        isNull,
      );
    });
  });
}

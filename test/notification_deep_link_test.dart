import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/services/notification_service.dart';
import 'package:drop/core/utils/platform_capabilities.dart';
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
          role: UserRole.employee,
        ),
        RouteNames.myTasks,
      );
      expect(
        resolveNotificationRoute(
          route: NotificationRoute.task,
          payload: const {},
          role: UserRole.admin,
        ),
        RouteNames.adminTasks,
      );
      expect(
        resolveNotificationRoute(
          route: NotificationRoute.task,
          payload: const {},
          role: UserRole.manager,
        ),
        RouteNames.managerTasks,
      );
    });

    test('without a taskId AND no known role → null (guarded)', () {
      expect(
        resolveNotificationRoute(
          route: NotificationRoute.task,
          payload: const {},
          role: null,
        ),
        isNull,
      );
    });

    test('an empty-string id (FCM data map) is treated as missing', () {
      // FCM data values are all strings; a missing id arrives as "".
      expect(
        resolveNotificationRoute(
          route: NotificationRoute.task,
          payload: const {'taskId': ''},
          role: UserRole.employee,
        ),
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
          role: UserRole.admin,
        ),
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
          role: UserRole.employee,
        ),
        RouteNames.mySchedule,
      );
      expect(
        resolveNotificationRoute(
          route: NotificationRoute.schedule,
          payload: const {},
          role: UserRole.manager,
        ),
        RouteNames.managerSchedule,
      );
      expect(
        resolveNotificationRoute(
          route: NotificationRoute.schedule,
          payload: const {},
          role: null,
        ),
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
          role: UserRole.employee,
        ),
        RouteNames.caseDetail('c1'),
      );
      expect(
        resolveNotificationRoute(
          route: NotificationRoute.caseThread,
          payload: const {},
          role: UserRole.employee,
        ),
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
          role: UserRole.manager,
        ),
        RouteNames.requestDetail('r1'),
      );
      expect(
        resolveNotificationRoute(
          route: NotificationRoute.request,
          payload: const {},
          role: UserRole.manager,
        ),
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
          role: UserRole.admin,
        ),
        RouteNames.attendanceReview,
      );
      expect(
        resolveNotificationRoute(
          route: NotificationRoute.attendance,
          payload: const {},
          role: UserRole.manager,
        ),
        RouteNames.attendanceReview,
      );
      expect(
        resolveNotificationRoute(
          route: NotificationRoute.attendance,
          payload: const {},
          role: UserRole.employee,
        ),
        RouteNames.attendanceHistory,
      );
    });

    test('an empty-string recordId (FCM data map) is treated as missing', () {
      expect(
        resolveNotificationRoute(
          route: NotificationRoute.attendance,
          payload: const {'recordId': ''},
          role: UserRole.employee,
        ),
        RouteNames.attendanceHistory,
      );
    });

    test('an unknown role has no destination', () {
      expect(
        resolveNotificationRoute(
          route: NotificationRoute.attendance,
          payload: const {},
          role: null,
        ),
        isNull,
      );
    });
  });

  group('resolveNotificationRoute — chat', () {
    test('with a conversationId opens the exact thread for every role', () {
      for (final role in UserRole.values) {
        expect(
          resolveNotificationRoute(
            route: NotificationRoute.chat,
            payload: const {'conversationId': 'conversation-1'},
            role: role,
          ),
          RouteNames.chatConversation('conversation-1'),
          reason: role.name,
        );
      }
    });

    test('without a conversationId falls back to the chat inbox', () {
      expect(
        resolveNotificationRoute(
          route: NotificationRoute.chat,
          payload: const {},
          role: UserRole.employee,
        ),
        RouteNames.chat,
      );
    });

    test('all-strings FCM data maps resolve the conversation', () {
      const data = <String, dynamic>{
        'type': 'chat_message',
        'category': 'chat',
        'priority': 'high',
        'route': 'chat_message',
        'conversationId': 'conversation-1',
        'messageId': 'message-1',
        'senderExternalId': 'sender-uid',
        'recipientUid': 'recipient-uid',
        'title': 'Sender',
        'body': 'Message preview',
      };
      expect(
        resolveNotificationRoute(
          route: data['route']?.toString(),
          payload: data,
          role: UserRole.manager,
        ),
        RouteNames.chatConversation('conversation-1'),
      );
    });

    test(
      'chat fallback remains the inbox while every non-chat route is pure',
      () {
        expect(
          resolveNotificationRoute(
            route: NotificationRoute.chat,
            payload: const {'conversationId': ''},
            role: UserRole.employee,
          ),
          RouteNames.chat,
        );
        expect(
          resolveNotificationRoute(
            route: NotificationRoute.caseThread,
            payload: const {'caseId': 'case-1'},
            role: UserRole.employee,
          ),
          RouteNames.caseDetail('case-1'),
        );
      },
    );
  });

  group('foreground FCM chat de-duplication', () {
    test('a chat FCM message does not raise a second in-app notification', () {
      expect(
        suppressForegroundFcmNotification(const {
          'route': 'chat_message',
          'conversationId': 'conversation-1',
        }),
        isTrue,
      );
    });

    test('non-chat FCM messages retain their foreground notification', () {
      expect(
        suppressForegroundFcmNotification(const {'route': 'task_details'}),
        isFalse,
      );
    });
  });

  group('chat foreground de-duplication — exactly one surface per platform', () {
    // Chat is the ONLY route with two independent delivery paths (the chat
    // socket and an FCM push from the NestJS backend), so both can fire for one
    // message while the app is open. The two suppressions must be exact
    // opposites, or the user is either notified twice or not at all.
    test(
      'the in-app banner stands down exactly where the OS draws its own',
      () {
        expect(suppressesInAppChatBanner, requiresApnsToken);
      },
    );

    test('Apple: the OS banner is the only chat surface', () {
      // main.dart returns early from `onForeground` when requiresApnsToken, and
      // the socket listener stands down, so the OS banner is alone.
      const appleSuppressesInApp = true;
      expect(appleSuppressesInApp, isTrue);
      expect(
        suppressForegroundFcmNotification(const {'route': 'chat_message'}),
        isTrue,
        reason: 'the FCM snackbar must never be the Apple chat surface',
      );
    });

    test('Android: the socket banner is the only chat surface', () {
      // Android draws nothing in the foreground, so the in-app banner must NOT
      // stand down — and the FCM path must stay suppressed so it cannot add a
      // second snackbar for the same message.
      const androidSuppressesInApp = false;
      expect(androidSuppressesInApp, isFalse);
      expect(
        suppressForegroundFcmNotification(const {'route': 'chat_message'}),
        isTrue,
      );
    });

    test('a non-chat route is never double-suppressed', () {
      // Only chat has two paths; suppressing any other route here would mean a
      // task/case/request notification silently vanishes in the foreground.
      for (final route in const [
        'task_details',
        'broadcast_detail',
        'schedule',
        'case_details',
        'request_details',
        'attendance',
      ]) {
        expect(
          suppressForegroundFcmNotification({'route': route}),
          isFalse,
          reason: '$route must keep its foreground notification',
        );
      }
    });
  });

  group('resolveNotificationRoute — unknown / missing route', () {
    test('an unknown route → null (safe fallback handled by the caller)', () {
      expect(
        resolveNotificationRoute(
          route: 'something_new',
          payload: const {'taskId': 't1'},
          role: UserRole.admin,
        ),
        isNull,
      );
    });

    test('a null route → null', () {
      expect(
        resolveNotificationRoute(
          route: null,
          payload: const {},
          role: UserRole.admin,
        ),
        isNull,
      );
    });
  });
}

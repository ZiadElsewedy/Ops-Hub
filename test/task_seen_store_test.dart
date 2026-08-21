import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/services/task_seen_store.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/features/task/presentation/widgets/task_attention_surface.dart';

void main() {
  // The store gracefully falls back to in-memory when path_provider is
  // unavailable (as in tests) — so these exercise the real store logic.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('taskIsUnseen', () {
    test('a never-opened pending task is new', () {
      expect(taskIsUnseen(TaskStatus.pending, null), isTrue);
    });

    test('an opened pending task is not new', () {
      expect(taskIsUnseen(TaskStatus.pending, 1), isFalse);
    });

    test('only pending is ever new — work in flight or closed never is', () {
      for (final s in TaskStatus.values) {
        if (s == TaskStatus.pending) continue;
        expect(
          taskIsUnseen(s, null),
          isFalse,
          reason: '$s must never wear the attention treatment',
        );
      }
    });
  });

  group('TaskSeenStore', () {
    test('a fresh pending task is new until it is opened', () async {
      final store = TaskSeenStore();
      await store.load('u1');
      expect(store.isUnseen('t1', TaskStatus.pending), isTrue);
      expect(store.markSeen('t1'), isTrue); // first time
      expect(store.isUnseen('t1', TaskStatus.pending), isFalse);
    });

    test('seen is permanent — a task never re-arms', () async {
      final store = TaskSeenStore();
      await store.load('u1');
      store.markSeen('t1');
      expect(store.markSeen('t1'), isFalse); // no second rebuild
      expect(store.isUnseen('t1', TaskStatus.pending), isFalse);
    });

    test('seen-state is namespaced per user (shared device)', () async {
      final store = TaskSeenStore();
      await store.load('u1');
      store.markSeen('t1');
      expect(store.isUnseen('t1', TaskStatus.pending), isFalse);
      await store.load('u2'); // account switch on the same store
      expect(store.isUnseen('t1', TaskStatus.pending), isTrue);
    });

    test('load reports readiness so Home can hold off the treatment', () async {
      final store = TaskSeenStore();
      expect(store.isLoaded, isFalse);
      await store.load('u1');
      expect(store.isLoaded, isTrue);
    });
  });

  group('taskAttentionTone', () {
    test('a new pending task is the only white edge', () {
      expect(
        taskAttentionTone(TaskStatus.pending, unseen: true),
        AppColors.primary.withAlpha(77),
      );
      expect(
        taskAttentionTone(TaskStatus.pending, unseen: false),
        AppColors.darkBorder,
      );
    });

    test('each live state carries its own soft tone', () {
      expect(
        taskAttentionTone(TaskStatus.started, unseen: false),
        AppColors.info.withAlpha(82),
      );
      expect(
        taskAttentionTone(TaskStatus.waitingReview, unseen: false),
        AppColors.warning.withAlpha(77),
      );
      expect(
        taskAttentionTone(TaskStatus.approved, unseen: false),
        AppColors.success.withAlpha(77),
      );
    });

    test('missed and rejected are red; cancelled is never red', () {
      final red = AppColors.error.withAlpha(77);
      expect(taskAttentionTone(TaskStatus.missed, unseen: false), red);
      expect(taskAttentionTone(TaskStatus.rejected, unseen: false), red);
      // Cancelled is a business decision, not a failure (spec §8).
      expect(
        taskAttentionTone(TaskStatus.cancelled, unseen: false),
        AppColors.textQuaternary,
      );
    });

    test('unseen never brightens a non-pending state', () {
      for (final s in TaskStatus.values) {
        if (s == TaskStatus.pending) continue;
        expect(
          taskAttentionTone(s, unseen: true),
          taskAttentionTone(s, unseen: false),
          reason: '$s must ignore the unseen flag',
        );
      }
    });
  });
}

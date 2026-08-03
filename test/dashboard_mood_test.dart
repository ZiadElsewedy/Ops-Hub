import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/utils/dashboard_mood.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dashboardMood — the two live states', () {
    test('zero needs-attention reads the calm, reassuring line (grey pulse)', () {
      final m = dashboardMood(needsAttention: 0);
      expect(m.tone, MoodTone.calm);
      expect(m.headline, 'All caught up — nothing needs you right now');
      expect(m.emphasised, isFalse);
      expect(m.pulseColor, AppColors.textSecondary);
    });

    test('a single item reads singular with the warning pulse', () {
      final m = dashboardMood(needsAttention: 1);
      expect(m.tone, MoodTone.attention);
      expect(m.headline, '1 task needs your attention');
      expect(m.emphasised, isTrue);
      expect(m.pulseColor, AppColors.warning);
    });

    test('several items read as one numbers-first total', () {
      expect(
        dashboardMood(needsAttention: 7).headline,
        '7 tasks need your attention',
      );
    });

    test('a negative total can never escalate the board — it stays calm', () {
      expect(dashboardMood(needsAttention: -2).tone, MoodTone.calm);
    });
  });
}

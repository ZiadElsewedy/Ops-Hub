import 'package:drop/core/theme/app_colors.dart';
import 'package:flutter/painting.dart';

/// The live operational **state** of the admin dashboard, expressed as one short
/// sentence beside a breathing pulse dot — so the hero reflects what is actually
/// happening right now instead of printing the same greeting every load.
///
/// Deliberately just **two** states (owner ruling): a calm board reads a quiet,
/// reassuring line with a grey pulse; a board with work reads a numbers-first
/// "needs your attention" line with the warning pulse. Both the hero sentence and
/// the Needs-attention section switch off the **same** [needsAttention] total, so
/// they can never disagree.
///
/// Pure (no Flutter beyond a [Color]) so it stays unit-testable and derives
/// entirely from counts the dashboard already has (no new reads).
enum MoodTone { calm, attention }

class DashboardMood {
  const DashboardMood(this.headline, this.tone);

  /// The contextual sentence shown under the greeting.
  final String headline;
  final MoodTone tone;

  /// Colour of the small "system pulse" dot beside the headline — meaningful,
  /// never decorative: a calm board reads a quiet light grey (all good), a board
  /// that needs attention picks up the warning accent.
  Color get pulseColor => switch (tone) {
        MoodTone.calm => AppColors.textSecondary,
        MoodTone.attention => AppColors.warning,
      };

  /// True when the mood should draw the eye (headline reads white); a calm mood
  /// stays a relaxed light grey.
  bool get emphasised => tone == MoodTone.attention;
}

/// Derive the dashboard's one live state sentence from [needsAttention] — the sum
/// of everything in the Needs-attention layer (pending review + overdue +
/// unassigned + sent back + swap requests).
///
/// - **0** → calm: a reassuring, positive line and the grey pulse.
/// - **> 0** → attention: a numbers-first total and the warning pulse
///   ("3 tasks need your attention"), singular-aware for one item.
DashboardMood dashboardMood({required int needsAttention}) {
  if (needsAttention <= 0) {
    return const DashboardMood(
      'All caught up — nothing needs you right now',
      MoodTone.calm,
    );
  }
  final noun = needsAttention == 1 ? 'task needs' : 'tasks need';
  return DashboardMood(
    '$needsAttention $noun your attention',
    MoodTone.attention,
  );
}

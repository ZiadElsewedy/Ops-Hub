import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/features/task/domain/note_category.dart';
import 'package:opshub/features/task/presentation/activity_format.dart';

/// Note categorization (Home Dashboard redesign) — the note's category is stored
/// as its activity `status` kind, and `activity_format` gives each a distinct
/// title / colour for the timeline hierarchy.
void main() {
  test('NoteCategory maps to its activity-status kind (info = back-compat note)',
      () {
    expect(NoteCategory.info.activityStatus, 'note');
    expect(NoteCategory.warning.activityStatus, 'noteWarning');
    expect(NoteCategory.issue.activityStatus, 'noteIssue');
  });

  test('activity_format renders the three note kinds distinctly', () {
    expect(activityTitle('note'), 'Note');
    expect(activityTitle('noteWarning'), 'Warning');
    expect(activityTitle('noteIssue'), 'Issue');
    expect(activityColor('note'), AppColors.textTertiary);
    // Warnings/issues wear the soft state palette (shared with the living
    // borders) — amber for warnings, soft red for issues.
    expect(activityColor('noteWarning'), kStateInReview);
    expect(activityColor('noteIssue'), kStateRejected);
  });
}

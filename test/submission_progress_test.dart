import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/task/presentation/submission_progress.dart';

const _mb = 1024 * 1024;

void main() {
  group('SubmissionProgress (uploading)', () {
    const p = SubmissionProgress(
      SubmissionStage.uploading,
      transferredBytes: 5 * _mb,
      totalBytes: 10 * _mb,
    );

    test('fraction / percent', () {
      expect(p.fraction, 0.5);
      expect(p.percent, 50);
    });

    test('sizeLabel is "X.X / Y.Y MB"', () {
      expect(p.sizeLabel, '5.0 / 10.0 MB');
    });

    test('caps the fraction at 1.0', () {
      const over = SubmissionProgress(SubmissionStage.uploading,
          transferredBytes: 12 * _mb, totalBytes: 10 * _mb);
      expect(over.fraction, 1.0);
      expect(over.percent, 100);
    });
  });

  group('SubmissionProgress (no size yet)', () {
    test('is indeterminate when total is 0', () {
      const p = SubmissionProgress(SubmissionStage.preparing);
      expect(p.fraction, isNull);
      expect(p.percent, isNull);
      expect(p.sizeLabel, isNull);
    });
  });

  group('SubmissionStage labels', () {
    test('match the overlay copy', () {
      expect(SubmissionStage.preparing.label, 'Preparing media');
      expect(SubmissionStage.uploading.label, 'Uploading attachments');
      expect(SubmissionStage.finalizing.label, 'Finalizing submission');
    });
  });
}

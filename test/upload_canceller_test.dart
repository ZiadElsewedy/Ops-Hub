import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/media/media_upload_service.dart';

void main() {
  group('UploadCanceller', () {
    test('starts un-cancelled', () {
      expect(UploadCanceller().isCancelled, isFalse);
    });

    test('cancel() flips isCancelled and is idempotent', () {
      final c = UploadCanceller();
      c.cancel();
      expect(c.isCancelled, isTrue);
      // A second cancel must not throw (double-tap the button, etc.).
      c.cancel();
      expect(c.isCancelled, isTrue);
    });

    test('cancel() with nothing attached is a safe no-op', () {
      // No active uploads registered — cancel just marks the flag.
      expect(UploadCanceller().cancel, returnsNormally);
    });
  });

  group('UploadCancelledException', () {
    test('is an Exception (so it propagates, not caught as a ServerException)',
        () {
      expect(const UploadCancelledException(), isA<Exception>());
    });
  });
}

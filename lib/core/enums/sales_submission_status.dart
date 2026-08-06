/// The review lifecycle stored on a daily branch sales submission.
enum SalesSubmissionStatus {
  pending,
  approved,
  rejected,
  correctionRequested;

  /// The string persisted in Firestore.
  String get value => name;

  /// Unknown or missing values must never contribute to approved sales.
  static SalesSubmissionStatus fromString(String? raw) {
    for (final status in values) {
      if (status.value == raw) return status;
    }
    return SalesSubmissionStatus.pending;
  }
}

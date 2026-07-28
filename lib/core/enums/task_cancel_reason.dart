/// Why a task was cancelled — the **fixed, structured picklist** every
/// cancellation must carry (`docs/design/AUTOMATED_TASKS_PRODUCT_SPEC.md` §5.5).
///
/// A reason is mandatory. Free text alone was rejected: the whole point of the
/// code is that cancellation volume **by reason** is a quality signal (§10.3) —
/// repeated `noLongerNeeded` means a routine that should be paused, repeated
/// `wrongTaskGenerated` means a misconfigured template. Un-coded free text can't
/// be counted, and an optional reason turns Cancel into a laundering hatch for
/// work that was simply not done.
///
/// ## The wire ids are frozen
/// Each value persists its **stable dotted-free string id** (`duplicate`,
/// `no_longer_needed`, …), never the Dart name — so the label may be reworded in
/// the UI without rewriting a single historical record. The reason is immutable
/// once written (enforced in `firestore.rules`): renaming an option later never
/// retroactively changes what a past cancellation said.
///
/// An id this build doesn't recognise round-trips as [unknown] rather than
/// crashing or silently becoming a *different* reason, so a newer client's code
/// can never corrupt an older client's reading of history.
enum TaskCancelReason {
  duplicate('duplicate', 'Duplicate Task'),
  wrongTaskGenerated('wrong_generated', 'Wrong Task Generated'),
  noLongerNeeded('no_longer_needed', 'No Longer Needed'),
  shiftCancelled('shift_cancelled', 'Shift Cancelled'),
  managementDecision('management_decision', 'Management Decision'),

  /// Forward-compatible fallback for a code written by a newer build. Never
  /// offered in the picker ([selectable]) and never written by this client.
  unknown('unknown', 'Other');

  const TaskCancelReason(this.value, this.label);

  /// The persisted, wire-stable id. Never the enum name.
  final String value;

  /// Human label shown in the picker and on the cancelled record.
  final String label;

  /// The five options a manager/admin may actually choose — [unknown] is a read
  /// fallback, not a choice.
  static const List<TaskCancelReason> selectable = [
    duplicate,
    wrongTaskGenerated,
    noLongerNeeded,
    shiftCancelled,
    managementDecision,
  ];

  /// Parses the stored id. Unknown → [unknown]; **missing → null**, so "this
  /// task carries no cancellation reason" stays distinguishable from "a reason
  /// this build doesn't know".
  static TaskCancelReason? fromString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final r in TaskCancelReason.values) {
      if (r.value == raw) return r;
    }
    return TaskCancelReason.unknown;
  }
}

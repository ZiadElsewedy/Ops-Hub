part of '../task_action_sheets.dart';

// ─── Create / edit ───────────────────────────────────────────────
class _TaskFormSheet extends StatefulWidget {
  const _TaskFormSheet({
    required this.cubit,
    required this.existing,
    required this.prefill,
    required this.isAdmin,
    required this.defaultBranchId,
  });

  final TaskCubit cubit;
  final TaskEntity? existing;
  final TaskTemplateEntity? prefill;
  final bool isAdmin;
  final String defaultBranchId;

  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  late final _title = TextEditingController(
    text: widget.existing?.title ?? widget.prefill?.title ?? '',
  );
  late final _desc = TextEditingController(
    text: widget.existing?.description ?? widget.prefill?.description ?? '',
  );
  late TaskPriority _priority =
      widget.existing?.priority ??
      widget.prefill?.priority ??
      TaskPriority.normal;

  /// Work-type selection + its schema-driven field values. The type is chosen on
  /// a new task (locked when editing — a task's kind never changes mid-life);
  /// [_workData] holds the values for the type's dynamic fields, seeded from an
  /// existing task and reset when the type changes.
  late String _workType = widget.existing?.workType ?? 'general';
  late Map<String, dynamic> _workData = {...?widget.existing?.data};
  Map<String, String> _workFieldErrors = const {};

  late DateTime? _startsAt = widget.existing?.startsAt;
  late DateTime? _deadline = widget.existing?.deadline;

  /// The shift the schedule was suggested from (Scheduling V2). **Persists**
  /// through customization so the banner can show "Originally: …" + Reset —
  /// cleared only when the shift/assignees no longer resolve to one.
  ScheduleShift? _scheduleSource;

  /// True once the manager edited either time away from the suggestion.
  bool _scheduleCustom = false;

  /// The quick deadline preset currently driving the window, if any. These
  /// presets are deadline-led, not shift-led, so roster resolving should not
  /// attach outside-shift warnings to them.
  Duration? _quickDeadlinePreset;

  /// The assignees are rostered on **different** shifts — prompt for a choice
  /// instead of auto-filling.
  bool _mixedShifts = false;

  /// A rostered-shift resolve is in flight (async schedule read).
  bool _resolvingShift = false;

  late RecurrenceFrequency _recurrence =
      widget.existing?.recurrence?.frequency ?? RecurrenceFrequency.none;

  /// Shift Assignment feature — new tasks only (an existing task/instance never
  /// changes its assignment mode, so these are seeded once and the selector to
  /// change them is hidden in edit mode; see the `widget.existing == null`
  /// gates in [build]).
  late TaskAssignmentType _assignmentType =
      widget.existing?.assignmentType ?? TaskAssignmentType.individual;
  late ScheduleShift? _shift = widget.existing?.shift;
  TemplateRepeatMode _shiftRepeat = TemplateRepeatMode.once;
  int _shiftWeekday = DateTime.now().weekday;

  /// Checklist state: parallel lists for controllers, required flag, id,
  /// and the original [ChecklistItem] (only set when editing an existing task,
  /// so we can preserve the completed/completedAt state on save).
  final List<TextEditingController> _itemControllers = [];
  final List<bool> _itemRequired = [];
  final List<String> _itemIds = [];
  final List<ChecklistItem?> _itemOriginals = [];

  /// Reference images: the already-uploaded ones kept on this task (removable in
  /// edit mode) + the newly-picked ones to upload on save.
  late final List<TaskAttachment> _existingRefs = [
    ...?widget.existing?.referenceAttachments,
  ];
  List<PickedAttachment> _newRefs = [];

  /// Admin-only branch selection (managers use their own fixed branch).
  late String? _branchId = _initialBranch();
  late final Future<List<BranchEntity>> _branchesFuture = widget.isAdmin
      ? widget.cubit.branches()
      : Future.value(const []);

  /// Assign-on-create: the selected employee uids (seeded from the existing task
  /// when editing) + the branch their list was loaded for, so an admin re-picking
  /// a branch reloads the team and clears a now-irrelevant selection.
  late final Set<String> _assignees = {...?widget.existing?.assigneeIds};
  Future<List<UserEntity>>? _employeesFuture;
  String _employeesBranch = '';

  /// A one-line explanation shown under the assignee field when switching modes
  /// forced us to change the selection (Group → Individual keeps a single
  /// owner). Cleared on the next deliberate change, so it never lingers.
  String? _assignmentNote;

  /// A new people-mode task has to reach someone: an empty `assigneeIds` is
  /// accessible to **nobody** (`canUserAccessTask`), so Create stays disabled
  /// until at least one person is picked. Shift mode targets the roster instead,
  /// and editing is exempt (an existing task's assignment is not re-litigated
  /// here).
  bool get _needsAssignee =>
      widget.existing == null &&
      _assignmentType != TaskAssignmentType.shift &&
      _assignees.isEmpty;

  String? _error;

  // ── Presentation-only state (no business logic) ──────────────────────
  /// Drives the collapsing header: the large hero title condenses into the
  /// pinned nav-bar title and a hairline appears once the body scrolls.
  final ScrollController _scroll = ScrollController();
  bool _scrolled = false;

  /// The checklist row to autofocus after an add — makes "Add step" feel
  /// immediate and rewarding. `-1` = none pending.
  int _lastAddedIndex = -1;

  /// Whether the optional "Options" panel (steps · priority · repeat ·
  /// attachments) is expanded. Collapsed by default so the required workflow is
  /// a short screen; opened automatically when a task already carries optional
  /// content (editing / a template prefill) so nothing is hidden.
  late bool _optionsExpanded = _hasOptionalContent;

  /// Inline error for the Title field — set on blur (or a defensive submit) when
  /// empty, cleared the moment a title is typed. Replaces the bottom banner for
  /// this simple, per-field check.
  String? _titleError;

  String? _initialBranch() {
    final fromExisting = widget.existing?.branchId;
    if (fromExisting != null && fromExisting.isNotEmpty) return fromExisting;
    final fromPrefill = widget.prefill?.branchId;
    if (fromPrefill != null && fromPrefill.isNotEmpty) return fromPrefill;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _initChecklist();
    _syncEmployeesFuture();
    // Live validation: the sticky Create button reflects readiness as the
    // manager types the title (the authoritative checks stay in [_save]).
    _title.addListener(_onFormChanged);
    _scroll.addListener(_onScroll);
  }

  /// Rebuild so the sticky footer's enabled state tracks the title live; also
  /// clears the title error as soon as text is entered.
  void _onFormChanged() {
    if (!mounted) return;
    setState(() {
      if (_titleError != null && _title.text.trim().isNotEmpty) {
        _titleError = null;
      }
    });
  }

  /// On-blur validation for the title (the button stays disabled until valid;
  /// this surfaces *why* at the field the moment focus leaves it empty).
  void _onTitleFocusChange(bool focused) {
    if (focused || !mounted) return;
    final empty = _title.text.trim().isEmpty;
    if (empty != (_titleError != null)) {
      setState(() => _titleError = empty ? 'Title is required' : null);
    }
  }

  void _onScroll() {
    final scrolled = _scroll.hasClients && _scroll.offset > 12;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  /// Commit a new people-selection and let the mode follow it
  /// ([TaskAssignmentType.forAssigneeCount] — one owner vs a sharing group).
  /// The picker is a single always-multi-select sheet that stays open while the
  /// selection is built, so the mode is a readout of what you land on rather
  /// than a question asked before you start.
  ///
  /// Also re-resolves the rostered shift, since the schedule suggestion depends
  /// on who is picked.
  void _onAssigneesChanged(Set<String> next) {
    setState(() {
      _assignees
        ..clear()
        ..addAll(next);
      // A deliberate pick supersedes any carry-over explanation.
      _assignmentNote = null;
      // Shift mode targets the roster, so a people-pick never drags it out of
      // it; editing never changes an existing task's mode.
      if (widget.existing == null &&
          _assignmentType != TaskAssignmentType.shift) {
        _assignmentType = TaskAssignmentType.forAssigneeCount(
          _assignees.length,
        );
      }
    });
    _resolveAssigneeSchedule();
  }

  /// Set the assignment mode **explicitly** and reconcile the current pick.
  ///
  /// Tapping a card still wins over the derivation until the next selection
  /// change — the cards are a control, not just a display. Only one case needs
  /// reconciling: **Group → Individual** with several people already picked.
  /// Rather than clearing the work or blocking the switch, we keep the person
  /// picked first and say so; the other direction (Individual → Group) simply
  /// carries that person in as the group's first member. Switching to Shift
  /// leaves the pick untouched — shift mode ignores `assigneeIds`, so coming
  /// back restores exactly what was there.
  void _onAssignmentModeChanged(TaskAssignmentType t) {
    if (t == _assignmentType) return;
    setState(() {
      _assignmentType = t;
      _assignmentNote = null;
      if (t == TaskAssignmentType.shift) {
        _mixedShifts = false;
      } else if (t == TaskAssignmentType.individual && _assignees.length > 1) {
        final total = _assignees.length;
        final kept = _assignees.first; // insertion order = first one picked
        _assignees
          ..clear()
          ..add(kept);
        _assignmentNote =
            'Kept 1 of $total — an Individual task has a single owner.';
      }
    });
    // Switching to individual/group re-resolves the roster.
    if (t != TaskAssignmentType.shift) {
      _resolveAssigneeSchedule();
    }
  }

  /// (Re)loads the branch's employee list for the assignee picker when the
  /// effective branch changes (manager: fixed; admin: the picked branch).
  void _syncEmployeesFuture() {
    final branch =
        (widget.isAdmin ? _branchId : widget.defaultBranchId)?.trim() ?? '';
    if (branch == _employeesBranch) return;
    _employeesBranch = branch;
    _employeesFuture = branch.isEmpty
        ? null
        : widget.cubit.branchEmployees(branch);
  }

  void _initChecklist() {
    if (widget.existing != null) {
      // Edit mode: seed from the task's existing checklist items, preserving state
      for (final item in widget.existing!.checklist) {
        _itemControllers.add(TextEditingController(text: item.title));
        _itemRequired.add(item.isRequired);
        _itemIds.add(item.id);
        _itemOriginals.add(item);
      }
    } else if (widget.prefill != null) {
      // New task from template: seed from the template's checklist items
      for (final t in widget.prefill!.checklistItems) {
        _itemControllers.add(TextEditingController(text: t.title));
        _itemRequired.add(t.isRequired);
        _itemIds.add(t.id);
        _itemOriginals.add(null);
      }
    }
  }

  @override
  void dispose() {
    _title.removeListener(_onFormChanged);
    _scroll.dispose();
    _title.dispose();
    _desc.dispose();
    for (final c in _itemControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addChecklistItem() {
    setState(() {
      _itemControllers.add(TextEditingController());
      _itemRequired.add(true);
      _itemIds.add(
        'ci_${DateTime.now().millisecondsSinceEpoch}_${_itemControllers.length}',
      );
      _itemOriginals.add(null);
      _lastAddedIndex = _itemControllers.length - 1; // autofocus the new row
    });
  }

  void _removeChecklistItem(int i) {
    _itemControllers[i].dispose();
    setState(() {
      _itemControllers.removeAt(i);
      _itemRequired.removeAt(i);
      _itemIds.removeAt(i);
      _itemOriginals.removeAt(i);
      _lastAddedIndex = -1; // indices shifted — don't steal focus
    });
  }

  void _toggleRequired(int i) =>
      setState(() => _itemRequired[i] = !_itemRequired[i]);

  List<ChecklistItem> _buildChecklist() {
    final result = <ChecklistItem>[];
    for (var i = 0; i < _itemControllers.length; i++) {
      final title = _itemControllers[i].text.trim();
      if (title.isEmpty) continue;
      final original = _itemOriginals[i];
      if (original != null) {
        // Preserve completed state, update title + required
        result.add(
          original.copyWith(title: title, isRequired: _itemRequired[i]),
        );
      } else {
        result.add(
          ChecklistItem(
            id: _itemIds[i],
            title: title,
            isRequired: _itemRequired[i],
          ),
        );
      }
    }
    return result;
  }

  void _save() {
    // NOTE: the validation *logic* below is unchanged — same checks, same order,
    // same early-returns. Only where each error is *surfaced* changed: the
    // simple per-field checks now show inline (title on its field; branch/shift/
    // schedule are gated by the disabled Create button + the footer hint + the
    // Schedule field's own inline error), so the bottom banner is reserved for
    // the cross-field work-type setup error only.
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Title is required');
      return;
    }
    final branchId = widget.isAdmin
        ? (_branchId ?? '')
        : widget.defaultBranchId;
    if (branchId.isEmpty) {
      return; // gated by _canSubmit; footer shows "Select a branch to continue"
    }
    if (widget.existing == null &&
        _assignmentType == TaskAssignmentType.shift &&
        _shift == null) {
      return; // gated by _canSubmit; footer shows "Choose a shift to continue"
    }
    if (_needsAssignee) {
      return; // gated by _canSubmit; footer shows "Choose who this task is for"
    }
    // Scheduling V2 — a due-before-start window is invalid (an outside-shift
    // window is only a non-blocking warning, so it does not stop here). The
    // Schedule field already renders this error inline (live).
    final scheduleError = _scheduleError;
    if (scheduleError != null) {
      return;
    }
    final description = _desc.text.trim().isEmpty ? null : _desc.text.trim();
    final checklist = _buildChecklist();

    // Work-type setup gate — each type validates its own fields (a general task
    // declares none, so this is a no-op for it).
    final workDef = WorkTypeRegistry.instance.byId(_workType);
    final setup = workDef.validateSetup(
      WorkDraft(
        data: _workData,
        checklistCount: checklist.length,
        assigneeCount: _assignees.length,
      ),
    );
    if (!setup.ok) {
      setState(() {
        _workFieldErrors = setup.fieldErrors;
        _error = setup.firstError;
      });
      return;
    }

    final existing = widget.existing;
    if (existing == null) {
      if (_assignmentType == TaskAssignmentType.shift) {
        if (_shiftRepeat == TemplateRepeatMode.once) {
          widget.cubit.createTask(
            title: title,
            description: description,
            type: TaskType.daily,
            workType: _workType,
            data: _workData,
            priority: _priority,
            branchId: branchId,
            startsAt: _startsAt,
            deadline: _deadline,
            checklist: checklist,
            referenceAttachments: _newRefs,
            assignmentType: TaskAssignmentType.shift,
            shift: _shift,
            instanceDate: _startsAt ?? _deadline,
          );
        } else {
          // Recurring shift templates generate general instances; a specialised
          // work type would be silently dropped, so require General here (until
          // templates learn to carry a work type).
          if (_workType != 'general') {
            setState(
              () => _error =
                  'Recurring shift templates support General tasks only for now — '
                  'choose "Once", or set the work type to General.',
            );
            return;
          }
          widget.cubit.createRecurringShiftTemplate(
            title: title,
            description: description,
            priority: _priority,
            branchId: branchId,
            shift: _shift!,
            checklistItems: [
              for (final c in checklist)
                ChecklistItemTemplate(
                  id: c.id,
                  title: c.title,
                  isRequired: c.isRequired,
                ),
            ],
            repeat: _shiftRepeat,
            weekday: _shiftWeekday,
          );
        }
      } else {
        // Infer type from recurrence: recurring = daily routine, else special
        final inferredType = _recurrence != RecurrenceFrequency.none
            ? TaskType.daily
            : TaskType.special;
        widget.cubit.createTask(
          title: title,
          description: description,
          type: inferredType,
          workType: _workType,
          data: _workData,
          priority: _priority,
          branchId: branchId,
          startsAt: _startsAt,
          deadline: _deadline,
          assigneeIds: _assignees.toList(),
          checklist: checklist,
          recurrence: _recurrence == RecurrenceFrequency.none
              ? null
              : RecurrenceConfig(frequency: _recurrence),
          referenceAttachments: _newRefs,
          assignmentType: _assignmentType,
        );
      }
    } else {
      widget.cubit.editTask(
        existing.copyWith(
          title: title,
          description: description,
          workType: _workType,
          data: _workData,
          priority: _priority,
          branchId: branchId,
          startsAt: _startsAt,
          deadline: _deadline,
          assigneeIds: _assignees.toList(),
          checklist: checklist,
          // Persist the kept references (removed ones drop off here); newly
          // picked ones upload via newReferenceAttachments below.
          referenceAttachments: _existingRefs,
        ),
        newReferenceAttachments: _newRefs,
      );
    }
    Navigator.of(context).pop();
  }

  /// Pick a full date **and** time (Task Scheduling V2 — start/due carry a time,
  /// not just a date). Presentation-only change: this uses a monochrome
  /// Cupertino wheel picker instead of the Material calendar/clock dialogs, so
  /// scheduling stays inside the OpsHub design language. The value range and the
  /// returned `DateTime` are unchanged — the scheduling engine is untouched.
  /// (Cancel makes no change; Done commits date + time in one step.)
  Future<DateTime?> _pickDateTime(DateTime? current) async {
    final now = DateTime.now();
    final minDate = DateTime(now.year - 1);
    final maxDate = DateTime(now.year + 3, 12, 31, 23, 59);
    var initial = current ?? now;
    if (initial.isBefore(minDate)) initial = minDate;
    if (initial.isAfter(maxDate)) initial = maxDate;

    var temp = initial;
    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Cancel',
                      style: AppTypography.label.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Text('Date & time', style: AppTypography.label),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(temp),
                    child: Text(
                      'Done',
                      style: AppTypography.label.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 216,
              child: CupertinoTheme(
                data: const CupertinoThemeData(brightness: Brightness.dark),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  backgroundColor: AppColors.darkSurface,
                  initialDateTime: initial,
                  minimumDate: minDate,
                  maximumDate: maxDate,
                  use24hFormat: false,
                  onDateTimeChanged: (dt) => temp = dt,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStart() async {
    final dt = await _pickDateTime(_startsAt);
    if (dt != null) {
      // Manual edit → custom (the source is kept so the banner can offer Reset).
      setState(() {
        _startsAt = dt;
        _scheduleCustom = true;
        _quickDeadlinePreset = null;
      });
    }
  }

  Future<void> _pickDue() async {
    final dt = await _pickDateTime(_deadline);
    if (dt != null) {
      setState(() {
        _deadline = dt;
        _scheduleCustom = true;
        _quickDeadlinePreset = null;
      });
    }
  }

  DateTime _nowToMinute() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  void _applyQuickDeadline(Duration duration) {
    final start = _nowToMinute();
    setState(() {
      _startsAt = start;
      _deadline = start.add(duration);
      _scheduleSource = null;
      _scheduleCustom = true;
      _quickDeadlinePreset = duration;
    });
  }

  /// The effective branch for schedule lookups (admin picks; manager is fixed).
  String get _effectiveBranchId =>
      (widget.isAdmin ? _branchId : widget.defaultBranchId)?.trim() ?? '';

  /// Apply [shift]'s standard hours as the smart-default window for the current
  /// day (keeps any date already chosen; overnight ends roll to the next day).
  void _suggestFromShift(ScheduleShift shift) {
    final date = _startsAt ?? _deadline ?? DateTime.now();
    final def = shiftDefaultSchedule(date, shift);
    _startsAt = def.start;
    _deadline = def.due;
    _scheduleSource = shift;
    _scheduleCustom = false;
    _quickDeadlinePreset = null;
  }

  void _resetToSource() {
    final shift = _scheduleSource;
    if (shift != null) setState(() => _suggestFromShift(shift));
  }

  /// Resolve the rostered shift of the current (individual/team) assignees and
  /// pre-fill the schedule as a smart default: a unanimous shift is suggested,
  /// mixed shifts prompt a choice, none leaves it manual. Best-effort + async.
  Future<void> _resolveAssigneeSchedule() async {
    if (_assignmentType == TaskAssignmentType.shift) return;
    final uids = _assignees.toList();
    final branchId = _effectiveBranchId;
    if (uids.isEmpty || branchId.isEmpty) {
      setState(() => _mixedShifts = false);
      return;
    }
    setState(() => _resolvingShift = true);
    final date = _startsAt ?? _deadline ?? DateTime.now();
    final res = await widget.cubit.resolveAssigneeShift(
      branchId: branchId,
      uids: uids,
      date: date,
    );
    if (!mounted) return;
    setState(() {
      _resolvingShift = false;
      switch (res.fit) {
        case AssigneeShiftFit.unanimous:
          _mixedShifts = false;
          if (_scheduleCustom) {
            if (_quickDeadlinePreset == null) {
              // keep the manager's times, update banner
              _scheduleSource = res.shift;
            }
          } else {
            _suggestFromShift(res.shift!);
          }
        case AssigneeShiftFit.mixed:
          _mixedShifts = true;
          if (!_scheduleCustom) {
            _scheduleSource = null; // ambiguous → user chooses
          }
        case AssigneeShiftFit.none:
          _mixedShifts = false;
      }
    });
  }

  /// The banner's suggestion source (e.g. "Morning shift · 08:30 – 16:30"), or
  /// null when no shift resolved.
  String? get _scheduleSourceLabel {
    final shift = _scheduleSource;
    if (shift == null) return null;
    final date = _startsAt ?? _deadline ?? DateTime.now();
    final hours = ShiftHours.standard(ScheduleDay.fromDate(date), shift);
    return '${shift.label} shift · ${hours.format()}';
  }

  /// Blocking validation — a due time at/before the start. Absolute instants, so
  /// a legitimate overnight window (start 23:00 → due 03:00 next day) passes.
  String? get _scheduleError {
    final s = _startsAt, d = _deadline;
    if (s != null && d != null && !d.isAfter(s)) {
      return 'The due time must be after the start time.';
    }
    return null;
  }

  /// Non-blocking advisory — a custom schedule that falls outside the source
  /// shift's hours (keep the user in control; never prevents saving).
  String? get _scheduleWarning {
    final shift = _scheduleSource;
    final s = _startsAt, d = _deadline;
    if (shift == null || !_scheduleCustom || s == null || d == null) {
      return null;
    }
    final window = shiftDefaultSchedule(s, shift);
    if (s.isBefore(window.start) || d.isAfter(window.due)) {
      final hours = ShiftHours.standard(ScheduleDay.fromDate(s), shift);
      return 'Outside ${shift.label} shift hours (${hours.format()})';
    }
    return null;
  }

  // ── Presentation helpers (read-only; [_save] stays the source of truth) ──

  /// Whether the always-required essentials are in place, so the sticky Create
  /// button can reflect readiness live. This is a *reflection* of state, not the
  /// gate — [_save] still runs the full, authoritative validation (including the
  /// work-type setup) and surfaces inline errors.
  bool get _canSubmit {
    if (_title.text.trim().isEmpty) return false;
    final branch = widget.isAdmin ? (_branchId ?? '') : widget.defaultBranchId;
    if (branch.trim().isEmpty) return false;
    if (widget.existing == null &&
        _assignmentType == TaskAssignmentType.shift &&
        _shift == null) {
      return false;
    }
    if (_needsAssignee) return false;
    return _scheduleError == null;
  }

  /// Any content entered — used to guard against losing work on Cancel (the
  /// bottom sheet's fatal flaw: one stray swipe wiped everything).
  bool get _dirty =>
      _title.text.trim().isNotEmpty ||
      _desc.text.trim().isNotEmpty ||
      _assignees.isNotEmpty ||
      _shift != null ||
      _newRefs.isNotEmpty ||
      _itemControllers.any((c) => c.text.trim().isNotEmpty);

  /// A one-line, plain-language summary under the Create button — what the
  /// manager is about to make, or the single thing still missing.
  String _footerSummary(bool isNew, bool shiftMode) {
    if (_title.text.trim().isEmpty) {
      return 'Add a title to continue';
    }
    if (widget.isAdmin && (_branchId ?? '').trim().isEmpty) {
      return 'Select a branch to continue';
    }
    if (isNew && shiftMode && _shift == null) {
      return 'Choose a shift to continue';
    }
    if (_needsAssignee) {
      return 'Choose who this task is for';
    }
    final who = shiftMode
        ? (_shift == null ? null : '${_shift!.label} shift')
        : (_assignees.isEmpty
              ? null
              : '${_assignees.length} '
                    '${_assignees.length == 1 ? 'person' : 'people'}');
    final when = _deadline != null
        ? 'due ${AppDateFormatter.dayMonth(_deadline!)}'
        : null;
    final parts = <String>[];
    if (who != null) parts.add('Assigned to $who');
    if (when != null) parts.add(when);
    if (parts.isEmpty) return isNew ? 'Ready to create' : 'Ready to save';
    return parts.join(' · ');
  }

  /// Cancel with a discard guard when there is unsaved work.
  Future<void> _confirmCancel() async {
    FocusScope.of(context).unfocus();
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(
          widget.existing == null ? 'Discard new task?' : 'Discard changes?',
        ),
        content: const Text('Your edits will not be saved.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  /// Whether any optional enhancement already carries content — used to open the
  /// Options panel automatically when editing or seeding from a template.
  bool get _hasOptionalContent =>
      _itemControllers.any((c) => c.text.trim().isNotEmpty) ||
      _priority != TaskPriority.normal ||
      _recurrence != RecurrenceFrequency.none ||
      _shiftRepeat != TemplateRepeatMode.once ||
      _newRefs.isNotEmpty ||
      _existingRefs.isNotEmpty;

  /// A compact readout of what's set inside the collapsed Options panel, so its
  /// state is legible without expanding it.
  String _optionsSummary(bool shiftMode) {
    final parts = <String>[];
    final steps = _itemControllers
        .where((c) => c.text.trim().isNotEmpty)
        .length;
    if (steps > 0) parts.add('$steps ${steps == 1 ? 'step' : 'steps'}');
    if (_priority != TaskPriority.normal) {
      parts.add('${_priorityLabel(_priority)} priority');
    }
    if (shiftMode) {
      if (_shiftRepeat != TemplateRepeatMode.once) parts.add('Repeats');
    } else if (_recurrence != RecurrenceFrequency.none) {
      parts.add('Repeats ${_recurrence.label.toLowerCase()}');
    }
    final photos = _newRefs.length + _existingRefs.length;
    if (photos > 0) parts.add('$photos ${photos == 1 ? 'photo' : 'photos'}');
    if (parts.isEmpty) return 'Steps · priority · repeat · attachments';
    return parts.join(' · ');
  }

  static String _priorityLabel(TaskPriority p) => switch (p) {
    TaskPriority.low => 'Low',
    TaskPriority.normal => 'Normal',
    TaskPriority.high => 'High',
  };

  /// Submit wrapper: runs the unchanged [_save], then — if it surfaced an error
  /// — makes sure the Options panel is open, so an error on a folded field
  /// (e.g. a work type that requires steps) is never hidden.
  void _submit() {
    _save();
    if (mounted && _error != null && !_optionsExpanded) {
      setState(() => _optionsExpanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    final shiftMode = _assignmentType == TaskAssignmentType.shift;

    // Each section (its group divider + content) fades + lifts in with a gentle
    // stagger, so opening the page feels like a workflow assembling rather than
    // a static form appearing.
    var step = 0;
    Widget section({String? label, IconData? icon, required Widget child}) {
      final body = label == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(label, icon: icon),
                child,
              ],
            );
      return EntranceFade(delay: staggerDelay(step++), child: body);
    }

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      // A pinned nav bar (Cancel · condensing title), a scrolling body, and a
      // Create action pinned to the bottom — the full-screen frame that a bottom
      // sheet never had. The footer is a bottomNavigationBar so it rides above
      // the keyboard automatically.
      body: Column(
        children: [
          _FormTopBar(
            isNew: isNew,
            scrolled: _scrolled,
            onCancel: _confirmCancel,
          ),
          Expanded(
            child: CupertinoScrollbar(
              controller: _scroll,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  AppSpacing.sm,
                  AppSpacing.pagePadding,
                  AppSpacing.xxxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EntranceFade(
                      offset: 10,
                      duration: const Duration(milliseconds: 420),
                      child: _FormHero(isNew: isNew),
                    ),

                    // ── Work type: the first, framing decision — it determines
                    //    the form's structure, so it establishes context before
                    //    any data entry. ─────────────────────────────────────
                    section(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _WorkTypeIntro(enabled: isNew),
                          const SizedBox(height: AppSpacing.md),
                          // Regenerates the type-specific fields in Task Details.
                          // Locked (static) in edit mode.
                          WorkTypePicker(
                            value: _workType,
                            enabled: isNew,
                            onChanged: (id) => setState(() {
                              _workType = id; // fields differ per type
                              _workData = {};
                              _workFieldErrors = const {};
                            }),
                          ),
                        ],
                      ),
                    ),

                    // ── Task Details: the "what is this" block — title, the
                    //    type's own fields, and an optional description ────────
                    section(
                      label: 'Task Details',
                      icon: Icons.subject_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            controller: _title,
                            label: 'Title',
                            prefixIcon: Icons.title_rounded,
                            autofocus: true,
                            errorText: _titleError,
                            onFocusChange: _onTitleFocusChange,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          // Type-specific fields (nothing for a general task).
                          DynamicWorkForm(
                            definition: WorkTypeRegistry.instance.byId(
                              _workType,
                            ),
                            initialData: _workData,
                            errors: _workFieldErrors,
                            onChanged: (data) => _workData = data,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _desc,
                            label: 'Description (optional)',
                            prefixIcon: Icons.notes_rounded,
                            maxLines: 4,
                            minLines: 1,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                          ),
                        ],
                      ),
                    ),

                    // ── Assignment: branch, mode, and who ───────────────────────────
                    section(
                      label: 'Assignment',
                      icon: Icons.group_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.isAdmin) ...[
                            _BranchField(
                              future: _branchesFuture,
                              value: _branchId,
                              onChanged: (v) => setState(() {
                                _branchId = v;
                                _assignees
                                    .clear(); // employees differ per branch
                                _syncEmployeesFuture();
                              }),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (isNew) ...[
                            const _FieldCaption('Assigned to'),
                            const SizedBox(height: AppSpacing.sm),
                            _AssignmentModeCards(
                              value: _assignmentType,
                              onChanged: _onAssignmentModeChanged,
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (shiftMode)
                            ShiftChipPicker(
                              value: _shift,
                              onChanged: (s) => setState(() {
                                _shift = s;
                                // Picking a shift pre-fills the schedule as a smart default
                                // (never a lock — the manager can still edit or reset).
                                _suggestFromShift(s);
                              }),
                            )
                          else ...[
                            _AssigneeField(
                              future: _employeesFuture,
                              selected: _assignees,
                              onChanged: _onAssigneesChanged,
                            ),
                            if (_assignmentNote != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              _AssignmentNote(text: _assignmentNote!),
                            ],
                          ],
                        ],
                      ),
                    ),

                    // ── Schedule: when the work starts and is due ───────────────────
                    section(
                      label: 'Schedule',
                      icon: Icons.event_note_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_mixedShifts) ...[
                            _MixedShiftChooser(
                              onPick: (shift) => setState(() {
                                _suggestFromShift(shift);
                                _mixedShifts = false;
                              }),
                              onCustom: () =>
                                  setState(() => _mixedShifts = false),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          _ScheduleField(
                            start: _startsAt,
                            due: _deadline,
                            resolving: _resolvingShift,
                            onQuickDeadline: isNew ? _applyQuickDeadline : null,
                            quickDeadlineDuration: _quickDeadlinePreset,
                            onPickStart: _pickStart,
                            onPickDue: _pickDue,
                            onClearStart: () => setState(() {
                              _startsAt = null;
                              _scheduleCustom = true;
                              _quickDeadlinePreset = null;
                            }),
                            onClearDue: () => setState(() {
                              _deadline = null;
                              _scheduleCustom = true;
                              _quickDeadlinePreset = null;
                            }),
                            sourceLabel: _scheduleSourceLabel,
                            custom: _scheduleCustom && _scheduleSource != null,
                            onReset: _scheduleSource == null
                                ? null
                                : _resetToSource,
                            warning: _scheduleWarning,
                            error: _scheduleError,
                          ),
                        ],
                      ),
                    ),

                    // ── Options: optional enhancements — always one tap away,
                    //    visually secondary, collapsed by default so the common
                    //    task stays a short screen. Steps · Priority · Repeat ·
                    //    Attachments. ─────────────────────────────────────────
                    EntranceFade(
                      delay: staggerDelay(step++),
                      child: _OptionsPanel(
                        title: 'Additional Details',
                        expanded: _optionsExpanded,
                        summary: _optionsSummary(shiftMode),
                        onToggle: () => setState(
                          () => _optionsExpanded = !_optionsExpanded,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Steps (checklist)
                            _ChecklistBuilder(
                              controllers: _itemControllers,
                              required: _itemRequired,
                              lastAdded: _lastAddedIndex,
                              onAdd: _addChecklistItem,
                              onRemove: _removeChecklistItem,
                              onToggleRequired: _toggleRequired,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const _FieldCaption('Priority'),
                            const SizedBox(height: AppSpacing.sm),
                            _Segmented<TaskPriority>(
                              value: _priority,
                              onChanged: (v) => setState(() => _priority = v),
                              segments: const [
                                _Seg(
                                  TaskPriority.low,
                                  'Low',
                                  icon: Icons.arrow_downward_rounded,
                                ),
                                _Seg(
                                  TaskPriority.normal,
                                  'Normal',
                                  icon: Icons.remove_rounded,
                                ),
                                _Seg(
                                  TaskPriority.high,
                                  'High',
                                  icon: Icons.priority_high_rounded,
                                ),
                              ],
                            ),
                            // Recurrence (new tasks only) — shift mode gets its
                            // own Once/Daily/Weekly picker (daily/weekly saves as
                            // a recurring shift-task template, not a single task).
                            if (isNew) ...[
                              const SizedBox(height: AppSpacing.lg),
                              if (shiftMode)
                                ShiftRepeatPicker(
                                  value: _shiftRepeat,
                                  onChanged: (v) =>
                                      setState(() => _shiftRepeat = v),
                                  weekday: _shiftWeekday,
                                  onWeekdayChanged: (w) =>
                                      setState(() => _shiftWeekday = w),
                                )
                              else ...[
                                const _FieldCaption('Repeats'),
                                const SizedBox(height: AppSpacing.sm),
                                _Segmented<RecurrenceFrequency>(
                                  value: _recurrence,
                                  onChanged: (v) =>
                                      setState(() => _recurrence = v),
                                  segments: const [
                                    _Seg(RecurrenceFrequency.none, 'None'),
                                    _Seg(RecurrenceFrequency.daily, 'Daily'),
                                    _Seg(RecurrenceFrequency.weekly, 'Weekly'),
                                    _Seg(
                                      RecurrenceFrequency.monthly,
                                      'Monthly',
                                    ),
                                  ],
                                ),
                              ],
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            AttachmentPickerField(
                              attachments: _newRefs,
                              allowVideo: false,
                              title: 'Reference images',
                              hint:
                                  'Attach photos showing how this should look — the '
                                  'employee sees them before starting. Photos are '
                                  'compressed before upload.',
                              existing: _existingRefs,
                              onRemoveExisting: (a) =>
                                  setState(() => _existingRefs.remove(a)),
                              onChanged: (list) =>
                                  setState(() => _newRefs = list),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Inline validation (the submit action lives in the
                    // sticky footer, always in reach) ──────────────────────
                    EntranceFade(
                      delay: staggerDelay(step++),
                      offset: 10,
                      child: _FormErrorBanner(message: _error),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _StickyCreateBar(
        isNew: isNew,
        canSubmit: _canSubmit,
        summary: _footerSummary(isNew, shiftMode),
        onSubmit: _submit,
      ),
    );
  }
}

// ─── Full-screen chrome (elevates the form into a first-class page) ──────

/// The pinned nav bar: a Cupertino **Cancel**, and a title that condenses in
/// from the hero as the body scrolls. A hairline appears only once scrolled, so
/// the bar is invisible at rest and orienting in motion.
class _FormTopBar extends StatelessWidget {
  const _FormTopBar({
    required this.isNew,
    required this.scrolled,
    required this.onCancel,
  });

  final bool isNew;
  final bool scrolled;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(top: top),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        border: Border(
          bottom: BorderSide(
            color: scrolled ? AppColors.darkBorder : AppColors.transparent,
          ),
        ),
      ),
      child: SizedBox(
        height: 50,
        child: Stack(
          children: [
            Center(
              child: AnimatedOpacity(
                opacity: scrolled ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Text(
                  isNew ? 'New Task' : 'Edit Task',
                  style: AppTypography.label,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                onPressed: onCancel,
                child: Text(
                  'Cancel',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The hero — the page's visual identity. An eyebrow beside a soft glyph tile,
/// then a large title and a one-line intent. This is what makes the screen read
/// as a destination, not a converted sheet.
class _FormHero extends StatelessWidget {
  const _FormHero({required this.isNew});
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppColors.subtleGradient,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Icon(
                  isNew ? Icons.add_task_rounded : Icons.edit_note_rounded,
                  size: 19,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                isNew ? 'CREATE · WORKFLOW' : 'EDIT · WORKFLOW',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isNew ? 'New Task' : 'Edit Task',
            style: AppTypography.displayMedium,
          ),
          const SizedBox(height: 6),
          Text(
            isNew
                ? 'Compose the work, then choose who runs it.'
                : 'Refine the details and reassign as needed.',
            style: AppTypography.body,
          ),
        ],
      ),
    );
  }
}

/// A short lead-in that frames the work type as the workflow's first decision
/// rather than one field among many.
class _WorkTypeIntro extends StatelessWidget {
  const _WorkTypeIntro({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What kind of work is this?',
          style: AppTypography.labelLarge.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 3),
        Text(
          enabled
              ? 'This shapes the fields below.'
              : "A task's type is fixed once it's created.",
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

/// The assignment-mode chooser as three interactive **cards** (Individual ·
/// Group · Shift) — each with a glyph, label, and a one-line description, so
/// choosing *how* the work is assigned feels like a decision, not a toggle.
///
/// The three modes describe how the branch actually works: one person owns it,
/// a few named people share it, or it belongs to whoever is on a shift. The
/// middle mode is deliberately **not** called "Team" — it is a set picked for
/// this one task, not a standing org unit — and it is **not** "everyone in the
/// branch": that claim used to sit on this card but nothing implemented it (an
/// empty pick reaches nobody, see `canUserAccessTask`).
class _AssignmentModeCards extends StatelessWidget {
  const _AssignmentModeCards({required this.value, required this.onChanged});

  final TaskAssignmentType value;
  final ValueChanged<TaskAssignmentType> onChanged;

  static const _meta = {
    TaskAssignmentType.individual: (
      Icons.person_outline_rounded,
      'One person owns this task',
    ),
    TaskAssignmentType.team: (
      Icons.groups_2_outlined,
      'A few people you pick, sharing the work',
    ),
    TaskAssignmentType.shift: (
      Icons.schedule_rounded,
      'Whoever is rostered on a shift',
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final t in TaskAssignmentType.values) ...[
          _AssignmentModeCard(
            selected: t == value,
            icon: _meta[t]!.$1,
            label: t.label,
            description: _meta[t]!.$2,
            onTap: () => onChanged(t),
          ),
          if (t != TaskAssignmentType.values.last)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _AssignmentModeCard extends StatelessWidget {
  const _AssignmentModeCard({
    required this.selected,
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label. $description',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.darkSurfaceElevated
                : AppColors.darkSurface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: selected ? AppColors.accentBorder : AppColors.darkBorder,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.darkBg,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.label.copyWith(
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      description,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              _ModeRadio(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// A minimal monochrome selection indicator (filled ring when chosen).
class _ModeRadio extends StatelessWidget {
  const _ModeRadio({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.accent : AppColors.transparent,
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.textQuaternary,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 13, color: AppColors.onAccent)
          : null,
    );
  }
}

/// The sticky Create action — always in reach at the bottom, riding above the
/// keyboard. It reflects readiness live (disabled until the essentials are set)
/// and states, in one line, what the manager is about to make.
class _StickyCreateBar extends StatelessWidget {
  const _StickyCreateBar({
    required this.isNew,
    required this.canSubmit,
    required this.summary,
    required this.onSubmit,
  });

  final bool isNew;
  final bool canSubmit;
  final String summary;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.darkBg,
        border: Border(top: BorderSide(color: AppColors.darkBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.md,
            AppSpacing.pagePadding,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                label: isNew ? 'Create Task' : 'Save Changes',
                icon: const Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: AppColors.onAccent,
                ),
                onPressed: canSubmit ? onSubmit : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  summary,
                  key: ValueKey(summary),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The optional-enhancements disclosure ("Additional Details" — steps · priority
/// · repeat · attachments), kept visually secondary and collapsed by default so
/// the required workflow reads as a short screen. A tappable header (with a live
/// summary of what's set) reveals the body with an [AnimatedSize] + fade. It
/// never *blocks* — it's always one tap away, in any order.
class _OptionsPanel extends StatelessWidget {
  const _OptionsPanel({
    required this.title,
    required this.expanded,
    required this.summary,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final bool expanded;
  final String summary;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: title,
            hint: expanded ? 'Collapse' : 'Expand',
            child: InkWell(
              onTap: onToggle,
              borderRadius: AppRadius.lgAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: AppRadius.lgAll,
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      title,
                      style: AppTypography.label.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // The summary of what's set — hidden once expanded (the fields
                    // themselves are then visible right below).
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: expanded
                            ? const SizedBox.shrink()
                            : Text(
                                summary,
                                key: ValueKey(summary),
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.expand_more_rounded,
                        size: 20,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

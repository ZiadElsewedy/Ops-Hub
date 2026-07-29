part of '../../task_action_sheets.dart';

// ─── Premium form primitives ─────────────────────────────────────
// A small, cohesive kit shared across the create form so every section reads
// as one system: group dividers, quiet duration controls, summary picker tiles,
// the deadline field and an animated validation banner. (The page's hero header
// now lives with the full-screen chrome in task_form_sheet.dart.)

/// A group divider — a small labelled heading with a trailing hairline that
/// visually partitions the long form into scannable sections.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Divider(color: AppColors.darkBorder, height: 1),
          ),
        ],
      ),
    );
  }
}

/// A small caption above a control (e.g. above a segmented control).
class _FieldCaption extends StatelessWidget {
  const _FieldCaption(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
  );
}

/// The soft rounded 36px icon tile that leads a [_PickerTile] / list row.
class _LeadIcon extends StatelessWidget {
  const _LeadIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Icon(icon, size: 18, color: AppColors.textSecondary),
    );
  }
}

/// A tappable summary row — a leading glyph, a label, and the current value (or
/// a muted placeholder). The house replacement for dropdown-style selectors:
/// the *value* stays visible in the form; the *choosing* happens in a sheet.
/// On desktop the tile warms its border and surface on hover so a selectable row
/// feels alive under the pointer.
class _PickerTile extends StatefulWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    this.value,
    this.placeholder,
    this.leading,
    this.onTap,
    this.onClear,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? placeholder;
  final Widget? leading;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool enabled;

  @override
  State<_PickerTile> createState() => _PickerTileState();
}

class _PickerTileState extends State<_PickerTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final filled = w.value != null;
    final interactive = w.enabled && w.onTap != null;
    final hovered = _hovered && interactive;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final lifted = hovered && !reduceMotion;
    return Opacity(
      opacity: w.enabled ? 1 : 0.55,
      child: MouseRegion(
        cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) {
          if (interactive) setState(() => _hovered = true);
        },
        onExit: (_) {
          if (_hovered) setState(() => _hovered = false);
        },
        child: InkWell(
          onTap: w.enabled ? w.onTap : null,
          borderRadius: AppRadius.xlAll,
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, lifted ? -1 : 0, 0),
            transformAlignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.subtleGradient,
              borderRadius: AppRadius.xlAll,
              border: Border.all(
                color: hovered ? AppColors.textTertiary : AppColors.darkBorder,
              ),
              boxShadow: lifted
                  ? const [
                      BoxShadow(
                        color: Color(0x52000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                w.leading ?? _LeadIcon(icon: w.icon),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Field label = supporting label (light grey); the chosen
                      // value is the content (white); an unset placeholder is the
                      // faintest step (dark grey), so an empty field reads clearly
                      // "not filled yet" without competing with its label.
                      Text(
                        w.label,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        filled ? w.value! : (w.placeholder ?? ''),
                        style: AppTypography.body.copyWith(
                          color: filled
                              ? AppColors.textPrimary
                              : AppColors.textQuaternary,
                          fontWeight: filled
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (w.onClear != null && filled)
                  GestureDetector(
                    onTap: w.onClear,
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  )
                else if (w.enabled)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: hovered
                        ? AppColors.textSecondary
                        : AppColors.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The **Schedule** control (Task Scheduling V2) — optional quick deadline
/// presets, then a Start row and a Due row, each carrying a date **and** time,
/// plus the estimated duration, validation, and a smart-default banner.
/// Times are pre-filled from the resolved shift as a
/// *suggestion*; the moment the manager edits either value the banner flips to
/// "Custom schedule / Originally: Morning shift · 08:30 – 16:30 / Reset to
/// shift". Suggestions **never lock** the fields; overnight windows (due on a
/// later day) are fully supported.
class _ScheduleField extends StatelessWidget {
  const _ScheduleField({
    required this.start,
    required this.due,
    required this.onPickStart,
    required this.onPickDue,
    required this.onClearStart,
    required this.onClearDue,
    this.resolving = false,
    this.onQuickDeadline,
    this.quickDeadlineDuration,
    this.sourceLabel,
    this.custom = false,
    this.onReset,
    this.warning,
    this.error,
  });

  final DateTime? start;
  final DateTime? due;
  final VoidCallback onPickStart;
  final VoidCallback onPickDue;
  final VoidCallback onClearStart;
  final VoidCallback onClearDue;

  /// A rostered-shift resolve is in flight (subtle "Checking roster…" hint).
  final bool resolving;

  /// Optional create-mode shortcuts: start now, due after the picked duration.
  final ValueChanged<Duration>? onQuickDeadline;

  /// The active quick deadline preset, if this schedule came from one.
  final Duration? quickDeadlineDuration;

  /// The suggestion source (e.g. "Morning shift · 08:30 – 16:30"), or null when
  /// nothing resolved (no banner — pure manual scheduling).
  final String? sourceLabel;

  /// True once the manager has overridden the suggestion.
  final bool custom;

  /// Restore the suggestion; null when there's nothing to reset to.
  final VoidCallback? onReset;

  /// Non-blocking advisory (e.g. "Outside Morning shift hours"), or null.
  final String? warning;

  /// Blocking validation (e.g. due before start), or null.
  final String? error;

  static String _fmt(DateTime d) => AppDateFormatter.dayMonthYearTime(d);
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    Duration? span;
    if (error == null && start != null && due != null) {
      final d = due!.difference(start!);
      if (d.inMinutes > 0) span = d;
    }
    final overnight = start != null && due != null && !_sameDay(start!, due!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onQuickDeadline != null) ...[
          _ScheduleQuickPresets(
            selected: quickDeadlineDuration,
            onPick: onQuickDeadline!,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        _PickerTile(
          icon: Icons.play_circle_outline_rounded,
          label: 'Start',
          value: start == null ? null : _fmt(start!),
          placeholder: 'Not set',
          onTap: onPickStart,
          onClear: onClearStart,
        ),
        const SizedBox(height: AppSpacing.sm),
        _PickerTile(
          icon: Icons.flag_outlined,
          label: 'Due',
          value: due == null ? null : _fmt(due!),
          placeholder: 'No due time',
          onTap: onPickDue,
          onClear: onClearDue,
        ),
        if (resolving)
          // Contextual helper / metadata under the fields → medium grey.
          _scheduleNote(
            Icons.sync_rounded,
            'Checking roster…',
            AppColors.textTertiary,
          ),
        if (error != null)
          _scheduleNote(Icons.error_outline_rounded, error!, AppColors.error)
        // A tangible start → due timeline instead of a plain "8h" line — the
        // window becomes something you can see, with the duration riding the
        // track and an overnight window reading its moon.
        else if (span != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ScheduleTimeline(
            start: start!,
            due: due!,
            span: span,
            overnight: overnight,
            emphasized: quickDeadlineDuration != null,
          ),
        ],
        if (warning != null)
          _scheduleNote(
            Icons.warning_amber_rounded,
            warning!,
            AppColors.warning,
          ),
        if (sourceLabel != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _ScheduleBanner(
            sourceLabel: sourceLabel!,
            custom: custom,
            onReset: onReset,
          ),
        ],
      ],
    );
  }

  /// A small icon + text info line under the schedule rows.
  static Widget _scheduleNote(IconData icon, String text, Color color) =>
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm, left: 2),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: AppTypography.caption.copyWith(color: color),
              ),
            ),
          ],
        ),
      );
}

class _ScheduleQuickPresets extends StatelessWidget {
  const _ScheduleQuickPresets({required this.selected, required this.onPick});

  final Duration? selected;
  final ValueChanged<Duration> onPick;

  static const _options = [
    _DeadlinePresetOption(
      label: 'Tomorrow',
      detail: '24h',
      icon: Icons.today_outlined,
      duration: Duration(days: 1),
      semanticLabel: 'Start now and due tomorrow',
    ),
    _DeadlinePresetOption(
      label: '2 days',
      detail: '48h',
      icon: Icons.filter_2_rounded,
      duration: Duration(days: 2),
      semanticLabel: 'Start now and due in 2 days',
    ),
    _DeadlinePresetOption(
      label: 'Week',
      detail: '7d',
      icon: Icons.calendar_view_week_outlined,
      duration: Duration(days: 7),
      semanticLabel: 'Start now and due in 1 week',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _options.indexWhere((o) => o.duration == selected);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.subtleGradient,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = _options.length;
          final slot = constraints.maxWidth / count;
          final firstStop = slot / 2;
          final segment = count <= 1 ? 0.0 : slot;
          final selectedX = selectedIndex < 0
              ? firstStop
              : firstStop + (segment * selectedIndex);
          final activeWidth = selectedIndex < 0 ? 0.0 : selectedX - firstStop;

          return SizedBox(
            height: 74,
            child: Stack(
              children: [
                Positioned(
                  left: firstStop,
                  right: firstStop,
                  top: 17,
                  child: Container(height: 1, color: AppColors.darkBorder),
                ),
                AnimatedPositioned(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 340),
                  curve: Curves.easeOutCubic,
                  left: firstStop,
                  top: 16.5,
                  width: activeWidth,
                  child: Container(height: 2, color: AppColors.textSecondary),
                ),
                if (selectedIndex >= 0)
                  AnimatedPositioned(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 340),
                    curve: Curves.easeOutCubic,
                    left: selectedX - 13,
                    top: 5,
                    child: _DeadlineRailThumb(
                      icon: _options[selectedIndex].icon,
                    ),
                  ),
                Row(
                  children: [
                    for (var i = 0; i < count; i++)
                      Expanded(
                        child: _DeadlinePresetStop(
                          option: _options[i],
                          selected: i == selectedIndex,
                          onTap: () => onPick(_options[i].duration),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DeadlinePresetOption {
  const _DeadlinePresetOption({
    required this.label,
    required this.detail,
    required this.icon,
    required this.duration,
    required this.semanticLabel,
  });

  final String label;
  final String detail;
  final IconData icon;
  final Duration duration;
  final String semanticLabel;
}

class _DeadlineRailThumb extends StatelessWidget {
  const _DeadlineRailThumb({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary),
      ),
      child: Icon(icon, size: 13, color: AppColors.onAccent),
    );
  }
}

class _DeadlinePresetStop extends StatefulWidget {
  const _DeadlinePresetStop({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _DeadlinePresetOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DeadlinePresetStop> createState() => _DeadlinePresetStopState();
}

class _DeadlinePresetStopState extends State<_DeadlinePresetStop> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final option = widget.option;
    final labelColor = selected
        ? AppColors.textPrimary
        : _hovered
        ? AppColors.textSecondary
        : AppColors.textTertiary;
    final detailColor = selected
        ? AppColors.textSecondary
        : AppColors.textQuaternary;

    return Semantics(
      button: true,
      selected: selected,
      label: option.semanticLabel,
      child: Tooltip(
        message: option.semanticLabel,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: 74,
              child: Column(
                children: [
                  SizedBox(
                    height: 36,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOut,
                        width: selected ? 8 : 6,
                        height: selected ? 8 : 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? AppColors.transparent
                              : _hovered
                              ? AppColors.textTertiary
                              : AppColors.darkSurfaceElevated,
                          border: Border.all(
                            color: selected
                                ? AppColors.transparent
                                : _hovered
                                ? AppColors.textSecondary
                                : AppColors.darkBorder,
                          ),
                        ),
                      ),
                    ),
                  ),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    style: AppTypography.labelSmall.copyWith(
                      color: labelColor,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    option.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: detailColor,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact **start → due** timeline that visualises the scheduled window: the
/// two times as endpoints (white, tabular so they align), a connecting track
/// with a node at each end, and the duration riding the middle of the track (a
/// moon when the window runs overnight). Makes the schedule tangible instead of
/// reading it off two separate fields.
class _ScheduleTimeline extends StatelessWidget {
  const _ScheduleTimeline({
    required this.start,
    required this.due,
    required this.span,
    required this.overnight,
    required this.emphasized,
  });

  final DateTime start;
  final DateTime due;
  final Duration span;
  final bool overnight;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      key: ValueKey('${span.inMinutes}-$overnight-$emphasized'),
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            gradient: AppColors.subtleGradient,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: emphasized ? AppColors.accentBorder : AppColors.darkBorder,
            ),
          ),
          child: Row(
            children: [
              // Overnight is signalled by the moon on the duration pill, so the
              // due endpoint stays short and safe at large text scales.
              _endpoint(AppDateFormatter.time(start), 'Start'),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _track(progress)),
              const SizedBox(width: AppSpacing.sm),
              _endpoint(AppDateFormatter.time(due), 'Due', end: true),
            ],
          ),
        );
      },
    );
  }

  Widget _endpoint(String time, String label, {bool end = false}) => Column(
    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        time,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelLarge.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      const SizedBox(height: 1),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
      ),
    ],
  );

  Widget _node({required bool filled}) {
    final active = filled || emphasized;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: active ? 10 : 9,
      height: active ? 10 : 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.textSecondary : AppColors.darkSurface,
        border: Border.all(
          color: active ? AppColors.textSecondary : AppColors.textTertiary,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _track(double progress) => SizedBox(
    height: 36,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Row(
          children: [
            _node(filled: true),
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(height: 2, color: AppColors.darkBorder),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0, 1),
                    child: Container(
                      height: 2,
                      color: emphasized
                          ? AppColors.textSecondary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            _node(filled: progress > 0.96),
          ],
        ),
        Transform.scale(
          scale: 0.94 + (0.06 * progress),
          child: Opacity(
            opacity: progress.clamp(0.35, 1),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: emphasized ? AppColors.primary : AppColors.darkSurface,
                borderRadius: AppRadius.fullAll,
                border: Border.all(
                  color: emphasized
                      ? AppColors.transparent
                      : AppColors.darkBorder,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: Row(
                  key: ValueKey(span.inMinutes),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      overnight
                          ? Icons.nightlight_round
                          : Icons.timelapse_rounded,
                      size: 12,
                      color: emphasized
                          ? AppColors.onAccent
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      formatScheduleDuration(span),
                      style: AppTypography.labelSmall.copyWith(
                        color: emphasized
                            ? AppColors.onAccent
                            : AppColors.textSecondary,
                        fontWeight: emphasized
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The Suggested / Custom banner under the Schedule rows. When suggested it's a
/// single confirming line; once customized it keeps the **original** shift on
/// screen ("Originally: …") so the manager always knows what the system proposed
/// and can snap back with one tap.
class _ScheduleBanner extends StatelessWidget {
  const _ScheduleBanner({
    required this.sourceLabel,
    required this.custom,
    required this.onReset,
  });

  final String sourceLabel;
  final bool custom;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.subtleGradient,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            custom ? Icons.tune_rounded : Icons.check_circle_outline_rounded,
            size: 15,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: custom
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom schedule',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Originally: $sourceLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Suggested from $sourceLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
          if (onReset != null) ...[
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: onReset,
              behavior: HitTestBehavior.opaque,
              child: Text(
                custom ? 'Reset to shift' : 'Reset',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown when the picked assignees span **different** shifts — the schedule
/// can't be auto-suggested, so the manager picks Morning / Night / Custom
/// (keeping them in control per the "smart defaults, never locked" principle).
class _MixedShiftChooser extends StatelessWidget {
  const _MixedShiftChooser({required this.onPick, required this.onCustom});

  final void Function(ScheduleShift) onPick;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.warning.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.groups_2_outlined,
                size: 15,
                color: AppColors.warning,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'These people work mixed shifts — pick a schedule',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _ChooserChip(
                label: ScheduleShift.morning.label,
                onTap: () => onPick(ScheduleShift.morning),
              ),
              _ChooserChip(
                label: ScheduleShift.night.label,
                onTap: () => onPick(ScheduleShift.night),
              ),
              _ChooserChip(label: 'Custom', onTap: onCustom),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChooserChip extends StatelessWidget {
  const _ChooserChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.fullAll,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// One option in a [_Segmented] control.
class _Seg<T> {
  const _Seg(this.value, this.label, {this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// A premium iOS-style segmented control with a sliding thumb — the house
/// replacement for a short single-choice dropdown (priority, assignment mode,
/// recurrence). Equal-width segments; the white thumb eases to the selection.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<_Seg<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = segments.length;
    final index = segments.indexWhere((s) => s.value == value);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    // Align.x for equal-width slots: -1 at slot 0 … +1 at slot n-1.
    final thumbX = n <= 1 ? 0.0 : (2 * (index < 0 ? 0 : index) / (n - 1)) - 1;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: AppColors.subtleGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Stack(
        children: [
          if (index >= 0)
            Positioned.fill(
              child: AnimatedAlign(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment(thumbX, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final seg in segments)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: seg.value == value,
                    label: seg.label,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(seg.value),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _SegLabel(
                          seg: seg,
                          selected: seg.value == value,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegLabel extends StatelessWidget {
  const _SegLabel({required this.seg, required this.selected});
  final _Seg seg;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.onPrimary : AppColors.textSecondary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (seg.icon != null) ...[
          Icon(seg.icon, size: 15, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(
              seg.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

/// Animated, monochrome-friendly validation banner shown above the CTA. Slides
/// open when a message arrives and collapses cleanly when it clears, so an error
/// reads as a deliberate moment rather than red text jumping in.
class _FormErrorBanner extends StatelessWidget {
  const _FormErrorBanner({required this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: EntranceFade(
                offset: 8,
                duration: const Duration(milliseconds: 220),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorSurface,
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(color: AppColors.error.withAlpha(90)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          message!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

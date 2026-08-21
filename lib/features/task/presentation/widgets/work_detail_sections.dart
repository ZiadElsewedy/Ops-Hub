import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';

/// # Work Details design system
///
/// One shared, Apple-flavoured visual language for the **work-type detail
/// experience**. Every work type (General, Transfer, Purchase, Inventory,
/// Inspection — and any future type) composes the *same* premium sections in a
/// different order, instead of inventing a bespoke layout. That keeps the
/// experience coherent and preserves the framework's promise that adding a new
/// type needs no screen surgery: an unrecognised type simply composes the
/// generic sections here.
///
/// Design stance (owner-locked): **strictly monochrome** — black / white / grey
/// surfaces, with the sanctioned attention **red** reserved for the genuinely
/// off-nominal case (over budget, shrinkage, an inspection failure). Large
/// numbers, generous whitespace, cards over tables, summary-before-detail.
///
/// The widgets below are the alphabet; `WorkTypePanel` is the composer.

// ─── Typography helpers ──────────────────────────────────────────────

/// Big-number metric type (Apple Health / Wallet). Kept here so every metric
/// across every work type reads at exactly the same weight and rhythm.
const TextStyle _kMetricValue = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 26,
  fontWeight: FontWeight.w700,
  height: 1.05,
  letterSpacing: -0.6,
  color: AppColors.textPrimary,
);

const TextStyle _kMetricValueLg = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 34,
  fontWeight: FontWeight.w700,
  height: 1.0,
  letterSpacing: -1,
  color: AppColors.textPrimary,
);

// ─── Value formatting ────────────────────────────────────────────────

/// Presentation number / money formatting for the detail cards. The domain
/// stores money as a plain `num` (no currency is modelled), so this groups
/// thousands and drops a redundant `.00` — never inventing a symbol.
class WorkFmt {
  const WorkFmt._();

  static String money(num v) {
    final whole = v == v.roundToDouble();
    final s = whole ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return _group(s);
  }

  static String signed(num v) {
    final body = money(v.abs());
    if (v > 0) return '+$body';
    if (v < 0) return '−$body'; // real minus sign
    return body;
  }

  static String _group(String number) {
    final dot = number.indexOf('.');
    final intPart = dot == -1 ? number : number.substring(0, dot);
    final frac = dot == -1 ? '' : number.substring(dot);
    final neg = intPart.startsWith('-');
    final digits = neg ? intPart.substring(1) : intPart;
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return '${neg ? '−' : ''}$buf$frac';
  }
}

// ─── Base card ───────────────────────────────────────────────────────

/// The single container every detail section card uses — a flat elevated
/// surface with a hairline border and roomy padding. Defined once so cards
/// never drift apart.
class WorkCard extends StatelessWidget {
  const WorkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: borderColor ?? AppColors.darkBorder),
      ),
      child: child,
    );
  }
}

/// A small uppercase eyebrow label used to head a card or a sub-group.
class WorkEyebrow extends StatelessWidget {
  const WorkEyebrow(this.text, {super.key, this.icon, this.trailing});
  final String text;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: AppColors.textTertiary),
          const SizedBox(width: 6),
        ],
        Text(
          text.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

// ─── State pill ──────────────────────────────────────────────────────

/// The tone of a [WorkStatePill] / metric. Monochrome by default; [attention]
/// is the one sanctioned red (over budget, shrinkage, a failure).
enum WorkTone { neutral, positive, attention }

Color _toneColor(WorkTone tone) => switch (tone) {
      WorkTone.neutral => AppColors.textSecondary,
      WorkTone.positive => AppColors.success,
      WorkTone.attention => AppColors.error,
    };

/// A compact status pill (e.g. "Within budget", "Over budget", "Reconciled",
/// "All clear", "Auto-approvable").
class WorkStatePill extends StatelessWidget {
  const WorkStatePill({
    super.key,
    required this.label,
    this.icon,
    this.tone = WorkTone.neutral,
  });

  final String label;
  final IconData? icon;
  final WorkTone tone;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(tone);
    final surface =
        tone == WorkTone.neutral ? AppColors.darkBg : color.withAlpha(28);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: 5),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppRadius.fullAll,
        border: Border.all(
            color: tone == WorkTone.neutral
                ? AppColors.darkBorder
                : color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              )),
        ],
      ),
    );
  }
}

// ─── Stat strip (three-up metrics) ───────────────────────────────────

/// One metric in a [WorkStatStrip].
class WorkStat {
  const WorkStat({
    required this.value,
    required this.label,
    this.tone = WorkTone.neutral,
    this.emphasize = false,
  });

  final String value;
  final String label;
  final WorkTone tone;

  /// Render this stat's value larger — used for the headline figure of a card
  /// (e.g. "Remaining") so the eye lands on it first.
  final bool emphasize;
}

/// The signature "three numbers in a card, split by hairlines" metric row
/// (Apple Health / Fitness). Equal-width columns; the value reads first, the
/// label sits quietly beneath. Scales from 2 to 4 stats.
class WorkStatStrip extends StatelessWidget {
  const WorkStatStrip({super.key, required this.stats});
  final List<WorkStat> stats;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      if (i > 0) {
        children.add(Container(
          width: 1,
          height: 34,
          color: AppColors.darkBorder,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ));
      }
      children.add(Expanded(child: _cell(stats[i])));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: children);
  }

  Widget _cell(WorkStat s) {
    final valueColor =
        s.tone == WorkTone.neutral ? AppColors.textPrimary : _toneColor(s.tone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            s.value,
            maxLines: 1,
            style: (s.emphasize ? _kMetricValueLg : _kMetricValue)
                .copyWith(color: valueColor),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          s.label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Progress bar ────────────────────────────────────────────────────

/// A thin, rounded, animated progress track with optional captions above it.
/// Used for budget burn-down and any 0–1 completion.
class WorkProgressBar extends StatelessWidget {
  const WorkProgressBar({
    super.key,
    required this.value,
    this.leading,
    this.trailing,
    this.tone = WorkTone.neutral,
    this.height = 8,
  });

  final double value;
  final String? leading;
  final String? trailing;
  final WorkTone tone;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fill =
        tone == WorkTone.attention ? AppColors.error : AppColors.textPrimary;
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null || trailing != null) ...[
          Row(
            children: [
              if (leading != null)
                Text(leading!,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary)),
              const Spacer(),
              if (trailing != null)
                Text(trailing!,
                    style: AppTypography.caption.copyWith(
                      color: tone == WorkTone.attention
                          ? AppColors.error
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    )),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: clamped),
            duration: const Duration(milliseconds: 620),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: height,
              backgroundColor: AppColors.darkBg,
              valueColor: AlwaysStoppedAnimation(fill),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Segment bar (inspection distribution) ───────────────────────────

/// A proportional stacked bar — pass / warning / fail — with a legend. The
/// distribution reads in one glance (Apple Activity rings, flattened). Only the
/// failure share carries red; pass is white, warning a mid grey.
class WorkSegmentBar extends StatelessWidget {
  const WorkSegmentBar({
    super.key,
    required this.pass,
    required this.warning,
    required this.fail,
  });

  final int pass;
  final int warning;
  final int fail;

  int get _total => pass + warning + fail;

  @override
  Widget build(BuildContext context) {
    final total = _total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: total == 0
                ? const ColoredBox(color: AppColors.darkBg)
                : Row(
                    children: [
                      if (pass > 0)
                        Expanded(
                            flex: pass,
                            child: const ColoredBox(color: AppColors.textPrimary)),
                      if (warning > 0)
                        Expanded(
                            flex: warning,
                            child: const ColoredBox(
                                color: AppColors.textTertiary)),
                      if (fail > 0)
                        Expanded(
                            flex: fail,
                            child: const ColoredBox(color: AppColors.error)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            _legend(AppColors.textPrimary, 'Pass', pass),
            const SizedBox(width: AppSpacing.lg),
            _legend(AppColors.textTertiary, 'Warning', warning),
            const SizedBox(width: AppSpacing.lg),
            _legend(AppColors.error, 'Fail', fail),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color dot, String label, int n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$n $label',
            style: AppTypography.caption
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

// ─── Fact list (captured data, premium) ──────────────────────────────

/// One captured field for [WorkFacts].
class WorkFact {
  const WorkFact(this.label, this.value, {this.multiline = false});
  final String label;
  final String value;

  /// Render the value as flowing body text on its own line (a note / paragraph)
  /// rather than a tight single line.
  final bool multiline;
}

/// The premium replacement for a key–value table: each fact is a stacked
/// label→value block separated by hairlines, so captured data reads as content,
/// not a database dump.
class WorkFacts extends StatelessWidget {
  const WorkFacts({super.key, required this.facts});
  final List<WorkFact> facts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < facts.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Divider(height: 1, color: AppColors.darkBorder),
            ),
          _row(facts[i]),
        ],
      ],
    );
  }

  Widget _row(WorkFact f) {
    if (f.multiline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.label.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 6),
          Text(f.value,
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary, height: 1.5)),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(f.label,
              style: AppTypography.body
                  .copyWith(color: AppColors.textTertiary)),
        ),
        const SizedBox(width: AppSpacing.lg),
        Flexible(
          child: Text(
            f.value,
            textAlign: TextAlign.right,
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

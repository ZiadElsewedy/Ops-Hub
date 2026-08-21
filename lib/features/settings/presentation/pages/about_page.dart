import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drop/core/constants/app_constants.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_glass_card.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/brand_watermark.dart';
import 'package:drop/core/widgets/opshub_logo.dart';

/// What DROP is, and how to reach a human about it.
///
/// Composed from the design-system primitives rather than hand-rolled boxes:
/// [AppGlassCard] for the surfaces (gradient + two-layer depth), the real
/// [OpsHubLogo] artwork behind a [BrandWatermark] so the lockup matches the
/// splash, and [EntranceFade] so the page assembles with the same stagger as
/// every other screen.
///
/// The support rows are **subject-led**, the same way the notification inbox
/// is: the address is the headline and the channel is a small kicker above it.
/// A support row exists to give you the address, so the address is what carries
/// the weight.
///
/// Each row hands a `mailto:` / `https:` URL to the OS. That can fail for
/// reasons this app cannot fix — no mail account configured, WhatsApp not
/// installed — so a failed hand-off **copies the value to the clipboard**
/// rather than reporting a dead end, and the value is selectable text besides.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const String _supportEmail = 'ZiadElsewedy1@gmail.com';
  static const String _whatsAppUrl =
      'https://wa.me/201028203969?text=Hi%20Ziad';
  static const String _whatsAppNumber = '+20 102 820 3969';

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'About',
      contentMaxWidth: 620,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.lg,
          AppSpacing.pagePadding,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EntranceFade(delay: staggerDelay(0), child: const _BrandCard()),
            const SizedBox(height: AppSpacing.xxl),
            EntranceFade(
              delay: staggerDelay(1),
              child: const _SectionLabel('Support'),
            ),
            const SizedBox(height: AppSpacing.md),
            EntranceFade(
              delay: staggerDelay(2),
              child: AppGlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SupportRow(
                      asset: 'assets/gmail.svg',
                      channel: 'Email',
                      value: _supportEmail,
                      isFirst: true,
                      onTap: () => _open(
                        context,
                        Uri(
                          scheme: 'mailto',
                          path: _supportEmail,
                          queryParameters: {
                            'subject': '${AppConstants.appName} support',
                          },
                        ),
                        copyOnFailure: _supportEmail,
                        failureLabel: 'No mail app is set up',
                      ),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.darkBorder,
                    ),
                    _SupportRow(
                      asset: 'assets/whatsapp.svg',
                      channel: 'WhatsApp',
                      value: _whatsAppNumber,
                      isLast: true,
                      onTap: () => _open(
                        context,
                        Uri.parse(_whatsAppUrl),
                        copyOnFailure: _whatsAppNumber,
                        failureLabel: 'Could not open WhatsApp',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            EntranceFade(
              delay: staggerDelay(3),
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'We usually reply within a working day.',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            EntranceFade(delay: staggerDelay(4), child: const _Colophon()),
          ],
        ),
      ),
    );
  }

  /// Hands [uri] to the OS. On any failure the value is copied instead, so the
  /// tap always leaves the user with something they can act on.
  static Future<void> _open(
    BuildContext context,
    Uri uri, {
    required String copyOnFailure,
    required String failureLabel,
  }) async {
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      AppLog.error('about', 'launch failed: $uri', e, st);
    }
    if (launched || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: copyOnFailure));
    if (context.mounted) {
      AppSnackbar.info(context, '$failureLabel — copied $copyOnFailure');
    }
  }
}

/// The brand lockup + what the product is. The real logo artwork over a
/// barely-there watermark of itself — the same mark the splash opens with, so
/// the page reads as part of the product rather than a settings sub-screen.
class _BrandCard extends StatelessWidget {
  const _BrandCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppGlassCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        // Small enough to stay in the corner beneath the last line of type. At
        // 118 it spanned the card and at 76 it still crossed the closing
        // paragraph — the one thing a watermark must never do, since it then
        // reads as a smudge on the text rather than a quiet mark.
        child: BrandWatermark(
          assetLogo: true,
          assetHeight: 54,
          opacity: 0.02,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const OpsHubLogo(height: 36),
              const SizedBox(height: 10),
              Text(
                'OPERATIONS',
                style: AppTypography.caption.copyWith(
                  fontSize: 10,
                  letterSpacing: 4.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // A hairline that stops short of the edge — the rule reads as a
              // deliberate mark rather than a full-width divider cutting the
              // card in two.
              Container(width: 44, height: 1, color: AppColors.darkBorder),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Drop Operations runs the day-to-day of a multi-branch operation. '
                'Tasks, shifts, attendance and approvals live in one place, '
                'so every branch opens and closes the same way — and a manager '
                'can see that it did, without asking.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Built for teams that work in shifts, not at desks.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textTertiary,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.caption.copyWith(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
      );
}

/// One support channel. The **address leads**; the channel name is a kicker
/// above it, and the glyph carries the type — the row language the notification
/// inbox uses, so the two surfaces read as one system.
class _SupportRow extends StatelessWidget {
  const _SupportRow({
    required this.asset,
    required this.channel,
    required this.value,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  /// The brand mark, as an SVG carrying its own colours.
  ///
  /// These are **the only colours on this screen** — everything else obeys the
  /// monochrome rule, where colour means status. A brand mark is the exception
  /// that proves it: identifying the channel is the row's whole job, and a grey
  /// WhatsApp glyph is just a speech bubble.
  ///
  /// SVG rather than an icon font because a font paints **one** colour, and
  /// Gmail's mark is four — as a font it came out a flat red M, which reads as
  /// a wrong logo rather than a brand.
  final String asset;

  final String channel;
  final String value;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(isFirst ? AppRadius.card : 0),
        bottom: Radius.circular(isLast ? AppRadius.card : 0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.darkBorder),
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                asset,
                width: 19,
                height: 19,
                // The marks have different aspect ratios (Gmail is wide,
                // WhatsApp square); contain keeps both inside the same optical
                // square so the two tiles read as a set.
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    channel.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Selectable so the address is still reachable if both the
                  // hand-off and the clipboard copy fail.
                  SelectableText(
                    value,
                    style: AppTypography.label.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              Icons.north_east_rounded,
              size: 15,
              color: AppColors.textQuaternary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The quiet sign-off at the foot of the page — a hairline and the version, in
/// the faintest step of the ramp. It closes the page instead of leaving it to
/// trail off into empty space.
class _Colophon extends StatelessWidget {
  const _Colophon();

  @override
  Widget build(BuildContext context) {
    // `stretch` (not the default `center`): the parent Column aligns its
    // children to the start, so a shrink-wrapped Column lands on the left edge
    // however its own children are aligned.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 28,
            height: 1,
            color: AppColors.darkBorder,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '${AppConstants.appName} · Version 1.0.0',
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(
            fontSize: 10,
            letterSpacing: 1.2,
            color: AppColors.textQuaternary,
          ),
        ),
      ],
    );
  }
}

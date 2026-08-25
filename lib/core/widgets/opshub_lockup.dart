import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/widgets/opshub_logo.dart';
import 'package:opshub/core/widgets/opshub_wordmark.dart';

/// **OpsHubLockup** — the horizontal brand lockup: the hub glyph [OpsHubLogo]
/// followed by the "OpsHub" [OpsHubWordmark] text, so the written name reads
/// beside the mark. This is the app-wide brand mark for shared chrome — the
/// desktop sidebar, the role-home app bar, and the quiet trailing mark on every
/// [AdaptiveScaffold] page.
///
/// Both halves tint to [color] (white on the dark UI by default). Size it with
/// [height] (the glyph height); the wordmark scales proportionally.
///
/// It is exposed as a single accessibility node labelled [semanticLabel]
/// (default `'OpsHub'`) so screen readers announce one brand element, not a glyph
/// and a word separately. Callers that want the bar to announce something else
/// (e.g. the role-home app bar announcing "Dashboard") pass their own label.
///
/// **Never truncates.** In a width-constrained slot (a crowded mobile app bar)
/// wrap it in a `FittedBox(fit: BoxFit.scaleDown)` — the whole lockup scales down
/// as one unit rather than clipping the name to "OpsH…".
class OpsHubLockup extends StatelessWidget {
  const OpsHubLockup({
    super.key,
    this.height = 20,
    this.color,
    this.semanticLabel = 'OpsHub',
  });

  /// The glyph height. The wordmark is sized proportionally from it.
  final double height;
  final Color? color;

  /// The single accessibility label for the whole lockup.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textPrimary;
    return Semantics(
      header: true,
      image: true,
      label: semanticLabel,
      // One node for the brand — the glyph and the word must not announce twice.
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            OpsHubLogo(height: height, color: tint),
            SizedBox(width: height * 0.4),
            OpsHubWordmark(fontSize: height * 0.92, color: tint),
          ],
        ),
      ),
    );
  }
}

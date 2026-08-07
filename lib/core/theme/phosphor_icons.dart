import 'package:flutter/widgets.dart';

/// Phosphor icon glyphs, self-hosted.
///
/// We deliberately do **not** depend on the `phosphor_flutter` package. Its
/// public `IconData` subclass (`class PhosphorIconData extends IconData`) fails
/// to compile on our SDK (Dart 3.12+), where `IconData` is a `final class` and
/// can no longer be extended outside its own library — the package is stuck on
/// that pattern and its latest release (2.1.0) has no fix. So, exactly like the
/// hand-rolled xlsx/pdf writers elsewhere in this repo, we vendor only what we
/// use: the two font weights (`assets/fonts/Phosphor-Regular.ttf` and
/// `Phosphor-Fill.ttf`, declared in `pubspec.yaml`) plus plain `const IconData`
/// constants for the subset of glyphs the navigation chrome needs.
///
/// The two classes mirror the package's `PhosphorIconsRegular` /
/// `PhosphorIconsFill` naming so call sites read the same. Regular is the
/// inactive weight, Fill the active one — the sidebar and bottom nav swap
/// between them on selection. Codepoints are copied verbatim from Phosphor
/// 2.1.0 (they are identical across weights; only the font file differs).
///
/// To add a glyph: find its codepoint in the Phosphor source (or phosphoricons.com)
/// and add a matching `const` to **both** classes.
class PhosphorIconsRegular {
  const PhosphorIconsRegular._();

  static const _family = 'PhosphorRegular';

  static const squaresFour = IconData(0xe464, fontFamily: _family);
  static const listChecks = IconData(0xeadc, fontFamily: _family);
  static const calendarDots = IconData(0xe7b4, fontFamily: _family);
  static const fingerprint = IconData(0xe23e, fontFamily: _family);
  static const megaphone = IconData(0xe324, fontFamily: _family);
  static const chatCircle = IconData(0xe168, fontFamily: _family);
  static const chatsCircle = IconData(0xe17e, fontFamily: _family);
  static const stamp = IconData(0xea48, fontFamily: _family);
  static const bell = IconData(0xe0ce, fontFamily: _family);
  static const chartBar = IconData(0xe150, fontFamily: _family);
  static const storefront = IconData(0xe470, fontFamily: _family);
  static const trendUp = IconData(0xe4ae, fontFamily: _family);
  static const identificationBadge = IconData(0xe6f6, fontFamily: _family);
  static const usersThree = IconData(0xe68e, fontFamily: _family);
  static const house = IconData(0xe2c2, fontFamily: _family);
  static const clock = IconData(0xe19a, fontFamily: _family);
}

class PhosphorIconsFill {
  const PhosphorIconsFill._();

  static const _family = 'PhosphorFill';

  static const squaresFour = IconData(0xe464, fontFamily: _family);
  static const listChecks = IconData(0xeadc, fontFamily: _family);
  static const calendarDots = IconData(0xe7b4, fontFamily: _family);
  static const fingerprint = IconData(0xe23e, fontFamily: _family);
  static const megaphone = IconData(0xe324, fontFamily: _family);
  static const chatCircle = IconData(0xe168, fontFamily: _family);
  static const chatsCircle = IconData(0xe17e, fontFamily: _family);
  static const stamp = IconData(0xea48, fontFamily: _family);
  static const bell = IconData(0xe0ce, fontFamily: _family);
  static const chartBar = IconData(0xe150, fontFamily: _family);
  static const storefront = IconData(0xe470, fontFamily: _family);
  static const trendUp = IconData(0xe4ae, fontFamily: _family);
  static const identificationBadge = IconData(0xe6f6, fontFamily: _family);
  static const usersThree = IconData(0xe68e, fontFamily: _family);
  static const house = IconData(0xe2c2, fontFamily: _family);
  static const clock = IconData(0xe19a, fontFamily: _family);
}

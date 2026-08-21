import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/auth/presentation/pages/splash_page.dart';

/// Measures the ACTUAL visual centre of the DROP artwork inside the Lottie's
/// settled tail frames (what's held on screen while bootstrap finishes) and
/// asserts the in-code compensation constant matches it. The splash can then
/// never be visually off-centre without this test failing — the constant is
/// locked to the asset's real pixels, not to anyone's eyeballing.
///
/// Also prints the artwork centre at several timeline points: the intro's
/// camera move swings the logo around mid-flight (by design), so only the
/// settled tail is a valid centering target.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('kLogoVisualCenterOffset matches the measured artwork centre of the '
      'settled Lottie tail', () async {
    final raw = File('assets/0704.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;

    // The export embeds every frame as a base64 WebP in `assets`, ordered by
    // the numeric suffix of the asset id (image_0 … image_N).
    final images =
        (json['assets'] as List)
            .cast<Map<String, dynamic>>()
            .where((a) => (a['p'] as String? ?? '').startsWith('data:image'))
            .toList()
          ..sort((a, b) {
            int n(Map<String, dynamic> m) =>
                int.parse(RegExp(r'\d+').firstMatch(m['id'] as String)![0]!);
            return n(a).compareTo(n(b));
          });
    expect(images, isNotEmpty, reason: 'Lottie must embed raster frames');

    Future<(ui.Offset, int)> artworkBounds(int index) async {
      final dataUri = images[index]['p'] as String;
      final bytes = base64Decode(dataUri.substring(dataUri.indexOf(',') + 1));
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final w = image.width, h = image.height;
      final rgba = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;

      // Bounding box of pixels bright enough to be the metallic logo (the
      // faint background vignette stays below this threshold).
      int minX = w, maxX = -1, minY = h, maxY = -1;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          final lum =
              0.299 * rgba.getUint8(i) +
              0.587 * rgba.getUint8(i + 1) +
              0.114 * rgba.getUint8(i + 2);
          if (lum > 45) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
      if (maxX < 0) return (ui.Offset.zero, 0); // fully dark frame
      return (
        ui.Offset((minX + maxX) / 2 - w / 2, (minY + maxY) / 2 - h / 2),
        minY,
      );
    }

    final n = images.length;
    // Full-timeline sweep — documents the camera move (information only):
    // how far off-centre does the artwork travel during the flight?
    var minDx = 0.0, maxDx = 0.0, minDy = 0.0, maxDy = 0.0;
    var minDxFrame = 0, maxDxFrame = 0;
    for (var f = 0; f < n; f++) {
      final (o, _) = await artworkBounds(f);
      if (o.dx < minDx) {
        minDx = o.dx;
        minDxFrame = f;
      }
      if (o.dx > maxDx) {
        maxDx = o.dx;
        maxDxFrame = f;
      }
      if (o.dy < minDy) minDy = o.dy;
      if (o.dy > maxDy) maxDy = o.dy;
    }
    // ignore: avoid_print
    print(
      '[measure] flight envelope over $n frames: '
      'dx ∈ [$minDx (f$minDxFrame), $maxDx (f$maxDxFrame)], '
      'dy ∈ [$minDy, $maxDy]',
    );

    // The settled tail — the frames held on screen during the wait. The
    // compensation targets their mean.
    final tail = [n - 3, n - 2, n - 1];
    var sum = ui.Offset.zero;
    var sumTop = 0;
    for (final f in tail) {
      final (o, top) = await artworkBounds(f);
      sum += o;
      sumTop += top;
      // ignore: avoid_print
      print('[measure] frame $f/$n (settled): artwork offset $o top=$top');
    }
    final mean = sum / tail.length.toDouble();
    final meanTop = sumTop / tail.length;
    // ignore: avoid_print
    print(
      '[measure] settled-tail mean offset: $mean, mean artwork top: $meanTop '
      '→ kLogoVisualCenterOffset should be '
      'Offset(${mean.dx.toStringAsFixed(0)}, ${mean.dy.toStringAsFixed(0)}), '
      'kLogoArtworkTop should be ${meanTop.toStringAsFixed(0)}',
    );

    expect(
      kLogoVisualCenterOffset.dx,
      moreOrLessEquals(mean.dx, epsilon: 2.5),
      reason: 'horizontal compensation drifted from the asset',
    );
    expect(
      kLogoVisualCenterOffset.dy,
      moreOrLessEquals(mean.dy, epsilon: 2.5),
      reason: 'vertical compensation drifted from the asset',
    );
    expect(
      kLogoArtworkTop,
      moreOrLessEquals(meanTop, epsilon: 4),
      reason:
          'artwork-top inset (drives the lockup framing) drifted '
          'from the asset',
    );
  });
}

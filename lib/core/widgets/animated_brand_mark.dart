import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:opshub/core/widgets/opshub_logo.dart';

/// The DROP brand mark rendered from the **Lottie animation** (`assets/0704.json`)
/// — the same asset the splash plays — so the animated logo can appear in-app
/// (e.g. the desktop sidebar lockup), not only at cold start.
///
/// The export's frames are **opaque rasters with a black background baked in**
/// (lossy WebP, no alpha). A luminance→alpha [ColorFilter.matrix] turns each
/// white-on-black frame into a **transparent white mark**, so it composites
/// cleanly onto any surface (the near-black sidebar included) instead of showing
/// a black box — and stays strictly monochrome.
///
/// Plays **once** on mount by default then rests on the assembled logo; a load
/// failure falls back to the static [OpsHubLogo]. The embedded frames decode at a
/// bounded width so a small chrome mark never pays the splash's full footprint.
class AnimatedBrandMark extends StatefulWidget {
  const AnimatedBrandMark({
    super.key,
    this.height = 36,
    this.aspectRatio = 1,
    this.fit = BoxFit.cover,
    this.scale = 1.2,
    this.repeat = false,
    this.decodeWidth = 240,
  });

  /// Rendered box height; width follows [aspectRatio].
  final double height;

  /// Box width / height. A value < 16/9 trims the export's wide black margins.
  final double aspectRatio;

  final BoxFit fit;

  /// Extra zoom into the centered glyph (the export leaves generous margins).
  final double scale;

  final bool repeat;

  /// Bound the embedded raster decode — a chrome mark needs far less than the
  /// splash hero, so keep its memory footprint small.
  final int decodeWidth;

  @override
  State<AnimatedBrandMark> createState() => _AnimatedBrandMarkState();
}

class _AnimatedBrandMarkState extends State<AnimatedBrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  // Output: white RGB, alpha = input luminance → the baked black turns
  // transparent, the white mark stays opaque. Input alpha is ignored (all zero
  // in the A row), which is exactly right for opaque frames.
  static const List<double> _lumaToAlpha = <double>[
    0, 0, 0, 0, 255, //
    0, 0, 0, 0, 255, //
    0, 0, 0, 0, 255, //
    0.2126, 0.7152, 0.0722, 0, 0, //
  ];

  void _onLoaded(LottieComposition composition) {
    if (!mounted) return;
    _controller.duration = composition.duration;
    if (widget.repeat) {
      _controller.repeat();
    } else if (!_controller.isAnimating) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: widget.height * widget.aspectRatio,
      child: ClipRect(
        child: Transform.scale(
          scale: widget.scale,
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(_lumaToAlpha),
            child: LottieBuilder(
              lottie: _BoundedAssetLottie('assets/0704.json', widget.decodeWidth),
              controller: _controller,
              fit: widget.fit,
              repeat: false,
              animate: false,
              onLoaded: _onLoaded,
              errorBuilder: (_, _, _) =>
                  Center(child: OpsHubLogo(height: widget.height * 0.72)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps the Lottie intact while bounding its embedded raster-frame decode size
/// (the export resolves data-URI images at full 720×405 otherwise).
class _BoundedAssetLottie extends AssetLottie {
  // ignore: use_super_parameters
  _BoundedAssetLottie(String assetName, this._decodedWidth)
      : super(assetName, backgroundLoading: true);

  final int _decodedWidth;

  @override
  ImageProvider<Object>? getImageProvider(LottieImageAsset lottieImage) {
    final provider = super.getImageProvider(lottieImage);
    return provider == null
        ? null
        : ResizeImage(provider, width: _decodedWidth, allowUpscaling: false);
  }
}

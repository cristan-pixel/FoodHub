import 'package:flutter/material.dart';

/// Brand artwork from `assets/App_Logo`.
///
/// [full] renders the mark together with the "FoodHub" wordmark; the default
/// renders just the mark, which is what compact headers and the app bar use.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 72,
    this.full = false,
    this.alignment = Alignment.center,
  });

  final double size;
  final bool full;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      full
          ? 'assets/App_Logo/foodhub_logo_full.png'
          : 'assets/App_Logo/foodhub_mark.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      alignment: alignment,
      filterQuality: FilterQuality.high,
      semanticLabel: 'FoodHub',
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.fastfood_rounded,
        size: size * 0.6,
        color: const Color(0xFFFF6600),
      ),
    );
  }
}

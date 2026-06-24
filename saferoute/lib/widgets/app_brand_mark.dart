import 'package:flutter/material.dart';

class AppBrandMark extends StatelessWidget {
  final double size;
  final double iconSize;
  final BorderRadius? borderRadius;

  const AppBrandMark({
    super.key,
    this.size = 48,
    this.iconSize = 24,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF334155), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius ?? BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.22),
            blurRadius: size * 0.2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: iconSize,
            ),
            Positioned(
              top: size * 0.18,
              child: Container(
                width: iconSize * 0.24,
                height: iconSize * 0.24,
                decoration: const BoxDecoration(
                  color: Color(0xFF93C5FD),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/map_catch_marker.dart';

/// Rarity-colored pin placed on the map for each caught plant.
///
/// Rare/Legendary get a glow halo — consistent with how their Dex cards are
/// treated (glow border for Rare, shimmer for Legendary).
class CatchMarkerWidget extends StatelessWidget {
  const CatchMarkerWidget({
    super.key,
    required this.marker,
    required this.isSelected,
  });

  final MapCatchMarker marker;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final color = marker.rarity.color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Glow halo for Rare / Legendary (or selected)
            if (marker.rarity.isHighRarity || isSelected)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(isSelected ? 0.7 : 0.45),
                      blurRadius: isSelected ? 16 : 10,
                      spreadRadius: isSelected ? 4 : 2,
                    ),
                  ],
                ),
              ),

            // Pin circle — white bg, rarity color as thick ring border
            Container(
              width: isSelected ? 40 : 34,
              height: isSelected ? 40 : 34,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: color,
                  width: isSelected ? 4 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  marker.rarity.emoji,
                  style: TextStyle(fontSize: isSelected ? 18 : 15),
                ),
              ),
            ),
          ],
        ),

        // Pointer tip
        CustomPaint(
          size: const Size(10, 6),
          painter: _TipPainter(color: color),
        ),
      ],
    );
  }
}

class _TipPainter extends CustomPainter {
  const _TipPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_TipPainter old) => old.color != color;
}

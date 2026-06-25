import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../models/map_catch_marker.dart';

/// Rarity legend — light card to sit over Voyager tiles.
class MapLegendWidget extends StatelessWidget {
  const MapLegendWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface.withOpacity(0.93),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: MarkerRarity.values.map((rarity) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: rarity.color,
                    shape: BoxShape.circle,
                    boxShadow: rarity.isHighRarity
                        ? [
                            BoxShadow(
                              color: rarity.color.withOpacity(0.5),
                              blurRadius: 4,
                            )
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  '${rarity.emoji} ${rarity.label}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

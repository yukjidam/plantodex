import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/rarity.dart';

class RarityPill extends StatelessWidget {
  const RarityPill(this.rarity, {super.key});
  final Rarity rarity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: rarity.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 10, color: rarity.color),
          const SizedBox(width: 5),
          Text(
            rarity.label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: rarity.color,
            ),
          ),
        ],
      ),
    );
  }
}

class RarityBadge extends StatelessWidget {
  const RarityBadge(this.rarity, {super.key});
  final Rarity rarity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: rarity.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        rarity.label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: rarity.color,
        ),
      ),
    );
  }
}

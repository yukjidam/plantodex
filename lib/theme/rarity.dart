import 'package:flutter/material.dart';
import '../theme/colors.dart';

enum Rarity { common, rare, epic, legendary }

extension RarityX on Rarity {
  String get label => switch (this) {
        Rarity.common => 'Common',
        Rarity.rare => 'Rare',
        Rarity.epic => 'Epic',
        Rarity.legendary => 'Legendary',
      };

  Color get color => switch (this) {
        Rarity.common => gray,
        Rarity.rare => blue,
        Rarity.epic => purple,
        Rarity.legendary => amber,
      };

  Color get background => switch (this) {
        Rarity.common => grayLight,
        Rarity.rare => blueLight,
        Rarity.epic => purpleLight,
        Rarity.legendary => amberLight,
      };

  // Number of filled dots (out of 5) shown on catch screen
  int get dots => switch (this) {
        Rarity.common => 1,
        Rarity.rare => 3,
        Rarity.epic => 4,
        Rarity.legendary => 5,
      };
}

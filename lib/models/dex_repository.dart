import '../dao/caught_plant_dao.dart';
import 'caught_plant.dart';
import 'dex_card_data.dart';
import 'plant_rarity_lookup.dart';
import '../theme/rarity.dart';

class DexSections {
  const DexSections({
    required this.all,
    required this.stats,
  });

  final List<DexCardData> all;
  final DexStats stats;

  static const empty = DexSections(
    all: [],
    stats: DexStats(caughtCount: 0, rarePlusCount: 0, legendaryCount: 0),
  );
}

class DexStats {
  const DexStats({
    required this.caughtCount,
    required this.rarePlusCount,
    required this.legendaryCount,
  });

  final int caughtCount;
  final int rarePlusCount;
  final int legendaryCount;
}

class DexRepository {
  const DexRepository(this._dao);

  final CaughtPlantDao _dao;

  Stream<DexSections> watchSections() {
    return _dao.watchAllPlants().map(_buildSections);
  }

  DexSections _buildSections(List<CaughtPlant> caughtPlants) {
    // Sort: legendary first, then epic, rare, common. Within each tier,
    // most recently caught first.
    final sorted = [...caughtPlants]..sort((a, b) {
        final ra = parseRarity(a.rarity);
        final rb = parseRarity(b.rarity);
        final rarityOrder = _rarityOrder(rb) - _rarityOrder(ra);
        if (rarityOrder != 0) return rarityOrder;
        return b.caughtAt.compareTo(a.caughtAt);
      });

    final all = sorted.map(DexCardData.caught).toList();

    final rarePlusCount = caughtPlants
        .where((p) => parseRarity(p.rarity) != Rarity.common)
        .length;
    final legendaryCount = caughtPlants
        .where((p) => parseRarity(p.rarity) == Rarity.legendary)
        .length;

    return DexSections(
      all: all,
      stats: DexStats(
        caughtCount: caughtPlants.length,
        rarePlusCount: rarePlusCount,
        legendaryCount: legendaryCount,
      ),
    );
  }

  int _rarityOrder(Rarity r) => switch (r) {
        Rarity.legendary => 3,
        Rarity.epic => 2,
        Rarity.rare => 1,
        Rarity.common => 0,
      };
}

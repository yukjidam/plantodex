import '../dao/caught_plant_dao.dart';
import 'caught_plant.dart';
import 'dex_card_data.dart';
import 'plant_rarity_lookup.dart';

/// How many of the most-recently-caught plants appear in "Recent catches".
const int recentCatchesLimit = 4;

/// Holds the sectioned lists the Dex screen renders.
///
/// "Recent catches" only ever shows real catches — there's no fixed
/// catalog backing it, since any plant the user successfully identifies
/// gets saved. "Legendary" and "Rare" are different: they're backed by a
/// fixed target list ([legendaryTargets] / [rareTargets]) so the user
/// always sees what's left to hunt, shown as locked cards until caught.
class DexSections {
  const DexSections({
    required this.recent,
    required this.legendary,
    required this.rare,
    required this.stats,
  });

  final List<DexCardData> recent;
  final List<DexCardData> legendary;
  final List<DexCardData> rare;
  final DexStats stats;

  static const empty = DexSections(
    recent: [],
    legendary: [],
    rare: [],
    stats: DexStats(caughtCount: 0, rarePlusCount: 0, legendaryCount: 0),
  );
}

/// Summary counts shown in the top stat pills.
class DexStats {
  const DexStats({
    required this.caughtCount,
    required this.rarePlusCount,
    required this.legendaryCount,
  });

  /// Total plants caught, any rarity.
  final int caughtCount;

  /// Caught plants with rarity rare or legendary.
  final int rarePlusCount;

  /// Caught plants with rarity legendary.
  final int legendaryCount;
}

/// Reads live caught-plant data from [CaughtPlantDao] and combines it
/// with the fixed rare/legendary target lists to build the Dex sections.
class DexRepository {
  const DexRepository(this._dao);

  final CaughtPlantDao _dao;

  /// Reactive stream of sectioned Dex data. Recomputes whenever the
  /// underlying `caught_plants` table changes.
  Stream<DexSections> watchSections() {
    return _dao.watchAllPlants().map(_buildSections);
  }

  DexSections _buildSections(List<CaughtPlant> caughtPlants) {
    // Index caught rows by normalized scientific name for matching
    // against the fixed target lists. If caught more than once, keep
    // the most recent row.
    final Map<String, CaughtPlant> caughtByScientificName = {};
    for (final plant in caughtPlants) {
      final key = plant.scientificName.trim().toLowerCase();
      final existing = caughtByScientificName[key];
      if (existing == null || plant.caughtAt > existing.caughtAt) {
        caughtByScientificName[key] = plant;
      }
    }

    // watchAllPlants() already orders by caughtAt DESC, so the first N
    // are the most recent.
    final recent =
        caughtPlants.take(recentCatchesLimit).map(DexCardData.caught).toList();

    final legendary =
        _buildTargetSection(legendaryTargets, caughtByScientificName);
    final rare = _buildTargetSection(rareTargets, caughtByScientificName);

    final rarePlusCount =
        caughtPlants.where((p) => p.rarity.toLowerCase() != 'common').length;
    final legendaryCount =
        caughtPlants.where((p) => p.rarity.toLowerCase() == 'legendary').length;

    final stats = DexStats(
      caughtCount: caughtPlants.length,
      rarePlusCount: rarePlusCount,
      legendaryCount: legendaryCount,
    );

    return DexSections(
      recent: recent,
      legendary: legendary,
      rare: rare,
      stats: stats,
    );
  }

  /// Builds a section for a fixed target list: caught targets show real
  /// data, uncaught targets show as locked cards. Caught entries sort
  /// first, then locked ones.
  List<DexCardData> _buildTargetSection(
    List<TargetSpecies> targets,
    Map<String, CaughtPlant> caughtByScientificName,
  ) {
    final caught = <DexCardData>[];
    final locked = <DexCardData>[];

    for (final target in targets) {
      final key = target.scientificName.trim().toLowerCase();
      final caughtPlant = caughtByScientificName[key];
      if (caughtPlant != null) {
        caught.add(DexCardData.caught(caughtPlant));
      } else {
        locked.add(DexCardData.locked(target));
      }
    }

    return [...caught, ...locked];
  }
}

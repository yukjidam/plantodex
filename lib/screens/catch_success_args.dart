import '../repositories/plant_repository.dart';
import '../theme/rarity.dart';

/// Passed via `context.push('/catch', extra: CatchSuccessArgs(...))`.
/// Bundles the already-resolved [rarity] (from GbifService) with the
/// full [result] so the catch screen never has to re-derive rarity from
/// confidence percent.
class CatchSuccessArgs {
  const CatchSuccessArgs({required this.result, required this.rarity});

  final PlantResult result;
  final Rarity rarity;
}

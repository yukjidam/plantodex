import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../theme/rarity.dart';

/// Derives [Rarity] from GBIF occurrence counts.
///
/// Flow:
///   1. Match scientific name → get GBIF usageKey (taxonKey)
///   2. Fetch occurrence count for that taxonKey
///   3. Map count → Rarity tier
///
/// Thresholds (tuned generously for Philippine endemic plants):
///   < 1000  occurrences → Legendary
///   1000–4999           → Rare
///   5000–19999          → Epic
///   20000+              → Common
///
/// Falls back to [Rarity.common] on any network error so a bad
/// connection never blocks saving a catch.
class GbifService {
  GbifService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _speciesMatchBase = 'https://api.gbif.org/v1/species/match';
  static const _occurrenceCountBase =
      'https://api.gbif.org/v1/occurrence/count';

  /// Returns the [Rarity] for [scientificName] based on GBIF occurrence count.
  Future<Rarity> rarityFor(String scientificName) async {
    try {
      final taxonKey = await _matchTaxon(scientificName);
      if (taxonKey == null) {
        debugPrint('[GbifService] No taxon match for "$scientificName"');
        return Rarity.common;
      }

      final count = await _occurrenceCount(taxonKey);
      debugPrint(
          '[GbifService] "$scientificName" → taxonKey=$taxonKey, count=$count');

      return _rarityFromCount(count);
    } catch (e) {
      debugPrint(
          '[GbifService] Error fetching rarity for "$scientificName": $e');
      return Rarity.common;
    }
  }

  /// Step 1 — match name to GBIF backbone, return usageKey (taxonKey).
  Future<int?> _matchTaxon(String scientificName) async {
    final uri = Uri.parse(_speciesMatchBase).replace(queryParameters: {
      'name': scientificName,
      'kingdom': 'Plantae',
      'verbose': 'false',
    });

    final response = await _client.get(uri);
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // matchType can be EXACT, FUZZY, HIGHERRANK, or NONE
    final matchType = json['matchType'] as String? ?? 'NONE';
    if (matchType == 'NONE') return null;

    return json['usageKey'] as int?;
  }

  /// Step 2 — fetch total occurrence count for a taxonKey.
  Future<int> _occurrenceCount(int taxonKey) async {
    final uri = Uri.parse(_occurrenceCountBase).replace(queryParameters: {
      'taxonKey': taxonKey.toString(),
    });

    final response = await _client.get(uri);
    if (response.statusCode != 200) return 0;

    // The count endpoint returns a plain integer, not a JSON object.
    return int.tryParse(response.body.trim()) ?? 0;
  }

  /// Maps occurrence count to a rarity tier.
  Rarity _rarityFromCount(int count) {
    if (count < 1000) return Rarity.legendary;
    if (count < 5000) return Rarity.rare;
    if (count < 20000) return Rarity.epic;
    return Rarity.common;
  }
}

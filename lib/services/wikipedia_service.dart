import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/plant_care_info.dart';

/// Fetches plant reference data from Wikipedia using two HTTP calls:
///
/// 1. REST `/page/summary/{title}` → extract, thumbnail, page ID.
/// 2. Action API `action=parse&prop=sections|text` → all section headings
///    AND their full HTML in a single response. Dart then matches headings
///    to fields and strips HTML to plain text.
///
/// If the exact species page returns a 404 or near-empty result, the service
/// automatically falls back to the genus name (first word of the scientific
/// name). This means "Taraxacum japonicum" gracefully falls back to
/// "Taraxacum" so users always see useful info.
class WikipediaService {
  WikipediaService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _restBase = 'https://en.wikipedia.org/api/rest_v1';
  static const _actionBase = 'https://en.wikipedia.org/w/api.php';

  /// Minimum character count for a summary to be considered "useful".
  /// Wikipedia disambiguation and stub pages are usually very short.
  static const _minSummaryLength = 120;

  Future<PlantCareInfo> fetchByScientificName(String scientificName) async {
    // ── Try species first, then fall back to genus ─────────────────────────
    final candidates = _buildCandidates(scientificName);

    for (final candidate in candidates) {
      final result = await _tryFetch(
        title: candidate.title,
        scientificName: scientificName,
        isGenusLevel: candidate.isGenus,
      );
      if (result != null) return result;
    }

    // Nothing found at all — return an empty shell.
    debugPrint('[Wikipedia] all candidates exhausted for "$scientificName"');
    return PlantCareInfo.empty;
  }

  // ── Candidate building ─────────────────────────────────────────────────────

  static List<_WikiCandidate> _buildCandidates(String scientificName) {
    final parts = scientificName.trim().split(RegExp(r'\s+'));
    final candidates = <_WikiCandidate>[];

    // 1. Full name as-is  e.g. "Taraxacum japonicum"
    if (parts.length >= 2) {
      candidates.add(_WikiCandidate(
        title: _toWikiTitle(scientificName),
        isGenus: false,
      ));
    }

    // 2. Genus only  e.g. "Taraxacum"
    if (parts.isNotEmpty) {
      final genus = _toWikiTitle(parts.first);
      // Avoid duplicate if input was already just a genus.
      if (candidates.isEmpty || candidates.first.title != genus) {
        candidates.add(_WikiCandidate(title: genus, isGenus: true));
      }
    }

    return candidates;
  }

  // ── Single fetch attempt ───────────────────────────────────────────────────

  Future<PlantCareInfo?> _tryFetch({
    required String title,
    required String scientificName,
    required bool isGenusLevel,
  }) async {
    debugPrint('[Wikipedia] trying title="$title" (genus=$isGenusLevel)');

    // ── 1. Summary ──────────────────────────────────────────────────────────
    Map<String, dynamic> summaryJson;
    try {
      final res = await _dio.get('$_restBase/page/summary/$title');
      debugPrint('[Wikipedia] summary OK status=${res.statusCode}');
      summaryJson = res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      debugPrint('[Wikipedia] summary FAILED status=$status msg=${e.message}');
      // 404 = page genuinely doesn't exist; try next candidate.
      if (status == 404) return null;
      rethrow;
    }

    // Reject disambiguation pages and very short stubs — try next candidate.
    final extract = summaryJson['extract'] as String? ?? '';
    final pageType = summaryJson['type'] as String? ?? '';
    if (pageType == 'disambiguation' || extract.length < _minSummaryLength) {
      debugPrint(
          '[Wikipedia] skipping "$title": type=$pageType extractLen=${extract.length}');
      return null;
    }

    // ── 2. Full article parse ───────────────────────────────────────────────
    Map<String, String> sectionTexts = {};
    try {
      final parseRes = await _dio.get(_actionBase, queryParameters: {
        'action': 'parse',
        'page': title,
        'prop': 'sections|text',
        'format': 'json',
        'redirects': '1',
        'mobileformat': '1',
      });

      debugPrint('[Wikipedia] parse OK status=${parseRes.statusCode}');

      final parse = parseRes.data['parse'] as Map<String, dynamic>? ?? {};
      final rawSections = parse['sections'] as List<dynamic>? ?? [];
      debugPrint('[Wikipedia] section count=${rawSections.length}');

      final fullHtml = parse['text']?['*'] as String? ?? '';
      sectionTexts = _extractSections(rawSections, fullHtml);
      debugPrint('[Wikipedia] matched fields=${sectionTexts.keys.toList()}');
    } on DioException catch (e) {
      debugPrint('[Wikipedia] parse FAILED status=${e.response?.statusCode} '
          'msg=${e.message}');
    } catch (e) {
      debugPrint('[Wikipedia] parse unexpected error: $e');
    }

    return PlantCareInfo.fromWikipediaJson(
      summaryJson: summaryJson,
      sectionTexts: sectionTexts,
      scientificName: scientificName,
      // Let the UI know this came from a genus-level fallback.
      isGenusLevel: isGenusLevel,
      genusName: isGenusLevel ? title : null,
    );
  }

  // ── Section extraction ─────────────────────────────────────────────────────

  static Map<String, String> _extractSections(
    List<dynamic> sections,
    String fullHtml,
  ) {
    const buckets = <String, List<String>>{
      'habitat': [
        'distribution',
        'habitat',
        'range',
        'ecology',
        'native_range',
        'geographic',
      ],
      'careTips': [
        'cultivat',
        'growing',
        'horticulture',
        'gardening',
      ],
      'propagation': ['propagat', 'reproduct'],
      'floweringSeason': [
        'flower',
        'bloom',
        'phenolog',
        'fruit',
      ],
      'conservationStatus': [
        'conservat',
        'threat',
        'endangered',
        'status',
      ],
      'funFacts': [
        'uses',
        'ethnobotany',
        'history',
        'cultural',
        'folklore',
        'traditional',
        'economic',
        'symbolism',
        'in_culture',
        'toxicity',
      ],
    };

    final anchorToField = <String, String>{};
    for (final raw in sections) {
      final anchor = (raw['anchor'] as String? ?? '').toLowerCase();
      final line = (raw['line'] as String? ?? '').toLowerCase();
      for (final entry in buckets.entries) {
        if (anchorToField.values.contains(entry.key)) continue;
        if (entry.value.any((kw) => anchor.contains(kw) || line.contains(kw))) {
          anchorToField[raw['anchor'] as String] = entry.key;
          break;
        }
      }
    }

    if (anchorToField.isEmpty || fullHtml.isEmpty) return {};

    final result = <String, String>{};

    for (final entry in anchorToField.entries) {
      final anchor = entry.key;
      final fieldKey = entry.value;

      final pattern = RegExp(
        '<h[23][^>]*>.*?id="${RegExp.escape(anchor)}".*?</h[23]>'
        r'(.*?)'
        r'(?=<h[23]|$)',
        caseSensitive: true,
        dotAll: true,
      );

      final match = pattern.firstMatch(fullHtml);
      if (match == null) {
        debugPrint('[Wikipedia] no HTML match for anchor=$anchor');
        continue;
      }

      final sectionHtml = match.group(1) ?? '';
      final plain = _htmlToPlainText(sectionHtml);
      if (plain.isEmpty) continue;

      result[fieldKey] = _trimToSentences(plain, 5);
    }

    return result;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _toWikiTitle(String name) {
    final t = name.trim();
    if (t.isEmpty) return '';
    return t[0].toUpperCase() + t.substring(1).replaceAll(' ', '_');
  }

  static String _htmlToPlainText(String html) {
    return html
        // 1. Nuke entire <style>…</style> blocks before anything else —
        //    mobileformat still injects inline CSS that looks like garbage text.
        .replaceAll(
            RegExp(r'<style[^>]*>.*?</style>',
                dotAll: true, caseSensitive: false),
            '')
        // 2. Remove <script>…</script> blocks for good measure.
        .replaceAll(
            RegExp(r'<script[^>]*>.*?</script>',
                dotAll: true, caseSensitive: false),
            '')
        // 3. Remove edit-section containers entirely (the span + its inner text).
        //    The visible "edit" word lives inside these as link text.
        .replaceAll(
            RegExp(
                r'<span[^>]*class="[^"]*mw-editsection[^"]*"[^>]*>.*?</span>',
                dotAll: true),
            '')
        // 4. Remove citation superscripts  e.g. <sup class="reference">…</sup>
        .replaceAll(
            RegExp(r'<sup[^>]*class="[^"]*reference[^"]*"[^>]*>.*?</sup>',
                dotAll: true),
            '')
        // 5. Remove any other <sup> (footnote markers outside .reference too)
        .replaceAll(RegExp(r'<sup[^>]*>.*?</sup>', dotAll: true), '')
        // 6. Strip remaining HTML tags
        .replaceAll(RegExp(r'<[^>]+>', dotAll: true), ' ')
        // 7. Decode common HTML entities
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#160;', ' ')
        .replaceAll('&quot;', '"')
        // 8. Remove citation brackets in ALL forms:
        //    [2]  [ 2 ]  [ 18 ]  [nb 1]  [note 3]  [a]
        .replaceAll(RegExp(r'\[\s*\d+\s*\]'), '')
        .replaceAll(RegExp(r'\[\s*nb\s*\d+\s*\]'), '')
        .replaceAll(RegExp(r'\[\s*note\s*\d+\s*\]'), '')
        .replaceAll(RegExp(r'\[\s*[a-z]\s*\]'), '')
        // 9. Remove <a> tags whose visible text is exactly "edit" —
        //    these are edit-section links that sit outside the mw-editsection span.
        .replaceAll(
            RegExp(r'<a\b[^>]*>\s*edit\s*</a>',
                dotAll: true, caseSensitive: false),
            '')
        // 10. (merged into step 12)
        // 11. Collapse whitespace
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim()
        // 12. Strip "edit" from the very start of the text and after sentence endings —
        //     Wikipedia mobile consistently emits this token at paragraph boundaries.
        .replaceAll(
            RegExp(r'^edit\s+', caseSensitive: false, multiLine: true), '')
        .replaceAll(RegExp(r'(?<=[.!?]\s)edit\s+', caseSensitive: false), '');
  }

  static String _trimToSentences(String text, int max) {
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    return sentences.take(max).join(' ').trim();
  }
}

// ── Internal helper ────────────────────────────────────────────────────────────

class _WikiCandidate {
  const _WikiCandidate({required this.title, required this.isGenus});
  final String title;
  final bool isGenus;
}

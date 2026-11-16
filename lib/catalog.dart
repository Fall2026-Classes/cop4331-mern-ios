import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api.dart';

/// Title suggestions and posters from the web app's /catalog.json (TMDB top rated).
/// Same matching rules as the web client's catalog.js.
const _posterBase = 'https://image.tmdb.org/t/p/w342';

String normalizeTitle(String? s) {
  var out = (s ?? '').toLowerCase().replaceAll('&', ' and ');
  out = out.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  return out.replaceFirst(RegExp(r'^(the|a|an) '), '');
}

class CatalogTitle {
  CatalogTitle(this.title, this.type, this.year, this.rank, this.posterUrl, this.keys);
  final String title;
  final String type;
  final int? year;
  final int rank;
  final String? posterUrl;
  final List<String> keys;
}

class Catalog {
  static List<CatalogTitle>? _titles;
  static Future<List<CatalogTitle>>? _loading;

  static Future<List<CatalogTitle>> load() {
    if (_titles != null) return Future.value(_titles);
    return _loading ??= _fetch().then((t) => _titles = t).catchError((Object e) {
      _loading = null;
      throw e;
    });
  }

  static Future<List<CatalogTitle>> _fetch() async {
    final res = await http.get(Uri.parse('${Api.baseUrl}/catalog.json')).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('Catalog not available');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['titles'] as List? ?? []).map((raw) {
      final t = raw as Map<String, dynamic>;
      final keys = {normalizeTitle(t['title'] as String?), normalizeTitle(t['originalTitle'] as String?)}
        ..removeWhere((k) => k.isEmpty);
      final poster = t['posterPath'] as String?;
      return CatalogTitle(
        '${t['title']}',
        '${t['type']}',
        (t['year'] as num?)?.toInt(),
        (t['rank'] as num?)?.toInt() ?? 9999,
        poster == null ? null : '$_posterBase$poster',
        keys.toList(),
      );
    }).toList();
  }

  static List<CatalogTitle> search(String q, {String? preferType, int limit = 8}) {
    final key = normalizeTitle(q);
    final all = _titles;
    if (key.isEmpty || all == null) return [];
    final found = all.where((t) => t.keys.any((k) => k.contains(key))).toList()
      ..sort((a, b) {
        int score(CatalogTitle t) =>
            (t.type == preferType ? 0 : 2) + (t.keys.any((k) => k.startsWith(key)) ? 0 : 1);
        final s = score(a) - score(b);
        return s != 0 ? s : a.rank - b.rank;
      });
    return found.take(limit).toList();
  }

  static String? findPoster(String title, String type, int? year) {
    final all = _titles;
    if (all == null) return null;
    final key = normalizeTitle(title);
    if (key.isEmpty) return null;
    final candidates = all.where((t) => t.type == type && t.keys.contains(key)).toList()
      ..sort((a, b) => a.rank - b.rank);
    if (candidates.isEmpty) return null;
    final match = candidates.firstWhere((c) => year != null && c.year == year, orElse: () => candidates.first);
    return match.posterUrl;
  }
}

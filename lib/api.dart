import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown when the API answers with an error (or can't be reached).
class ApiException implements Exception {
  ApiException(this.message, [this.status = 0]);
  final String message;
  final int status;

  @override
  String toString() => message;
}

/// Talks to the movie-reviews API and remembers who is logged in.
/// Same endpoints the web app uses: /api/users, /api/auth/login, /api/reviews.
class Api {
  static const defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mern.fire-line.tech',
  );

  static String baseUrl = defaultBaseUrl;
  static String? token;
  static Map<String, dynamic>? user;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString('baseUrl') ?? defaultBaseUrl;
    token = prefs.getString('token');
    final u = prefs.getString('user');
    user = u == null ? null : jsonDecode(u) as Map<String, dynamic>;
  }

  static Future<void> setBaseUrl(String url) async {
    var clean = url.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (clean.isEmpty) clean = defaultBaseUrl;
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'http://$clean';
    }
    baseUrl = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseUrl', clean);
  }

  static Future<void> _saveLogin(String t, Map<String, dynamic> u) async {
    token = t;
    user = u;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', t);
    await prefs.setString('user', jsonEncode(u));
  }

  static Future<void> logout() async {
    token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  static String get displayName {
    final u = user;
    if (u == null) return '';
    final name = [u['firstName'], u['lastName']]
        .where((s) => s != null && '$s'.isNotEmpty)
        .join(' ');
    return name.isNotEmpty ? name : '${u['login'] ?? ''}';
  }

  static Future<dynamic> request(String path, {String method = 'GET', Object? body}) async {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final req = http.Request(method, Uri.parse('$baseUrl/api$path'))..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);

    http.Response res;
    try {
      res = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 15)),
      );
    } catch (_) {
      throw ApiException('Could not reach the server at $baseUrl');
    }

    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      data = null;
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = data is Map && data['error'] != null
          ? '${data['error']}'
          : 'Request failed (${res.statusCode})';
      throw ApiException(msg, res.statusCode);
    }
    return data;
  }

  // ---- auth ----

  static Future<void> register({
    required String firstName,
    required String lastName,
    required String login,
    required String password,
  }) async {
    await request('/users', method: 'POST', body: {
      'firstName': firstName,
      'lastName': lastName,
      'login': login,
      'password': password,
    });
  }

  static Future<void> login(String login, String password) async {
    final data = Map<String, dynamic>.from(
      await request('/auth/login', method: 'POST', body: {'login': login, 'password': password}) as Map,
    );
    final t = data.remove('token') as String;
    await _saveLogin(t, data);
  }

  // ---- reviews ----

  static Future<List<Entry>> listReviews() async {
    final data = await request('/reviews') as List;
    return data.map((r) => Entry.fromReview(r as Map<String, dynamic>)).toList();
  }

  static Future<Entry> createReview(Entry e) async =>
      Entry.fromReview(await request('/reviews', method: 'POST', body: e.toReviewBody()) as Map<String, dynamic>);

  static Future<Entry> updateReview(Entry e) async => Entry.fromReview(
      await request('/reviews/${e.id}', method: 'PATCH', body: e.toReviewBody()) as Map<String, dynamic>);

  static Future<void> deleteReview(String id) => request('/reviews/$id', method: 'DELETE');
}

/// A diary entry. The API stores it as a review: { movieTitle, description, ... }.
class Entry {
  Entry({
    this.id,
    required this.title,
    this.type = 'movie',
    this.year,
    this.rating = 0,
    this.review = '',
    this.watchedOn,
    this.createdAt = '',
  });

  final String? id;
  final String title;
  final String type;
  final int? year;
  final double rating;
  final String review;
  final DateTime? watchedOn; // calendar day, stored as midnight UTC
  final String createdAt;

  factory Entry.fromReview(Map<String, dynamic> r) => Entry(
        id: r['_id'] as String?,
        title: '${r['movieTitle'] ?? ''}',
        type: '${r['type'] ?? 'movie'}',
        year: (r['year'] as num?)?.toInt(),
        rating: (r['rating'] as num?)?.toDouble() ?? 0,
        review: '${r['description'] ?? ''}',
        watchedOn: r['watchedOn'] == null ? null : DateTime.tryParse('${r['watchedOn']}')?.toUtc(),
        createdAt: '${r['createdAt'] ?? ''}',
      );

  Map<String, dynamic> toReviewBody() => {
        'movieTitle': title.trim(),
        'type': type,
        'year': year,
        'rating': rating,
        'description': review.trim(),
        'watchedOn': watchedOn == null
            ? null
            : '${watchedOn!.year.toString().padLeft(4, '0')}-'
                '${watchedOn!.month.toString().padLeft(2, '0')}-'
                '${watchedOn!.day.toString().padLeft(2, '0')}',
      };
}

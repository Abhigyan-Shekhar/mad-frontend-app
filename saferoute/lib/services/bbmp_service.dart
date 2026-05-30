import 'dart:convert';
import 'package:http/http.dart' as http;

import 'supabase_service.dart';

class WardScore {
  final String wardName;
  final int totalGrievances;
  final int roadGrievances;
  final int lightGrievances;
  final double safetyScore;

  WardScore({
    required this.wardName,
    required this.totalGrievances,
    required this.roadGrievances,
    required this.lightGrievances,
    required this.safetyScore,
  });

  Map<String, dynamic> toJson() => {
        'ward_name': wardName,
        'total_grievances': totalGrievances,
        'road_grievances': roadGrievances,
        'light_grievances': lightGrievances,
        'safety_score': safetyScore,
      };

  factory WardScore.fromJson(Map<String, dynamic> json) {
    return WardScore(
      wardName: json['ward_name']?.toString() ?? 'Unknown',
      totalGrievances:
          int.tryParse(json['total_grievances']?.toString() ?? '') ?? 0,
      roadGrievances:
          int.tryParse(json['road_grievances']?.toString() ?? '') ?? 0,
      lightGrievances:
          int.tryParse(json['light_grievances']?.toString() ?? '') ?? 0,
      safetyScore:
          (json['safety_score'] as num?)?.toDouble() ??
              double.tryParse(json['safety_score']?.toString() ?? '') ??
              70,
    );
  }
}

class BbmpService {
  static const String _base = 'https://data.opencity.in/api/3/action/datastore_search_sql';
  static const String _rid  = '1342a93b-9a61-4766-9c34-c8357b7926c2';

  static BbmpService? _instance;
  static BbmpService get instance => _instance ??= BbmpService._();
  final http.Client _client;
  final Future<List<Map<String, dynamic>>> Function()? _wardScoresLoader;
  final Future<void> Function(List<Map<String, dynamic>> scores)? _wardScoresUpserter;

  BbmpService._()
      : _client = http.Client(),
        _wardScoresLoader = SupabaseService.instance.getWardSafetyScores,
        _wardScoresUpserter = SupabaseService.instance.upsertWardSafetyScores;
  BbmpService({
    http.Client? client,
    Future<List<Map<String, dynamic>>> Function()? wardScoresLoader,
    Future<void> Function(List<Map<String, dynamic>> scores)? wardScoresUpserter,
  })  : _client = client ?? http.Client(),
        _wardScoresLoader = wardScoresLoader,
        _wardScoresUpserter = wardScoresUpserter;

  Map<String, WardScore> _cache = {};
  DateTime? _lastFetch;

  /// Returns ward scores, cached for 10 minutes
  Future<Map<String, WardScore>> getWardScores() async {
    if (_lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(minutes: 10)) {
      return _cache;
    }
    final scores = await _loadSupabaseThenFallback();
    _cache = scores;
    _lastFetch = DateTime.now();
    return scores;
  }

  Future<Map<String, WardScore>> getCachedWardScores() async {
    if (_lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(minutes: 10) &&
        _cache.isNotEmpty) {
      return _cache;
    }
    final scores = await _safeLoadFromSupabase();
    if (scores.isNotEmpty) {
      _cache = scores;
      _lastFetch = DateTime.now();
    }
    return scores;
  }

  Future<Map<String, WardScore>> _loadSupabaseThenFallback() async {
    final supabaseScores = await _safeLoadFromSupabase();
    if (supabaseScores.isNotEmpty) return supabaseScores;

    try {
      final openCityScores = await _fetchAndScore();
      if (openCityScores.isNotEmpty) {
        await _safeUpsertToSupabase(openCityScores);
      }
      return openCityScores;
    } catch (_) {
      return _cache;
    }
  }

  Future<Map<String, WardScore>> _safeLoadFromSupabase() async {
    final loader = _wardScoresLoader;
    if (loader == null) return const {};
    try {
      final rows = await loader();
      return {
        for (final row in rows)
          WardScore.fromJson(row).wardName: WardScore.fromJson(row),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> _safeUpsertToSupabase(Map<String, WardScore> scores) async {
    final upserter = _wardScoresUpserter;
    if (upserter == null || scores.isEmpty) return;
    try {
      await upserter(
        scores.values.map((score) => score.toJson()).toList(growable: false),
      );
    } catch (_) {
      // The mobile/web app should keep working even if the cache write fails.
    }
  }

  Future<Map<String, WardScore>> _fetchAndScore() async {
    // Aggregate open grievances by ward & category
    const sql = '''
      SELECT "Ward Name", "Category", COUNT(*) as cnt
      FROM "$_rid"
      WHERE "Grievance Status" != 'Closed'
      GROUP BY "Ward Name", "Category"
      LIMIT 5000
    ''';

    final uri = Uri.parse('$_base?sql=${Uri.encodeComponent(sql)}');
    final resp = await _client.get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) return _cache;

    final data = jsonDecode(resp.body);
    if (data['success'] != true) return _cache;

    final records = List<Map<String, dynamic>>.from(data['result']['records']);

    // Tally per ward
    final Map<String, int> total = {};
    final Map<String, int> road = {};
    final Map<String, int> light = {};

    for (final r in records) {
      final ward = r['Ward Name'] as String? ?? 'Unknown';
      final cat  = (r['Category'] as String? ?? '').toLowerCase();
      final cnt  = int.tryParse(r['cnt'].toString()) ?? 0;

      total[ward] = (total[ward] ?? 0) + cnt;
      if (cat.contains('road') || cat.contains('pothole') || cat.contains('footpath')) {
        road[ward] = (road[ward] ?? 0) + cnt;
      }
      if (cat.contains('light') || cat.contains('street light') || cat.contains('electricity')) {
        light[ward] = (light[ward] ?? 0) + cnt;
      }
    }

    // Score = 100 - min(total/2, 50) clamped to [0,100]
    final scores = <String, WardScore>{};
    for (final ward in total.keys) {
      final t = total[ward] ?? 0;
      final r = road[ward] ?? 0;
      final l = light[ward] ?? 0;
      final score = (100 - (t / 2).clamp(0, 50)).toDouble();
      scores[ward] = WardScore(
        wardName: ward,
        totalGrievances: t,
        roadGrievances: r,
        lightGrievances: l,
        safetyScore: score,
      );
    }
    return scores;
  }

  /// Score a given ward name (case-insensitive fuzzy match)
  Future<WardScore?> scoreForWard(String wardName) async {
    final scores = await getWardScores();
    final key = _matchWardKey(scores, wardName);
    return key.isEmpty ? null : scores[key];
  }

  Future<WardScore?> scoreForWardCached(String wardName) async {
    final scores = await getCachedWardScores();
    final key = _matchWardKey(scores, wardName);
    return key.isEmpty ? null : scores[key];
  }

  /// Score a route by averaging scores of origin & destination wards
  Future<double> routeSafetyScore(String fromWard, String toWard) async {
    final a = await scoreForWard(fromWard);
    final b = await scoreForWard(toWard);
    final scoreA = a?.safetyScore ?? 70.0;
    final scoreB = b?.safetyScore ?? 70.0;
    return (scoreA + scoreB) / 2;
  }

  Future<double> routeSafetyScoreCached(String fromWard, String toWard) async {
    final a = await scoreForWardCached(fromWard);
    final b = await scoreForWardCached(toWard);
    final scoreA = a?.safetyScore ?? 70.0;
    final scoreB = b?.safetyScore ?? 70.0;
    return (scoreA + scoreB) / 2;
  }

  Future<WardScore?> describeRouteArea(String fromLabel, String toLabel) async {
    final destination = await scoreForWard(toLabel);
    if (destination != null) return destination;
    return scoreForWard(fromLabel);
  }

  Future<WardScore?> describeRouteAreaCached(String fromLabel, String toLabel) async {
    final destination = await scoreForWardCached(toLabel);
    if (destination != null) return destination;
    return scoreForWardCached(fromLabel);
  }

  Future<List<Map<String, dynamic>>> topRiskWards({int limit = 5}) async {
    final scores = await getWardScores();
    final list = scores.values.toList()
      ..sort((a, b) => a.safetyScore.compareTo(b.safetyScore));
    return list
        .take(limit)
        .map((score) => score.toJson())
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> topRiskWardsCached({int limit = 5}) async {
    final scores = await getCachedWardScores();
    final list = scores.values.toList()
      ..sort((a, b) => a.safetyScore.compareTo(b.safetyScore));
    return list
        .take(limit)
        .map((score) => score.toJson())
        .toList(growable: false);
  }

  String _matchWardKey(Map<String, WardScore> scores, String wardName) {
    return scores.keys.firstWhere(
      (k) =>
          wardName.toLowerCase().contains(k.toLowerCase()) ||
          k.toLowerCase().contains(wardName.toLowerCase()),
      orElse: () => '',
    );
  }
}

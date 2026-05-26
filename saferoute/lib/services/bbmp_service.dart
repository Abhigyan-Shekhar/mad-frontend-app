import 'dart:convert';
import 'package:http/http.dart' as http;

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
}

class BbmpService {
  static const String _base = 'https://data.opencity.in/api/3/action/datastore_search_sql';
  static const String _rid  = '1342a93b-9a61-4766-9c34-c8357b7926c2';

  static BbmpService? _instance;
  static BbmpService get instance => _instance ??= BbmpService._();
  BbmpService._();

  Map<String, WardScore> _cache = {};
  DateTime? _lastFetch;

  /// Returns ward scores, cached for 10 minutes
  Future<Map<String, WardScore>> getWardScores() async {
    if (_lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(minutes: 10)) {
      return _cache;
    }
    final scores = await _fetchAndScore();
    _cache = scores;
    _lastFetch = DateTime.now();
    return scores;
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
    final resp = await http.get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) return {};

    final data = jsonDecode(resp.body);
    if (data['success'] != true) return {};

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
    final key = scores.keys.firstWhere(
      (k) => k.toLowerCase().contains(wardName.toLowerCase()),
      orElse: () => '',
    );
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
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

const _grievanceResourceId = '1342a93b-9a61-4766-9c34-c8357b7926c2';
const _grievanceSqlEndpoint =
    'https://data.opencity.in/api/3/action/datastore_search_sql';
const _streetDatasetEndpoint =
    'https://data.opencity.in/api/3/action/package_show?id=bengaluru-ward-wise-street-map';

Future<void> main() async {
  await dotenv.load(fileName: '.env');

  final supabaseUrl = _required('SUPABASE_URL');
  final serviceRoleKey = _required('SUPABASE_SERVICE_ROLE_KEY');

  final wardScores = await _fetchWardSafetyScores();
  final streetSegments = await _fetchStreetSegments(limitResources: 12);

  await _postgrestUpsert(
    supabaseUrl: supabaseUrl,
    serviceRoleKey: serviceRoleKey,
    table: 'ward_safety_scores',
    rows: wardScores,
    onConflict: 'ward_name',
  );
  await _postgrestUpsert(
    supabaseUrl: supabaseUrl,
    serviceRoleKey: serviceRoleKey,
    table: 'street_segments',
    rows: streetSegments,
    onConflict: 'ward_name,street_id',
  );

  stdout.writeln(
    'Synced ${wardScores.length} ward score rows and ${streetSegments.length} street segment rows.',
  );
}

Future<List<Map<String, dynamic>>> _fetchWardSafetyScores() async {
  const sql = '''
    SELECT "Ward Name", "Category", COUNT(*) as cnt
    FROM "$_grievanceResourceId"
    WHERE "Grievance Status" != 'Closed'
    GROUP BY "Ward Name", "Category"
    LIMIT 5000
  ''';

  final uri = Uri.parse(
    '$_grievanceSqlEndpoint?sql=${Uri.encodeComponent(sql)}',
  );
  final response = await http
      .get(uri, headers: {'Accept': 'application/json'})
      .timeout(const Duration(seconds: 30));

  if (response.statusCode != 200) {
    throw HttpException(
      'Failed to fetch BBMP grievances: ${response.statusCode}',
      uri: uri,
    );
  }

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final records =
      (body['result']?['records'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>();

  final total = <String, int>{};
  final road = <String, int>{};
  final light = <String, int>{};

  for (final record in records) {
    final ward = (record['Ward Name']?.toString() ?? 'Unknown').trim();
    final category = (record['Category']?.toString() ?? '').toLowerCase();
    final count = int.tryParse(record['cnt'].toString()) ?? 0;

    total[ward] = (total[ward] ?? 0) + count;
    if (category.contains('road') ||
        category.contains('pothole') ||
        category.contains('footpath')) {
      road[ward] = (road[ward] ?? 0) + count;
    }
    if (category.contains('light') ||
        category.contains('street light') ||
        category.contains('electricity')) {
      light[ward] = (light[ward] ?? 0) + count;
    }
  }

  return total.entries.map((entry) {
    final ward = entry.key;
    final totalCount = entry.value;
    final score = (100 - (totalCount / 2).clamp(0, 50)).toDouble();
    return {
      'ward_name': ward,
      'total_grievances': totalCount,
      'road_grievances': road[ward] ?? 0,
      'light_grievances': light[ward] ?? 0,
      'safety_score': score,
      'source_year': '2025',
      'source_dataset': 'bbmp_grievances',
    };
  }).toList(growable: false);
}

Future<List<Map<String, dynamic>>> _fetchStreetSegments({
  int limitResources = 12,
}) async {
  final datasetResponse = await http
      .get(Uri.parse(_streetDatasetEndpoint))
      .timeout(const Duration(seconds: 30));

  if (datasetResponse.statusCode != 200) {
    throw HttpException(
      'Failed to fetch street dataset metadata: ${datasetResponse.statusCode}',
      uri: Uri.parse(_streetDatasetEndpoint),
    );
  }

  final datasetBody = jsonDecode(datasetResponse.body) as Map<String, dynamic>;
  final resources =
      (datasetBody['result']?['resources'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .where(
            (resource) =>
                (resource['format']?.toString().toUpperCase() ?? '') == 'CSV',
          )
          .take(limitResources)
          .toList(growable: false);

  final rows = <Map<String, dynamic>>[];
  for (final resource in resources) {
    final url = resource['url']?.toString();
    if (url == null || url.isEmpty) continue;

    final csvResponse =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (csvResponse.statusCode != 200) continue;

    final csvRows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(csvResponse.body);
    if (csvRows.length < 2) continue;

    final headers = csvRows.first
        .map((value) => value.toString().trim())
        .toList(growable: false);

    for (final values in csvRows.skip(1)) {
      final row = <String, String>{};
      for (var index = 0; index < headers.length && index < values.length; index++) {
        row[headers[index]] = values[index].toString().trim();
      }

      final wardName = row['Ward Name'] ?? row['Ward name'] ?? row['Ward Name '] ?? '';
      final streetId = row['Street Id'] ?? row['Street ID'] ?? row['Street Id '] ?? '';
      if (wardName.isEmpty || streetId.isEmpty) continue;

      rows.add({
        'ward_name': wardName,
        'ward_number': row['Ward No'] ?? row['Ward Number'],
        'street_id': streetId,
        'street_name':
            row['Street Name'] ?? row['Street'] ?? row['Road Name'] ?? '',
        'source_url': url,
      });
    }
  }

  return rows;
}

Future<void> _postgrestUpsert({
  required String supabaseUrl,
  required String serviceRoleKey,
  required String table,
  required List<Map<String, dynamic>> rows,
  required String onConflict,
}) async {
  if (rows.isEmpty) return;

  final uri = Uri.parse(
    '$supabaseUrl/rest/v1/$table?on_conflict=${Uri.encodeQueryComponent(onConflict)}',
  );
  final response = await http
      .post(
        uri,
        headers: {
          'apikey': serviceRoleKey,
          'Authorization': 'Bearer $serviceRoleKey',
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates',
        },
        body: jsonEncode(rows),
      )
      .timeout(const Duration(seconds: 60));

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException(
      'Failed to upsert $table: ${response.statusCode} ${response.body}',
      uri: uri,
    );
  }
}

String _required(String key) {
  final value = dotenv.env[key]?.trim();
  if (value == null || value.isEmpty) {
    throw StateError('Missing required environment value: $key');
  }
  return value;
}

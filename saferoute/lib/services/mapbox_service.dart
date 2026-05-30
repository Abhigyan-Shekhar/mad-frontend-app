import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'app_config.dart';

class MapboxPlace {
  final String label;
  final LatLng point;

  const MapboxPlace({required this.label, required this.point});
}

String _normalizeGeocodeText(String value) {
  final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
}

double geocodeMatchScore(String query, String label) {
  final queryTokens = _normalizeGeocodeText(query)
      .split(' ')
      .where((token) => token.isNotEmpty && token.length > 2)
      .toList(growable: false);
  if (queryTokens.isEmpty) return 0;

  final normalizedLabel = _normalizeGeocodeText(label);
  var matchedWeight = 0.0;
  var totalWeight = 0.0;

  for (final token in queryTokens) {
    final weight = token.length <= 4 ? 2.5 : 1.0;
    totalWeight += weight;
    if (normalizedLabel.contains(token)) {
      matchedWeight += weight;
    }
  }

  if (totalWeight == 0) return 0;
  return matchedWeight / totalWeight;
}

class NavigationStep {
  final String instruction;
  final double distanceMeters;
  final double durationMinutes;
  final String? maneuverType;
  final String? maneuverModifier;

  const NavigationStep({
    required this.instruction,
    this.distanceMeters = 0,
    this.durationMinutes = 0,
    this.maneuverType,
    this.maneuverModifier,
  });
}

class NavigationRoute {
  final String id;
  final double durationMinutes;
  final double distanceKm;
  final List<LatLng> points;
  final List<NavigationStep> steps;

  const NavigationRoute({
    required this.id,
    required this.durationMinutes,
    required this.distanceKm,
    required this.points,
    this.steps = const [],
  });
}

NavigationStep parseNavigationStepFromMapbox(Map<String, dynamic> rawStep) {
  final maneuver = (rawStep['maneuver'] as Map<String, dynamic>?) ?? const {};
  return NavigationStep(
    instruction:
        maneuver['instruction']?.toString() ??
        rawStep['name']?.toString() ??
        'Continue on the route',
    distanceMeters: (rawStep['distance'] as num?)?.toDouble() ?? 0,
    durationMinutes: ((rawStep['duration'] as num?)?.toDouble() ?? 0) / 60,
    maneuverType: maneuver['type']?.toString(),
    maneuverModifier: maneuver['modifier']?.toString(),
  );
}

NavigationRoute parseNavigationRouteFromMapbox(
  Map<String, dynamic> route, {
  required String id,
}) {
  final geometry = route['geometry'] as Map<String, dynamic>;
  final coords = (geometry['coordinates'] as List<dynamic>)
      .map((coord) {
        final pair = (coord as List<dynamic>).cast<num>();
        return LatLng(pair[1].toDouble(), pair[0].toDouble());
      })
      .toList(growable: false);
  final legs = (route['legs'] as List<dynamic>? ?? const []);
  final steps = legs
      .expand(
        (leg) =>
            ((leg as Map<String, dynamic>)['steps'] as List<dynamic>? ??
            const []),
      )
      .map(
        (step) => parseNavigationStepFromMapbox(step as Map<String, dynamic>),
      )
      .toList(growable: false);

  return NavigationRoute(
    id: id,
    durationMinutes: ((route['duration'] as num?)?.toDouble() ?? 0) / 60,
    distanceKm: ((route['distance'] as num?)?.toDouble() ?? 0) / 1000,
    points: coords,
    steps: steps,
  );
}

class MapboxService {
  static MapboxService? _instance;
  static MapboxService get instance => _instance ??= MapboxService._();
  MapboxService._();

  String get _token {
    final token = AppConfig.mapboxPublicKey;
    if (token == null) {
      throw StateError('MAPBOX_PUBLIC_KEY is missing from .env.');
    }
    return token;
  }

  String _buildFallbackQuery(String query) {
    final normalized = _normalizeGeocodeText(query);
    if (normalized.contains('bengaluru') || normalized.contains('bangalore')) {
      return query.trim();
    }
    return '${query.trim()}, Bengaluru';
  }

  MapboxPlace? _pickBestMapboxPlace(
    String query,
    List<dynamic> features,
  ) {
    MapboxPlace? bestPlace;
    var bestScore = 0.0;

    for (final feature in features.whereType<Map<String, dynamic>>()) {
      final center = (feature['center'] as List<dynamic>?)?.cast<num>();
      if (center == null || center.length < 2) continue;
      final label =
          feature['place_name']?.toString() ??
          feature['text']?.toString() ??
          '';
      if (label.isEmpty) continue;

      final score = geocodeMatchScore(query, label);
      if (score > bestScore) {
        bestScore = score;
        bestPlace = MapboxPlace(
          label: label,
          point: LatLng(center[1].toDouble(), center[0].toDouble()),
        );
      }
    }

    if (bestScore >= 0.72) return bestPlace;
    return null;
  }

  Future<MapboxPlace?> _openStreetMapFallback(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'jsonv2',
      'limit': '5',
      'countrycodes': 'in',
      'q': _buildFallbackQuery(query),
    });

    final response = await http.get(
      uri,
      headers: const {
        'User-Agent': 'SafeRoute/1.0 (destination-search fallback)',
      },
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body) as List<dynamic>;
    if (body.isEmpty) return null;

    MapboxPlace? bestPlace;
    var bestScore = 0.0;
    for (final raw in body.whereType<Map<String, dynamic>>()) {
      final label = raw['display_name']?.toString();
      final lat = double.tryParse(raw['lat']?.toString() ?? '');
      final lon = double.tryParse(raw['lon']?.toString() ?? '');
      if (label == null || lat == null || lon == null) continue;

      final score = geocodeMatchScore(query, label);
      if (score > bestScore) {
        bestScore = score;
        bestPlace = MapboxPlace(label: label, point: LatLng(lat, lon));
      }
    }

    return bestPlace;
  }

  Future<MapboxPlace> geocode(String query, {LatLng? proximity}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      throw ArgumentError('Destination is required.');
    }

    final params = <String, String>{
      'access_token': _token,
      'country': 'IN',
      'limit': '1',
    };
    if (proximity != null) {
      params['proximity'] = '${proximity.longitude},${proximity.latitude}';
    }

    final uri = Uri.https(
      'api.mapbox.com',
      '/geocoding/v5/mapbox.places/${Uri.encodeComponent(cleanQuery)}.json',
      params,
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Mapbox geocoding failed (${response.statusCode}).');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (body['features'] as List<dynamic>? ?? const []);
    final bestMapboxPlace = _pickBestMapboxPlace(cleanQuery, features);
    if (bestMapboxPlace != null) {
      return bestMapboxPlace;
    }

    final fallbackPlace = await _openStreetMapFallback(cleanQuery);
    if (fallbackPlace != null) return fallbackPlace;

    if (features.isNotEmpty) {
      final feature = features.first as Map<String, dynamic>;
      final center = (feature['center'] as List<dynamic>).cast<num>();
      return MapboxPlace(
        label: feature['place_name']?.toString() ?? cleanQuery,
        point: LatLng(center[1].toDouble(), center[0].toDouble()),
      );
    }

    throw StateError('No location found for "$cleanQuery".');
  }

  Future<String?> reverseGeocode(LatLng point) async {
    final uri = Uri.https(
      'api.mapbox.com',
      '/geocoding/v5/mapbox.places/${point.longitude},${point.latitude}.json',
      {
        'access_token': _token,
        'limit': '1',
        'types': 'poi,address,place,locality,neighborhood',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (body['features'] as List<dynamic>? ?? const []);
    if (features.isEmpty) return null;
    return (features.first as Map<String, dynamic>)['place_name']?.toString();
  }

  Future<List<NavigationRoute>> directions({
    required LatLng start,
    required LatLng end,
  }) async {
    final coordinates =
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
    final uri = Uri.https(
      'api.mapbox.com',
      '/directions/v5/mapbox/driving/$coordinates',
      {
        'access_token': _token,
        'alternatives': 'true',
        'geometries': 'geojson',
        'overview': 'full',
        'steps': 'true',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Mapbox routing failed (${response.statusCode}).');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rawRoutes = (body['routes'] as List<dynamic>? ?? const []);
    if (rawRoutes.isEmpty) {
      throw StateError('No route was returned for this journey.');
    }

    return rawRoutes
        .asMap()
        .entries
        .map(
          (entry) => parseNavigationRouteFromMapbox(
            entry.value as Map<String, dynamic>,
            id: 'mapbox-${entry.key}',
          ),
        )
        .toList(growable: false);
  }
}

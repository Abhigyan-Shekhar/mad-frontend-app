import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'app_config.dart';

class MapboxPlace {
  final String label;
  final LatLng point;

  const MapboxPlace({required this.label, required this.point});
}

class NavigationRoute {
  final String id;
  final double durationMinutes;
  final double distanceKm;
  final List<LatLng> points;

  const NavigationRoute({
    required this.id,
    required this.durationMinutes,
    required this.distanceKm,
    required this.points,
  });
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
    if (features.isEmpty) {
      throw StateError('No location found for "$cleanQuery".');
    }

    final feature = features.first as Map<String, dynamic>;
    final center = (feature['center'] as List<dynamic>).cast<num>();
    return MapboxPlace(
      label: feature['place_name']?.toString() ?? cleanQuery,
      point: LatLng(center[1].toDouble(), center[0].toDouble()),
    );
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
        'steps': 'false',
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

    return rawRoutes.asMap().entries.map((entry) {
      final route = entry.value as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coords = (geometry['coordinates'] as List<dynamic>)
          .map((coord) {
            final pair = (coord as List<dynamic>).cast<num>();
            return LatLng(pair[1].toDouble(), pair[0].toDouble());
          })
          .toList(growable: false);

      return NavigationRoute(
        id: 'mapbox-${entry.key}',
        durationMinutes: ((route['duration'] as num?)?.toDouble() ?? 0) / 60,
        distanceKm: ((route['distance'] as num?)?.toDouble() ?? 0) / 1000,
        points: coords,
      );
    }).toList(growable: false);
  }
}

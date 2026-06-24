import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class FullscreenMapRouteLine {
  final List<LatLng> points;
  final Color color;
  final double strokeWidth;

  const FullscreenMapRouteLine({
    required this.points,
    required this.color,
    this.strokeWidth = 5,
  });
}

class FullscreenMapMarkerData {
  final LatLng point;
  final Color color;
  final IconData icon;
  final double size;

  const FullscreenMapMarkerData({
    required this.point,
    required this.color,
    required this.icon,
    this.size = 44,
  });
}

class FullscreenRouteMapScreen extends StatelessWidget {
  final String title;
  final String? subtitle;
  final LatLng initialCenter;
  final CameraFit? initialCameraFit;
  final List<FullscreenMapRouteLine> routeLines;
  final List<FullscreenMapMarkerData> markers;

  const FullscreenRouteMapScreen({
    super.key,
    required this.title,
    required this.initialCenter,
    required this.routeLines,
    this.subtitle,
    this.initialCameraFit,
    this.markers = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
              ),
          ],
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 14,
              initialCameraFit: initialCameraFit,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.saferoute.app',
              ),
              if (routeLines.isNotEmpty)
                PolylineLayer(
                  polylines: routeLines
                      .map(
                        (line) => Polyline(
                          points: line.points,
                          color: line.color,
                          strokeWidth: line.strokeWidth,
                        ),
                      )
                      .toList(growable: false),
                ),
              if (markers.isNotEmpty)
                MarkerLayer(
                  markers: markers
                      .map(
                        (marker) => Marker(
                          point: marker.point,
                          width: marker.size,
                          height: marker.size,
                          child: _FullscreenMapPin(
                            color: marker.color,
                            icon: marker.icon,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 20,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(
                  'Pinch and drag to inspect the route',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenMapPin extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _FullscreenMapPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

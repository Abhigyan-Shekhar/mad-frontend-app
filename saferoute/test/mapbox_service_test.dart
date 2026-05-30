import 'package:flutter_test/flutter_test.dart';
import 'package:saferoute/services/mapbox_service.dart';

void main() {
  test('scores landmark acronym matches above generic college matches', () {
    final exact = geocodeMatchScore(
      'bms college of engineering',
      'BMS College of Engineering, Bengaluru',
    );
    final generic = geocodeMatchScore(
      'bms college of engineering',
      'DS College Of Engineering, Kumaraswamy Layout, Bengaluru',
    );

    expect(exact, greaterThan(generic));
    expect(exact, greaterThan(0.8));
    expect(generic, lessThan(0.7));
  });

  test('parses navigation steps from a Mapbox route payload', () {
    final route = parseNavigationRouteFromMapbox({
      'duration': 780.0,
      'distance': 5400.0,
      'geometry': {
        'coordinates': [
          [77.5946, 12.9716],
          [77.6050, 12.9750],
        ],
      },
      'legs': [
        {
          'steps': [
            {
              'distance': 120.0,
              'duration': 30.0,
              'maneuver': {
                'instruction': 'Head north on 6th Cross Road',
                'type': 'depart',
                'modifier': 'straight',
              },
            },
            {
              'distance': 400.0,
              'duration': 90.0,
              'maneuver': {
                'instruction': 'Turn right onto Brigade Road',
                'type': 'turn',
                'modifier': 'right',
              },
            },
          ],
        },
      ],
    }, id: 'mapbox-0');

    expect(route.id, 'mapbox-0');
    expect(route.durationMinutes, 13);
    expect(route.distanceKm, 5.4);
    expect(route.steps, hasLength(2));
    expect(route.steps.first.instruction, 'Head north on 6th Cross Road');
    expect(route.steps.first.maneuverType, 'depart');
    expect(route.steps.last.maneuverModifier, 'right');
  });
}

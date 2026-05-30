import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saferoute/services/bbmp_service.dart';

void main() {
  test('cached-only reads do not fall back to OpenCity when Supabase is empty', () async {
    var clientCalled = false;
    final service = BbmpService(
      client: MockClient((request) async {
        clientCalled = true;
        return http.Response('{}', 500);
      }),
      wardScoresLoader: () async => [],
    );

    final scores = await service.getCachedWardScores();
    final routeScore = await service.routeSafetyScoreCached('Origin', 'Destination');

    expect(scores, isEmpty);
    expect(routeScore, 70);
    expect(clientCalled, isFalse);
  });

  test('prefers Supabase ward scores before OpenCity fetch', () async {
    final service = BbmpService(
      client: MockClient((request) async {
        throw http.ClientException('should not be needed', request.url);
      }),
      wardScoresLoader: () async => [
        {
          'ward_name': 'MG Road',
          'total_grievances': 10,
          'road_grievances': 3,
          'light_grievances': 2,
          'safety_score': 82.0,
        },
      ],
    );

    final scores = await service.getWardScores();
    final routeScore = await service.routeSafetyScore('Origin', 'MG Road');

    expect(scores.keys, contains('MG Road'));
    expect(routeScore, 76);
  });

  test('returns empty scores and default route score when BBMP fetch fails', () async {
    final service = BbmpService(
      client: MockClient((request) async {
        throw http.ClientException('failed', request.url);
      }),
    );

    final scores = await service.getWardScores();
    final routeScore = await service.routeSafetyScore('Origin', 'Destination');

    expect(scores, isEmpty);
    expect(routeScore, 70);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:saferoute/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseTableGuard', () {
    test(
      'recognizes missing table schema-cache errors for the expected table',
      () {
        const error = PostgrestException(
          message:
              "Could not find the table 'public.route_analyses' in the schema cache",
          code: 'PGRST205',
        );

        expect(
          SupabaseTableGuard.isMissingTableError(error, 'route_analyses'),
          isTrue,
        );
        expect(
          SupabaseTableGuard.isMissingTableError(error, 'street_segments'),
          isFalse,
        );
      },
    );

    test('returns fallback value for missing table errors', () {
      const error = PostgrestException(
        message:
            "Could not find the table 'public.street_segments' in the schema cache",
        code: 'PGRST205',
      );

      final rows =
          SupabaseTableGuard.fallbackIfMissingTable<List<Map<String, dynamic>>>(
            error,
            tableName: 'street_segments',
            fallback: const [],
          );

      expect(rows, isEmpty);
    });

    test('rethrows non-matching errors', () {
      const error = PostgrestException(
        message: 'permission denied',
        code: '42501',
      );

      expect(
        () => SupabaseTableGuard.fallbackIfMissingTable<Map<String, dynamic>?>(
          error,
          tableName: 'route_analyses',
          fallback: null,
        ),
        throwsA(same(error)),
      );
    });
  });
}

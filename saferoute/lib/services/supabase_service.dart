import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseTableGuard {
  static bool isMissingTableError(Object error, String tableName) {
    if (error is! PostgrestException) return false;
    if (error.code != 'PGRST205') return false;
    return error.message.contains("public.$tableName");
  }

  static T fallbackIfMissingTable<T>(
    Object error, {
    required String tableName,
    required T fallback,
  }) {
    if (isMissingTableError(error, tableName)) {
      return fallback;
    }
    throw error;
  }
}

String deriveTripStatusAfterSos({required String currentStatus}) {
  return currentStatus == 'completed' ? 'completed' : 'sos_triggered';
}

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();
  SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;
  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  String get _userId {
    final id = currentUser?.id;
    if (id == null) throw StateError('Sign in required.');
    return id;
  }

  // ─── AUTH ────────────────────────────────────────────────────
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<Map<String, dynamic>?> getMyProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return _client.from('profiles').select().eq('id', user.id).maybeSingle();
  }

  // ─── TRIPS ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> startTrip({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required String destinationName,
  }) async {
    final existing = await getActiveTrip();
    if (existing != null) {
      throw StateError('End the current active trip before starting another.');
    }

    final resp = await _client
        .from('trips')
        .insert({
          'user_id': _userId,
          'start_lat': startLat,
          'start_lng': startLng,
          'end_lat': endLat,
          'end_lng': endLng,
          'destination_name': destinationName,
          'status': 'active',
        })
        .select()
        .single();
    return Map<String, dynamic>.from(resp);
  }

  Future<void> endTrip(String tripId) async {
    await _client
        .from('trips')
        .update({
          'status': 'completed',
          'ended_at': DateTime.now().toIso8601String(),
        })
        .eq('id', tripId);
  }

  Future<List<Map<String, dynamic>>> getMyTrips() async {
    final rows = await _client
        .from('trips')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(20);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>?> getActiveTrip() async {
    final rows = await _client
        .from('trips')
        .select()
        .eq('user_id', _userId)
        .inFilter('status', ['active', 'sos_triggered'])
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  // ─── LOCATION PINGS ──────────────────────────────────────────
  Future<void> sendLocationPing({
    required String tripId,
    required double lat,
    required double lng,
    double speed = 0,
    int? batteryLevel,
  }) async {
    await _client.from('location_pings').insert({
      'trip_id': tripId,
      'lat': lat,
      'lng': lng,
      'speed': speed,
      if (batteryLevel != null) 'battery_level': batteryLevel,
    });
  }

  /// Stream of live pings for a specific trip (for Guardian Mode)
  Stream<List<Map<String, dynamic>>> listenToTripPings(String tripId) {
    return _client
        .from('location_pings')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .order('timestamp', ascending: false)
        .limit(1);
  }

  Future<Map<String, dynamic>?> getLatestTripPing(String tripId) async {
    final rows = await _client
        .from('location_pings')
        .select()
        .eq('trip_id', tripId)
        .order('timestamp', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  // ─── SOS ALERTS ──────────────────────────────────────────────
  Future<Map<String, dynamic>> triggerSOS({
    required double lat,
    required double lng,
    String? tripId,
  }) async {
    if (tripId != null) {
      final trip = await _client
          .from('trips')
          .select('status')
          .eq('id', tripId)
          .maybeSingle();
      final currentStatus = trip?['status']?.toString() ?? 'active';
      await _client
          .from('trips')
          .update({
            'status': deriveTripStatusAfterSos(currentStatus: currentStatus),
          })
          .eq('id', tripId);
    }
    final row = await _client
        .from('sos_alerts')
        .insert({
          'user_id': _userId,
          'trip_id': tripId,
          'lat': lat,
          'lng': lng,
          'is_resolved': false,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<void> resolveSOS(String alertId) async {
    await _client
        .from('sos_alerts')
        .update({
          'is_resolved': true,
          'resolved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', alertId);
  }

  // ─── HAZARDS ─────────────────────────────────────────────────
  Future<void> reportHazard({
    required String hazardType,
    required double lat,
    required double lng,
    required String description,
  }) async {
    await _client.from('hazards').insert({
      'reporter_id': _userId,
      'hazard_type': hazardType,
      'lat': lat,
      'lng': lng,
      'description': description,
      'is_active': true,
    });
  }

  Future<List<Map<String, dynamic>>> getActiveHazards() async {
    final rows = await _client
        .from('hazards')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Realtime stream for new hazards
  RealtimeChannel listenForNewHazards(
    void Function(Map<String, dynamic>) onNew,
  ) {
    return _client
        .channel('public:hazards')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'hazards',
          callback: (payload) => onNew(payload.newRecord),
        )
        .subscribe();
  }

  // ─── EMERGENCY CONTACTS ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    final rows = await _client
        .from('emergency_contacts')
        .select()
        .eq('user_id', _userId)
        .order('is_primary', ascending: false)
        .order('created_at', ascending: true);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> addEmergencyContact({
    required String name,
    required String phone,
    bool isPrimary = false,
  }) async {
    await _client.from('emergency_contacts').insert({
      'user_id': _userId,
      'contact_name': name,
      'phone_number': phone,
      'is_primary': isPrimary,
    });
  }

  Future<void> deleteEmergencyContact(String id) async {
    await _client.from('emergency_contacts').delete().eq('id', id);
  }

  // ─── ROUTE ANALYSIS / SAFETY DATA ───────────────────────────
  Future<void> saveRouteAnalysis({
    required String routeId,
    required String destinationName,
    String? tripId,
    required double score,
    required double baseScore,
    required double hazardPenalty,
    required String coverage,
    required List<String> highlights,
    required List<String> hazardTypes,
    String? wardName,
    String? streetSummary,
  }) async {
    try {
      await _client.from('route_analyses').insert({
        'user_id': _userId,
        'trip_id': tripId,
        'route_id': routeId,
        'destination_name': destinationName,
        'score': score,
        'base_score': baseScore,
        'hazard_penalty': hazardPenalty,
        'coverage': coverage,
        'highlights': highlights,
        'hazard_types': hazardTypes,
        if (wardName != null) 'ward_name': wardName,
        if (streetSummary != null) 'street_summary': streetSummary,
      });
    } catch (error) {
      SupabaseTableGuard.fallbackIfMissingTable<void>(
        error,
        tableName: 'route_analyses',
        fallback: null,
      );
    }
  }

  Future<Map<String, dynamic>?> getLatestRouteAnalysis({String? tripId}) async {
    try {
      final query = tripId == null
          ? _client
                .from('route_analyses')
                .select()
                .eq('user_id', _userId)
                .order('created_at', ascending: false)
                .limit(1)
          : _client
                .from('route_analyses')
                .select()
                .eq('user_id', _userId)
                .eq('trip_id', tripId)
                .order('created_at', ascending: false)
                .limit(1);
      final rows = await query;
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    } catch (error) {
      return SupabaseTableGuard.fallbackIfMissingTable<Map<String, dynamic>?>(
        error,
        tableName: 'route_analyses',
        fallback: null,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getWardSafetyScores({
    int limit = 20,
  }) async {
    try {
      final rows = await _client
          .from('ward_safety_scores')
          .select()
          .order('safety_score', ascending: true)
          .limit(limit);
      return rows.map((row) => Map<String, dynamic>.from(row)).toList();
    } catch (error) {
      return SupabaseTableGuard.fallbackIfMissingTable<
        List<Map<String, dynamic>>
      >(error, tableName: 'ward_safety_scores', fallback: const []);
    }
  }

  Future<List<Map<String, dynamic>>> getStreetSegments({
    String? wardName,
    int limit = 20,
  }) async {
    try {
      final query = wardName == null || wardName.trim().isEmpty
          ? _client
                .from('street_segments')
                .select()
                .order('created_at', ascending: false)
                .limit(limit)
          : _client
                .from('street_segments')
                .select()
                .filter('ward_name', 'ilike', '%${wardName.trim()}%')
                .order('created_at', ascending: false)
                .limit(limit);
      final rows = await query;
      return rows.map((row) => Map<String, dynamic>.from(row)).toList();
    } catch (error) {
      return SupabaseTableGuard.fallbackIfMissingTable<
        List<Map<String, dynamic>>
      >(error, tableName: 'street_segments', fallback: const []);
    }
  }

  Future<void> upsertWardSafetyScores(List<Map<String, dynamic>> scores) async {
    if (scores.isEmpty) return;
    try {
      await _client.from('ward_safety_scores').upsert(scores);
    } catch (error) {
      SupabaseTableGuard.fallbackIfMissingTable<void>(
        error,
        tableName: 'ward_safety_scores',
        fallback: null,
      );
    }
  }

  Future<void> upsertStreetSegments(List<Map<String, dynamic>> segments) async {
    if (segments.isEmpty) return;
    try {
      await _client.from('street_segments').upsert(segments);
    } catch (error) {
      SupabaseTableGuard.fallbackIfMissingTable<void>(
        error,
        tableName: 'street_segments',
        fallback: null,
      );
    }
  }
}

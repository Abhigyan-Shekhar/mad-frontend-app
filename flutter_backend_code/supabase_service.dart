import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // ==========================================
  // AUTHENTICATION
  // ==========================================
  
  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signUp(String email, String password, String fullName) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName}, // Triggers handle_new_user in Postgres
    );
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ==========================================
  // TRIPS & GUARDIAN MODE
  // ==========================================

  Future<String> startTrip(double startLat, double startLng, double endLat, double endLng, String destName) async {
    final response = await _client.from('trips').insert({
      'user_id': currentUser!.id,
      'start_lat': startLat,
      'start_lng': startLng,
      'end_lat': endLat,
      'end_lng': endLng,
      'destination_name': destName,
      'status': 'active'
    }).select('id').single();
    
    return response['id'];
  }

  Future<void> endTrip(String tripId) async {
    await _client.from('trips').update({
      'status': 'completed',
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', tripId);
  }

  // Used by the foreground/background location tracker
  Future<void> sendLocationPing(String tripId, double lat, double lng, double speed) async {
    await _client.from('location_pings').insert({
      'trip_id': tripId,
      'lat': lat,
      'lng': lng,
      'speed': speed,
    });
  }

  // ==========================================
  // SOS ALERTS
  // ==========================================

  Future<void> triggerSOS(double lat, double lng, {String? tripId}) async {
    await _client.from('sos_alerts').insert({
      'user_id': currentUser!.id,
      'trip_id': tripId, // Optional, can be null if not in a trip
      'lat': lat,
      'lng': lng,
    });
    // The Postgres trigger 'mark_trip_sos' will automatically update the trip status to 'sos_triggered'
  }

  Future<void> resolveSOS(String alertId) async {
    await _client.from('sos_alerts').update({
      'is_resolved': true,
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', alertId);
  }

  // ==========================================
  // HAZARDS (COMMUNITY REPORTING)
  // ==========================================

  Future<void> reportHazard(String hazardType, double lat, double lng, String description) async {
    await _client.from('hazards').insert({
      'reporter_id': currentUser!.id,
      'hazard_type': hazardType,
      'lat': lat,
      'lng': lng,
      'description': description,
    });
  }

  Future<List<Map<String, dynamic>>> getActiveHazards() async {
    return await _client.from('hazards').select().eq('is_active', true);
  }

  // ==========================================
  // REAL-TIME LISTENERS (WebSockets)
  // ==========================================

  // Listen for new hazards appearing near the user
  void listenForNewHazards(Function(Map<String, dynamic>) onHazardReported) {
    _client.channel('public:hazards')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'hazards',
        callback: (payload) {
          onHazardReported(payload.newRecord);
        }
      )
      .subscribe();
  }

  // Guardian listens to their ward's active trip location
  void listenToGuardianTrip(String tripId, Function(Map<String, dynamic>) onLocationUpdate) {
    _client.channel('trip_$tripId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'location_pings',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'trip_id',
          value: tripId,
        ),
        callback: (payload) {
          onLocationUpdate(payload.newRecord);
        }
      )
      .subscribe();
  }
}

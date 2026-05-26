import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();
  SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;
  User? get currentUser => _client.auth.currentUser;

  // ─── AUTH ────────────────────────────────────────────────────
  Future<void> signOut() => _client.auth.signOut();

  // ─── TRIPS ───────────────────────────────────────────────────
  Future<String> startTrip({
    required String from,
    required String to,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    double? safetyScore,
  }) async {
    final resp = await _client.from('trips').insert({
      'user_id': currentUser!.id,
      'from_label': from,
      'to_label': to,
      'start_lat': startLat,
      'start_lng': startLng,
      'end_lat': endLat,
      'end_lng': endLng,
      'safety_score': safetyScore,
      'status': 'active',
    }).select('id').single();
    return resp['id'] as String;
  }

  Future<void> endTrip(String tripId) async {
    await _client.from('trips').update({
      'status': 'completed',
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', tripId);
  }

  Future<List<Map<String, dynamic>>> getMyTrips() async {
    return await _client
        .from('trips')
        .select()
        .eq('user_id', currentUser!.id)
        .order('created_at', ascending: false)
        .limit(20);
  }

  // ─── LOCATION PINGS ──────────────────────────────────────────
  Future<void> sendLocationPing({
    required String tripId,
    required double lat,
    required double lng,
    double speed = 0,
  }) async {
    await _client.from('location_pings').insert({
      'trip_id': tripId,
      'lat': lat,
      'lng': lng,
      'speed': speed,
    });
  }

  /// Stream of live pings for a specific trip (for Guardian Mode)
  Stream<List<Map<String, dynamic>>> listenToTripPings(String tripId) {
    return _client
        .from('location_pings')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .order('created_at', ascending: false)
        .limit(1);
  }

  // ─── SOS ALERTS ──────────────────────────────────────────────
  Future<void> triggerSOS({
    required double lat,
    required double lng,
    String? tripId,
  }) async {
    await _client.from('sos_alerts').insert({
      'user_id': currentUser!.id,
      'trip_id': tripId,
      'lat': lat,
      'lng': lng,
      'is_resolved': false,
    });
  }

  // ─── HAZARDS ─────────────────────────────────────────────────
  Future<void> reportHazard({
    required String hazardType,
    required double lat,
    required double lng,
    required String description,
  }) async {
    await _client.from('hazards').insert({
      'reporter_id': currentUser!.id,
      'hazard_type': hazardType,
      'lat': lat,
      'lng': lng,
      'description': description,
      'is_active': true,
    });
  }

  Future<List<Map<String, dynamic>>> getActiveHazards() async {
    return await _client.from('hazards').select().eq('is_active', true).limit(50);
  }

  /// Realtime stream for new hazards
  RealtimeChannel listenForNewHazards(
      void Function(Map<String, dynamic>) onNew) {
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
    return await _client
        .from('emergency_contacts')
        .select()
        .eq('user_id', currentUser!.id);
  }

  Future<void> addEmergencyContact({
    required String name,
    required String phone,
    String relation = 'Guardian',
  }) async {
    await _client.from('emergency_contacts').insert({
      'user_id': currentUser!.id,
      'name': name,
      'phone': phone,
      'relation': relation,
    });
  }

  Future<void> deleteEmergencyContact(String id) async {
    await _client.from('emergency_contacts').delete().eq('id', id);
  }
}

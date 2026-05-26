import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static String get supabaseUrl => _required('SUPABASE_URL');
  static String get supabaseAnonKey => _required('SUPABASE_ANON_KEY');

  static String? get mapboxPublicKey {
    final value = dotenv.env['MAPBOX_PUBLIC_KEY']?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String _required(String key) {
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('Missing required environment value: $key');
    }
    return value;
  }
}

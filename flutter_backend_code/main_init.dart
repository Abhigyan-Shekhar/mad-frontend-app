import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Replace these with your actual keys when integrating into your Flutter app
  // Load these securely using flutter_dotenv or environment variables
  const supabaseUrl = 'YOUR_SUPABASE_URL';
  const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // runApp(const MyApp()); // Run your Flutter app here
}

final supabase = Supabase.instance.client;

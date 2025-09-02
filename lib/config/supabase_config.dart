import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Hardcoded fallback values for mobile deployment
<<<<<<< HEAD
  static const String _fallbackUrl = 'https://ffnemdxaenxwlgbcppgg.supabase.co';
  static const String _fallbackAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmbmVtZHhhZW54d2xnYmNwcGdnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3NDc0NTEsImV4cCI6MjA3MjMyMzQ1MX0.TvveQw7DgKLdPDk-UAavW1pWc0_7FoZPvIyzCP-Nq1U';
  static const String _fallbackServiceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmbmVtZHhhZW54d2xnYmNwcGdnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1Njc0NzQ1MSwiZXhwIjoyMDcyMzIzNDUxfQ.1Agh9Q4FpRnJGR3FP525yVm0G_lqjMkPC1VRBdoegEg';
=======
>>>>>>> 855eb23df949874e99596530a6e5c1834aac4ba0

  static String get url {
    // Priority: .env > dart-define > hardcoded fallback (prioritize .env for mobile)
    try {
      if (dotenv.isInitialized) {
        final envUrl = dotenv.env['SUPABASE_URL'];
        if (envUrl != null && envUrl.isNotEmpty) {
          return envUrl;
        }
      }
    } catch (e) {
      // Error accessing .env
    }

    final dartDefineUrl = const String.fromEnvironment('SUPABASE_URL');
    if (dartDefineUrl.isNotEmpty) {
      return dartDefineUrl;
    }

    return _fallbackUrl;
  }

  static String get anonKey {
    // Priority: .env > dart-define > hardcoded fallback (prioritize .env for mobile)
    try {
      if (dotenv.isInitialized) {
        final envKey = dotenv.env['SUPABASE_ANON_KEY'];
        if (envKey != null && envKey.isNotEmpty) {
          return envKey;
        }
      }
    } catch (e) {
      // Error accessing .env
    }

    final dartDefineKey = const String.fromEnvironment('SUPABASE_ANON_KEY');
    if (dartDefineKey.isNotEmpty) {
      return dartDefineKey;
    }

    return _fallbackAnonKey;
  }

    static String get serviceRoleKey {
    // Priority: .env > dart-define > hardcoded fallback (prioritize .env for mobile)
    try {
      if (dotenv.isInitialized) {
        final envKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'];
        if (envKey != null && envKey.isNotEmpty) {
          return envKey;
        }
      }
    } catch (e) {
      // Error accessing .env
    }

    final dartDefineKey = const String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');
    if (dartDefineKey.isNotEmpty) {
      return dartDefineKey;
    }

    return _fallbackServiceRoleKey;
  }
  
  static String get baseUrl => url;
  static String get apiKey => anonKey;
  static String get serviceRoleApiKey => serviceRoleKey;
  
  // Helper method to check if .env file exists in assets
  static Future<bool> _checkEnvAsset() async {
    try {
      await rootBundle.loadString('.env');
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Initialize Supabase
  static Future<void> initialize() async {
    try {
      // Try to load .env file if it exists, but don't fail if it doesn't
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        // .env file not found, using hardcoded fallback values
        // This is expected in production builds
      }
      
      final supabaseUrl = url;
      final supabaseAnonKey = anonKey;

      // Validate credentials
      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        throw const FormatException(
          'Supabase credentials missing. Check configuration.'
        );
      }

      // Validate URL format
      if (!supabaseUrl.startsWith('https://') || !supabaseUrl.contains('.supabase.co')) {
        throw const FormatException(
          'Invalid Supabase URL format. Expected: https://xxx.supabase.co'
        );
      }

      // Validate key format (basic JWT check)
      if (!supabaseAnonKey.startsWith('eyJ') || supabaseAnonKey.split('.').length != 3) {
        throw const FormatException(
          'Invalid Supabase anon key format. Expected JWT token.'
        );
      }

      // Initialize Supabase
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: false, // Disable debug logs in production
      );
      
      // Test connection
      try {
        final client = Supabase.instance.client;
        await client.from('profiles').select('count').limit(1);
      } catch (e) {
        // Don't throw here - let the app continue, connection might work later
      }
      
    } catch (e) {
      rethrow; // Re-throw so main.dart can handle it
    }
  }
  
  // Get Supabase client
  static SupabaseClient get client => Supabase.instance.client;
  
  // Get Supabase auth
  static GoTrueClient get auth => Supabase.instance.client.auth;
} 

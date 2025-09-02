// Database connectivity test utility
// Use this to debug database connection issues

import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';

class DatabaseTest {
  static final _supabase = SupabaseConfig.client;

  /// Test basic database connectivity
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      if (kDebugMode) {
        // Print which backend we are hitting on-device
        final backend = SupabaseConfig.url;
        print('🔌 DB Test -> backend host: '
            '${backend.replaceFirst('https://', '').split('/').first}');
      }
      
      // Test 1: Basic query
      final response = await _supabase
          .from('profiles')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 10));
      
      if (kDebugMode) {
        print('✅ DB Test -> connection OK (profiles id sample: ${response.isNotEmpty})');
      }
      return {
        'success': true,
        'message': 'Database connection working',
        'data': response,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ DB Test -> connection failed: $e');
      }
      return {
        'success': false,
        'message': 'Database connection failed: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  /// Test profiles table access
  static Future<Map<String, dynamic>> testProfilesAccess() async {
    try {
      if (kDebugMode) {
        print('🧪 DB Test -> testing profiles access (SELECT limited fields)');
      }
      
      final response = await _supabase
          .from('profiles')
          .select('id, username, email, role, status')
          .limit(5)
          .timeout(const Duration(seconds: 10));
      
      if (kDebugMode) {
        print('✅ DB Test -> profiles access OK, count=${response.length}');
      }
      
      return {
        'success': true,
        'message': 'Profiles access working',
        'count': response.length,
        'data': response,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ DB Test -> profiles access failed: $e');
      }
      return {
        'success': false,
        'message': 'Profiles access failed: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  /// Test username lookup (what happens during login)
  static Future<Map<String, dynamic>> testUsernameLookup(String username) async {
    try {
      if (kDebugMode) {
        print('🧪 DB Test -> username lookup: "$username"');
      }
      
      final response = await _supabase
          .from('profiles')
          .select('email, role, status')
          .eq('username', username)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
      
      if (response != null) {
        if (kDebugMode) {
          print('✅ DB Test -> username found (role=${response['role']}, status=${response['status']})');
        }
        return {
          'success': true,
          'message': 'Username found',
          'data': response,
        };
      } else {
        if (kDebugMode) {
          print('❌ DB Test -> username not found');
        }
        return {
          'success': false,
          'message': 'Username not found',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ DB Test -> username lookup failed: $e');
      }
      return {
        'success': false,
        'message': 'Username lookup failed: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  /// Test Supabase auth connectivity
  static Future<Map<String, dynamic>> testAuthConnectivity() async {
    try {
      if (kDebugMode) {
        print('🔐 DB Test -> testing auth connectivity');
      }
      
      // Try to get current session (should return null if not logged in)
      final session = _supabase.auth.currentSession;
      
      if (kDebugMode) {
        print('✅ DB Test -> auth client OK, session user: ${session?.user?.id ?? 'none'}');
      }
      
      return {
        'success': true,
        'message': 'Auth connectivity working',
        'has_session': session != null,
        'user_id': session?.user?.id,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ DB Test -> auth connectivity failed: $e');
      }
      return {
        'success': false,
        'message': 'Auth connectivity failed: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  /// Run comprehensive database tests
  static Future<Map<String, dynamic>> runAllTests({String? testUsername}) async {
    if (kDebugMode) {
      print('🧪 Running comprehensive database tests...');
    }
    
    final results = <String, dynamic>{};
    
    // Test 1: Basic connection
    results['connection'] = await testConnection();
    if (kDebugMode) print('➡️  connection: ${results['connection']}');
    
    // Test 2: Auth connectivity
    results['auth'] = await testAuthConnectivity();
    if (kDebugMode) print('➡️  auth: ${results['auth']}');
    
    // Test 3: Profiles access
    results['profiles'] = await testProfilesAccess();
    if (kDebugMode) print('➡️  profiles: ${results['profiles']}');
    
    // Test 4: Username lookup (if provided)
    if (testUsername != null && testUsername.isNotEmpty) {
      results['username_lookup'] = await testUsernameLookup(testUsername);
      if (kDebugMode) print('➡️  username_lookup: ${results['username_lookup']}');
    }
    
    // Summary
    final allSuccessful = results.values.every((test) => test['success'] == true);
    results['summary'] = {
      'all_tests_passed': allSuccessful,
      'message': allSuccessful 
          ? 'All database tests passed ✅' 
          : 'Some database tests failed ❌',
    };
    if (kDebugMode) {
      print('🧪 Database tests completed. All passed: $allSuccessful');
    }
    return results;
  }
}

// Helper function to run tests from anywhere in the app
Future<void> runDatabaseTests({String? username}) async {
  final results = await DatabaseTest.runAllTests(testUsername: username);
  print('🧪 TEST RESULTS: $results');
}

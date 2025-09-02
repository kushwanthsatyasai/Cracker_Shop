import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as app_user;
import '../config/supabase_config.dart';
import 'product_service.dart';

class AuthService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final GoTrueClient _auth = SupabaseConfig.auth;

  // Get current user
  app_user.User? get currentUser {
    final user = _auth.currentUser;
    if (user != null) {
      return app_user.User(
        id: user.id,
        username: user.email?.split('@').first ?? '',
        fullName: user.userMetadata?['full_name'] ?? '',
        role: user.userMetadata?['role'] ?? 'biller',
        status: 'active',
        createdAt: _parseDateTime(user.createdAt) ?? DateTime.now(),
        updatedAt: _parseDateTime(user.lastSignInAt) ?? _parseDateTime(user.createdAt) ?? DateTime.now(),
      );
    }
    return null;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // Get current session
  Session? get currentSession => _auth.currentSession;

  // Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  // Sign in with email and password
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 15));
      
      if (response.user != null) {
        // Fetch user profile from profiles table with timeout (non-blocking)
        try {
          await _fetchUserProfile(response.user!.id)
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          // Don't fail the entire login if profile fetch fails
        }
      }
      
      return response;
    } on AuthException catch (e) {
      // Handle specific auth errors
      if (e.message.toLowerCase().contains('invalid login credentials') ||
          e.message.toLowerCase().contains('invalid password') ||
          e.message.toLowerCase().contains('email not confirmed') ||
          e.statusCode == '400') {
        throw Exception('Invalid credentials');
      } else if (e.message.toLowerCase().contains('too many requests')) {
        throw Exception('Too many login attempts. Please try again later.');
      } else if (e.message.toLowerCase().contains('email not found') ||
                 e.message.toLowerCase().contains('user not found')) {
        throw Exception('Invalid credentials');
      } else {
        throw Exception('Login failed: ${e.message}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Login request timed out. Please check your connection.');
      }
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  // Sign in with username and password
  Future<AuthResponse> signInWithUsername(String username, String password) async {
    try {
      // Try to resolve username -> email from profiles with timeout
      try {
        final row = await _supabase
            .from('profiles')
            .select('email')
            .eq('username', username)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));
        
        final email = row != null ? (row['email'] as String?) : null;
        if (email != null && email.isNotEmpty) {
          return await signInWithEmail(email, password);
        }
      } catch (e) {
        // Continue with fallback if lookup fails
      }

      // Fallback: treat the provided username as email (in case username==email)
      return await signInWithEmail(username, password);
    } on Exception {
      // Re-throw our custom exceptions from signInWithEmail
      rethrow;
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  // Sign up with email and password
  Future<AuthResponse> signUpWithEmail(String email, String password, String fullName, String role) async {
    try {
      final response = await _auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role,
        },
      );
      
      if (response.user != null) {
        // Create user profile in profiles table
        await _createUserProfile(response.user!, fullName, role);
      }
      
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Clear any cached data in ProductService
      final productService = ProductService();
      productService.clearCache();
      
      await _auth.signOut().timeout(const Duration(seconds: 5));
    } catch (e) {
      rethrow;
    }
  }

  // Create user profile in profiles table
  Future<void> _createUserProfile(User user, String fullName, String role) async {
    try {
      await _supabase
          .from('profiles')
          .insert({
            'id': user.id,
            'username': user.email?.split('@').first ?? '',
            'email': user.email,
            'full_name': fullName,
            'role': role,
          'status': 'active',
          });
    } catch (e) {
      rethrow;
    }
  }

  // Fetch user profile from profiles table
  Future<void> _fetchUserProfile(String userId) async {
    try {
      await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 3));
      
      // Profile data is now available in the profiles table
    } catch (e) {
      // Profile fetch failed
    }
  }

  // Get user profile by ID
  Future<app_user.User?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 3));
      
      return app_user.User.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId);
    } catch (e) {
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  // Listen to auth state changes
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;
} 
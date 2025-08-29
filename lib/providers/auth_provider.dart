import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized;

  // Initialize authentication state
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _isLoading = true;
      notifyListeners();
      
      // Check if user is already signed in
      _user = _authService.currentUser;
      
      // Listen to auth state changes
      _authService.authStateChanges.listen((authState) {
        _handleAuthStateChange(authState);
      });
      
      _isInitialized = true;
    } catch (e) {
      // Auth initialization failed
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Handle authentication state changes
  void _handleAuthStateChange(AuthState authState) async {
    if (authState.event == AuthChangeEvent.signedIn) {
      if (authState.session?.user != null) {
        // Get user profile from profiles table with timeout
        try {
          final profile = await _authService.getUserProfile(authState.session!.user.id)
              .timeout(const Duration(seconds: 3));
          if (profile != null) {
            _user = profile;
          } else {
            _user = _authService.currentUser;
          }
        } catch (e) {
          // If profile fetch fails or times out, use basic user info
          _user = _authService.currentUser;
        }
      }
      _isLoading = false;
      notifyListeners();
    } else if (authState.event == AuthChangeEvent.signedOut) {
      _user = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign in
  Future<bool> signIn(String username, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Add timeout to prevent hanging
      final response = await _authService.signInWithUsername(username, password)
          .timeout(const Duration(seconds: 8));
      
      if (response.user != null) {
        // Don't fetch profile here - let _handleAuthStateChange handle it
        // This prevents double fetching and speeds up login
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign up
  Future<bool> signUp(String email, String password, String fullName, String role) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final response = await _authService.signUpWithEmail(email, password, fullName, role);
      
      if (response.user != null) {
        // User created successfully, but needs email verification
        return true;
      }
      return false;
    } catch (e) {
      print('Error signing up: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _authService.signOut();
      _user = null;
    } catch (e) {
      print('Error signing out: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user profile
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    if (_user == null) return false;
    
    try {
      await _authService.updateUserProfile(_user!.id, updates);
      
      // Update local user object
      _user = _user!.copyWith(
        fullName: updates['full_name'] ?? _user!.fullName,
        role: updates['role'] ?? _user!.role,
        status: updates['status'] ?? _user!.status,
        updatedAt: DateTime.now(),
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
      return true;
    } catch (e) {
      print('Error resetting password: $e');
      return false;
    }
  }

  // Update password
  Future<bool> updatePassword(String newPassword) async {
    try {
      await _authService.updatePassword(newPassword);
      return true;
    } catch (e) {
      print('Error updating password: $e');
      return false;
    }
  }

  // Check if user has admin role
  bool get isAdmin => _user?.role == 'admin';
  
  // Check if user has biller role
  bool get isBiller => _user?.role == 'biller';
} 
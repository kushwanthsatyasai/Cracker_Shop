import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart';
import '../config/supabase_config.dart';

class UserService {
  static final SupabaseClient _supabase = SupabaseConfig.client;
  
  // Helper to get admin client with service role key (has admin privileges via RLS)
  static SupabaseClient get _adminClient => SupabaseClient(
    SupabaseConfig.url,
    SupabaseConfig.serviceRoleKey,
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
    ),
  );

  // Get all users
  static Future<List<User>> getUsers() async {
    try {
      final response = await _adminClient
          .from('profiles')
          .select()
          .order('created_at', ascending: false);
      
      return response.map<User>((json) => User.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  // Create a new user - FIXED: Use proper admin API
  // Test admin client connectivity
  static Future<bool> testAdminClient() async {
    try {
      final adminClient = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.serviceRoleKey,
      );
      
      // Test a simple query with service role
      final result = await adminClient
          .from('profiles')
          .select('count(*)')
          .limit(1);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<User> createUser({
    required String username,
    required String fullName,
    required String email,
    required String password,
    required String role,
    required String status,
  }) async {
    try {
      // Create admin client for operations
      final adminClient = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.serviceRoleKey,
      );

      // Step 1: Validate user data using simple RPC
      final validationResponse = await adminClient.rpc(
        'create_user_simple',
        params: {
          'p_email': email,
          'p_password': password,
          'p_username': username,
          'p_full_name': fullName,
          'p_role': role,
          'p_status': status,
        },
      ).timeout(const Duration(seconds: 10));

      if (validationResponse == null) {
        throw Exception('Validation function returned null response');
      }

      final validationResult = validationResponse as Map<String, dynamic>;
      
      if (validationResult['success'] != true) {
        final error = validationResult['error'] ?? 'Validation failed';
        throw Exception(error);
      }

      // Step 2: Create auth user using Supabase Auth Admin API
      final authResponse = await adminClient.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: password,
          emailConfirm: true,
          userMetadata: {
            'username': username,
            'full_name': fullName,
          },
        ),
      ).timeout(const Duration(seconds: 15));

      if (authResponse.user == null) {
        throw Exception('Auth user creation failed - user is null');
      }

      final newUserId = authResponse.user!.id;

      // Step 3: Handle profile creation (trigger might have already created it)
      // Wait a moment for any triggers to complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check if profile already exists (created by trigger)
      try {
        final existingProfile = await adminClient
            .from('profiles')
            .select()
            .eq('id', newUserId)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));
        
        if (existingProfile != null) {
          // Update the existing profile with our data
          final updatedProfile = await adminClient
              .from('profiles')
              .update({
                'username': username,
                'full_name': fullName,
                'email': email,
                'role': role,
                'status': status,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', newUserId)
              .select()
              .single()
              .timeout(const Duration(seconds: 10));
          
          return User(
            id: newUserId,
            username: username,
            fullName: fullName,
            email: email,
            role: role,
            status: status,
            createdAt: DateTime.parse(updatedProfile['created_at']),
            updatedAt: DateTime.parse(updatedProfile['updated_at']),
          );
        } else {
          // Create new profile
          final profileData = {
            'id': newUserId,
            'username': username,
            'full_name': fullName,
            'email': email,
            'role': role,
            'status': status,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };

          final newProfile = await adminClient
              .from('profiles')
              .insert(profileData)
              .select()
              .single()
              .timeout(const Duration(seconds: 10));
          
          return User(
            id: newUserId,
            username: username,
            fullName: fullName,
            email: email,
            role: role,
            status: status,
            createdAt: DateTime.parse(newProfile['created_at']),
            updatedAt: DateTime.parse(newProfile['updated_at']),
          );
        }
      } catch (profileError) {
        // Clean up auth user if profile operations failed
        try {
          await adminClient.auth.admin.deleteUser(newUserId);
        } catch (cleanupError) {
          // Cleanup failed, but continue with original error
        }
        
        throw Exception('Profile handling failed: $profileError');
      }
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  // Delete user - removes both auth user and profile
  static Future<void> deleteUser(String userId) async {
    try {
      // Create admin client for operations
      final adminClient = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.serviceRoleKey,
      );

      // Step 1: Delete from profiles table first (foreign key dependency)
      await adminClient
          .from('profiles')
          .delete()
          .eq('id', userId)
          .timeout(const Duration(seconds: 10));

      // Step 2: Delete from auth.users using admin API
      await adminClient.auth.admin.deleteUser(userId);
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  // Check if user can be deleted (e.g., not the current user, has no bills, etc.)
  static Future<Map<String, dynamic>> checkUserDeletion(String userId) async {
    try {
      // Get current user to prevent self-deletion
      final currentUser = _supabase.auth.currentUser;
      if (currentUser?.id == userId) {
        return {
          'canDelete': false,
          'reason': 'Cannot delete your own account',
        };
      }

      // Check if user has any bills
      final bills = await _supabase
          .from('bills')
          .select('id')
          .eq('biller_id', userId)
          .limit(1);

      if (bills.isNotEmpty) {
        return {
          'canDelete': false,
          'reason': 'User has associated bills and cannot be deleted',
        };
      }

      return {
        'canDelete': true,
        'reason': 'User can be safely deleted',
      };
    } catch (e) {
      return {
        'canDelete': false,
        'reason': 'Error checking user deletion: $e',
      };
    }
  }

  // New admin method for user creation
  static Future<User> _createUserWithAdmin({
    required String username,
    required String fullName,
    required String email,
    required String password,
    required String role,
    required String status,
  }) async {
    try {
      // Create admin client with service role key
      final adminClient = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.serviceRoleKey,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
        ),
      );
      
      // Create auth user with admin API
      final authResponse = await adminClient.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: password,
          emailConfirm: true,
          userMetadata: {
            'username': username,
            'full_name': fullName,
            'role': role,
          },
        ),
      );
      
      if (authResponse.user?.id == null) {
        throw Exception('Admin createUser returned null user');
      }
      
      final userId = authResponse.user!.id;
      
      // Create profile record with required fields
      final profileData = {
        'id': userId,
        'username': username,
        'email': email,
        'full_name': fullName,
        'role': role,
        'status': status,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await adminClient.from('profiles').insert(profileData);
      
      return User(
        id: userId,
        username: username,
        email: email,
        fullName: fullName,
        role: role,
        status: status,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      rethrow;
    }
  }

  // Fallback method to create user without service role
  static Future<User> _createUserFallback({
    required String username,
    required String fullName,
    required String email,
    required String password,
    required String role,
    required String status,
  }) async {
    try {
      // Check if username already exists first
      final existingUser = await _supabase
          .from('profiles')
          .select('username')
          .eq('username', username)
          .maybeSingle();
      
      if (existingUser != null) {
        throw Exception('Username "$username" already exists');
      }
      
      // Check if email already exists in auth
      final existingEmail = await _supabase
          .from('profiles')
          .select('email')
          .eq('email', email)
          .maybeSingle();
      
      if (existingEmail != null) {
        throw Exception('Email "$email" already exists');
      }
      
      // Try to create the auth user using sign up
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'full_name': fullName,
          'role': role,
        },
      );
      
      if (authResponse.user == null) {
        throw Exception('Failed to create auth user - user is null');
      }
      
      final userId = authResponse.user!.id;
      
      // Wait for auth user to be fully created
      await Future.delayed(const Duration(milliseconds: 2000));
      
      // Create profile entry with all required fields
      final profileData = {
        'id': userId,
        'username': username,
        'email': email,
        'full_name': fullName,
        'role': role,
        'status': status,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Use admin client for profile creation to bypass RLS
      try {
        await _adminClient
            .from('profiles')
            .insert(profileData)
            .select()
            .single();
      } catch (insertError) {
        // If admin client fails, try regular client with upsert
        await _supabase
            .from('profiles')
            .upsert(profileData)
            .select()
            .single();
      }

      return User(
        id: userId,
        username: username,
        email: email,
        fullName: fullName,
        role: role,
        status: status,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to create user with fallback method: $e');
    }
  }

  // Update user status
  static Future<void> updateUserStatus(String userId, String status) async {
    try {
      await _supabase
          .from('profiles')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update user status: $e');
    }
  }

  // Update user profile
  static Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Delete user (set status to inactive instead of actual deletion)
  static Future<void> deactivateUser(String userId) async {
    try {
      await updateUserStatus(userId, 'inactive');
    } catch (e) {
      throw Exception('Failed to deactivate user: $e');
    }
  }

  // Get user sales data for a specific date range
  static Future<Map<String, double>> getUserSalesData(String userId, DateTime start, DateTime end) async {
    try {
      final response = await _supabase
          .from('bills')
          .select('total_amount, payment_method')
          .eq('biller_id', userId)
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());

      double totalSales = 0;
      double cashSales = 0;
      double onlineSales = 0;

      for (final bill in response) {
        final total = (bill['total_amount'] as num).toDouble();
        totalSales += total;
        
        if (bill['payment_method'] == 'cash') {
          cashSales += total;
        } else {
          onlineSales += total;
        }
      }

      return {
        'total': totalSales,
        'cash': cashSales,
        'online': onlineSales,
      };
    } catch (e) {
      return {'total': 0, 'cash': 0, 'online': 0};
    }
  }

  // Get today's sales for all users
  static Future<Map<String, Map<String, double>>> getTodaysSalesForAllUsers() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final users = await getUsers();
      final Map<String, Map<String, double>> userSalesData = {};

      for (final user in users) {
        if (user.role == 'biller') {
          userSalesData[user.id] = await getUserSalesData(user.id, startOfDay, endOfDay);
        }
      }

      return userSalesData;
    } catch (e) {
      return {};
    }
  }

  // Get all biller names
  static Future<List<String>> getBillerNames() async {
    try {
      final response = await _adminClient
          .from('profiles')
          .select('full_name')
          .eq('status', 'active')
          .order('full_name');
      
      return response.map<String>((item) => item['full_name'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  // Get sales data with filters
  static Future<Map<String, dynamic>> getSalesData({
    required String timeFilter, // today, yesterday, week
    required String paymentFilter, // all, cash, online
  }) async {
    try {
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;

      switch (timeFilter) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'yesterday':
          final yesterday = now.subtract(const Duration(days: 1));
          startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
          endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
          break;
        case 'week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        default:
          startDate = DateTime(now.year, now.month, now.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      }

      // Get bills first, then fetch biller names separately
      var billQuery = _supabase
          .from('bills')
          .select('biller_id, total_amount, payment_method')
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .eq('status', 'completed');

      if (paymentFilter != 'all') {
        billQuery = billQuery.eq('payment_method', paymentFilter);
      }

      final billsResponse = await billQuery;
      // Get unique biller IDs
      final billerIds = billsResponse
          .map((bill) => bill['biller_id'] as String)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      // Fetch biller names
      Map<String, String> billerNames = {};
      if (billerIds.isNotEmpty) {
        final billersResponse = await _adminClient
            .from('profiles')
            .select('id, full_name, role, status')
            .inFilter('id', billerIds);
        
        for (final biller in billersResponse) {
          final billerId = biller['id'] as String;
          final billerName = biller['full_name'] as String;
          billerNames[billerId] = billerName;
        }
        
        // Check for missing mappings and add default names
        for (final billerId in billerIds) {
          if (!billerNames.containsKey(billerId)) {
            billerNames[billerId] = 'Unknown User ($billerId)';
          }
        }
      }

      double totalAmount = 0;
      int totalBills = 0;
      Map<String, double> billerSales = {};

      for (final bill in billsResponse) {
        final amount = (bill['total_amount'] as num).toDouble();
        final billerId = bill['biller_id'] as String;
        totalAmount += amount;
        totalBills++;

        final billerName = billerNames[billerId] ?? 'Unknown Biller ($billerId)';
        billerSales[billerName] = (billerSales[billerName] ?? 0) + amount;
      }

      return {
        'totalAmount': totalAmount,
        'totalBills': totalBills,
        'billerSales': billerSales,
        'averageBill': totalBills > 0 ? totalAmount / totalBills : 0,
      };
    } catch (e) {
      return {
        'totalAmount': 0.0,
        'totalBills': 0,
        'billerSales': <String, double>{},
        'averageBill': 0.0,
      };
    }
  }

  // Fix bills with missing biller profiles by updating to existing admin ID
  static Future<void> fixBillsWithMissingProfiles() async {
    try {
      // Get all unique biller IDs from bills
      final billsResponse = await _supabase
          .from('bills')
          .select('biller_id');
      
      final billerIds = billsResponse
          .map((bill) => bill['biller_id'] as String)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      
      // Check which profiles exist
      final existingProfiles = await _supabase
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', billerIds);
      
      final existingIds = existingProfiles.map((p) => p['id'] as String).toSet();
      
      // Find missing biller IDs
      final missingIds = billerIds.where((id) => !existingIds.contains(id)).toList();
      
      if (missingIds.isNotEmpty) {
        // Get an existing admin/active profile to assign bills to
        final adminProfile = await _supabase
            .from('profiles')
            .select('id, full_name')
            .eq('status', 'active')
            .limit(1)
            .maybeSingle();
        
        if (adminProfile != null) {
          final adminId = adminProfile['id'] as String;
          
          // Update all bills with missing biller_ids to use admin ID
          for (final missingId in missingIds) {
            await _supabase
                .from('bills')
                .update({'biller_id': adminId})
                .eq('biller_id', missingId)
                .select('id, bill_number');
          }
        }
      }
    } catch (e) {
      // Error fixing bills
    }
  }
}

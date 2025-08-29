import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/product_selection_screen.dart';
import 'screens/billing_screen.dart';
import 'screens/add_product_screen.dart';
import 'screens/payment_confirmation_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/bill_details_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/not_found_screen.dart';
import 'models/bill.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase with helpful error surface and retry mechanism
  try {
    await SupabaseConfig.initialize();
    runApp(const MyApp());
  } catch (e) {
    runApp(SupabaseErrorApp(error: e.toString()));
  }
}

class SupabaseErrorApp extends StatefulWidget {
  final String error;
  
  const SupabaseErrorApp({super.key, required this.error});

  @override
  State<SupabaseErrorApp> createState() => _SupabaseErrorAppState();
}

class _SupabaseErrorAppState extends State<SupabaseErrorApp> {
  bool _isRetrying = false;

  Future<void> _retry() async {
    setState(() {
      _isRetrying = true;
    });

    try {
      await SupabaseConfig.initialize();
      // If successful, restart the app
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MyApp()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _isRetrying = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retry failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Connection Failed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to connect to Supabase. Please check your internet connection and try again.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.mutedForeground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isRetrying ? null : _retry,
                  icon: _isRetrying 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_isRetrying ? 'Retrying...' : 'Retry Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ExpansionTile(
                  title: const Text('Technical Details'),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.error,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'CrackShop Pro',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/products': (context) => const ProductSelectionScreen(),
          '/billing': (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              return BillingScreen(
                items: List<BillItem>.from(args['items'] ?? []),
                customerName: args['customerName'] ?? '',
                customerMobile: args['customerMobile'] ?? '',
              );
            }
            return const BillingScreen(
              items: [],
              customerName: '',
              customerMobile: '',
            );
          },
          '/add-product': (context) => const AddProductScreen(),
          '/payment-confirmation': (context) => const PaymentConfirmationScreen(),
          '/bill-details': (context) => const BillDetailsScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/inventory': (context) => const InventoryScreen(),
          '/not-found': (context) => const NotFoundScreen(),
        },
        onGenerateRoute: (settings) {
          // Handle dynamic routes like /bill/{id}
          if (settings.name?.startsWith('/bill/') == true) {
            final billId = settings.name!.split('/').last;
            return MaterialPageRoute(
              builder: (context) => const BillDetailsScreen(),
              settings: RouteSettings(
                name: settings.name,
                arguments: {'billId': billId},
              ),
            );
          }
          
          // Default to not found
          return MaterialPageRoute(
            builder: (context) => const NotFoundScreen(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Delay initialization to avoid build-time state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAuth();
    });
  }

  Future<void> _initializeAuth() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.initialize();
    } catch (e) {
      // Auth initialization failed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Reduced debug logging for better performance
        
        // Show loading while initializing
        if (!authProvider.isInitialized) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Initializing...',
                    style: TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Show loading while checking auth
        if (authProvider.isLoading) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // If authenticated, navigate based on role
        if (authProvider.isAuthenticated && authProvider.user != null) {
          final targetRoute = authProvider.user!.role == 'admin' 
              ? '/dashboard' 
              : '/products';
          
          // Navigation based on user role - Use WidgetsBinding to ensure proper navigation timing
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && ModalRoute.of(context)?.settings.name != targetRoute) {
              Navigator.of(context).pushReplacementNamed(targetRoute);
            }
          });
          
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Redirecting to ${authProvider.user!.role == 'admin' ? 'admin' : 'biller'} dashboard...',
                    style: TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Show login screen
        return const LoginScreen();
      },
    );
  }
}

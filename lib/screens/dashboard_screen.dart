import 'package:flutter/material.dart';
import '../models/bill.dart';
import '../models/user.dart';
import '../services/bill_service.dart';
import '../services/user_service.dart';
import '../config/supabase_config.dart';
import '../utils/responsive_utils.dart';
import '../widgets/logout_button.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Bill> _bills = [];
  List<User> _users = [];
  Map<String, Map<String, double>> _userSalesData = {};
  List<String> _billerNames = [];
  Map<String, dynamic> _salesData = {};
  bool _isLoading = true;
  String _billSearchTerm = '';
  String _selectedBiller = '';
  String _salesFilter = 'today'; // today, yesterday, week
  String _paymentFilter = 'all'; // all, cash, online

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Debug: Temporarily disabled profile fixing since profiles exist
      // await UserService.fixBillsWithMissingProfiles();
      
      // Load data in parallel for better performance with timeout
      final results = await Future.wait([
        BillService.getBills(),
        UserService.getUsers(),
        UserService.getTodaysSalesForAllUsers(),
        UserService.getBillerNames(),
        UserService.getSalesData(timeFilter: _salesFilter, paymentFilter: _paymentFilter),
      ]).timeout(const Duration(seconds: 15));
      
      if (mounted) {
        setState(() {
          _bills = results[0] as List<Bill>;
          _users = results[1] as List<User>;
          _userSalesData = results[2] as Map<String, Map<String, double>>;
          _billerNames = results[3] as List<String>;
          _salesData = results[4] as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Bill> get _filteredBills {
    return _bills.where((bill) {
      final matchesSearch = _billSearchTerm.isEmpty ||
          bill.id.toLowerCase().contains(_billSearchTerm.toLowerCase()) ||
          bill.customerName.toLowerCase().contains(_billSearchTerm.toLowerCase()) ||
          bill.customerMobile.contains(_billSearchTerm);

      final matchesBiller = _selectedBiller.isEmpty || bill.billerName == _selectedBiller;

      return matchesSearch && matchesBiller;
    }).toList();
  }

  Map<String, dynamic> get _analytics {
    final today = DateTime.now();
    final todayBills = _bills.where((bill) =>
        bill.createdAt.year == today.year &&
        bill.createdAt.month == today.month &&
        bill.createdAt.day == today.day).toList();

    final yesterdayBills = _bills.where((bill) =>
        bill.createdAt.year == today.year &&
        bill.createdAt.month == today.month &&
        bill.createdAt.day == today.day - 1).toList();

    final todayTotal = todayBills.fold(0.0, (sum, bill) => sum + bill.total);
    final yesterdayTotal = yesterdayBills.fold(0.0, (sum, bill) => sum + bill.total);
    final weekTotal = _bills
        .where((bill) => bill.createdAt.isAfter(today.subtract(const Duration(days: 7))))
        .fold(0.0, (sum, bill) => sum + bill.total);

    final growth = yesterdayTotal > 0 ? ((todayTotal - yesterdayTotal) / yesterdayTotal * 100) : 0;

    return {
      'todayTotal': todayTotal,
      'yesterdayTotal': yesterdayTotal,
      'weekTotal': weekTotal,
      'growth': growth,
      'todayBills': todayBills.length,
      'yesterdayBills': yesterdayBills.length,
    };
  }

  void _showSalesFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Sales Filter'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Time Period:'),
                  const SizedBox(height: 8),
                  ...['today', 'yesterday', 'week'].map((filter) {
                    return RadioListTile<String>(
                      title: Text(filter.toUpperCase()),
                      value: filter,
                      groupValue: _salesFilter,
                      onChanged: (value) {
                        setState(() {
                          _salesFilter = value!;
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                  const Text('Payment Method:'),
                  const SizedBox(height: 8),
                  ...['all', 'cash', 'online'].map((filter) {
                    return RadioListTile<String>(
                      title: Text(filter.toUpperCase()),
                      value: filter,
                      groupValue: _paymentFilter,
                      onChanged: (value) {
                        setState(() {
                          _paymentFilter = value!;
                        });
                      },
                    );
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Apply filters and reload data
                    _loadData();
                  },
                  child: const Text('Apply'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showDetailedSalesView();
                  },
                  child: const Text('Detailed View'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDetailedSalesView() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: 600,
            height: 500,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Detailed Sales Report',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text('Total Sales'),
                              Text(
                                '₹${_salesData['totalAmount']?.toStringAsFixed(0) ?? '0'}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text('Total Bills'),
                              Text(
                                '${_salesData['totalBills'] ?? 0}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text('Avg Bill'),
                              Text(
                                '₹${_salesData['averageBill']?.toStringAsFixed(0) ?? '0'}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Biller Performance
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Biller Performance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: (_salesData['billerSales'] as Map<String, double>?)?.length ?? 0,
                    itemBuilder: (context, index) {
                      final billerSales = _salesData['billerSales'] as Map<String, double>;
                      final entries = billerSales.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));
                      final entry = entries[index];
                      final percentage = _salesData['totalAmount'] > 0 
                          ? (entry.value / _salesData['totalAmount'] * 100) 
                          : 0.0;
                      
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text('#${index + 1}'),
                          ),
                          title: Text(entry.key),
                          subtitle: Text('${percentage.toStringAsFixed(1)}% of total sales'),
                          trailing: Text(
                            '₹${entry.value.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddUserDialog() {
    final _formKey = GlobalKey<FormState>();
    final _usernameController = TextEditingController();
    final _fullNameController = TextEditingController();
    final _emailController = TextEditingController();
    final _passwordController = TextEditingController();
    String _selectedRole = 'biller';
    String _selectedStatus = 'active';
    bool _isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New User'),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedRole,
                              decoration: const InputDecoration(
                                labelText: 'Role',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                                DropdownMenuItem(value: 'biller', child: Text('Biller')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedRole = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedStatus,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'active', child: Text('Active')),
                                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedStatus = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() {
                        _isLoading = true;
                      });
                      
                      try {
                        await UserService.createUser(
                          username: _usernameController.text.trim(),
                          fullName: _fullNameController.text.trim(),
                          email: _emailController.text.trim(),
                          password: _passwordController.text,
                          role: _selectedRole,
                          status: _selectedStatus,
                        );
                        
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('User created successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          // Use the parent widget's _loadData method
                          if (mounted) {
                            _loadData(); // Refresh data
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error creating user: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (context.mounted) {
                          setState(() {
                            _isLoading = false;
                          });
                        }
                      }
                    }
                  },
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create User'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final analytics = _analytics;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.star,
              color: Colors.amber[600],
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Admin Dashboard'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
        actions: [
          LogoutButton(),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Users'),
            Tab(text: 'Bills'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(analytics),
          _buildUsersTab(),
          _buildBillsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushNamed('/products'),
        label: const Text('Start Billing'),
        icon: const Icon(Icons.calculate),
      ),
    );
  }

  Widget _buildOverviewTab(Map<String, dynamic> analytics) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Quick Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed('/products'),
                  icon: const Icon(Icons.calculate),
                  label: const Text('Start Billing'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed('/inventory'),
                  icon: const Icon(Icons.inventory),
                  label: const Text('Inventory'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Analytics Cards
          LayoutBuilder(
            builder: (context, constraints) {
              if (ResponsiveUtils.isMobile(context)) {
                // Stack cards vertically on mobile
                return Column(
                  children: [
                    _buildAnalyticsCard(context, analytics),
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                    _buildActiveUsersCard(context),
                  ],
                );
              } else {
                // Side by side on tablet/desktop
                return Row(
                  children: [
                    Expanded(child: _buildAnalyticsCard(context, analytics)),
                    SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context)),
                    Expanded(child: _buildActiveUsersCard(context)),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // Sales Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Sales Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Today'),
                            Text(
                              '₹${analytics['todayTotal'].toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Week'),
                            Text(
                              '₹${analytics['weekTotal'].toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Growth'),
                            Text(
                              '+${analytics['growth'].toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Top Performers
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Performers Today',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._buildTopPerformers(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTopPerformers() {
    final Map<String, double> billerSales = (_salesData['billerSales'] as Map<String, double>?) ?? {};
    
    if (billerSales.isEmpty) {
      return [
        const Center(
          child: Text(
            'No sales data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ];
    }

    // Sort billers by sales amount
    final sortedBillers = billerSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Take top 3
    final topBillers = sortedBillers.take(3).toList();

    return topBillers.asMap().entries.map((entry) {
      final rank = entry.key + 1;
      final billerEntry = entry.value;
      return _buildPerformerItem(billerEntry.key, billerEntry.value.round(), rank);
    }).toList();
  }

  Widget _buildPerformerItem(String name, int sales, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${sales.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'User Management',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddUserDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Add User'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Real users from database
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_users.isEmpty)
            const Center(
              child: Column(
                children: [
                  Icon(Icons.people, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No users found'),
                ],
              ),
            )
          else
            ..._users.map((user) {
              print('Dashboard: Displaying user - ${user.fullName} (${user.username}) - ${user.role}');
              final salesData = _userSalesData[user.id];
              final todaySales = salesData?['total']?.round() ?? 0;
              return _buildUserCard(user.fullName, user.role, user.status, todaySales, user);
            }),
        ],
      ),
    );
  }

  Widget _buildUserCard(String name, String role, String status, int todaySales, [User? user]) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'active'
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$role • Joined ${DateTime.now().subtract(const Duration(days: 30)).toString().split(' ')[0]}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  if (role == 'Biller' && todaySales > 0)
                    Text(
                      'Today: ₹${todaySales.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                // TODO: Implement user actions
              },
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search and Filter
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search bills by ID, customer, or mobile...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (mounted) {
                setState(() {
                  _billSearchTerm = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Filter by biller',
              border: OutlineInputBorder(),
            ),
            value: _selectedBiller.isEmpty ? null : _selectedBiller,
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('All Billers'),
              ),
              ..._billerNames.map((biller) =>
                DropdownMenuItem(
                  value: biller,
                  child: Text(biller),
                ),
              ),
            ],
            onChanged: (value) {
              if (mounted) {
                setState(() {
                  _selectedBiller = value ?? '';
                });
              }
            },
          ),
          const SizedBox(height: 16),

          // Bills List
          if (_filteredBills.isEmpty)
            const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 48,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text('No bills found'),
                  Text(
                    'Try adjusting your search criteria',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ..._filteredBills.map((bill) => _buildBillCard(bill)),
        ],
      ),
    );
  }

  Widget _buildBillCard(Bill bill) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/bill/${bill.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).colorScheme.outline),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              bill.id.length > 8 ? '${bill.id.substring(0, 8)}...' : bill.id,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            bill.status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bill.customerName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${bill.customerMobile} • ${bill.items.length} items',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      ),
                    FutureBuilder<String?>(
                      future: SupabaseConfig.client
                          .from('profiles')
                          .select('full_name')
                          .eq('id', bill.billerId)
                          .maybeSingle()
                          .then((data) => data?['full_name'] as String?),
                      builder: (context, snapshot) {
                        return Text(
                          'by ${snapshot.data ?? 'Unknown'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        );
                      },
                    ),
                    Text(
                      bill.createdAt.toString().split('.')[0],
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${bill.total.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/bill/${bill.id}'),
                    icon: const Icon(Icons.visibility),
                    label: const Text('View'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(BuildContext context, Map<String, dynamic> analytics) {
    return Card(
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.currency_rupee,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context) / 2),
                Text(
                  "Today's Sales",
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
            GestureDetector(
              onTap: _showSalesFilterDialog,
              child: Text(
                '₹${_salesData['totalAmount']?.toStringAsFixed(0) ?? '0'}',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 24),
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(
              '+${analytics['growth'].toStringAsFixed(1)}%',
              style: TextStyle(
                color: Colors.green,
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveUsersCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context) / 2),
                Text(
                  'Active Billers',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
            Text(
              '${_users.where((u) => u.status == 'active').length}',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 24),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'of ${_users.length}',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
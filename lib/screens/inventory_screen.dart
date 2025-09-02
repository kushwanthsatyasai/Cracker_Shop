import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/logout_button.dart';
import '../widgets/app_logo.dart';
import '../providers/auth_provider.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await ProductService.getProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load products: $e'),
            backgroundColor: AppTheme.destructive,
          ),
        );
      }
    }
  }

  List<Product> get _filteredProducts {
    return _products.where((product) {
      final matchesSearch = product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || product.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<String> get _categories {
    final categories = _products.map((p) => p.category).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  Future<void> _showEditProductDialog(Product product) async {
    final _mrpController = TextEditingController(text: product.mrp.toString());
    final _sellingPriceController = TextEditingController(text: product.sellingPrice.toString());
    final _stockController = TextEditingController(text: product.stockQuantity.toString());
    final _formKey = GlobalKey<FormState>();
    bool _isLoading = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit ${product.name}'),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // MRP
                      TextFormField(
                        controller: _mrpController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'MRP (₹)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter MRP';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price <= 0) {
                            return 'Please enter a valid price';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Selling Price
                      TextFormField(
                        controller: _sellingPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Selling Price (₹)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter selling price';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price <= 0) {
                            return 'Please enter a valid price';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Stock Quantity
                      TextFormField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock Quantity',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter stock quantity';
                          }
                          final quantity = int.tryParse(value);
                          if (quantity == null || quantity < 0) {
                            return 'Please enter a valid quantity';
                          }
                          return null;
                        },
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
                        await ProductService().updateProduct(
                          product.id,
                          {
                            'price': double.parse(_mrpController.text),
                            'selling_price': double.parse(_sellingPriceController.text),
                            'stock_quantity': int.parse(_stockController.text),
                            'updated_at': DateTime.now().toIso8601String(),
                          },
                        );
                        
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Product updated successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadProducts(); // Refresh the list
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error updating product: $e'),
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
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleProductStatus(Product product) async {
    try {
      await ProductService().updateProduct(
        product.id,
        {
          'is_active': !product.isActive,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              product.isActive 
                  ? 'Product deactivated successfully' 
                  : 'Product activated successfully'
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadProducts(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating product status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAdminSummary() {
    final totalProducts = _products.length;
    final activeProducts = _products.where((p) => p.isActive).length;
    final lowStockProducts = _products.where((p) => p.stockQuantity < 10).length;
    final totalValue = _products.fold<double>(
      0.0, 
      (sum, p) => sum + (p.sellingPrice ?? p.price) * p.stockQuantity
    );

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.dashboard, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Inventory Summary',
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
                    child: _buildSummaryCard(
                      'Total Products',
                      totalProducts.toString(),
                      Icons.inventory,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      'Active',
                      activeProducts.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      'Low Stock',
                      lowStockProducts.toString(),
                      Icons.warning,
                      lowStockProducts > 0 ? Colors.red : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Value',
                      '₹${totalValue.toStringAsFixed(0)}',
                      Icons.currency_rupee,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.isAdmin;
    
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            AppIcon(size: 24),
            SizedBox(width: 8),
            Text('Inventory Management'),
          ],
        ),
        actions: const [LogoutButton()],
      ),
      body: Column(
        children: [
          // Admin Summary (only for admins)
          if (isAdmin) _buildAdminSummary(),
          
          // Search and Filter
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search Products',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value ?? 'All';
                    });
                  },
                ),
              ],
            ),
          ),

          // Products List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? const Center(
                        child: Text('No products found'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          final authProvider = Provider.of<AuthProvider>(context);
                          final isAdmin = authProvider.isAdmin;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                product.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Category: ${product.category}'),
                                  Text('MRP: ₹${product.mrp}'),
                                  Text('Selling Price: ₹${product.sellingPrice}'),
                                  Row(
                                    children: [
                                      Text('Stock: ${product.stockQuantity}'),
                                      if (product.stockQuantity < 10)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.destructive,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Low Stock',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: product.companyType == 'Standard'
                                          ? AppTheme.primary.withValues(alpha: 0.1)
                                          : AppTheme.accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      product.companyType == 'Standard'
                                          ? 'Standard Company'
                                          : 'Other Company',
                                      style: TextStyle(
                                        color: product.companyType == 'Standard'
                                            ? AppTheme.primary
                                            : AppTheme.accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    product.isActive ? Icons.check_circle : Icons.cancel,
                                    color: product.isActive ? AppTheme.success : AppTheme.destructive,
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(width: 8),
                                    PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        if (value == 'edit') {
                                          await _showEditProductDialog(product);
                                        } else if (value == 'toggle_status') {
                                          await _toggleProductStatus(product);
                                        }
                                      },
                                      itemBuilder: (BuildContext context) => [
                                        const PopupMenuItem<String>(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 16),
                                              SizedBox(width: 8),
                                              Text('Edit Price & Stock'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'toggle_status',
                                          child: Row(
                                            children: [
                                              Icon(
                                                product.isActive ? Icons.toggle_on : Icons.toggle_off,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(product.isActive ? 'Deactivate' : 'Activate'),
                                            ],
                                          ),
                                        ),
                                      ],
                                      icon: const Icon(Icons.more_vert),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: isAdmin ? FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).pushNamed('/add-product');
          if (result == true) {
            // Refresh the product list if a new product was added
            _loadProducts();
          }
        },
        label: const Text('Add Product'),
        icon: const Icon(Icons.add),
      ) : null,
    );
  }
} 
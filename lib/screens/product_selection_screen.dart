import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/bill.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/logout_button.dart';
import '../utils/responsive_utils.dart';

class ProductSelectionScreen extends StatefulWidget {
  const ProductSelectionScreen({super.key});

  @override
  State<ProductSelectionScreen> createState() => _ProductSelectionScreenState();
}

class _ProductSelectionScreenState extends State<ProductSelectionScreen> {
  List<Product> _products = [];
  List<BillItem> _selectedItems = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  
  // Variables to handle existing bill data
  List<BillItem> _existingItems = [];
  String _existingCustomerName = '';
  String _existingCustomerMobile = '';
  bool _isFromBilling = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _checkArguments();
  }

  void _checkArguments() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map<String, dynamic>) {
        setState(() {
          _existingItems = List<BillItem>.from(args['items'] ?? []);
          _existingCustomerName = args['customerName'] ?? '';
          _existingCustomerMobile = args['customerMobile'] ?? '';
          _isFromBilling = _existingCustomerName.isNotEmpty;
          
          // If coming from billing, initialize selected items with existing ones
          if (_isFromBilling) {
            _selectedItems = List<BillItem>.from(_existingItems);
          }
        });
      }
    });
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final productService = ProductService();
      final products = await productService.getAllProducts();
      setState(() {
        _products = products;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading products: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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

  void _addToBill(Product product) {
    final existingIndex = _selectedItems.indexWhere((item) => item.productId == product.id);
    
    if (existingIndex != -1) {
      // Update existing item
      setState(() {
        _selectedItems[existingIndex] = _selectedItems[existingIndex].copyWith(
          quantity: _selectedItems[existingIndex].quantity + 1,
          totalPrice: (_selectedItems[existingIndex].quantity + 1) * _selectedItems[existingIndex].unitPrice,
        );
      });
    } else {
      // Add new item
      final billItem = BillItem(
        productId: product.id,
        productName: product.name,
        category: product.category,
        quantity: 1,
        unitPrice: product.sellingPrice ?? product.price,
        totalPrice: product.sellingPrice ?? product.price,
      );
      
      setState(() {
        _selectedItems.add(billItem);
      });
    }
  }

  void _removeFromBill(String productId) {
    setState(() {
      _selectedItems.removeWhere((item) => item.productId == productId);
    });
  }

  void _updateQuantity(String productId, int newQuantity) {
    if (newQuantity <= 0) {
      _removeFromBill(productId);
      return;
    }

    setState(() {
      final index = _selectedItems.indexWhere((item) => item.productId == productId);
      if (index != -1) {
        final item = _selectedItems[index];
        _selectedItems[index] = item.copyWith(
          quantity: newQuantity,
          totalPrice: newQuantity * item.unitPrice,
        );
      }
    });
  }

  double get _subtotal {
    return _selectedItems.fold(0, (sum, item) => sum + item.totalPrice);
  }

  double get _existingSubtotal {
    return _existingItems.fold(0, (sum, item) => sum + item.totalPrice);
  }

  void _proceedToBilling() {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product to the bill'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    if (_isFromBilling) {
      // If coming from billing, just go back with updated items
      Navigator.pop(context, {
        'items': _selectedItems,
        'customerName': _existingCustomerName,
        'customerMobile': _existingCustomerMobile,
      });
    } else {
      // Show customer info dialog for new bill
      _showCustomerInfoDialog(_selectedItems);
    }
  }

  void _showCustomerInfoDialog(List<BillItem> allItems) {
    final customerNameController = TextEditingController();
    final customerMobileController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Customer Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: customerNameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: customerMobileController,
              decoration: const InputDecoration(
                labelText: 'Customer Mobile',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final customerName = customerNameController.text.trim();
              final customerMobile = customerMobileController.text.trim();
              
              if (customerName.isEmpty || customerMobile.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter customer information')),
                );
                return;
              }

              Navigator.pop(context);
              Navigator.of(context).pushNamed('/billing', arguments: {
                'items': allItems,
                'customerName': customerName,
                'customerMobile': customerMobile,
              });
            },
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isFromBilling ? 'Add More Products' : 'Product Selection'),
        actions: const [
          LogoutButton(),
        ],
      ),
      body: Column(
        children: [
          // Search and filter section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip('All'),
                      ..._getUniqueCategories().map(_buildCategoryChip),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Products grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? const Center(child: Text('No products found'))
                    : GridView.builder(
                        padding: ResponsiveUtils.getResponsivePadding(context),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: ResponsiveUtils.getGridColumns(context),
                          childAspectRatio: ResponsiveUtils.getCardAspectRatio(context),
                          crossAxisSpacing: ResponsiveUtils.getResponsiveSpacing(context),
                          mainAxisSpacing: ResponsiveUtils.getResponsiveSpacing(context),
                        ),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          return _buildProductCard(product);
                        },
                      ),
          ),

          // Bill summary
          if (_selectedItems.isNotEmpty) _buildBillSummary(),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(category),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = category;
          });
        },
        selectedColor: AppTheme.primary.withValues(alpha: 0.2),
        checkmarkColor: AppTheme.primary,
      ),
    );
  }

  List<String> _getUniqueCategories() {
    return _products.map((p) => p.category).toSet().toList()..sort();
  }

  Widget _buildProductCard(Product product) {
    final isInBill = _selectedItems.any((item) => item.productId == product.id);
    final billItem = isInBill ? _selectedItems.firstWhere((item) => item.productId == product.id) : null;
    
    return Card(
      margin: const EdgeInsets.all(4.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: product.companyType == 'Standard' ? Colors.blue : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    product.companyType ?? 'Standard',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Category: ${product.category}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    'Stock: ${product.stockQuantity}',
                    style: TextStyle(
                      color: product.stockQuantity > 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '₹${(product.sellingPrice ?? product.price).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isInBill) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Qty: ${billItem!.quantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Total: ₹${billItem.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () => _updateQuantity(product.id, billItem.quantity - 1),
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Colors.red,
                  ),
                  IconButton(
                    onPressed: () => _updateQuantity(product.id, billItem.quantity + 1),
                    icon: const Icon(Icons.add_circle_outline),
                    color: Colors.green,
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: product.stockQuantity > 0 ? () => _addToBill(product) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    product.stockQuantity > 0 ? 'Add to Bill' : 'Out of Stock',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBillSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isFromBilling ? 'Updated Bill Summary' : 'Bill Summary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.primary,
                ),
              ),
              Text(
                '${_selectedItems.length} items',
                style: TextStyle(
                  color: AppTheme.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Show existing bill amount if coming from billing
          if (_isFromBilling && _existingItems.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Previous Bill:',
                  style: TextStyle(
                    color: AppTheme.mutedForeground,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '₹${_existingSubtotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppTheme.mutedForeground,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          
          Text(
            'Subtotal: ₹${_subtotal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          
          // Show total amount if coming from billing
          if (_isFromBilling && _existingItems.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.primary,
                  ),
                ),
                Text(
                  '₹${(_existingSubtotal + _subtotal).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _proceedToBilling,
            child: Text(
              _isFromBilling ? 'Update Bill' : 'Proceed to Billing',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
} 
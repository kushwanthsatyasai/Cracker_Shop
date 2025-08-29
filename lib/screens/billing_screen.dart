import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bill.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../services/bill_service.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/logout_button.dart';


class BillingScreen extends StatefulWidget {
  final List<BillItem> items;
  final String customerName;
  final String customerMobile;

  const BillingScreen({
    super.key,
    required this.items,
    required this.customerName,
    required this.customerMobile,
  });

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final _notesController = TextEditingController();

  List<BillItem> _items = [];
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  final _searchController = TextEditingController();
  bool _isLoading = false;
  double _subtotal = 0;
  double _totalAmount = 0;
  double _standardSubtotal = 0;
  double _othersSubtotal = 0;
  double _discountPercentage = 0.0;
  double _discountAmount = 0.0;
  bool _isCreatingBill = false;
  final _customerNameController = TextEditingController();
  final _customerMobileController = TextEditingController();
  String _selectedPaymentMethod = 'cash';

  String _resolveCompanyType(String? companyType) {
    if (companyType == 'Standard' || companyType == 'Others') {
      return companyType!;
    }
    return 'Standard';
  }

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
    _customerNameController.text = widget.customerName;
    _customerMobileController.text = widget.customerMobile;
    _loadProducts();
    _calculateTotals();
  }
  
  Future<void> _refreshBillItemsWithFreshProducts() async {
    if (_items.isEmpty || _allProducts.isEmpty) return;
    
    final updatedItems = <BillItem>[];
    
    for (final item in _items) {
      final freshProduct = _allProducts.firstWhere(
        (product) => product.id == item.productId,
        orElse: () => item.product,
      );
      
      final updatedItem = BillItem(
        id: item.id,
        billId: item.billId,
        productId: item.productId,
        productName: item.productName,
        category: item.category,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        totalPrice: item.totalPrice,
        createdAt: item.createdAt,
        product: freshProduct,
        discountPercentage: item.discountPercentage,
      );
      
      updatedItems.add(updatedItem);
    }
    
    setState(() {
      _items = updatedItems;
    });
    
    _calculateTotals();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final productService = ProductService();
      final products = await productService.getAllProducts();
      
      setState(() {
        _allProducts = products;
        _filteredProducts = products;
      });
      
      await _refreshBillItemsWithFreshProducts();
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

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        final billProductIds = _items
            .map((item) => item.productId ?? item.product.id)
            .whereType<String>()
            .toSet();
        _filteredProducts = _allProducts
            .where((product) =>
                billProductIds.contains(product.id) &&
                (product.name.toLowerCase().contains(query.toLowerCase()) ||
                product.category.toLowerCase().contains(query.toLowerCase())))
            .toList();
      }
    });
  }

  void _addItem(Product product) {
    final freshProduct = _allProducts.firstWhere(
      (p) => p.id == product.id,
      orElse: () => product,
    );
    
    final existingIndex = _items.indexWhere((item) => item.productId == product.id);
    
    if (existingIndex != -1) {
    setState(() {
        _items[existingIndex] = _items[existingIndex].copyWith(
          quantity: _items[existingIndex].quantity + 1,
          totalPrice: (_items[existingIndex].quantity + 1) * _items[existingIndex].unitPrice,
        );
      });
    } else {
      final billItem = BillItem(
        productId: freshProduct.id,
        productName: freshProduct.name,
        category: freshProduct.category,
        quantity: 1,
        unitPrice: freshProduct.sellingPrice ?? freshProduct.price,
        totalPrice: freshProduct.sellingPrice ?? freshProduct.price,
        product: freshProduct,
      );
      
      setState(() {
        _items.add(billItem);
      });
    }
    
    _updateTotals();
  }

  void _removeItem(String productId) {
    setState(() {
      _items.removeWhere((item) => item.productId == productId);
    });
    _updateTotals();
  }

  void _updateItemQuantity(String productId, int newQuantity) {
    if (newQuantity <= 0) {
      _removeItem(productId);
      return;
    }

    setState(() {
      final index = _items.indexWhere((item) => item.productId == productId);
      if (index != -1) {
        final item = _items[index];
        _items[index] = item.copyWith(
        quantity: newQuantity,
          totalPrice: newQuantity * item.unitPrice,
        );
      }
    });
    _updateTotals();
  }

  void _updateItemPrice(String productId, double newPrice) {
    final item = _items.firstWhere((item) => item.productId == productId);
    final product = item.product;
    
    final minimumPrice = product.sellingPrice ?? product.price;
    final actualCompanyType = _resolveCompanyType(product.companyType);
    
    if (actualCompanyType != 'Standard' && newPrice < minimumPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Price cannot be below minimum price ₹${minimumPrice.toStringAsFixed(2)}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      final index = _items.indexWhere((item) => item.productId == productId);
      if (index != -1) {
        final item = _items[index];
        _items[index] = item.copyWith(
          unitPrice: newPrice,
          totalPrice: newPrice * item.quantity,
        );
      }
    });
    _updateTotals();
  }

  void _updateTotals() {
    double standardSubtotal = 0;
    double othersSubtotal = 0;
    
    for (final item in _items) {
      final actualCompanyType = _resolveCompanyType(item.product.companyType);
      
      if (actualCompanyType == 'Standard') {
        standardSubtotal += item.totalPrice;
      } else {
        othersSubtotal += item.totalPrice;
      }
    }
    
    final discountAmount = standardSubtotal * (_discountPercentage / 100);
    final discountedStandardSubtotal = standardSubtotal - discountAmount;
    
    final subtotal = discountedStandardSubtotal + othersSubtotal;
    final totalAmount = subtotal;

    setState(() {
      _standardSubtotal = standardSubtotal;
      _othersSubtotal = othersSubtotal;
      _discountAmount = discountAmount;
      _subtotal = subtotal;
      _totalAmount = totalAmount;
    });
  }

  void _calculateTotals() => _updateTotals();

  void _showCustomPriceDialog(BillItem item) {
    double customPrice = item.unitPrice;
    final controller = TextEditingController(text: item.unitPrice.toString());
    
    final product = item.product;
    final minimumPrice = product.sellingPrice ?? product.price;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Price for ${item.productName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Price: ₹${item.unitPrice}'),
            Text(
              'Minimum Price: ₹${minimumPrice.toStringAsFixed(2)}',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Custom Price',
                prefixText: '₹',
                border: const OutlineInputBorder(),
                helperText: 'Cannot be below ₹${minimumPrice.toStringAsFixed(2)}',
                errorText: customPrice < minimumPrice ? 'Price too low' : null,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                customPrice = double.tryParse(value) ?? item.unitPrice;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: customPrice >= minimumPrice ? () {
              _updateItemPrice(item.productId ?? item.id, customPrice);
              Navigator.of(context).pop();
            } : null,
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showQuantityDialog(BillItem item) {
    int newQuantity = item.quantity;
    final controller = TextEditingController(text: item.quantity.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Quantity for ${item.productName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Quantity: ${item.quantity}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'New Quantity',
                border: OutlineInputBorder(),
                helperText: 'Enter the desired quantity',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                newQuantity = int.tryParse(value) ?? item.quantity;
                if (newQuantity < 0) newQuantity = 0;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateItemQuantity(item.productId ?? item.id, newQuantity);
              Navigator.of(context).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDiscountDialog() {
    if (_standardSubtotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Standard products to apply discount'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    double tempDiscount = _discountPercentage;
    final controller = TextEditingController(text: _discountPercentage.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply Discount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Standard Products Subtotal: ₹${_standardSubtotal.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Discount Percentage',
                suffixText: '%',
                border: OutlineInputBorder(),
                helperText: 'Applies only to Standard products',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                tempDiscount = double.tryParse(value) ?? 0.0;
                if (tempDiscount < 0) tempDiscount = 0.0;
                if (tempDiscount > 100) tempDiscount = 100.0;
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Discount Amount: ₹${(_standardSubtotal * (tempDiscount / 100)).toStringAsFixed(2)}',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _discountPercentage = tempDiscount;
              });
              _updateTotals();
              Navigator.of(context).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }



  void _clearAllItems() {
              setState(() {
      _items.clear();
                _calculateTotals();
              });
  }

  Future<void> _createBill() async {
    if (_items.isNotEmpty) {
      setState(() {
        _isCreatingBill = true;
      });

    try {
      final bill = Bill(
          billNumber: _generateBillNumber(),
          customerName: widget.customerName,
          customerMobile: widget.customerMobile,
        billerId: context.read<AuthProvider>().user?.id ?? '',
        subtotal: _subtotal,
          taxAmount: 0,
        totalAmount: _standardSubtotal - _discountAmount + _othersSubtotal,
          paymentMethod: _selectedPaymentMethod,
          notes: _notesController.text.trim(),
        items: _items,
      );

        final billService = BillService();
        final createdBill = await billService.createBill(bill);
        
        // Create stock movement records (but don't update product stock yet)
        await _createStockMovements(createdBill.id);
        
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(
        '/bill-details',
        arguments: {
              'billId': createdBill.id,
        },
      );
        }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating bill: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isCreatingBill = false;
          });
        }
      }
    }
  }

  Future<void> _createStockMovements(String billId) async {
    try {
      final productService = ProductService();
      final List<String> createdMovements = [];
      final List<String> failedMovements = [];
      
      for (final item in _items) {
        if (item.productId != null && item.productId!.isNotEmpty) {
          try {
            // Validate quantity is positive
            if (item.quantity <= 0) {
              continue;
            }
            
            // Create stock movement record (without updating product stock)
            await productService.createStockMovement(
              item.productId!,
              'out',
              item.quantity,
              'bill',
              billId,
              'Bill ${billId.substring(0, 8)}... - Customer: ${widget.customerName} - ${item.productName}',
            );
            
            createdMovements.add('${item.productName} (-${item.quantity})');
            
          } catch (itemError) {
            failedMovements.add('${item.productName}: $itemError');
            continue;
          }
        } else {
          failedMovements.add('${item.productName}: Invalid product ID');
        }
      }
      
      // Show summary
      if (mounted) {
        if (createdMovements.isNotEmpty && failedMovements.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Stock movements created for ${createdMovements.length} products'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (failedMovements.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Some stock movements failed: ${failedMovements.length} items'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: Could not create stock movements'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _generateBillNumber() {
    final now = DateTime.now();
    return 'B${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Bill'),
        actions: [
          IconButton(
            onPressed: _clearAllItems,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.destructive.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete,
                color: AppTheme.destructive,
                size: 20,
              ),
            ),
            tooltip: 'Clear All Items',
          ),
          const LogoutButton(),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer: ${widget.customerName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Mobile: ${widget.customerMobile}'),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search Products',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: _filterProducts,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.pushNamed(
                          context, 
                          '/products', 
                          arguments: {
                            'items': _items,
                            'customerName': widget.customerName,
                            'customerMobile': widget.customerMobile,
                          }
                        );
                        
                        if (result != null && result is Map<String, dynamic>) {
                          final updatedItems = result['items'] as List<BillItem>?;
                          if (updatedItems != null) {
                            setState(() {
                              _items = List<BillItem>.from(updatedItems);
                            });
                            
                            await _refreshBillItemsWithFreshProducts();
                          }
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Products'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_searchController.text.isNotEmpty)
                  Text(
                    'Found ${_filteredProducts.length} products',
                    style: TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          if (_searchController.text.isNotEmpty && _filteredProducts.isNotEmpty)
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: ListView.builder(
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    
                    return ListTile(
                      title: Text(product.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${product.category} - ₹${product.sellingPrice}'),
                          if (product.companyType == 'Standard' && product.price != product.sellingPrice) ...[
                            Text(
                              'Discounted: ₹${(product.price * 0.2).toStringAsFixed(2)}',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          Builder(
                            builder: (context) {
                              final actualCompanyType = _resolveCompanyType(product.companyType);
                              final isStandard = actualCompanyType == 'Standard';
                              
                              return Text(
                                'Company: $actualCompanyType',
                                style: TextStyle(
                                  color: isStandard ? AppTheme.primary : AppTheme.accent,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        onPressed: () => _addItem(product),
                        icon: const Icon(Icons.add),
                      ),
                    );
                  },
                ),
              ),
            ),

          if (_isLoading) 
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            
          if (_items.isNotEmpty && !_isLoading) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.swipe_left,
                    size: 16,
                    color: AppTheme.mutedForeground,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Swipe left or right on any product to remove it',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.mutedForeground,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('No items in bill'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Dismissible(
                        key: Key(item.productId ?? item.id),
                        direction: DismissDirection.horizontal,
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Remove Product'),
                                content: Text('Are you sure you want to remove ${item.product.name} from the bill?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.destructive,
                                      foregroundColor: AppTheme.destructiveForeground,
                                    ),
                                    child: const Text('Remove'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (direction) {
                          _removeItem(item.productId ?? item.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${item.product.name} removed from bill'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () {
                                  setState(() {
                                    _items.insert(index, item);
                                    _calculateTotals();
                                  });
                                },
                              ),
                            ),
                          );
                        },
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.destructive,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Remove',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        secondaryBackground: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.destructive,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Remove',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(item.product.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => _updateItemQuantity(item.productId ?? item.id, item.quantity - 1),
                                      icon: const Icon(Icons.remove_circle_outline),
                                      iconSize: 20,
                                      color: Colors.red,
                                    ),
                                    GestureDetector(
                                      onTap: () => _showQuantityDialog(item),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: AppTheme.border),
                                          borderRadius: BorderRadius.circular(8),
                                          color: AppTheme.card,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${item.quantity}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.edit, size: 12),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _updateItemQuantity(item.productId ?? item.id, item.quantity + 1),
                                      icon: const Icon(Icons.add_circle_outline),
                                      iconSize: 20,
                                      color: Colors.green,
                                    ),
                                  ],
                                ),
                                if (item.unitPrice != item.product.sellingPrice) ...[
                                  Row(
                                    children: [
                                      Text(
                                        'Original: ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.mutedForeground,
                                        ),
                                      ),
                                      Text(
                                        '₹${item.product.sellingPrice}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.mutedForeground,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Price: ₹${item.unitPrice}',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ] else ...[
                                  Text('Price: ₹${item.unitPrice}'),
                                ],
                                Builder(
                                  builder: (context) {
                                    final actualCompanyType = _resolveCompanyType(item.product.companyType);
                                    final isStandard = actualCompanyType == 'Standard';
                                    
                                    return Text(
                                      isStandard ? 'Standard' : 'Others',
                                      style: TextStyle(
                                        color: isStandard ? AppTheme.primary : AppTheme.accent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${item.totalPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '₹${item.unitPrice.toStringAsFixed(2)}/unit',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                // Always show edit button for Others products
                                Builder(
                                  builder: (context) {
                                    final actualCompanyType = _resolveCompanyType(item.product.companyType);
                                    final isOthers = actualCompanyType != 'Standard';
                                    
                                    if (isOthers) {
                                      return IconButton(
                                        onPressed: () => _showCustomPriceDialog(item),
                                        icon: const Icon(Icons.edit),
                                        iconSize: 20,
                                        color: AppTheme.primary,
                                        tooltip: 'Edit Price',
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Payment Method and Bill Summary
          Container(
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
                // Bill Summary with detailed breakdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Standard Products Section
                    if (_standardSubtotal > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Standard Products:',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₹${_standardSubtotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      
                      // Discount Section (right after Standard Products)
                      if (_discountAmount > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Discount (${_discountPercentage.toStringAsFixed(1)}%):',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '-₹${_discountAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                    ],
                    
                    // Others Products Section
                    if (_othersSubtotal > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Others Products:',
                            style: TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₹${_othersSubtotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    
                    const Divider(),
                    
                    // Final Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '₹${_totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Action Buttons
                    Row(
                      children: [
                        if (_standardSubtotal > 0)
                          Expanded(
                            flex: 1,
                            child: ElevatedButton.icon(
                              onPressed: _showDiscountDialog,
                              icon: const Icon(Icons.percent, size: 16),
                              label: const Text('Discount'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        if (_standardSubtotal > 0) const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: (_items.isNotEmpty && !_isCreatingBill) ? _createBill : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: AppTheme.primaryForeground,
                            ),
                            child: _isCreatingBill 
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Create Bill'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


} 
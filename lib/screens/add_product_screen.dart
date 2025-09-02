import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/logout_button.dart';

// The company_type is fetched from the database in the following way:
// 1. In ProductService.getAllProducts(), we explicitly select company_type:
//    .from('products').select('*, company_type')
// 2. The JSON response includes company_type which is mapped to Product model
// 3. In Product.fromJson(), company_type is parsed as:
//    companyType: json['company_type']?.toString() ?? 'Standard'
// 4. This ensures company_type is always a String, defaulting to 'Standard'
// 5. The value is then used in the UI dropdown and business logic

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _mrpController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _stockController = TextEditingController();
  
  String _selectedCompanyType = 'Standard';
  bool _isLoading = false;
  
  final List<String> _categories = [
    'Sparklers',
    'Rockets', 
    'Ground',
    'Sound',
    'Fancy',
    'Others'
  ];

  @override
  void initState() {
    super.initState();
    _updateSellingPrice();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _mrpController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _updateSellingPrice() {
    if (_selectedCompanyType == 'Standard' && _mrpController.text.isNotEmpty) {
      final price = double.tryParse(_mrpController.text) ?? 0;
      // For standard products, selling price is calculated from price with 80% discount
      final sellingPrice = price * 0.2; // 20% of price (80% discount)
      _sellingPriceController.text = sellingPrice.toStringAsFixed(2);
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create product data map instead of Product object for creation
      final productData = {
        'name': _nameController.text.trim(),
        'category': _categoryController.text.trim(),
        'company_type': _selectedCompanyType,
        'price': double.parse(_mrpController.text),
        'selling_price': double.parse(_sellingPriceController.text),
        'stock_quantity': int.parse(_stockController.text),
        'is_active': true,
      };

      final created = await ProductService().createProductFromMap(productData);
      final success = created.id.isNotEmpty;
      
      if (!success) {
        throw Exception('Failed to add product');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Product added successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        
        // Clear form
        _formKey.currentState!.reset();
        _nameController.clear();
        _categoryController.clear();
        _mrpController.clear();
        _sellingPriceController.clear();
        _stockController.clear();
        setState(() {
          _selectedCompanyType = 'Standard';
        });
        
        // Return success result so parent can refresh
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding product: $e'),
            backgroundColor: AppTheme.destructive,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Product'),
        actions: const [LogoutButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Product Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Product Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Product Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter product name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Category
                      DropdownButtonFormField<String>(
                        value: _categoryController.text.isEmpty ? null : _categoryController.text,
                        decoration: const InputDecoration(
                          labelText: 'Category *',
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
                            _categoryController.text = value ?? '';
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a category';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Company Type
                      DropdownButtonFormField<String>(
                        value: _selectedCompanyType,
                        decoration: const InputDecoration(
                          labelText: 'Company Type *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Standard',
                            child: Text('Standard'),
                          ),
                          DropdownMenuItem(
                            value: 'Others',
                            child: Text('Others'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCompanyType = value ?? 'Standard';
                            _updateSellingPrice();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                                              // Price (MRP)
                        TextFormField(
                          controller: _mrpController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Price (MRP) *',
                            border: OutlineInputBorder(),
                            prefixText: '₹',
                          ),
                          onChanged: (value) {
                            _updateSellingPrice();
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter price';
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
                        enabled: _selectedCompanyType == 'Others',
                        decoration: InputDecoration(
                          labelText: 'Selling Price *',
                          border: const OutlineInputBorder(),
                          prefixText: '₹',
                          helperText: _selectedCompanyType == 'Standard' 
                              ? 'Automatically calculated from Price (80% discount)'
                              : 'Enter custom selling price',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter selling price';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price <= 0) {
                            return 'Please enter a valid selling price';
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
                          labelText: 'Stock Quantity *',
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
              
              const SizedBox(height: 24),
              
              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.primaryForeground,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Product',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              
              const SizedBox(height: 16),
              
              // Back Button
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Back to Billing',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
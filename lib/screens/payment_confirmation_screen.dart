import 'package:flutter/material.dart';
import '../models/bill.dart';
import '../services/bill_service.dart';
import '../theme/app_theme.dart';
import '../widgets/logout_button.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  const PaymentConfirmationScreen({super.key});

  @override
  State<PaymentConfirmationScreen> createState() => _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  Bill? _bill;
  List<BillItem> _items = [];
  String _customerName = '';
  String _customerMobile = '';
  String _paymentMethod = 'Cash';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Remove _loadBillData() call from here
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load bill data here instead of initState
    if (_bill == null) {
      _loadBillData();
    }
  }

  void _loadBillData() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      setState(() {
        _bill = args['bill'] as Bill;
        _items = List<BillItem>.from(args['items'] as List<BillItem>);
        _customerName = args['customerName'] as String;
        _customerMobile = args['customerMobile'] as String;
      });
    }
  }

  Future<void> _confirmPayment() async {
    if (_bill == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Update bill with payment method
      final updatedBill = Bill(
        id: _bill!.id,
        billNumber: _bill!.billNumber,
        customerName: _bill!.customerName,
        customerMobile: _bill!.customerMobile,
        billerId: _bill!.billerId,
        billerName: _bill!.billerName,
        subtotal: _bill!.subtotal,
        taxAmount: _bill!.taxAmount,
        totalAmount: _bill!.totalAmount,
        paymentMethod: _paymentMethod,
        status: 'completed',
        notes: _bill!.notes,
        createdAt: _bill!.createdAt,
        items: _bill!.items,
      );

      final createdBill = await BillService().createBill(updatedBill);
      
      if (createdBill != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment confirmed! Bill created successfully.'),
              backgroundColor: AppTheme.success,
            ),
          );
          
          // Navigate to bill details with send option
          Navigator.pushReplacementNamed(
            context,
            '/bill/${createdBill.id}',
            arguments: createdBill,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create bill'),
              backgroundColor: AppTheme.destructive,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.destructive,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  double _getStandardSubtotal() {
    return _items.where((item) => item.product.companyType == 'Standard').fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double _getStandardDiscount() {
    // Discount percentage per item is no longer tracked; return 0
    return 0.0;
  }

  double _getOtherSubtotal() {
    return _items.where((item) => item.product.companyType != 'Standard').fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double _getDiscountPercentage() {
    final standardSubtotal = _getStandardSubtotal();
    if (standardSubtotal == 0) return 0;
    
    // Calculate total original price for standard products
    // No discount tracking → 0
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_bill == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Payment Confirmation'),
          actions: const [LogoutButton()],
        ),
        body: const Center(child: Text('No bill data found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Confirmation'),
        actions: const [LogoutButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Shop Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Vani Fire Crackers',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bill #${_bill!.billNumber}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Date: ${_bill!.createdAt.toString().split(' ')[0]}',
                      style: TextStyle(
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Customer Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Name: $_customerName'),
                    Text('Mobile: $_customerMobile'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Products List
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Products',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${item.quantity} × ₹${item.unitPrice}',
                                  style: TextStyle(
                                    color: AppTheme.mutedForeground,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              '₹${item.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bill Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Standard Products Summary
                    if (_items.any((item) => item.product.companyType == 'Standard')) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Standard Products:'),
                          Text('₹${_getStandardSubtotal().toStringAsFixed(2)}'),
                        ],
                      ),
                      if (_getStandardDiscount() > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Discount (${_getDiscountPercentage()}%):'),
                            Text('-₹${_getStandardDiscount().toStringAsFixed(2)}'),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Standard Subtotal:'),
                            Text('₹${(_getStandardSubtotal() - _getStandardDiscount()).toStringAsFixed(2)}'),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],

                    // Other Products Summary
                    if (_items.any((item) => item.product.companyType != 'Standard')) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Other Products:'),
                          Text('₹${_getOtherSubtotal().toStringAsFixed(2)}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:'),
                        Text('₹${_bill!.subtotal.toStringAsFixed(2)}'),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '₹${_bill!.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Method
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Method',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Select Payment Method',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _paymentMethod = value ?? 'Cash';
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Confirm Payment Button
            ElevatedButton(
              onPressed: _isProcessing ? null : _confirmPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.primaryForeground,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Confirm Payment',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }
} 
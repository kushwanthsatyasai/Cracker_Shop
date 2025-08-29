import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import '../models/bill.dart';
import '../models/product.dart';
import '../services/bill_service.dart';
import '../services/product_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/logout_button.dart';

class BillDetailsScreen extends StatefulWidget {
  const BillDetailsScreen({super.key});

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen> {
  Bill? _bill;
  bool _isLoading = true;
  Map<String, Product> _products = {};

  @override
  void initState() {
    super.initState();
    // Remove _loadBillDetails() call from here
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load bill details here instead of initState
    if (_bill == null) {
      _loadBillDetails();
    }
  }

  Future<void> _loadBillDetails() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final billId = args?['billId'] as String?;
    
    if (billId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final bill = await BillService.getBillById(billId);
      
      if (bill != null) {
        // Load product details for all items to get original prices
        await _loadProductDetails(bill);
        
        setState(() {
          _bill = bill;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load bill details: $e'),
            backgroundColor: AppTheme.destructive,
          ),
        );
      }
    }
  }

  Future<void> _loadProductDetails(Bill bill) async {
    try {
      final productService = ProductService();
      final productIds = bill.items.map((item) => item.productId).whereType<String>().toSet();
      
      for (final productId in productIds) {
        try {
          final product = await productService.getProductById(productId);
          if (product != null) {
            _products[productId] = product;
          }
        } catch (e) {
          // Failed to load product, continue with others
        }
      }
    } catch (e) {
      // Failed to load product details
    }
  }

  void _handleBack() {
    // Navigate to product selection to start a fresh bill
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/products',
      (route) => false, // Remove all previous routes
    );
  }

  void _showPaymentMethodDialog() {
    if (_bill == null) return;
    
    showDialog(
      context: context,
      builder: (context) => _PaymentMethodDialog(
        bill: _bill!,
        onPaymentMethodSelected: _updatePaymentMethod,
      ),
    );
  }
  
  Future<void> _updatePaymentMethod(String paymentMethod) async {
    if (_bill == null) return;
    
    try {
      // Update the bill's payment method in the database
      await BillService.updatePaymentMethod(_bill!.id, paymentMethod);
      
      // Update the local state after successful database update
      setState(() {
        _bill = _bill!.copyWith(paymentMethod: paymentMethod);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment confirmed! Stock will be updated automatically by database.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update payment method: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }



  Future<void> _handleDownload() async {
    if (_bill == null) return;
    
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Generating PDF...'),
            ],
          ),
          backgroundColor: Colors.blue,
        ),
      );
      
      // Generate PDF bytes (works on all platforms)
      final pdfBytes = await PDFService.generateBillPDFBytes(_bill!);
      
      // Use platform-specific sharing
      await _sharePDF(
        pdfBytes,
        'bill_${_bill!.billNumber}.pdf',
        'Bill from Vani Fire Crackers - ${_bill!.billNumber}',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF downloaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleSendToCustomer() {
    if (_bill == null) return;
    
    // Show dialog with PDF WhatsApp option only
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Bill to Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${_bill!.customerName}'),
            Text('Mobile: ${_bill!.customerMobile}'),
            const SizedBox(height: 16),
            Text('Send bill directly to: ${_bill!.customerMobile}'),
            const SizedBox(height: 16),
            
            // WhatsApp Text Message Option
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _sendTextViaWhatsApp(),
                icon: const Icon(Icons.message, color: Colors.white),
                label: const Text('Send Bill as Text'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // WhatsApp PDF Option
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _sendPDFViaWhatsApp(),
                icon: const Icon(Icons.picture_as_pdf, color: Colors.green),
                label: const Text('Send Bill as PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }



  // Create formatted bill message for WhatsApp
  String _createWhatsAppBillMessage() {
    if (_bill == null) return '';
    
    final bill = _bill!;
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('🏪 *VANI FIRE CRACKERS*');
    buffer.writeln('🎆 _Your Trusted Fireworks Store_');
    buffer.writeln('Shop No: 1');
    buffer.writeln('');
    
    // Bill details
    buffer.writeln('📄 *Bill Details:*');
    buffer.writeln('• Bill No: *${bill.billNumber}*');
    buffer.writeln('• Customer: *${bill.customerName}*');
    buffer.writeln('• Mobile: ${bill.customerMobile}');
    buffer.writeln('• Date: ${_formatDate(bill.createdAt)}');
    buffer.writeln('• Payment: *${(bill.paymentMethod ?? 'cash').toUpperCase()}*');
    if (bill.billerName != null) {
      buffer.writeln('• Biller: ${bill.billerName}');
    }
    buffer.writeln('');
    
    // Items
    buffer.writeln('📋 *PURCHASED ITEMS:*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    
    for (int i = 0; i < bill.items.length; i++) {
      final item = bill.items[i];
      buffer.writeln('${i + 1}. *${item.productName}*');
      buffer.writeln('   ${item.category} | Qty: ${item.quantity}');
      buffer.writeln('   Rate: Rs.${item.unitPrice.toStringAsFixed(2)} × ${item.quantity} = *Rs.${item.totalPrice.toStringAsFixed(2)}*');
      
      if (i < bill.items.length - 1) {
        buffer.writeln('');
      }
    }
    
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    
    // Totals with detailed discount information
    buffer.writeln('Subtotal: Rs.${bill.subtotal.toStringAsFixed(2)}');
    
    if (bill.subtotal != bill.totalAmount) {
      final discountAmount = bill.subtotal - bill.totalAmount;
      final discountPercentage = ((discountAmount / bill.subtotal) * 100);
      
      buffer.writeln('');
      buffer.writeln('💸 *DISCOUNT APPLIED:*');
      buffer.writeln('• Discount Amount: Rs.${discountAmount.toStringAsFixed(2)}');
      buffer.writeln('• Discount %: ${discountPercentage.toStringAsFixed(1)}%');
      buffer.writeln('• Amount after discount: Rs.${bill.totalAmount.toStringAsFixed(2)}');
      buffer.writeln('');
    }
    
    buffer.writeln('*💰 FINAL TOTAL: Rs.${bill.totalAmount.toStringAsFixed(2)}*');
    buffer.writeln('');
    
    // Notes if any
    if (bill.notes != null && bill.notes!.isNotEmpty) {
      buffer.writeln('📝 *Notes:* ${bill.notes}');
      buffer.writeln('');
    }
    
    // Footer
    buffer.writeln('✨ Thank you for choosing Vani Fire Crackers!');
    buffer.writeln('🎆 Wishing you a safe and joyful celebration!');
    buffer.writeln('');
    buffer.writeln('For any queries, please contact us.');
    
    return buffer.toString();
  }
  
  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _sendTextViaWhatsApp() async {
    if (_bill == null) return;
    
    try {
      Navigator.pop(context); // Close dialog first
      
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Opening WhatsApp...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
      
      // Create formatted bill message
      final billMessage = _createWhatsAppBillMessage();
      
      // Send directly to customer's WhatsApp
      await _sendToCustomerWhatsApp(billMessage);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening WhatsApp for ${_bill!.customerName}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open WhatsApp: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendPDFViaWhatsApp() async {
    if (_bill == null) return;
    
    try {
      Navigator.pop(context); // Close dialog first
      
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Generating PDF...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
      
      // Generate PDF bytes
      final pdfBytes = await PDFService.generateBillPDFBytes(_bill!);
      
      // Create a short message to accompany the PDF
      final shortMessage = 'Bill from Vani Fire Crackers\nBill No: ${_bill!.billNumber}\nCustomer: ${_bill!.customerName}\nAmount: Rs.${_bill!.totalAmount.toStringAsFixed(2)}\n\nPlease find the detailed bill in the attached PDF.';
      
      if (kIsWeb) {
        // On web, we can't directly send files, so open WhatsApp Web with message
        await _sendToCustomerWhatsApp(shortMessage);
        
        // Also provide PDF download
        await _sharePDF(pdfBytes, 'bill_${_bill!.billNumber}.pdf', shortMessage);
      } else {
        // On mobile, try to share PDF with the customer's WhatsApp
        try {
          // Create a temporary file for sharing
          final pdfFile = await PDFService.generateBillPDF(_bill!);
          if (pdfFile != null) {
            await Share.shareXFiles(
              [XFile(pdfFile.path)],
              text: shortMessage,
            );
          } else {
            // Fallback to general PDF sharing
            await _sharePDF(pdfBytes, 'bill_${_bill!.billNumber}.pdf', shortMessage);
          }
        } catch (e) {
          // If file sharing fails, fall back to general sharing
          await _sharePDF(pdfBytes, 'bill_${_bill!.billNumber}.pdf', shortMessage);
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF prepared for ${_bill!.customerName}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to prepare PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Send bill directly to customer's WhatsApp
  Future<void> _sendToCustomerWhatsApp(String shareText) async {
    if (_bill == null) return;
    
    try {
      final phoneNumber = _bill!.customerMobile;
      
      // Clean phone number - remove any non-digit characters except +
      String cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // If number doesn't start with +, assume it's Indian number and add +91
      if (!cleanedNumber.startsWith('+')) {
        // Remove leading 0 if present (common in Indian numbers)
        if (cleanedNumber.startsWith('0')) {
          cleanedNumber = cleanedNumber.substring(1);
        }
        cleanedNumber = '+91$cleanedNumber';
      }
      

      
      if (kIsWeb) {
        // Web: Open WhatsApp Web with phone number and message
        final whatsappWebUrl = 'https://web.whatsapp.com/send?phone=$cleanedNumber&text=${Uri.encodeComponent(shareText)}';
        await launchUrl(
          Uri.parse(whatsappWebUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Mobile: Open WhatsApp app with phone number and message
        final whatsappUrl = 'https://wa.me/$cleanedNumber?text=${Uri.encodeComponent(shareText)}';
        
        final uri = Uri.parse(whatsappUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        } else {
          throw 'WhatsApp is not installed on this device';
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  // Platform-specific PDF sharing method (fallback)
  Future<void> _sharePDF(Uint8List pdfBytes, String filename, String shareText) async {
    // Mobile: Use share_plus as fallback
    try {
      await Share.shareXFiles(
        [XFile.fromData(
          pdfBytes,
          name: filename,
          mimeType: 'application/pdf',
        )],
        text: shareText,
      );
    } catch (e) {
      // Fallback: Try simple text sharing
      try {
        await Share.share(shareText);
      } catch (shareError) {
        throw 'Sharing not available on this device.';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_bill == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Bill Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
        ),
        body: const Center(
          child: Text('Bill not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_bill?.billNumber ?? 'Bill Details'),
        actions: const [
          LogoutButton(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Bill Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.star,
                          color: Colors.amber[600],
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Vani Fire Crackers',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Festive Crackers Store',
                      style: TextStyle(fontSize: 14),
                    ),
                    const Text(
                      'Festive Crackers Store',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Customer & Bill Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Customer & Bill Information',
                          style: TextStyle(
                            fontSize: 16,
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Customer Name:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(_bill!.customerName),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mobile:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(_bill!.customerMobile),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bill ID:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(_bill!.id),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Date & Time:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(_bill!.createdAt.toString().split('.')[0]),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Biller:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(_bill!.billerName ?? 'Unknown'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Payment:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(_bill!.paymentMethod ?? 'Cash'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Items
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Items (${_bill!.items.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._bill!.items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Theme.of(context).colorScheme.outline,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            item.category,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Show quantity and unit price
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${item.quantity} × ₹${item.unitPrice.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                              ),
                                            ),
                                            // Show original price if different from unit price
                                            if (_products[item.productId] != null) ...[
                                              Builder(
                                                builder: (context) {
                                                  final product = _products[item.productId]!;
                                                  final originalPrice = product.price;
                                                  if (originalPrice != item.unitPrice) {
                                                    return Text(
                                                      'Original: ₹${originalPrice.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.grey,
                                                        decoration: TextDecoration.lineThrough,
                                                      ),
                                                    );
                                                  }
                                                  return const SizedBox.shrink();
                                                },
                                              ),
                                            ],
                                          ],
                                        ),
                                        // Show discount info if available
                                        if (item.discountPercentage != null && item.discountPercentage! > 0)
                                          Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${item.discountPercentage}% off',
                                              style: TextStyle(
                                                color: AppTheme.primary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${item.totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          if (index < _bill!.items.length - 1)
                            const Divider(height: 24),
                        ],
                      );
                    }),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calculate,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Bill Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:'),
                        Text('₹${_bill!.subtotal.toStringAsFixed(2)}'),
                      ],
                    ),
                    // GST removed
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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            if (_bill!.notes != null && _bill!.notes!.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_bill!.notes!),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Action Buttons Row 1
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleDownload,
                    icon: const Icon(Icons.download),
                    label: const Text('Download PDF'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleSendToCustomer,
                    icon: const Icon(Icons.send),
                    label: const Text('Send to Customer'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Payment Method Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showPaymentMethodDialog,
                icon: const Icon(Icons.payment),
                label: Text('Update Payment Method (${(_bill!.paymentMethod ?? 'cash').toUpperCase()})'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleBack,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Start New Bill'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodDialog extends StatefulWidget {
  final Bill bill;
  final Function(String) onPaymentMethodSelected;

  const _PaymentMethodDialog({
    required this.bill,
    required this.onPaymentMethodSelected,
  });

  @override
  State<_PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<_PaymentMethodDialog> {
  late String selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    selectedPaymentMethod = widget.bill.paymentMethod ?? 'cash';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Payment Method'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Customer: ${widget.bill.customerName}'),
          Text('Total Amount: ₹${widget.bill.totalAmount.toStringAsFixed(2)}'),
          const SizedBox(height: 16),
          const Text('Payment Method:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          RadioListTile<String>(
            title: const Text('💵 Cash'),
            value: 'cash',
            groupValue: selectedPaymentMethod,
            onChanged: (value) {
              setState(() {
                selectedPaymentMethod = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text('💳 Online'),
            value: 'online',
            groupValue: selectedPaymentMethod,
            onChanged: (value) {
              setState(() {
                selectedPaymentMethod = value!;
              });
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
          onPressed: () async {
            await widget.onPaymentMethodSelected(selectedPaymentMethod);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm Payment'),
        ),
      ],
    );
  }
} 

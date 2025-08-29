import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bill.dart';
import '../config/supabase_config.dart';

class BillService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Create a new bill
  Future<Bill> createBill(Bill bill) async {
    try {
      // Start a transaction
      final billResponse = await _supabase
          .from('bills')
          .insert({
          'bill_number': bill.billNumber,
          'customer_name': bill.customerName,
          'customer_mobile': bill.customerMobile,
          'biller_id': bill.billerId,
          'subtotal': bill.subtotal,
          'tax_amount': bill.taxAmount,
          'total_amount': bill.totalAmount,
            'payment_method': bill.paymentMethod,
          'status': bill.status,
          'notes': bill.notes,
          })
          .select()
          .single();

      final createdBill = Bill.fromJson(billResponse);

      // Create bill items
        for (final item in bill.items) {
        await _supabase
            .from('bill_items')
            .insert({
              'bill_id': createdBill.id,
              'product_id': item.productId,
              'product_name': item.productName,
              'category': item.category,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'total_price': item.totalPrice,
            });
      }
      
      return createdBill.copyWith(items: bill.items);
    } catch (e) {
      print('Error creating bill: $e');
      rethrow;
    }
  }

  // Backward compatibility static wrappers
  static Future<List<Bill>> getBills() async {
    return BillService().getAllBills();
  }

  static Future<Bill?> getBillById(String id) async {
    return BillService().fetchBillById(id);
  }

  static Future<void> updatePaymentMethod(String billId, String paymentMethod) async {
    return BillService().updateBillPaymentMethod(billId, paymentMethod);
  }

  // Get bill by ID
  Future<Bill?> fetchBillById(String id) async {
    try {
      // Get bill details
      final billResponse = await _supabase
          .from('bills')
          .select()
          .eq('id', id)
          .single();
      
      final bill = Bill.fromJson(billResponse);
      
      // Get biller name
      String? billerName;
      if (bill.billerId.isNotEmpty) {
        final billerResponse = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', bill.billerId)
            .maybeSingle();
        
        if (billerResponse != null) {
          billerName = billerResponse['full_name'] as String?;
        }
      }
      
      // Get bill items
      final itemsResponse = await _supabase
          .from('bill_items')
          .select()
          .eq('bill_id', id);
      
      final items = itemsResponse.map((json) => BillItem.fromJson(json)).toList();
      
      return bill.copyWith(
        items: items,
        billerName: billerName,
      );
    } catch (e) {
      print('Error getting bill by ID: $e');
      return null;
    }
  }

  // Get bill by bill number
  Future<Bill?> getBillByNumber(String billNumber) async {
    try {
      // Get bill details
      final billResponse = await _supabase
          .from('bills')
          .select()
          .eq('bill_number', billNumber)
          .single();

          // Get bill items
      final itemsResponse = await _supabase
          .from('bill_items')
          .select()
          .eq('bill_id', billResponse['id']);
      
      final items = itemsResponse.map((json) => BillItem.fromJson(json)).toList();
      
      return Bill.fromJson(billResponse).copyWith(items: items);
    } catch (e) {
      print('Error getting bill by number: $e');
      return null;
    }
  }

  // Get all bills
  Future<List<Bill>> getAllBills() async {
    try {
      // Get bills first
      final billsResponse = await _supabase
          .from('bills')
          .select()
          .order('created_at', ascending: false);
      
      List<Bill> bills = [];
      
      // Get unique biller IDs
      final billerIds = billsResponse
          .map((bill) => bill['biller_id'] as String)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      // Fetch biller names
      Map<String, String> billerNames = {};
      if (billerIds.isNotEmpty) {
        final billersResponse = await _supabase
            .from('profiles')
            .select('id, full_name, role, status')
            .inFilter('id', billerIds);
        
        for (final biller in billersResponse) {
          final billerId = biller['id'] as String;
          final billerName = biller['full_name'] as String;
          billerNames[billerId] = billerName;
        }
        
        // Check for unmapped IDs and add default names
        for (final billerId in billerIds) {
          if (!billerNames.containsKey(billerId)) {
            billerNames[billerId] = 'Unknown User';
          }
        }
      }
      
      // Process each bill
      for (final json in billsResponse) {
        final bill = Bill.fromJson(json);
        
        // Get biller name
        final billerName = billerNames[bill.billerId] ?? 'Unknown Biller';
        
        // Get items for this bill
        final itemsResponse = await _supabase
            .from('bill_items')
            .select()
            .eq('bill_id', bill.id);
        
        final items = itemsResponse.map((json) => BillItem.fromJson(json)).toList();
        
        // Add bill with biller name and items
        bills.add(bill.copyWith(
          items: items,
          billerName: billerName,
        ));
      }
      
      return bills;
    } catch (e) {
      rethrow;
    }
  }

  // Get bills by biller ID
  Future<List<Bill>> getBillsByBiller(String billerId) async {
    try {
      final response = await _supabase
          .from('bills')
          .select()
          .eq('biller_id', billerId)
          .order('created_at', ascending: false);
      
      final bills = response.map((json) => Bill.fromJson(json)).toList();
      
      // Get items for each bill
      for (final bill in bills) {
        final itemsResponse = await _supabase
            .from('bill_items')
            .select()
            .eq('bill_id', bill.id);
        
        final items = itemsResponse.map((json) => BillItem.fromJson(json)).toList();
        bills[bills.indexOf(bill)] = bill.copyWith(items: items);
      }
      
      return bills;
    } catch (e) {
      rethrow;
    }
  }

  // Update bill payment method
  Future<void> updateBillPaymentMethod(String billId, String paymentMethod) async {
    try {
      await _supabase
          .from('bills')
          .update({'payment_method': paymentMethod})
          .eq('id', billId)
          .select();
    } catch (e) {
      rethrow;
    }
  }

  // Update bill status
  Future<void> updateBillStatus(String billId, String status) async {
    try {
      await _supabase
          .from('bills')
          .update({'status': status})
          .eq('id', billId);
    } catch (e) {
      rethrow;
    }
  }

  // Cancel bill
  Future<void> cancelBill(String billId) async {
    try {
      await _supabase
          .from('bills')
          .update({'status': 'cancelled'})
          .eq('id', billId);
    } catch (e) {
      print('Error cancelling bill: $e');
      rethrow;
    }
  }

  // Get bills by date range
  Future<List<Bill>> getBillsByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final response = await _supabase
          .from('bills')
          .select()
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: false);
      
      final bills = response.map((json) => Bill.fromJson(json)).toList();
      
      // Get items for each bill
      for (final bill in bills) {
        final itemsResponse = await _supabase
            .from('bill_items')
            .select()
            .eq('bill_id', bill.id);
        
        final items = itemsResponse.map((json) => BillItem.fromJson(json)).toList();
        bills[bills.indexOf(bill)] = bill.copyWith(items: items);
      }
      
      return bills;
    } catch (e) {
      print('Error getting bills by date range: $e');
      rethrow;
    }
  }

  // Generate unique bill number
  Future<String> generateBillNumber() async {
    try {
      final today = DateTime.now();
      final datePrefix = '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
      
      // Get the last bill number for today
      final response = await _supabase
          .from('bills')
          .select('bill_number')
          .like('bill_number', '$datePrefix%')
          .order('bill_number', ascending: false)
          .limit(1);
      
      if (response.isEmpty) {
        return '${datePrefix}001';
      }
      
      final lastBillNumber = response.first['bill_number'] as String;
      final lastSequence = int.parse(lastBillNumber.substring(8));
      final newSequence = lastSequence + 1;
      
      return '${datePrefix}${newSequence.toString().padLeft(3, '0')}';
    } catch (e) {
      print('Error generating bill number: $e');
      // Fallback to timestamp-based number
      return '${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // Get bill statistics
  Future<Map<String, dynamic>> getBillStatistics(DateTime startDate, DateTime endDate) async {
    try {
      final response = await _supabase
          .from('bills')
          .select('total_amount, status, created_at')
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String());
      
      double totalRevenue = 0;
      int totalBills = 0;
      int completedBills = 0;
      int cancelledBills = 0;
      
      for (final bill in response) {
        totalBills++;
        if (bill['status'] == 'completed') {
          totalRevenue += (bill['total_amount'] as num).toDouble();
          completedBills++;
        } else if (bill['status'] == 'cancelled') {
          cancelledBills++;
        }
      }
      
      return {
        'totalRevenue': totalRevenue,
        'totalBills': totalBills,
        'completedBills': completedBills,
        'cancelledBills': cancelledBills,
        'averageBillValue': totalBills > 0 ? totalRevenue / totalBills : 0,
      };
    } catch (e) {
      print('Error getting bill statistics: $e');
      rethrow;
    }
  }
} 
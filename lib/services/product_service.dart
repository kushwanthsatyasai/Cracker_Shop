import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../config/supabase_config.dart';

class ProductService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  
  // Admin client for operations that require elevated privileges
  SupabaseClient? _adminClient;
  
  SupabaseClient get adminClient {
    if (_adminClient == null) {
      try {
        _adminClient = SupabaseClient(
          SupabaseConfig.url,
          SupabaseConfig.serviceRoleKey,
        );
      } catch (e) {
        _adminClient = _supabase;
      }
    }
    return _adminClient!;
  }
  
  // Test method to check if we can update products
  Future<void> testProductUpdate(String productId) async {
    try {
      print('🧪 Testing product update permissions for: $productId');
      
      // First try to read the product
      final readResult = await _supabase
          .from('products')
          .select('id, name, stock_quantity, is_active')
          .eq('id', productId)
          .single();
      
      print('📖 Read test successful: ${readResult['name']} - Stock: ${readResult['stock_quantity']}');
      
      // Try a dummy update (set stock to current value)
      final currentStock = readResult['stock_quantity'];
      final updateResult = await _supabase
          .from('products')
          .update({'stock_quantity': currentStock})
          .eq('id', productId)
          .select();
      
      print('✅ Update test successful: $updateResult');
      
    } catch (e) {
      print('❌ Product update test failed: $e');
      if (e.toString().contains('row-level security')) {
        print('🔒 RLS Issue: Current user cannot update products table');
      }
      rethrow;
    }
  }

  // Get all products
  Future<List<Product>> getAllProducts() async {
    try {
      final response = await _supabase
          .from('products')
          .select('*, company_type')  // Explicitly select company_type
          .eq('is_active', true)
          .order('name');
      
      return response.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Backward compatibility static wrappers
  static Future<List<Product>> getProducts() async {
    return ProductService().getAllProducts();
  }

  // Get products by category
  Future<List<Product>> getProductsByCategory(String category) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('category', category)
          .eq('is_active', true)
          .order('name');
      
      return response.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      print('Error getting products by category: $e');
      rethrow;
    }
  }

  // Get product by ID
  Future<Product?> getProductById(String id) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('id', id)
          .single();
      
      return Product.fromJson(response);
    } catch (e) {
      print('Error getting product by ID: $e');
      return null;
    }
  }

  // Create new product
  Future<Product> createProduct(Product product) async {
    try {
      final response = await _supabase
          .from('products')
          .insert(product.toJson())
          .select()
          .single();
      
      return Product.fromJson(response);
    } catch (e) {
      print('Error creating product: $e');
      rethrow;
    }
  }

  // Update product
  Future<Product> updateProduct(Product product) async {
    try {
      final response = await _supabase
          .from('products')
          .update(product.toJson())
          .eq('id', product.id)
          .select()
          .single();
      
      return Product.fromJson(response);
    } catch (e) {
      print('Error updating product: $e');
      rethrow;
    }
  }

  // Delete product (soft delete by setting is_active to false)
  Future<void> deleteProduct(String id) async {
    try {
      await _supabase
          .from('products')
          .update({'is_active': false})
          .eq('id', id);
    } catch (e) {
      print('Error deleting product: $e');
      rethrow;
    }
  }

  // Update stock quantity (admin operation)
  Future<void> updateStockQuantity(String productId, int newQuantity, String reason) async {
    try {
      // Update product stock using admin client
      await adminClient
          .from('products')
          .update({'stock_quantity': newQuantity})
          .eq('id', productId);
      
      // Create stock movement record using admin client
      await adminClient
          .from('stock_movements')
          .insert({
            'product_id': productId,
            'movement_type': 'adjustment',
            'quantity': newQuantity,
            'notes': reason,
          });
    } catch (e) {
      print('Error updating stock quantity: $e');
      rethrow;
    }
  }

  // Add stock (in movement) - admin operation
  Future<void> addStock(String productId, int quantity, String notes) async {
    try {
      // Get current stock
      final product = await getProductById(productId);
      if (product == null) throw Exception('Product not found');
      
      final newQuantity = product.stockQuantity + quantity;
      
      // Update product stock using admin client
      await adminClient
          .from('products')
          .update({'stock_quantity': newQuantity})
          .eq('id', productId);
      
      // Create stock movement record using admin client
      await adminClient
          .from('stock_movements')
          .insert({
            'product_id': productId,
            'movement_type': 'in',
            'quantity': quantity,
            'notes': notes,
          });
    } catch (e) {
      print('Error adding stock: $e');
      rethrow;
    }
  }

  // Remove stock (out movement)
  Future<void> removeStock(String productId, int quantity, String referenceType, String referenceId, String notes) async {
    try {
      print('🔄 removeStock called: productId=$productId, quantity=$quantity');
      
      // Test permissions first
      await testProductUpdate(productId);
      
      // Get current stock
      final product = await getProductById(productId);
      if (product == null) {
        print('❌ Product not found: $productId');
        throw Exception('Product not found');
      }
      
      print('📦 Current stock for ${product.name}: ${product.stockQuantity}');
      
      if (product.stockQuantity < quantity) {
        print('❌ Insufficient stock: required=$quantity, available=${product.stockQuantity}');
        throw Exception('Insufficient stock: required $quantity, available ${product.stockQuantity}');
      }
      
      final newQuantity = product.stockQuantity - quantity;
      print('📉 Updating stock: ${product.stockQuantity} -> $newQuantity');
      
      // Get current user info for debugging
      final currentUser = _supabase.auth.currentUser;
      print('👤 Current user: ${currentUser?.id} (${currentUser?.email})');
      
      // Update product stock with explicit column specification using admin client
      print('🔄 Executing update query with admin privileges...');
      final updateResult = await adminClient
          .from('products')
          .update({
            'stock_quantity': newQuantity,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', productId)
          .select('id, name, stock_quantity, updated_at');
      
      print('✅ Product stock update result: $updateResult');
      
      if (updateResult.isEmpty) {
        print('⚠️ Update returned empty result - checking if product exists...');
        final existsCheck = await _supabase
            .from('products')
            .select('id, name, stock_quantity')
            .eq('id', productId)
            .maybeSingle();
        
        if (existsCheck == null) {
          throw Exception('Product does not exist: $productId');
        } else {
          print('🔍 Product exists but update failed. Current state: $existsCheck');
          throw Exception('Stock update failed - no rows affected');
        }
      }
      
      // Verify the update worked by fetching the updated product
      final verifyResult = await _supabase
          .from('products')
          .select('id, name, stock_quantity, updated_at')
          .eq('id', productId)
          .single();
      
      print('🔍 Verification - Product after update:');
      print('   Name: ${verifyResult['name']}');
      print('   Stock: ${verifyResult['stock_quantity']}');
      print('   Updated: ${verifyResult['updated_at']}');
      
      // Confirm the stock actually changed
      if (verifyResult['stock_quantity'] != newQuantity) {
        throw Exception('Stock verification failed: expected $newQuantity, got ${verifyResult['stock_quantity']}');
      }
      
      // Create stock movement record using admin client
      print('🔄 Creating stock movement record...');
      final movementResult = await adminClient
          .from('stock_movements')
          .insert({
            'product_id': productId,
            'movement_type': 'out',
            'quantity': quantity,
            'reference_type': referenceType,
            'reference_id': referenceId,
            'notes': notes,
          })
          .select();
      
      print('✅ Stock movement record created: $movementResult');
      print('🎯 Stock update completed successfully for ${product.name}');
      print('   Previous stock: ${product.stockQuantity}');
      print('   New stock: ${verifyResult['stock_quantity']}');
      print('   Quantity sold: $quantity');
      
    } catch (e) {
      print('❌ Error removing stock: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Get stock movements for a product
  Future<List<StockMovement>> getStockMovements(String productId) async {
    try {
      final response = await _supabase
          .from('stock_movements')
          .select()
          .eq('product_id', productId)
          .order('created_at', ascending: false);
      
      return response.map((json) => StockMovement.fromJson(json)).toList();
    } catch (e) {
      print('Error getting stock movements: $e');
      rethrow;
    }
  }

  // Search products by name
  Future<List<Product>> searchProducts(String query) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .ilike('name', '%$query%')
          .eq('is_active', true)
          .order('name');
      
      return response.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      print('Error searching products: $e');
      rethrow;
    }
  }

  // Create a stock movement record without updating product stock
  Future<void> createStockMovement(
    String productId,
    String movementType,
    int quantity,
    String referenceType,
    String referenceId,
    String notes,
  ) async {
    try {
      // Try admin client first, fallback to regular client
      SupabaseClient clientToUse = adminClient;
      
      try {
        await clientToUse
            .from('stock_movements')
            .insert({
              'product_id': productId,
              'movement_type': movementType,
              'quantity': quantity,
              'reference_type': referenceType,
              'reference_id': referenceId,
              'notes': notes,
            });
      } catch (adminError) {
        // Fallback to regular client
        await _supabase
            .from('stock_movements')
            .insert({
              'product_id': productId,
              'movement_type': movementType,
              'quantity': quantity,
              'reference_type': referenceType,
              'reference_id': referenceId,
              'notes': notes,
            });
      }
      
    } catch (e) {
      rethrow;
    }
  }

  // Process stock updates for a completed bill
  Future<void> processStockUpdatesForCompletedBill(String billId) async {
    try {
      print('🔄 Processing stock updates for completed bill: $billId');
      
      // Get all stock movements for this bill
      final stockMovements = await adminClient
          .from('stock_movements')
          .select('id, product_id, quantity, movement_type, notes')
          .eq('reference_type', 'bill')
          .eq('reference_id', billId);
      
      print('📝 Found ${stockMovements.length} stock movements for bill $billId');
      
      if (stockMovements.isEmpty) {
        print('⚠️ No stock movements found for bill $billId');
        return;
      }
      
      final List<String> successfulUpdates = [];
      final List<String> failedUpdates = [];
      
      // Process each stock movement
      for (final movement in stockMovements) {
        try {
          final productId = movement['product_id'] as String;
          final quantity = movement['quantity'] as int;
          final movementType = movement['movement_type'] as String;
          
          // Get current product stock
          final product = await getProductById(productId);
          if (product == null) {
            failedUpdates.add('Product not found: $productId');
            continue;
          }
          
          if (movementType == 'out') {
            // Reduce stock for 'out' movements (sales)
            if (product.stockQuantity < quantity) {
              print('⚠️ Insufficient stock for ${product.name}: required=$quantity, available=${product.stockQuantity}');
              failedUpdates.add('${product.name}: Insufficient stock');
              continue;
            }
            
            final newQuantity = product.stockQuantity - quantity;
            
            print('📦 Updating stock for ${product.name}: ${product.stockQuantity} -> $newQuantity');
            
            // Update product stock using admin client
            await adminClient
                .from('products')
                .update({
                  'stock_quantity': newQuantity,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', productId);
            
            successfulUpdates.add('${product.name} (-$quantity)');
            print('✅ Stock reduced for ${product.name}: $quantity units');
            
          } else if (movementType == 'in') {
            // Increase stock for 'in' movements (returns, adjustments)
            final newQuantity = product.stockQuantity + quantity;
            
            print('📦 Updating stock for ${product.name}: ${product.stockQuantity} -> $newQuantity');
            
            // Update product stock using admin client
            await adminClient
                .from('products')
                .update({
                  'stock_quantity': newQuantity,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', productId);
            
            successfulUpdates.add('${product.name} (+$quantity)');
            print('✅ Stock increased for ${product.name}: $quantity units');
          }
          
        } catch (itemError) {
          failedUpdates.add('Movement ${movement['id']}: $itemError');
          print('❌ Failed to process movement: $itemError');
        }
      }
      
      // Log summary
      print('🎯 Stock update summary for bill $billId:');
      print('   ✅ Successful: ${successfulUpdates.length}');
      print('   ❌ Failed: ${failedUpdates.length}');
      
      if (successfulUpdates.isNotEmpty) {
        print('   Success details: ${successfulUpdates.join(', ')}');
      }
      
      if (failedUpdates.isNotEmpty) {
        print('   Failed details: ${failedUpdates.join(', ')}');
        throw Exception('Some stock updates failed: ${failedUpdates.join(', ')}');
      }
      
    } catch (e) {
      print('❌ Error processing stock updates for bill $billId: $e');
      rethrow;
    }
  }
  
  // Clear cached data
  void clearCache() {
    _adminClient = null;
  }
} 
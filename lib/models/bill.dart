import 'package:uuid/uuid.dart';
import 'product.dart';

class Bill {
  final String id;
  final String billNumber;
  final String customerName;
  final String customerMobile;
  final String billerId;
  // Backward-compatibility: some screens read billerName directly
  final String? billerName;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final String paymentMethod;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final List<BillItem> items;

  Bill({
    String? id,
    required this.billNumber,
    required this.customerName,
    required this.customerMobile,
    required this.billerId,
    this.billerName,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    this.paymentMethod = 'cash',
    this.status = 'completed',
    this.notes,
    DateTime? createdAt,
    List<BillItem>? items,
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now(),
    items = items ?? [];

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'] ?? '',
      billNumber: json['bill_number'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerMobile: json['customer_mobile'] ?? '',
      billerId: json['biller_id'] ?? '',
      billerName: json['biller_name'],
      subtotal: (json['subtotal'] ?? 0.0).toDouble(),
      taxAmount: (json['tax_amount'] ?? 0.0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
      paymentMethod: json['payment_method'] ?? 'cash',
      status: json['status'] ?? 'completed',
      notes: json['notes'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      items: json['items'] != null 
          ? List<BillItem>.from(json['items'].map((x) => BillItem.fromJson(x)))
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bill_number': billNumber,
      'customer_name': customerName,
      'customer_mobile': customerMobile,
      'biller_id': billerId,
      // biller_name is not stored in DB; omit or include if present
      if (billerName != null) 'biller_name': billerName,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'items': items.map((x) => x.toJson()).toList(),
    };
  }

  Bill copyWith({
    String? id,
    String? billNumber,
    String? customerName,
    String? customerMobile,
    String? billerId,
    String? billerName,
    double? subtotal,
    double? taxAmount,
    double? totalAmount,
    String? paymentMethod,
    String? status,
    String? notes,
    DateTime? createdAt,
    List<BillItem>? items,
  }) {
    return Bill(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      customerName: customerName ?? this.customerName,
      customerMobile: customerMobile ?? this.customerMobile,
      billerId: billerId ?? this.billerId,
      billerName: billerName ?? this.billerName,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }

  @override
  String toString() {
    return 'Bill(id: $id, billNumber: $billNumber, customerName: $customerName, totalAmount: $totalAmount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Bill && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Backward-compatibility: some screens use bill.total
  double get total => totalAmount;
}

class BillItem {
  final String id;
  final String? billId;
  final String? productId;
  final String productName;
  final String category;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final DateTime createdAt;
  // Backward-compatibility field for UI convenience
  final Product product;
  final double? discountPercentage;

  BillItem({
    String? id,
    this.billId,
    this.productId,
    required this.productName,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    DateTime? createdAt,
    Product? product,
    this.discountPercentage,
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now(),
    product = product ?? Product(
      id: productId ?? const Uuid().v4(),
      name: productName,
      category: category,
      price: unitPrice,
      stockQuantity: 0,
      discountLimit: 0,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      companyType: 'Standard', // Default companyType like add_product_screen.dart
    );

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      id: json['id'] ?? '',
      billId: json['bill_id'],
      productId: json['product_id'],
      productName: json['product_name'] ?? '',
      category: json['category'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPrice: (json['unit_price'] ?? 0.0).toDouble(),
      totalPrice: (json['total_price'] ?? 0.0).toDouble(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      // UI-only fields are not populated from DB JSON
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bill_id': billId,
      'product_id': productId,
      'product_name': productName,
      'category': category,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'created_at': createdAt.toIso8601String(),
      // UI-only fields are intentionally not serialized
    };
  }

  BillItem copyWith({
    String? id,
    String? billId,
    String? productId,
    String? productName,
    String? category,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    DateTime? createdAt,
    Product? product,
    double? discountPercentage,
  }) {
    return BillItem(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      createdAt: createdAt ?? this.createdAt,
      product: product ?? this.product,
      discountPercentage: discountPercentage ?? this.discountPercentage,
    );
  }

  @override
  String toString() {
    return 'BillItem(id: $id, productName: $productName, quantity: $quantity, totalPrice: $totalPrice)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BillItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 
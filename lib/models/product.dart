class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final int stockQuantity;
  final double discountLimit;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? companyType;
  final double? sellingPrice;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stockQuantity,
    this.discountLimit = 0.0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.companyType,
    this.sellingPrice,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawCompanyType = json['company_type'];
    final resolvedCompanyType = rawCompanyType?.toString() ?? 'Standard';
    
    // Debug logging to see what's coming from database
    print('🔍 Product.fromJson: ${json['name']}');
    print('   Raw company_type from DB: "$rawCompanyType" (${rawCompanyType.runtimeType})');
    print('   Resolved companyType: "$resolvedCompanyType"');
    
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      stockQuantity: json['stock_quantity'] ?? 0,
      discountLimit: (json['discount_limit'] ?? 0.0).toDouble(),
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : DateTime.now(),
      companyType: resolvedCompanyType,
      sellingPrice: json['selling_price'] != null 
          ? (json['selling_price'] as num).toDouble() 
          : null,
    );
  }

  // Convenience getters for backward compatibility
  double get mrp => price;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'stock_quantity': stockQuantity,
      'discount_limit': discountLimit,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'company_type': companyType,
      'selling_price': sellingPrice,
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? category,
    double? price,
    int? stockQuantity,
    double? discountLimit,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? companyType,
    double? sellingPrice,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      discountLimit: discountLimit ?? this.discountLimit,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      companyType: companyType ?? this.companyType,
      sellingPrice: sellingPrice ?? this.sellingPrice,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, category: $category, price: $price, stockQuantity: $stockQuantity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 
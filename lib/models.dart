/// Product from the shared catalog (products table in Supabase).
class Product {
  final String id;
  final String categoryId;
  final String categoryName;
  final String name;
  final String brand;
  final String? supplier;
  final double price;
  final double lastPrice;
  final double cheapestSupplierPrice;
  final int stock;
  final double rating;
  final int reviews;
  final String? imageUrl;
  final int leadTime;
  final String? abcClass; // ABC Classification (A, B, C)
  final String satuan;

  // Compatibility getters for the existing UI code
  double get supplierPrice => cheapestSupplierPrice;
  String? get supplierName => supplier ?? 'Pemasok Umum';
  double get supplierRating => rating;
  String? get grade => 'A';

  const Product({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.brand,
    this.supplier,
    required this.price,
    required this.lastPrice,
    required this.cheapestSupplierPrice,
    required this.stock,
    required this.rating,
    this.reviews = 0,
    this.imageUrl,
    this.leadTime = 0,
    this.abcClass,
    this.satuan = 'pcs',
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    String catName = '';
    final catObj = json['category'] ?? json['categories'];
    if (catObj is String) {
      catName = catObj;
    } else if (catObj is Map) {
      catName = (catObj['name'] ?? catObj['nama'] ?? '').toString();
    } else if (catObj is List && catObj.isNotEmpty) {
      final first = catObj.first;
      if (first is Map) {
        catName = (first['name'] ?? first['nama'] ?? '').toString();
      }
    }

    return Product(
      id: json['id']?.toString() ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      categoryName: catName,
      name: (json['name'] ?? '') as String,
      brand: json['brand']?.toString() ?? '',
      supplier: json['supplier']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      lastPrice: (json['last_price'] as num?)?.toDouble() ?? 0.0,
      cheapestSupplierPrice: (json['cheapest_supplier_price'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      rating: 0.0,
      reviews: 0,
      imageUrl: json['image_url'] as String?,
      leadTime: 0,
      abcClass: null,
      satuan: json['unit']?.toString() ?? json['satuan']?.toString() ?? 'pcs',
    );
  }

  Product copyWith({
    String? id,
    String? categoryId,
    String? categoryName,
    String? name,
    String? brand,
    String? supplier,
    double? price,
    double? lastPrice,
    double? cheapestSupplierPrice,
    int? stock,
    double? rating,
    int? reviews,
    String? imageUrl,
    int? leadTime,
    String? abcClass,
    String? satuan,
  }) {
    return Product(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      supplier: supplier ?? this.supplier,
      price: price ?? this.price,
      lastPrice: lastPrice ?? this.lastPrice,
      cheapestSupplierPrice: cheapestSupplierPrice ?? this.cheapestSupplierPrice,
      stock: stock ?? this.stock,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
      imageUrl: imageUrl ?? this.imageUrl,
      leadTime: leadTime ?? this.leadTime,
      abcClass: abcClass ?? this.abcClass,
      satuan: satuan ?? this.satuan,
    );
  }
}

/// User's own inventory item (mapped from products for low stock warnings).
class InventoryItem {
  final String id;
  final String name;
  final int qtyAvailable;
  final double capitalPrice;
  final double sellingPrice;
  final String? imageUrl;
  final DateTime? expDate;
  final DateTime? updatedAt;
  final int leadTime;
  final String satuan;

  const InventoryItem({
    required this.id,
    required this.name,
    this.qtyAvailable = 0,
    this.capitalPrice = 0,
    this.sellingPrice = 0,
    this.imageUrl,
    this.expDate,
    this.updatedAt,
    this.leadTime = 0,
    this.satuan = 'pcs',
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? '') as String,
      qtyAvailable: (json['qty_available'] as num?)?.toInt() ?? 0,
      capitalPrice: (json['capital_price'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url'] as String? ?? json['image'] as String?,
      expDate: json['exp_date'] != null ? DateTime.tryParse(json['exp_date'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      leadTime: (json['lead_time'] as num?)?.toInt() ?? 0,
      satuan: json['satuan']?.toString() ?? 'pcs',
    );
  }
}

/// Product category (mapped from unique values or fallback table).
class Category {
  final String id;
  final String name;

  const Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? json['name']?.toString() ?? '',
      name: (json['name'] ?? '') as String,
    );
  }
}

/// User profile from the profiles table in Supabase.
class UserProfile {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? phoneNumber;
  final String? storeName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.phoneNumber,
    this.storeName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] ?? '') as String,
      fullName: (json['full_name'] ?? '') as String,
      avatarUrl: json['avatar_url'] as String?,
      phoneNumber: json['phone_number'] as String?,
      storeName: json['store_name'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'avatar_url': avatarUrl,
    'phone_number': phoneNumber,
    'store_name': storeName,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// Notification model for notifications table
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String? body;
  final String? type;
  final String? relatedInventoryId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    this.type,
    this.relatedInventoryId,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title'] ?? '',
      body: json['body'],
      type: json['type'],
      relatedInventoryId: json['related_inventory_id']?.toString(),
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

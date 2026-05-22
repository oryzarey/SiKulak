/// Product from the shared catalog (products table in Supabase).
class Product {
  final String id; // Represents the bigint ID as a string for compatibility
  final String category;
  final String name;
  final String brand;
  final String? supplier;
  final double price;
  final int stock;
  final double rating;
  final int reviews;

  // Compatibility getters for the existing UI code
  String? get categoryId => category;
  String? get categoryName => category;
  double get supplierPrice => price;
  String? get supplierName => supplier ?? 'Pemasok Umum';
  double get supplierRating => rating;
  String? get grade => 'A';
  String? get imageUrl => null;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    this.supplier,
    required this.price,
    required this.stock,
    required this.rating,
    this.reviews = 0,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? '') as String,
      category: (json['category'] ?? '') as String,
      brand: (json['brand'] ?? '') as String,
      supplier: json['supplier'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: (json['reviews'] as num?)?.toInt() ?? 0,
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

  const InventoryItem({
    required this.id,
    required this.name,
    this.qtyAvailable = 0,
    this.capitalPrice = 0,
    this.sellingPrice = 0,
    this.imageUrl,
    this.expDate,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    final price = (json['price'] as num?)?.toDouble() ?? 0.0;
    return InventoryItem(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? '') as String,
      qtyAvailable: (json['stock'] as num?)?.toInt() ?? 0,
      capitalPrice: price * 0.90, // Assume capital cost is 90% of price
      sellingPrice: price,
      imageUrl: json['image_url'] as String?,
      expDate: null,
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

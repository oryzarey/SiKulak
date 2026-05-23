/// Product from the shared catalog (products table in Supabase).
class Product {
  final String id; // Represents the ID as a string for compatibility
  final String categoryId; // The category_id UUID
  final String categoryName; // The category name
  final String name;
  final String brand;
  final String? supplier;
  final double price;
  final int stock;
  final double rating;
  final int reviews;
  final String? imageUrl;

  // Compatibility getters for the existing UI code
  double get supplierPrice => price;
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
    required this.stock,
    required this.rating,
    this.reviews = 0,
    this.imageUrl,
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
      brand: (json['brand'] ?? '') as String,
      supplier: json['supplier'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: (json['reviews'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url'] as String?,
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
    return InventoryItem(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? '') as String,
      qtyAvailable: (json['qty_available'] as num?)?.toInt() ?? 0,
      capitalPrice: (json['capital_price'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url'] as String?,
      expDate: json['exp_date'] != null ? DateTime.tryParse(json['exp_date'].toString()) : null,
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

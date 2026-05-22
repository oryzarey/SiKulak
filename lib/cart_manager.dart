import 'dart:collection';

/// A single item in the cart (stores metadata so price calculation is self-contained).
class CartEntry {
  final String productName;
  final double price;
  final String? imageUrl;
  int quantity;

  CartEntry({
    required this.productName,
    required this.price,
    this.imageUrl,
    this.quantity = 1,
  });
}

/// Lightweight singleton that holds cart state shared across pages.
/// Works with the existing `setState` architecture — call `setState` in your
/// widget after mutating the cart so the UI rebuilds.
class CartManager {
  // ── Singleton ──────────────────────────────────────────────
  static final CartManager _instance = CartManager._internal();
  factory CartManager() => _instance;
  CartManager._internal();

  // ── State ──────────────────────────────────────────────────
  final Map<String, CartEntry> _items = {}; // productId (UUID) → entry

  /// Unmodifiable view of the cart contents.
  UnmodifiableMapView<String, CartEntry> get items =>
      UnmodifiableMapView(_items);

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  /// Total number of individual items in the cart.
  int get totalItems =>
      _items.values.fold(0, (sum, entry) => sum + entry.quantity);

  /// Quantity of a specific product.
  int quantityOf(String productId) => _items[productId]?.quantity ?? 0;

  /// Total price across all items.
  double get totalPrice => _items.values
      .fold<double>(0, (sum, e) => sum + (e.price * e.quantity));

  /// Formatted total price as Rupiah string.
  String get formattedTotalPrice => formatPrice(totalPrice);

  // ── Mutations ──────────────────────────────────────────────
  void add(String productId,
      {required String name, required double price, String? imageUrl}) {
    if (_items.containsKey(productId)) {
      _items[productId]!.quantity++;
    } else {
      _items[productId] = CartEntry(
        productName: name,
        price: price,
        imageUrl: imageUrl,
        quantity: 1,
      );
    }
  }

  void remove(String productId) {
    final entry = _items[productId];
    if (entry == null) return;
    if (entry.quantity > 1) {
      entry.quantity--;
    } else {
      _items.remove(productId);
    }
  }

  void clear() => _items.clear();

  // ── Helpers ────────────────────────────────────────────────
  /// Format any number as Indonesian Rupiah, e.g. "Rp. 120.000"
  static String formatPrice(num amount) {
    final intAmount = amount.toInt();
    final str = intAmount.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return 'Rp. ${buffer.toString().split('').reversed.join()}';
  }
}

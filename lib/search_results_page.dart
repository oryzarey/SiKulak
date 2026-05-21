import 'package:flutter/material.dart';
import 'models.dart';

class SearchResultsPage extends StatefulWidget {
  final String searchQuery;
  final List<Product> products;

  const SearchResultsPage({
    super.key,
    required this.searchQuery,
    required this.products,
  });

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  late TextEditingController _searchController;
  final Map<int, int> _cartItems = {};
  final Set<int> _wishlistItems = {};
  String? _selectedBrand;
  String? _selectedSupplier;
  String? _selectedRating;
  String? _selectedPrice;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filteredProducts {
    return widget.products.where((product) {
      final matchesSearch = product.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          product.brand.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          product.category.toLowerCase().contains(_searchController.text.toLowerCase());

      final matchesBrand = _selectedBrand == null || product.brand == _selectedBrand;
      final matchesSupplier = _selectedSupplier == null || product.supplier == _selectedSupplier;

      return matchesSearch && matchesBrand && matchesSupplier;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Blue Gradient Header ────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button + Title
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Hasil Pencarian',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search field
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {},
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Cari produk...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Filter Chips Row ────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Filter',
                      icon: Icons.tune,
                      onTap: () {},
                      isSelected: false,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Rating',
                      isSelected: _selectedRating != null,
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Harga',
                      isSelected: _selectedPrice != null,
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Toko',
                      isSelected: _selectedSupplier != null,
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Brand',
                      isSelected: _selectedBrand != null,
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Jumlah',
                      isSelected: false,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Product Grid ────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = _filteredProducts[index];
                  return _ProductCard(
                    product: product,
                    isWishlisted: _wishlistItems.contains(product.id),
                    quantity: _cartItems[product.id] ?? 0,
                    onWishlistTap: () {
                      setState(() {
                        if (_wishlistItems.contains(product.id)) {
                          _wishlistItems.remove(product.id);
                        } else {
                          _wishlistItems.add(product.id);
                        }
                      });
                    },
                    onAddToCart: () {
                      setState(() {
                        _cartItems[product.id] = (_cartItems[product.id] ?? 0) + 1;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Ditambahkan ke keranjang',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                          elevation: 0,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          margin: const EdgeInsets.only(bottom: 120, left: 80, right: 80),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    onRemoveFromCart: () {
                      setState(() {
                        if ((_cartItems[product.id] ?? 0) > 1) {
                          _cartItems[product.id] = _cartItems[product.id]! - 1;
                        } else {
                          _cartItems.remove(product.id);
                        }
                      });
                    },
                  );
                },
                childCount: _filteredProducts.length,
              ),
            ),
          ),

          // ── Bottom Cart Section ────────────────────────
          if (_cartItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[400]!, Colors.blue[600]!],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue,
                          ),
                          child: const Text('Lihat Belanjaan mu'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _cartItems.values.fold(0, (sum, qty) => sum + qty).toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Rp. ${(_cartItems.entries.fold<int>(0, (sum, entry) => sum + (entry.key * entry.value)) ~/ 1000000).toStringAsFixed(1)}jt',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          SliverToBoxAdapter(child: const SizedBox(height: 20)),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool isWishlisted;
  final int quantity;
  final VoidCallback onWishlistTap;
  final VoidCallback onAddToCart;
  final VoidCallback onRemoveFromCart;

  const _ProductCard({
    required this.product,
    required this.isWishlisted,
    required this.quantity,
    required this.onWishlistTap,
    required this.onAddToCart,
    required this.onRemoveFromCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  ),
                  child: Center(child: Icon(Icons.image, size: 50, color: Colors.grey[300])),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: onWishlistTap,
                    child: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 16),
                    Text(' ${product.rating}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    'Rp ${product.price}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                if (quantity == 0)
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: onAddToCart,
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: const Text('Tambah'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: onRemoveFromCart,
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.blue, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        Text(quantity.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        IconButton(
                          onPressed: onAddToCart,
                          icon: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isSelected;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: isSelected ? Colors.white : Colors.grey[600], size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

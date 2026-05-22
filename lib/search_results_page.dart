import 'dart:async';
import 'package:flutter/material.dart';
import 'main.dart';
import 'models.dart';
import 'cart_manager.dart';

class SearchResultsPage extends StatefulWidget {
  final String? initialQuery;

  const SearchResultsPage({super.key, this.initialQuery});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  late TextEditingController _searchController;
  final CartManager _cart = CartManager();
  Set<String> _wishlistItems = {};

  List<Product> _products = [];
  bool _isLoading = false;
  bool _initialLoad = true;
  Timer? _debounce;

  // Filters (UI-ready, expandable later)
  String? _selectedFilter;

  final List<String> _filterLabels = [
    'Filter',
    'Rating',
    'Harga',
    'Toko',
    'Brand',
    'Jumlah',
  ];

  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _fetchFavorites();
    _fetchCategories();
    _fetchAllProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Data fetching ──────────────────────────────────────────
  Future<void> _fetchAllProducts() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('products')
          .select('*, categories(id, name), supplier_products(*, suppliers(*))')
          .order('name');

      if (!mounted) return;
      setState(() {
        _products =
            (data as List).map((json) => Product.fromJson(json)).toList();
        _isLoading = false;
        _initialLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _initialLoad = false;
      });
    }
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      _fetchAllProducts();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('products')
          .select('*, categories(id, name), supplier_products(*, suppliers(*))')
          .ilike('name', '%${query.trim()}%')
          .order('name');

      if (!mounted) return;
      setState(() {
        _products =
            (data as List).map((json) => Product.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchProducts(query);
    });
  }

  void _onCategoryTap(String category) {
    _searchController.text = category;
    _searchProducts(category);
  }

  Future<void> _fetchCategories() async {
    try {
      final data =
          await supabase.from('categories').select().order('name');
      if (!mounted) return;
      setState(() {
        _categories =
            (data as List).map((j) => Category.fromJson(j)).toList();
      });
    } catch (_) {}
  }

  Future<void> _fetchFavorites() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('favorites')
          .select('product_id')
          .eq('user_id', userId);

      if (!mounted) return;
      setState(() {
        _wishlistItems = (data as List)
            .map<String>((row) => row['product_id'] as String)
            .toSet();
      });
    } catch (_) {}
  }

  Future<void> _toggleFavorite(String productId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final isFav = _wishlistItems.contains(productId);

    setState(() {
      if (isFav) {
        _wishlistItems.remove(productId);
      } else {
        _wishlistItems.add(productId);
      }
    });

    try {
      if (isFav) {
        await supabase
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('product_id', productId);
      } else {
        await supabase.from('favorites').insert({
          'user_id': userId,
          'product_id': productId,
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (isFav) {
          _wishlistItems.add(productId);
        } else {
          _wishlistItems.remove(productId);
        }
      });
    }
  }

  void _showCartModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            final entries = _cart.items.entries.toList();
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Keranjang Belanja',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_cart.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text('Keranjang kosong',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final productId = entries[index].key;
                          final entry = entries[index].value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: entry.imageUrl != null &&
                                          entry.imageUrl!.isNotEmpty
                                      ? Image.network(entry.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Icon(Icons.image,
                                                  color: Colors.grey[300]))
                                      : Icon(Icons.image,
                                          color: Colors.grey[300]),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(entry.productName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Text(
                                          CartManager.formatPrice(entry.price),
                                          style: const TextStyle(
                                              color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.blue),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          _cart.remove(productId);
                                          setModalState(() {});
                                          setState(() {});
                                        },
                                        icon: const Icon(
                                            Icons.remove_circle_outline,
                                            size: 18,
                                            color: Colors.blue),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: Text(
                                            entry.quantity.toString(),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          _cart.add(productId,
                                              name: entry.productName,
                                              price: entry.price,
                                              imageUrl: entry.imageUrl);
                                          setModalState(() {});
                                          setState(() {});
                                        },
                                        icon: const Icon(
                                            Icons.add_circle_outline,
                                            size: 18,
                                            color: Colors.blue),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[400]!, Colors.blue[600]!],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total: ${_cart.totalItems} items',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                            Text(_cart.formattedTotalPrice,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Lanjut ke pembayaran',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.white)),
                                backgroundColor:
                                    Colors.black.withValues(alpha: 0.5),
                                elevation: 0,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                                margin: const EdgeInsets.only(
                                    bottom: 95, left: 80, right: 80),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.payment),
                          label: const Text('Lanjut'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Blue Gradient Header with Search ────────────
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 55, 16, 20),
                  child: Row(
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.chevron_left,
                              color: Colors.white, size: 28),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Search field
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          autofocus: false,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          cursorColor: Colors.white,
                          decoration: InputDecoration(
                            hintText: 'Hari ini beli apa?',
                            hintStyle:
                                TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                            prefixIcon: Icon(Icons.search,
                                color: Colors.white.withValues(alpha: 0.7)),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(
                                  color: Colors.white, width: 1.5),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Filter Chips Row ────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filterLabels.map((label) {
                        final isSelected = _selectedFilter == label;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFilter =
                                    isSelected ? null : label;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2979FF)
                                    : Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2979FF)
                                      : const Color(0xFFBDD7FF),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (label == 'Filter') ...[
                                    Icon(Icons.tune,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey[600],
                                        size: 16),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey[600],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              // ── Sub-Kategori Grid ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: _categories.isEmpty
                      ? const SizedBox.shrink()
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _categories.map((cat) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: GestureDetector(
                                  onTap: () => _onCategoryTap(cat.name),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: const Color(0xFFBDD7FF),
                                              width: 1.5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.04),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Icon(
                                            _getCategoryIcon(cat.name),
                                            color: const Color(0xFF2979FF),
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        cat.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // ── Loading indicator ──────────────────────────
              if (_isLoading && _initialLoad)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                          color: Color(0xFF2979FF)),
                    ),
                  ),
                )
              else if (_products.isEmpty && !_isLoading)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.search_off,
                              color: Colors.grey[300], size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _searchController.text.isEmpty
                                ? 'Belum ada produk'
                                : 'Tidak ada produk ditemukan',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                // ── Product Grid ────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.62,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = _products[index];
                        return _ProductCard(
                          product: product,
                          isWishlisted:
                              _wishlistItems.contains(product.id),
                          quantity: _cart.quantityOf(product.id),
                          onWishlistTap: () =>
                              _toggleFavorite(product.id),
                          onAddToCart: () {
                            _cart.add(
                              product.id,
                              name: product.name,
                              price: product.supplierPrice,
                              imageUrl: product.imageUrl,
                            );
                            setState(() {});
                          },
                          onRemoveFromCart: () {
                            _cart.remove(product.id);
                            setState(() {});
                          },
                        );
                      },
                      childCount: _products.length,
                    ),
                  ),
                ),

              // Extra bottom spacing for sticky bar
              SliverToBoxAdapter(
                child: SizedBox(
                    height: _cart.isNotEmpty ? 140 : 40),
              ),
            ],
          ),

          // ── Inline loading overlay (non-blocking) ──────────
          if (_isLoading && !_initialLoad)
            Positioned(
              top: 140,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2979FF),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Mencari...',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),

          // ── Sticky Bottom Bar ("Lihat Belanjaanmu") ────────
          if (_cart.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: GestureDetector(
                onTap: () => _showCartModal(context),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2979FF),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Lihat Belanjaanmu',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _cart.totalItems.toString(),
                              style: const TextStyle(
                                color: Color(0xFF2979FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _cart.formattedTotalPrice,
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
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String label) {
    switch (label.toLowerCase()) {
      case 'sabun':
        return Icons.sanitizer;
      case 'shampoo':
        return Icons.water_drop;
      case 'detergen':
        return Icons.local_laundry_service;
      case 'pelembut':
        return Icons.spa;
      default:
        return Icons.category;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  PRIVATE WIDGETS
// ═══════════════════════════════════════════════════════════════

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
    return GestureDetector(
      onTap: onAddToCart,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image area with price badge & heart ──
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: product.imageUrl != null &&
                            product.imageUrl!.isNotEmpty
                        ? Image.network(product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                                child: Icon(Icons.image,
                                    size: 50, color: Colors.grey[300])))
                        : Center(
                            child: Icon(Icons.image,
                                size: 50, color: Colors.grey[300])),
                  ),
                  // Heart
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: onWishlistTap,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                            isWishlisted
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.red,
                            size: 20),
                      ),
                    ),
                  ),
                  // Quantity Badge
                  if (quantity > 0)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3D5CA),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          '$quantity x',
                          style: const TextStyle(
                            color: Color(0xFF5E503F),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Price badge
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2979FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        CartManager.formatPrice(product.supplierPrice),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Info area ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star,
                          color: Colors.orange, size: 16),
                      const SizedBox(width: 2),
                      Text('${product.supplierRating}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      // Add-to-cart button + counter + blue dot
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: onAddToCart,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2979FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('$quantity',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2979FF),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

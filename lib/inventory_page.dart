import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'main.dart';
import 'models.dart';
import 'cart_manager.dart';
import 'widgets/navbar.dart';
import 'edit_item_page.dart';

class InventoryPage extends StatefulWidget {
  final String? initialQuery;

  const InventoryPage({super.key, this.initialQuery});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late TextEditingController _searchController;

  List<Product> _products = [];
  bool _isLoading = false;
  bool _initialLoad = true;
  Timer? _debounce;
  String _userName = 'User';

  // Tab: 0 = Stock, 1 = Riwayat Penjualan
  int _selectedTab = 0;

  // Stock sub-filter
  String _stockFilter = 'Semua';
  final List<String> _stockFilters = [
    'Semua',
    'Stock Tersedia',
    'Stock Sedikit',
    'Stok Habis',
  ];

  // Transaction history data
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoadingTransactions = false;
  String _salesTimeframe = 'Harian';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _fetchProfile();
    _fetchAllProducts();
    _fetchTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Profile ─────────────────────────────────────────────────
  Future<void> _fetchProfile() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _setUserNameFromAuth();
        return;
      }

      final data = await supabase
          .from('profiles')
          .select('full_name, avatar_url, updated_at')
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;
      if (data != null) {
        final raw = (data['full_name'] ?? '').toString();
        setState(() {
          if (raw.isNotEmpty) {
            _userName = raw.length > 12 ? '${raw.substring(0, 12)}...' : raw;
          }
        });
      } else {
        _setUserNameFromAuth();
      }
    } catch (_) {
      _setUserNameFromAuth();
    }
  }

  Stream<UserProfile?> _profileStream() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();
    return supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((data) => data.isNotEmpty ? UserProfile.fromJson(data.first) : null);
  }

  void _setUserNameFromAuth() {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final meta = user.userMetadata;
    final raw = (meta?['full_name'] ?? meta?['nama'] ?? meta?['name'] ?? user.email ?? 'User')
        .toString()
        .split('@')
        .first;
    if (mounted) {
      setState(() {
        _userName = raw.length > 12 ? '${raw.substring(0, 12)}...' : raw;
      });
    }
  }

  // ── Data fetching ──────────────────────────────────────────
  Future<void> _fetchAllProducts() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('inventories')
          .select()
          .eq('user_id', userId)
          .order('name');

      if (!mounted) return;
      final list = data as List;
      final parsedProducts = list.map((json) {
        final price = (json['selling_price'] as num?)?.toDouble() ?? 0.0;
        final stock = (json['qty_available'] as num?)?.toInt() ?? 0;
        return Product(
          id: json['id']?.toString() ?? '',
          categoryId: '',
          categoryName: '',
          name: (json['name'] ?? '') as String,
          brand: '',
          price: price,
          stock: stock,
          rating: 4.5,
        );
      }).toList();

      setState(() {
        _products = parsedProducts;
        _isLoading = false;
        _initialLoad = false;
      });
    } catch (e) {
      debugPrint('[SiKulak] Error fetching all products: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _initialLoad = false;
      });
    }
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoadingTransactions = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('transactions')
          .select('*, transaction_items(*, products(name, price, image_url))')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      if (!mounted) return;
      setState(() {
        _transactions = List<Map<String, dynamic>>.from(data as List);
        _isLoadingTransactions = false;
      });
    } catch (e) {
      debugPrint('[SiKulak] Error fetching transactions: $e');
      if (!mounted) return;
      setState(() => _isLoadingTransactions = false);
    }
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      _fetchAllProducts();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('inventories')
          .select()
          .eq('user_id', userId)
          .ilike('name', '%${query.trim()}%')
          .order('name');

      if (!mounted) return;
      final list = data as List;
      final parsedProducts = list.map((json) {
        final price = (json['selling_price'] as num?)?.toDouble() ?? 0.0;
        final stock = (json['qty_available'] as num?)?.toInt() ?? 0;
        return Product(
          id: json['id']?.toString() ?? '',
          categoryId: '',
          categoryName: '',
          name: (json['name'] ?? '') as String,
          brand: '',
          price: price,
          stock: stock,
          rating: 4.5,
        );
      }).toList();

      setState(() {
        _products = parsedProducts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[SiKulak] Error searching products: $e');
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

  // ── Filtered products by stock ─────────────────────────────
  List<Product> get _filteredProducts {
    switch (_stockFilter) {
      case 'Stock Tersedia':
        return _products.where((p) => p.stock > 10).toList();
      case 'Stock Sedikit':
        return _products.where((p) => p.stock > 0 && p.stock <= 10).toList();
      case 'Stok Habis':
        return _products.where((p) => p.stock == 0).toList();
      default: // 'Semua'
        return _products;
    }
  }

  // ── Stock badge color helpers ──────────────────────────────
  Color _stockBadgeColor(int stock) {
    if (stock == 0) return const Color(0xFFEF4444);
    if (stock <= 10) return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
  }

  Color _stockBadgeTextColor(int stock) {
    return Colors.white;
  }

  Widget _stockBadgeIcon(int stock) {
    if (stock == 0) {
      return Icon(Icons.remove_circle_outline, size: 18, color: Colors.red[700]);
    }
    if (stock <= 10) {
      return Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange[700]);
    }
    return const SizedBox.shrink();
  }

  // ── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ─────────── HEADER (same as HomePage) ───────────
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            toolbarHeight: 140,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: StreamBuilder<UserProfile?>(
              stream: _profileStream(),
              builder: (context, snapshot) {
                final profile = snapshot.data;
                final userName = profile?.fullName ?? _userName;
                final avatarUrl = profile?.avatarUrl;

                return Container(
                  padding: const EdgeInsets.only(top: 15, left: 20, right: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop(4);
                            },
                            child: _GlassContainer(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14),
                              borderRadius: BorderRadius.circular(30),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white24,
                                    ),
                                    child: avatarUrl != null && avatarUrl.isNotEmpty
                                        ? ClipOval(
                                            child: Image.network(
                                              '$avatarUrl?t=${profile?.updatedAt.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}',
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Icon(Icons.person,
                                                    color: Colors.white, size: 22);
                                              },
                                            ),
                                          )
                                        : const Icon(Icons.person,
                                            color: Colors.white, size: 22),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Selamat datang,',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11)),
                                        const SizedBox(height: 1),
                                        Text(userName,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: _HeaderIcon(
                          icon: Icons.notifications_none_outlined,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                );
              }
            ),
            flexibleSpace: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color:
                      const Color(0xFF2979FF).withValues(alpha: 0.8),
                ),
              ),
            ),
          ),

          // ─────────── SEARCH BAR ───────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Cari barang anda',
                          hintStyle: TextStyle(
                              color: Colors.grey[400], fontSize: 14),
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const Icon(Icons.filter_list, color: Colors.blue),
                  ],
                ),
              ),
            ),
          ),

          // ─────────── STOCK / RIWAYAT TABS ───────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildTabButton('Stock', 0),
                  const SizedBox(width: 12),
                  _buildTabButton('Riwayat Penjualan', 1),
                ],
              ),
            ),
          ),

          // ─────────── STOCK SUB-FILTER CHIPS ───────────
          if (_selectedTab == 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                    top: 12, left: 20, right: 20, bottom: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _stockFilters.map((filter) {
                      final isSelected = _stockFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _stockFilter = filter),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2979FF)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF2979FF)
                                    : const Color(0xFFBDD7FF),
                                width: 1.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF2979FF)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Text(
                              filter,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

          // ─────────── CONTENT AREA ───────────
          if (_selectedTab == 0)
            ..._buildStockList()
          else
            ..._buildTransactionHistory(),

          // Bottom spacing for navbar
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // ─────────── NAVBAR ───────────
      bottomNavigationBar: CustomNavBar(
        selectedIndex: 1, // Inventory tab is selected
        onItemTapped: (index) {
          if (index == 1) return; // Already on this page
          if (index == 0) {
            Navigator.of(context).pop();
          } else {
            // For other tabs, pop back to home and let home handle it
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  // ── Tab button builder ─────────────────────────────────────
  Widget _buildTabButton(String label, int tabIndex) {
    final isSelected = _selectedTab == tabIndex;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tabIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2979FF) : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2979FF)
                : const Color(0xFFBDD7FF),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2979FF).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Stock list content ─────────────────────────────────────
  List<Widget> _buildStockList() {
    if (_isLoading && _initialLoad) {
      return [
        const SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(
                  color: Color(0xFF2979FF)),
            ),
          ),
        ),
      ];
    }

    final products = _filteredProducts;

    if (products.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined,
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
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final product = products[index];
              return _buildProductListItem(product);
            },
            childCount: products.length,
          ),
        ),
      ),
    ];
  }

  // ── Single product list item (matching design image 3) ─────
  Widget _buildProductListItem(Product product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product image
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                ? Image.network(
                    product.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(Icons.image,
                          size: 36, color: Colors.grey[300]),
                    ),
                  )
                : Center(
                    child: Icon(Icons.image,
                        size: 36, color: Colors.grey[300]),
                  ),
          ),
          const SizedBox(width: 14),
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Stock badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _stockBadgeColor(product.stock),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${product.stock} Sachet',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _stockBadgeTextColor(product.stock),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _stockBadgeIcon(product.stock),
                  ],
                ),
              ],
            ),
          ),
          // Price + Edit
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rp.${CartManager.formatPrice(product.price).replaceFirst('Rp. ', '')}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditItemPage(
                        product: product,
                        onSaved: () {
                          _fetchAllProducts();
                          _fetchTransactions();
                        },
                      ),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  // ── Sales history statistics & aggregation ─────────────────
  Map<String, dynamic> _computeSalesStats() {
    final now = DateTime.now();
    double totalProfit = 0.0;
    int itemsSold = 0;
    
    final Map<String, Map<String, dynamic>> productSales = {};

    for (final tx in _transactions) {
      final createdAtStr = tx['created_at'] as String?;
      if (createdAtStr == null) continue;
      final date = DateTime.tryParse(createdAtStr)?.toLocal();
      if (date == null) continue;

      // Check timeframe filter
      bool inTimeframe = false;
      if (_salesTimeframe == 'Harian') {
        inTimeframe = date.year == now.year && date.month == now.month && date.day == now.day;
      } else if (_salesTimeframe == 'Mingguan') {
        final difference = now.difference(date).inDays;
        inTimeframe = difference <= 7;
      } else if (_salesTimeframe == 'Bulanan') {
        inTimeframe = date.year == now.year && date.month == now.month;
      } else if (_salesTimeframe == 'Tahunan') {
        inTimeframe = date.year == now.year;
      }

      if (!inTimeframe) continue;

      totalProfit += (tx['total_profit'] as num?)?.toDouble() ?? 0.0;
      final items = tx['transaction_items'] as List? ?? [];
      
      for (final item in items) {
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
        itemsSold += qty;

        final product = item['products'] as Map<String, dynamic>?;
        if (product != null) {
          final productId = item['product_id']?.toString() ?? '';
          final productName = product['name'] as String? ?? 'Produk';
          final price = (product['price'] as num?)?.toDouble() ?? 0.0;
          final imageUrl = product['image_url'] as String?;

          if (productSales.containsKey(productId)) {
            productSales[productId]!['quantity'] = productSales[productId]!['quantity'] + qty;
          } else {
            productSales[productId] = {
              'id': productId,
              'name': productName,
              'price': price,
              'image_url': imageUrl,
              'quantity': qty,
              'stock': (product['stock'] as num?)?.toInt() ?? 0,
            };
          }
        }
      }
    }

    if (_transactions.isEmpty) {
      return {
        'total_profit': 0.0,
        'items_sold': 0,
        'products': [],
      };
    }

    return {
      'total_profit': totalProfit,
      'items_sold': itemsSold,
      'products': productSales.values.toList(),
    };
  }

  // ── Redesigned Transaction history content ──────────────────
  List<Widget> _buildTransactionHistory() {
    if (_isLoadingTransactions) {
      return [
        const SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(
                  color: Color(0xFF2979FF)),
            ),
          ),
        ),
      ];
    }

    final stats = _computeSalesStats();
    final double totalProfit = stats['total_profit'] as double;
    final int itemsSold = stats['items_sold'] as int;
    final List<Map<String, dynamic>> products = List<Map<String, dynamic>>.from(stats['products']);

    return [
      // 1. Timeframe Filter Chips
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, left: 20, right: 20, bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Harian', 'Mingguan', 'Bulanan', 'Tahunan'].map((tf) {
              final isSel = _salesTimeframe == tf;
              return GestureDetector(
                onTap: () => setState(() => _salesTimeframe = tf),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF2979FF) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSel ? const Color(0xFF2979FF) : const Color(0xFFBDD7FF),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    tf,
                    style: TextStyle(
                      color: isSel ? Colors.white : const Color(0xFF2979FF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),

      // 2. Statistics Cards Row
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Keuntungan',
                        style: TextStyle(
                          color: Color(0xFF22C55E),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rp. ${CartManager.formatPrice(totalProfit).replaceFirst('Rp. ', '')}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Items Sold',
                        style: TextStyle(
                          color: Color(0xFF2979FF),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$itemsSold',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // 3. Section Header: Penjualan
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(left: 20, right: 20, bottom: 12),
          child: Text(
            'Penjualan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ),
      ),

      // 4. Sales List
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final prod = products[index];
              return _buildSalesListItem(prod);
            },
            childCount: products.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildSalesListItem(Map<String, dynamic> prod) {
    final String id = prod['id'].toString();
    final String name = prod['name'] as String;
    final double price = prod['price'] as double;
    final String? imageUrl = prod['image_url'] as String?;
    final int qty = prod['quantity'] as int;
    final int stock = prod['stock'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.image, size: 30, color: Colors.grey),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.image, size: 30, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 14),

          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Rp.${CartManager.formatPrice(price).replaceFirst('Rp. ', '')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Terjual: $qty',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2979FF),
                  ),
                ),
              ],
            ),
          ),

          // Edit Button on right
          GestureDetector(
            onTap: () {
              // Create a dummy Product object to navigate to EditItemPage
              final dummyProduct = Product(
                id: id,
                categoryId: '',
                categoryName: '',
                name: name,
                brand: '',
                price: price,
                stock: stock,
                rating: 4.5,
                imageUrl: imageUrl,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditItemPage(
                    product: dummyProduct,
                    onSaved: () {
                      _fetchAllProducts();
                      _fetchTransactions();
                    },
                  ),
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 2),
                Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
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

// ═══════════════════════════════════════════════════════════════
//  PRIVATE WIDGETS
// ═══════════════════════════════════════════════════════════════

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;

  const _GlassContainer({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: borderRadius,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.2), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _GlassContainer(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(50),
        child: Center(child: Icon(icon, color: Colors.white, size: 24)),
      ),
    );
  }
}

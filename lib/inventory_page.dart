import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'models.dart';
import 'cart_manager.dart';
import 'notification_page.dart';
import 'widgets/navbar.dart';
import 'edit_item_page.dart';
import 'add_item_page.dart';

class InventoryPage extends StatefulWidget {
  final String? initialQuery;

  const InventoryPage({super.key, this.initialQuery});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late TextEditingController _searchController;

  List<Product> _products = [];
  Map<String, List<int>> _productDailySales = {};
  bool _isLoading = false;
  bool _initialLoad = true;
  Timer? _debounce;
  String _userName = 'User';

  StreamSubscription<AuthState>? _authStateSubscription;

  // Stock sub-filter
  String _stockFilter = 'Semua';
  final List<String> _stockFilters = [
    'Semua',
    'Stock Tersedia',
    'Stock Sedikit',
    'Stok Habis',
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _fetchProfile();
    _fetchAllProducts();
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Stream<List<Map<String, dynamic>>> _notificationStream() {
    final userId = supabase.auth.currentUser?.id ?? supabase.auth.currentSession?.user.id;
    if (userId == null) return const Stream.empty();
    return supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId);
  }

  Widget _buildNotificationBadgeIcon() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _notificationStream(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? const [];
        final count = data.where((row) => row['is_read'] == false).length;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _HeaderIcon(
              icon: Icons.notifications_none_outlined,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotificationPage(
                      onNotificationsMarkedRead: () {},
                    ),
                  ),
                );
              },
            ),
            if (count > 0)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _authStateSubscription?.cancel();
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

			// Fetch global products for fallbacks
			final globalProductsData = await supabase.from('products').select();
			final Map<String, String> nameToImage = {};
			final Map<String, String> nameToBrand = {};
			final Map<String, String> nameToCategoryName = {};
			final Map<String, String> nameToCategoryId = {};
			final Map<String, double> nameToRating = {};
			final Map<String, int> nameToLeadTime = {};

			for (final p in globalProductsData as List) {
				final name = (p['name'] ?? '') as String;
				final imageUrl = p['image_url'] as String?;
				final brand = p['brand'] as String? ?? '';
				final rating = (p['rating'] as num?)?.toDouble() ?? 4.5;
				final leadTime = (p['lead_time'] as num?)?.toInt() ?? 3;
				final categoryId = p['category_id']?.toString() ?? '';

				String catName = '';
				final catObj = p['category'] ?? p['categories'];
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

				if (name.isNotEmpty) {
					if (imageUrl != null && imageUrl.isNotEmpty) nameToImage[name] = imageUrl;
					if (brand.isNotEmpty) nameToBrand[name] = brand;
					if (catName.isNotEmpty) nameToCategoryName[name] = catName;
					if (categoryId.isNotEmpty) nameToCategoryId[name] = categoryId;
					nameToRating[name] = rating;
					nameToLeadTime[name] = leadTime;
				}
			}

			final data = await supabase
					.from('inventories')
					.select()
					.eq('user_id', userId)
					.order('name');

			if (!mounted) return;
			final list = data as List;
			final parsedProducts = list.map((json) {
				final name = (json['name'] ?? '') as String;
				final price = (json['selling_price'] as num?)?.toDouble() ?? 
											(json['price'] as num?)?.toDouble() ?? 0.0;
				final stock = (json['qty_available'] as num?)?.toInt() ?? 
											(json['stock'] as num?)?.toInt() ?? 0;
				return Product(
					id: json['id']?.toString() ?? '',
					categoryId: (json['category_id']?.toString() ?? '').isNotEmpty 
											? json['category_id'].toString() 
											: (nameToCategoryId[name] ?? ''),
					categoryName: (json['category_name']?.toString() ?? '').isNotEmpty
											? json['category_name'].toString()
											: (nameToCategoryName[name] ?? ''),
					name: name,
					brand: (json['brand']?.toString() ?? '').isNotEmpty
											? json['brand'].toString()
											: (nameToBrand[name] ?? ''),
					price: price,
					stock: stock,
					rating: (json['rating'] as num?)?.toDouble() ?? (nameToRating[name] ?? 4.5),
					imageUrl: (json['image_url']?.toString() ?? '').isNotEmpty
											? json['image_url'].toString()
											: findImageUrlFallback(name, nameToImage),
					leadTime: (json['lead_time'] as num?)?.toInt() ?? (nameToLeadTime[name] ?? 3),
				);
			}).toList();

			// Fetch sales from the last 30 days to calculate daily demand
			final dateThreshold = DateTime.now().subtract(const Duration(days: 30)).toUtc().toIso8601String();
			final salesData = await supabase
					.from('pos_order_items')
					.select('qty, inventories!inner(id), pos_orders!inner(created_at)')
					.eq('inventories.user_id', userId)
					.gte('pos_orders.created_at', dateThreshold);

			final salesList = salesData as List? ?? [];
			final Map<String, Map<String, int>> dailyMap = {};
			for (final row in salesList) {
				final inv = row['inventories'] as Map<String, dynamic>?;
				if (inv == null) continue;
				final id = inv['id'].toString();

				final order = row['pos_orders'] as Map<String, dynamic>?;
				if (order == null || order['created_at'] == null) continue;
				final dateKey = order['created_at'].toString().substring(0, 10); // YYYY-MM-DD

				final qty = (row['qty'] as num?)?.toInt() ?? 0;

				dailyMap.putIfAbsent(id, () => {});
				dailyMap[id]![dateKey] = (dailyMap[id]![dateKey] ?? 0) + qty;
			}

			// Convert dailyMap to 30 days list
			final Map<String, List<int>> productSalesList = {};
			for (final p in parsedProducts) {
				final dailySales = dailyMap[p.id] ?? {};
				productSalesList[p.id] = List.generate(30, (index) {
					final date = DateTime.now().subtract(Duration(days: index));
					final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
					return dailySales[dateKey] ?? 0;
				});
			}

			setState(() {
				_products = parsedProducts;
				_productDailySales = productSalesList;
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

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      _fetchAllProducts();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch global products for fallbacks
      final globalProductsData = await supabase.from('products').select();
      final Map<String, String> nameToImage = {};
      final Map<String, String> nameToBrand = {};
      final Map<String, String> nameToCategoryName = {};
      final Map<String, String> nameToCategoryId = {};
      final Map<String, double> nameToRating = {};
      final Map<String, int> nameToLeadTime = {};

      for (final p in globalProductsData as List) {
        final name = (p['name'] ?? '') as String;
        final imageUrl = p['image_url'] as String?;
        final brand = p['brand'] as String? ?? '';
        final rating = (p['rating'] as num?)?.toDouble() ?? 4.5;
        final leadTime = (p['lead_time'] as num?)?.toInt() ?? 3;
        final categoryId = p['category_id']?.toString() ?? '';

        String catName = '';
        final catObj = p['category'] ?? p['categories'];
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

        if (name.isNotEmpty) {
          if (imageUrl != null && imageUrl.isNotEmpty) nameToImage[name] = imageUrl;
          if (brand.isNotEmpty) nameToBrand[name] = brand;
          if (catName.isNotEmpty) nameToCategoryName[name] = catName;
          if (categoryId.isNotEmpty) nameToCategoryId[name] = categoryId;
          nameToRating[name] = rating;
          nameToLeadTime[name] = leadTime;
        }
      }

      final data = await supabase
          .from('inventories')
          .select()
          .eq('user_id', userId)
          .ilike('name', '%${query.trim()}%')
          .order('name');

      if (!mounted) return;
      final list = data as List;
      final parsedProducts = list.map((json) {
        final name = (json['name'] ?? '') as String;
        final price = (json['selling_price'] as num?)?.toDouble() ?? 
                      (json['price'] as num?)?.toDouble() ?? 0.0;
        final stock = (json['qty_available'] as num?)?.toInt() ?? 
                      (json['stock'] as num?)?.toInt() ?? 0;
        return Product(
          id: json['id']?.toString() ?? '',
          categoryId: (json['category_id']?.toString() ?? '').isNotEmpty 
                      ? json['category_id'].toString() 
                      : (nameToCategoryId[name] ?? ''),
          categoryName: (json['category_name']?.toString() ?? '').isNotEmpty
                      ? json['category_name'].toString()
                      : (nameToCategoryName[name] ?? ''),
          name: name,
          brand: (json['brand']?.toString() ?? '').isNotEmpty
                      ? json['brand'].toString()
                      : (nameToBrand[name] ?? ''),
          price: price,
          stock: stock,
          rating: (json['rating'] as num?)?.toDouble() ?? (nameToRating[name] ?? 4.5),
          imageUrl: (json['image_url']?.toString() ?? '').isNotEmpty
                      ? json['image_url'].toString()
                      : findImageUrlFallback(name, nameToImage),
          leadTime: (json['lead_time'] as num?)?.toInt() ?? (nameToLeadTime[name] ?? 3),
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

  int _calculateSafetyStock(Product product) {
    final sales = _productDailySales[product.id] ?? List.filled(30, 0);

    // 1. Calculate daily average
    final double totalSales = sales.fold(0.0, (sum, val) => sum + val);
    final double mean = totalSales / 30.0;

    // 2. Calculate daily variance & standard deviation
    double varianceSum = 0.0;
    for (final s in sales) {
      varianceSum += (s - mean) * (s - mean);
    }
    final double variance = varianceSum / 30.0;
    final double stdDevDaily = variance > 0 ? sqrt(variance) : 0.0;

    // Fallback standard deviation jika belum ada penjualan (biar safety stock awal bernilai 3 sachet)
    double stdDev = stdDevDaily;
    if (stdDev == 0) {
      stdDev = 1.05; // 1.65 * 1.05 * sqrt(3) = 1.73 * 1.73 = 3
    }

    // 3. Safety Stock = Z * stdDev * sqrt(LT)
    // Z = 1.65 (Service Level 95%)
    const double zValue = 1.65;
    final double lt = product.leadTime.toDouble();
    final double stdDevLeadTime = stdDev * sqrt(lt);
    final double ss = zValue * stdDevLeadTime;

    return ss.round().clamp(1, 9999);
  }

  // ── Filtered products by stock ─────────────────────────────
  List<Product> get _filteredProducts {
    switch (_stockFilter) {
      case 'Stock Tersedia':
        return _products.where((p) => p.stock > _calculateSafetyStock(p)).toList();
      case 'Stock Sedikit':
        return _products.where((p) => p.stock > 0 && p.stock <= _calculateSafetyStock(p)).toList();
      case 'Stok Habis':
        return _products.where((p) => p.stock == 0).toList();
      default: // 'Semua'
        return _products;
    }
  }

  // ── Stock badge color helpers ──────────────────────────────
  Color _stockBadgeColor(Product product) {
    if (product.stock == 0) return const Color(0xFFEF4444);
    if (product.stock <= _calculateSafetyStock(product)) return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
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
          // ─────────── 1. HEADER SECTION ───────────
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

                return Container(
                  padding: const EdgeInsets.only(top: 15, left: 20, right: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // User Profile (Top Left)
                      _GlassContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                              child: profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        '${profile.avatarUrl}?t=${profile.updatedAt.millisecondsSinceEpoch}',
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Selamat datang,',
                                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                                Text(userName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Notification (Top Right)
                      _buildNotificationBadgeIcon(),
                    ],
                  ),
                );
              }
            ),
            flexibleSpace: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: const Color(0xFF2979FF).withValues(alpha: 0.8),
                ),
              ),
            ),
          ),

          // ─────────── 2. SEARCH & MAIN ACTIONS ───────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFF2979FF), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Color(0xFF2979FF), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: const InputDecoration(
                              hintText: 'Cari barang anda',
                              hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const Icon(Icons.filter_list, color: Color(0xFF2979FF), size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Action Buttons (Split row)
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: 'Stock',
                          isSelected: true,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionButton(
                          label: 'Tambah Produk',
                          isSelected: false,
                          icon: Icons.add,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddItemPage(
                                  onSaved: () => _fetchAllProducts(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─────────── FILTER CHIPS (NON-SCROLLABLE) ───────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _stockFilters.map((filter) {
                  final isSelected = _stockFilter == filter;
                  return GestureDetector(
                    onTap: () => setState(() => _stockFilter = filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2979FF) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF2979FF),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF2979FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ─────────── 3. INVENTORY LIST ───────────
          ..._buildStockList(),

          // Bottom spacing for navbar
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      bottomNavigationBar: CustomNavBar(
        selectedIndex: 1,
        onItemTapped: (index) {
          if (index == 1) return;
          Navigator.of(context).pop(index);
        },
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required bool isSelected,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2979FF) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: isSelected ? null : Border.all(color: const Color(0xFF2979FF), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: isSelected ? Colors.white : const Color(0xFF2979FF), size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF2979FF),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStockList() {
    if (_isLoading && _initialLoad) {
      return [
        const SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Color(0xFF2979FF)),
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
                  Icon(Icons.inventory_2_outlined, color: Colors.grey[300], size: 48),
                  const SizedBox(height: 12),
                  Text(
                    _searchController.text.isEmpty ? 'Belum ada produk' : 'Tidak ada produk ditemukan',
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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

  Widget _buildProductListItem(Product product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
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
      child: Row(
        children: [
          // Left: Square product image
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                ? Image.network(
                    product.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(Icons.image, size: 30, color: Colors.grey[300]),
                    ),
                  )
                : Center(
                    child: Icon(Icons.image, size: 30, color: Colors.grey[300]),
                  ),
          ),
          const SizedBox(width: 14),
          // Middle: Product name + stock badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _stockBadgeColor(product),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${product.stock} Sachet',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Safety Stock: ${_calculateSafetyStock(product)} Sachet',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Right: Price + Edit
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rp.${CartManager.formatPrice(product.price).replaceFirst('Rp. ', '')}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditItemPage(
                        product: product,
                        onSaved: () => _fetchAllProducts(),
                      ),
                    ),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: 14, color: Color(0xFF94A3B8)),
                    SizedBox(width: 4),
                    Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
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
}

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

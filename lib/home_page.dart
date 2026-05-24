import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'main.dart';
import 'models.dart';
import 'cart_manager.dart';
import 'inventory_page.dart';
import 'dashboard_page.dart';
import 'widgets/navbar.dart';
import 'profile_page.dart';
import 'notification_service.dart';
import 'product_detail_page.dart';
import 'product_search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ── State ──────────────────────────────────────────────────
  final CartManager _cart = CartManager();
  final Set<String> _wishlistItems = {}; // local-only (no BE table)
  String? _selectedCategoryId; // null = "Semua Produk"
  int _selectedNavItem = 0;

  List<Product> _products = [];
  List<Category> _categories = [];
  String _userName = 'User';
  bool _isLoading = true;
  String? _errorMessage;
  bool _lowStockChecked = false;

  // Promo carousel
  late final PageController _promoPageController;
  int _currentPromoPage = 0;
  Timer? _promoAutoScrollTimer;

  // Static promo data (no is_promo field in DB)
  final List<Map<String, String>> _promoData = const [
    {
      'title': 'Harga Sabun sedang\nturun sebanyak 30%',
      'subtitle': 'Tawaran terbatas. Beli sekarang.',
    },
    {
      'title': 'Diskon Detergen\nhingga 25%!',
      'subtitle': 'Stok terbatas, jangan lewatkan.',
    },
    {
      'title': 'Promo Shampoo\nbeli 2 gratis 1',
      'subtitle': 'Berlaku untuk semua merek.',
    },
    {
      'title': 'Minyak Goreng Hemat\ndiskon khusus hari ini',
      'subtitle': 'Maksimal pembelian 2 pcs.',
    },
    {
      'title': 'Bumbu Dapur Lengkap\nharga mulai Rp 1.000',
      'subtitle': 'Segar setiap hari langsung kirim.',
    },
  ];

  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _promoPageController = PageController(viewportFraction: 1.0);
    _loadData();
  }

  @override
  void dispose() {
    _promoPageController.dispose();
    _promoAutoScrollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAndInitializeInventory() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Check if user has items in inventories
      final data = await supabase
          .from('inventories')
          .select('id')
          .eq('user_id', userId)
          .limit(1);

      if ((data as List).isEmpty) {
        debugPrint('[SiKulak] User has empty inventory. Initializing from global products catalog...');
        // Fetch all global products
        final globalProducts = await supabase.from('products').select();
        final list = globalProducts as List;

        // Insert each product into inventories
        for (final p in list) {
          final price = (p['price'] as num?)?.toDouble() ?? 10000.0;
          await supabase.from('inventories').insert({
            'user_id': userId,
            'name': p['name'],
            'qty_available': (p['stock'] as num?)?.toInt() ?? 15,
            'capital_price': price * 0.90,
            'selling_price': price,
            'exp_date': null,
          });
        }
        debugPrint('[SiKulak] Inventory initialization complete.');
      }
    } catch (e) {
      debugPrint('[SiKulak] Error initializing inventory: $e');
    }
  }

  // ── Data loading ───────────────────────────────────────────
  Future<void> _loadData() async {
    await _checkAndInitializeInventory();
    // Run independently so one failure doesn't block the others
    _fetchProfile();
    _fetchCategories();
    await _fetchProducts();
    _startPromoAutoScroll();
    if (!_lowStockChecked) {
      _lowStockChecked = true;
      _checkLowStock();
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        // Not logged in — try auth metadata as fallback
        _setUserNameFromAuth();
        return;
      }

      final data = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;
      if (data != null && data['full_name'] != null) {
        final raw = data['full_name'].toString();
        setState(() {
          _userName = raw.length > 12 ? '${raw.substring(0, 12)}...' : raw;
        });
      } else {
        _setUserNameFromAuth();
      }
    } catch (_) {
      _setUserNameFromAuth();
    }
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

  Future<void> _fetchCategories() async {
    try {
      final data =
          await supabase.from('categories').select().order('name');
      if (!mounted) return;
      setState(() {
        _categories =
            (data as List).map((j) => Category.fromJson(j)).toList();
      });
    } catch (_) {
      // Fallback: static categories
      if (!mounted) return;
      setState(() {
        _categories = const [
          Category(id: 'Sabun', name: 'Sabun'),
          Category(id: 'Shampoo', name: 'Shampoo'),
          Category(id: 'Detergen', name: 'Detergen'),
        ];
      });
    }
  }

  Future<void> _fetchProducts() async {
    try {
      final data = await supabase
          .from('products')
          .select();

      if (!mounted) return;
      final list = data as List;
      debugPrint('[SiKulak] Fetched ${list.length} products');
      final parsedProducts = list.map((json) => Product.fromJson(json)).toList();

      setState(() {
        _products = parsedProducts;
        // Only set categories from products if _categories is empty
        if (_categories.isEmpty) {
          final uniqueCats = parsedProducts
              .map((p) => p.categoryName)
              .where((cat) => cat.isNotEmpty)
              .toSet();
          if (uniqueCats.isNotEmpty) {
            _categories = uniqueCats.map((name) => Category(id: name, name: name)).toList();
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[SiKulak] Error fetching products: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat produk: $e';
        _isLoading = false;
      });
    }
  }

  // ── Promo carousel ─────────────────────────────────────────
  void _startPromoAutoScroll() {
    _promoAutoScrollTimer?.cancel();
    _promoAutoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_promoPageController.hasClients) return;
      final next = (_currentPromoPage + 1) % _promoData.length;
      _promoPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  // ── Filtered products ──────────────────────────────────────
  List<Product> get _filteredProducts {
    if (_selectedCategoryId == null) return _products;
    final isUuid = _selectedCategoryId!.contains('-');
    if (isUuid) {
      return _products
          .where((p) => p.categoryId == _selectedCategoryId)
          .toList();
    } else {
      return _products
          .where((p) => p.categoryName.toLowerCase() == _selectedCategoryId!.toLowerCase())
          .toList();
    }
  }

// ── Low stock check (from inventories table) ───────────────
  Future<void> _checkLowStock() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch items with qty_available <= 5 (including stock = 0)
      final data = await supabase
          .from('inventories')
          .select()
          .eq('user_id', userId)
          .lte('qty_available', 5);

      if (!mounted) return;
      final items =
          (data as List).map((j) => InventoryItem.fromJson(j)).toList();
      if (items.isNotEmpty) {
        // Fire OS push notifications for ALL low-stock items
        for (final item in items) {
          NotificationService().showLowStockNotification(
            itemName: item.name,
            qty: item.qtyAvailable,
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showLowStockDialog(items);
        });
      }
    } catch (_) {}
  }

  // ── Checkout Cart ──────────────────────────────────────────
  Future<void> _checkoutCart(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User tidak terautentikasi.');
      final userId = user.id;
      final totalPrice = _cart.totalPrice;
      final totalProfit = totalPrice * 0.10; // 10% profit margin

      // 1. Create transaction in DB
      final transactionResponse = await supabase.from('transactions').insert({
        'user_id': userId,
        'total_price': totalPrice,
        'total_profit': totalProfit,
        'status': 'completed',
      }).select().single();

      final transactionId = transactionResponse['id'];

      // 2. Insert transaction items and update stock for each item
      for (final entry in _cart.items.entries) {
        final productIdStr = entry.key;
        final cartItem = entry.value;
        final productId = productIdStr;

        // Insert item details
        await supabase.from('transaction_items').insert({
          'transaction_id': transactionId,
          'product_id': productId,
          'quantity': cartItem.quantity,
          'price_at_purchase': cartItem.price,
          'profit_at_purchase': cartItem.price * 0.10,
        });

        // Fetch current stock to subtract from user's inventories
        final invData = await supabase
            .from('inventories')
            .select('id, qty_available')
            .eq('user_id', userId)
            .or('id.eq.$productId,name.eq.${cartItem.productName}')
            .maybeSingle();
        if (invData != null) {
          final invId = invData['id'];
          final currentQty = (invData['qty_available'] as num?)?.toInt() ?? 0;
          final newQty = (currentQty - cartItem.quantity).clamp(0, 999999);
          await supabase
              .from('inventories')
              .update({'qty_available': newQty})
              .eq('id', invId);
        }
      }

      // 3. Clear cart and reload
      _cart.clear();
      _loadData();

      if (!context.mounted) return;
      Navigator.pop(context); // Dismiss spinner
      Navigator.pop(context); // Dismiss cart modal

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pembayaran berhasil! Transaksi disimpan ke database.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white)),
          backgroundColor: Colors.green.shade900.withValues(alpha: 0.8),
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30)),
          margin: const EdgeInsets.only(bottom: 95, left: 40, right: 40),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Dismiss spinner
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal melakukan checkout: $e',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white)),
          backgroundColor: Colors.red.shade900.withValues(alpha: 0.8),
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30)),
          margin: const EdgeInsets.only(bottom: 95, left: 40, right: 40),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Low Stock Dialog ───────────────────────────────────────
  void _showLowStockDialog(List<InventoryItem> items) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tambah Stock Anda!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2979FF),
                ),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 20),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    final isOut = item.qtyAvailable == 0;
                    return Row(
                      children: [
                        // Product image from DB or fallback icon
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: item.imageUrl != null &&
                                  item.imageUrl!.isNotEmpty
                              ? Image.network(
                                  item.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                      Icons.inventory_2,
                                      color: Colors.grey[400]),
                                )
                              : Icon(Icons.inventory_2,
                                  color: Colors.grey[400]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isOut
                                          ? Colors.red[100]
                                          : Colors.orange[100],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${item.qtyAvailable} Sachet',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isOut
                                            ? Colors.red[700]
                                            : Colors.orange[800],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    isOut
                                        ? Icons.remove_circle_outline
                                        : Icons.warning_amber_rounded,
                                    size: 18,
                                    color: isOut ? Colors.red : Colors.orange,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // Navigate to SearchPage (restock)
                    setState(() => _selectedNavItem = 1);
                    Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (_) => const InventoryPage()))
                        .then((_) {
                      if (mounted) setState(() => _selectedNavItem = 0);
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C6BC0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'PESAN SEKARANG',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Nanti',
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cart Modal ─────────────────────────────────────────────
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
                          onPressed: () => _checkoutCart(context),
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
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ─────────── GLASSMORPHISM HEADER ───────────
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            toolbarHeight: 140,
            automaticallyImplyLeading: false,
            flexibleSpace: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color:
                      const Color(0xFF2979FF).withValues(alpha: 0.8),
                  padding: const EdgeInsets.only(
                      top: 55, left: 20, right: 20, bottom: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: _GlassContainer(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14),
                            borderRadius: BorderRadius.circular(30),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white24,
                                  child: Icon(Icons.person,
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
                                      Text(_userName,
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
                ),
              ),
            ),
          ),

          // ─────────── SEARCH BAR (tappable → SearchPage) ───────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 20),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(
                          builder: (_) => const ProductSearchPage()))
                      .then((_) => setState(() {}));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
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
                        child: Text('Hari ini beli apa?',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 14)),
                      ),
                      const Icon(Icons.tune, color: Colors.blue),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─────────── CATEGORY CHIPS ───────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.only(top: 8, left: 20, bottom: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // "Semua Produk" chip
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _CategoryChip(
                        label: 'Semua Produk',
                        isSelected: _selectedCategoryId == null,
                        onTap: () =>
                            setState(() => _selectedCategoryId = null),
                      ),
                    ),
                    ..._categories.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _CategoryChip(
                            label: cat.name,
                            isSelected:
                                _selectedCategoryId == cat.id,
                            onTap: () => setState(
                                () => _selectedCategoryId = cat.id),
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ),

          // ─────────── PROMO BANNER CAROUSEL ───────────
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(
                  height: 180,
                  child: PageView.builder(
                    controller: _promoPageController,
                    onPageChanged: (p) =>
                        setState(() => _currentPromoPage = p),
                    itemCount: _promoData.length,
                    itemBuilder: (_, index) {
                      final promo = _promoData[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 20),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF1E3A8A),
                              Color(0xFF3B82F6)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(promo['title']!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(promo['subtitle']!,
                                style: const TextStyle(
                                    color: Colors.white70)),
                            const SizedBox(height: 15),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context)
                                    .push(MaterialPageRoute(
                                        builder: (_) =>
                                            const InventoryPage()))
                                    .then((_) => setState(() {}));
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A1A2E),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  )),
                              child: const Text('Beli Sekarang',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _promoData.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin:
                          const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPromoPage == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPromoPage == i
                            ? const Color(0xFF2979FF)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─────────── SECTION TITLE ───────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(left: 20, top: 20, bottom: 8),
              child: Text('Produk Pilihan',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A))),
            ),
          ),

          // ─────────── LOADING / ERROR / GRID ───────────
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(
                      color: Color(0xFF2979FF)),
                ),
              ),
            )
          else if (_errorMessage != null)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(children: [
                    Icon(Icons.error_outline,
                        color: Colors.red[300], size: 48),
                    const SizedBox(height: 12),
                    Text(_errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _errorMessage = null;
                        });
                        _loadData();
                      },
                      child: const Text('Coba Lagi'),
                    ),
                  ]),
                ),
              ),
            )
          else if (_filteredProducts.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(children: [
                    Icon(Icons.inventory_2_outlined,
                        color: Colors.grey[300], size: 48),
                    const SizedBox(height: 12),
                    Text('Belum ada produk di kategori ini',
                        style: TextStyle(color: Colors.grey[500])),
                  ]),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = _filteredProducts[index];
                    return _ProductCard(
                      product: product,
                      isWishlisted:
                          _wishlistItems.contains(product.id),
                      onWishlistTap: () {
                        setState(() {
                          if (_wishlistItems.contains(product.id)) {
                            _wishlistItems.remove(product.id);
                          } else {
                            _wishlistItems.add(product.id);
                          }
                        });
                      },
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ProductDetailPage(product: product),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    );
                  },
                  childCount: _filteredProducts.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // ─────────── NAVBAR ───────────
      bottomNavigationBar: CustomNavBar(
        selectedIndex: _selectedNavItem,
        onItemTapped: (index) {
          if (index == _selectedNavItem) return;
          if (index == 1) {
            // Inventory/Search tab
            setState(() => _selectedNavItem = 1);
            Navigator.of(context)
                .push(PageRouteBuilder(
                  pageBuilder: (_, __, ___) =>
                      const InventoryPage(),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ))
                .then((_) {
              if (mounted) setState(() => _selectedNavItem = 0);
            });
          } else if (index == 3) {
            // Dashboard/Analytics tab
            setState(() => _selectedNavItem = 3);
            Navigator.of(context)
                .push(PageRouteBuilder(
                  pageBuilder: (_, __, ___) =>
                      const DashboardPage(),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ))
                .then((_) {
              if (mounted) setState(() => _selectedNavItem = 0);
            });
          } else if (index == 2) {
            // Show cart modal
            _showCartModal(context);
          } else {
            // index 4 (Profile)
            setState(() => _selectedNavItem = 4);
            Navigator.of(context)
                .push(PageRouteBuilder(
                  pageBuilder: (_, __, ___) =>
                      const ProfilePage(),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ))
                .then((_) {
              if (mounted) setState(() => _selectedNavItem = 0);
            });
          }
        },
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2979FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2979FF) : const Color(0xFFBDD7FF),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: const Color(0xFF2979FF).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isWishlisted,
    required this.onWishlistTap,
    required this.onTap,
  });

  final Product product;
  final bool isWishlisted;
  final VoidCallback onWishlistTap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
                          color: Colors.white.withValues(alpha: 0.9),
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

class SlidingNotificationBanner extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const SlidingNotificationBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  @override
  State<SlidingNotificationBanner> createState() => _SlidingNotificationBannerState();
}

class _SlidingNotificationBannerState extends State<SlidingNotificationBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();
    
    // Auto-exit after 3.5 seconds
    Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFBDD7FF),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EFFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFF2979FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Peringatan Stok Rendah!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'models.dart';
import 'cart_manager.dart';
import 'inventory_page.dart';
import 'dashboard_page.dart';
import 'pos_page.dart';
import 'widgets/navbar.dart';
import 'profile_page.dart';
import 'notification_service.dart';
import 'product_detail_page.dart';
import 'product_search_page.dart';
import 'notification_page.dart';

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
  bool _lowStockDialogShownThisSession = false;
  StreamSubscription<AuthState>? _authStateSubscription;

  // Sales Insights
  int _outOfStockCount = 0;
  int _lowStockCount = 0;
  int _itemsSoldCount = 0;
  double _totalProfit = 0.0;
  bool _isProfitVisible = true;
  List<Map<String, dynamic>> _allTransactions = [];
  String _selectedPeriod = 'Hari';



  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadData();
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
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
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
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
    _fetchSalesInsights();
    await _fetchProducts();
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
    } catch (e, stack) {
      debugPrint('[SiKulak] Error in _fetchProfile: $e\n$stack');
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

  Future<void> _fetchSalesInsights() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      // 1. Fetch inventories for out-of-stock and low stock
      final inventoriesResponse = await supabase
          .from('inventories')
          .select('qty_available')
          .eq('user_id', userId);

      final invList = inventoriesResponse as List;
      int outOfStock = 0;
      int lowStock = 0;
      for (final item in invList) {
        final stock = (item['qty_available'] as num?)?.toInt() ?? 0;
        if (stock == 0) {
          outOfStock++;
        } else if (stock <= 5) {
          lowStock++;
        }
      }

      // 2. Fetch transactions & transaction items for items sold and profit
      final transactionsResponse = await supabase
          .from('pos_orders')
          .select('total_profit, created_at, pos_order_items(qty, price_at_sale, profit_at_sale, inventories(capital_price))')
          .eq('user_id', userId);

      final txList = (transactionsResponse as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (mounted) {
        setState(() {
          _outOfStockCount = outOfStock;
          _lowStockCount = lowStock;
          _allTransactions = txList;
          _updateInsightsForPeriod();
        });
      }
    } catch (e) {
      debugPrint('[SiKulak] Error fetching sales insights: $e');
    }
  }

  void _updateInsightsForPeriod() {
    double totalProfit = 0.0;
    int itemsSold = 0;
    final now = DateTime.now();

    for (final tx in _allTransactions) {
      final txCreatedAt = tx['created_at'];
      if (txCreatedAt == null) continue;
      final txDate = DateTime.tryParse(txCreatedAt.toString())?.toLocal();
      if (txDate == null) continue;

      bool match = false;
      if (_selectedPeriod == 'Hari') {
        match = txDate.year == now.year && txDate.month == now.month && txDate.day == now.day;
      } else if (_selectedPeriod == 'Bulan') {
        match = txDate.year == now.year && txDate.month == now.month;
      } else if (_selectedPeriod == 'Tahun') {
        match = txDate.year == now.year;
      }

      if (match) {
        double txProfit = 0.0;
        final items = tx['pos_order_items'] as List? ?? [];
        for (final item in items) {
          final qty = (item['qty'] as num?)?.toInt() ?? 0;
          final price = (item['price_at_sale'] as num?)?.toDouble() ?? 0.0;
          final inv = item['inventories'] as Map<String, dynamic>?;
          final capital = (inv?['capital_price'] as num?)?.toDouble() ??
                          (item['profit_at_sale'] != null ? (price - (item['profit_at_sale'] as num).toDouble()) : (price * 0.90));
          txProfit += (price - capital) * qty;
          itemsSold += qty;
        }
        totalProfit += txProfit;
      }
    }

    _totalProfit = totalProfit;
    _itemsSoldCount = itemsSold;
  }

  Widget _buildPeriodButton(String period) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
          _updateInsightsForPeriod();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2979FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          period,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
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

  Future<bool> _shouldInsertNotification({
    required String userId,
    required InventoryItem item,
    required String notifType,
  }) async {
    final lastNotif = await supabase
        .from('notifications')
        .select('type, created_at')
        .eq('user_id', userId)
        .eq('related_inventory_id', item.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (lastNotif == null) return true;

    final lastType = lastNotif['type']?.toString();
    final lastCreatedAt = DateTime.tryParse(lastNotif['created_at']?.toString() ?? '');

    if (lastType != notifType) return true;

    if (item.updatedAt != null && lastCreatedAt != null) {
      return item.updatedAt!.isAfter(lastCreatedAt);
    }

    return false;
  }

// ── Low stock check (from inventories table) ───────────────
  Future<void> _checkLowStock() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch items with qty_available <= 10 from the database.
      final data = await supabase
          .from('inventories')
          .select()
          .eq('user_id', userId)
          .lte('qty_available', 10)
          .order('qty_available', ascending: true);

      if (!mounted) return;

      final items = (data as List)
          .map((j) => InventoryItem.fromJson(j))
          .toList()
        ..sort((a, b) {
          final aOut = a.qtyAvailable == 0;
          final bOut = b.qtyAvailable == 0;
          if (aOut != bOut) {
            return aOut ? -1 : 1;
          }
          return a.qtyAvailable.compareTo(b.qtyAvailable);
        });

      if (items.isNotEmpty) {
        final List<InventoryItem> notifiedItems = [];
        try {
          for (final item in items) {
            final notifTitle = item.qtyAvailable == 0
                ? 'Stock ${item.name} Habis'
                : 'Stock ${item.name} Rendah';
            final notifBody = item.qtyAvailable == 0
                ? 'Segera tambah stock ${item.name} (stok habis)'
                : 'Segera tambah stock ${item.name}';
            final notifType = item.qtyAvailable == 0 ? 'out_of_stock' : 'low_stock';
            final shouldInsert = await _shouldInsertNotification(
              userId: userId,
              item: item,
              notifType: notifType,
            );
            if (!shouldInsert) continue;

            await supabase.from('notifications').insert({
              'user_id': userId,
              'title': notifTitle,
              'body': notifBody,
              'type': notifType,
              'related_inventory_id': item.id,
              'is_read': false,
              'created_at': DateTime.now().toUtc().toIso8601String(),
            });
            notifiedItems.add(item);
          }
        } catch (e) {
          debugPrint('[ERROR] _checkLowStock insert notification: $e');
        }

        if (notifiedItems.isNotEmpty) {
          for (final item in notifiedItems) {
            NotificationService().showLowStockNotification(
              itemName: item.name,
              qty: item.qtyAvailable,
            );
          }
        }

        if (!_lowStockDialogShownThisSession) {
          _lowStockDialogShownThisSession = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showLowStockDialog(items);
          });
        }
      }
    } catch (e) {
      debugPrint('[ERROR] _checkLowStock: $e');
    }
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
      double totalProfit = 0.0;
      for (final entry in _cart.items.entries) {
        final item = entry.value;
        totalProfit += (item.price - item.capitalPrice) * item.quantity;
      }

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
          'profit_at_purchase': cartItem.price - cartItem.capitalPrice,
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
              .update({
                'qty_available': newQty,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
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
                    final label = isOut ? 'Habis' : 'Stok Menipis';
                    final labelColor = isOut ? Colors.red[700] : Colors.orange[800];
                    final labelBg = isOut ? Colors.red[100] : Colors.orange[100];
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
                                      color: labelBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: labelColor,
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
                              const SizedBox(height: 4),
                              Text(
                                '${item.qtyAvailable} Sachet tersisa',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
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
                                              capitalPrice: entry.capitalPrice,
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

  void _handleTabSelection(int index) {
    if (index == _selectedNavItem) return;
    if (index == 0) {
      if (mounted) {
        setState(() {
          _selectedNavItem = 0;
        });
        _fetchProfile();
        _fetchSalesInsights();
      }
    } else if (index == 1) {
      setState(() => _selectedNavItem = 1);
      Navigator.of(context)
          .push(PageRouteBuilder(
            pageBuilder: (_, __, ___) => const InventoryPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ))
          .then((result) {
        if (mounted) {
          if (result is int) {
            _handleTabSelection(result);
          } else {
            setState(() => _selectedNavItem = 0);
            _fetchProfile();
            _fetchSalesInsights();
          }
        }
      });
    } else if (index == 3) {
      setState(() => _selectedNavItem = 3);
      Navigator.of(context)
          .push(PageRouteBuilder(
            pageBuilder: (_, __, ___) => const DashboardPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ))
          .then((result) {
        if (mounted) {
          if (result is int) {
            _handleTabSelection(result);
          } else {
            setState(() => _selectedNavItem = 0);
            _fetchProfile();
            _fetchSalesInsights();
          }
        }
      });
    } else if (index == 2) {
      setState(() => _selectedNavItem = 2);
      Navigator.of(context)
          .push(PageRouteBuilder(
            pageBuilder: (_, __, ___) => const PosPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ))
          .then((result) {
        if (mounted) {
          if (result is int) {
            _handleTabSelection(result);
          } else {
            setState(() => _selectedNavItem = 0);
            _fetchProfile();
            _fetchSalesInsights();
          }
        }
      });
    } else if (index == 4) {
      setState(() => _selectedNavItem = 4);
      Navigator.of(context)
          .push(PageRouteBuilder(
            pageBuilder: (_, __, ___) => const ProfilePage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ))
          .then((result) {
        if (mounted) {
          if (result is int) {
            _handleTabSelection(result);
          } else {
            setState(() => _selectedNavItem = 0);
            _fetchProfile();
            _fetchSalesInsights();
          }
        }
      });
    }
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
                            onTap: () => _handleTabSelection(4),
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
                        child: _buildNotificationBadgeIcon(),
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

          // ─────────── SALES ACTIVITY SECTION ───────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sales Activity',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2979FF),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPeriodButton('Hari'),
                            _buildPeriodButton('Bulan'),
                            _buildPeriodButton('Tahun'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Total Keuntungan Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D3365), Color(0xFF2979FF)],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedPeriod == 'Hari'
                                    ? 'Keuntungan Hari Ini'
                                    : _selectedPeriod == 'Bulan'
                                        ? 'Keuntungan Bulan Ini'
                                        : 'Keuntungan Tahun Ini',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _isProfitVisible
                                      ? '${CartManager.formatPrice(_totalProfit)},00'
                                      : 'Rp. ••••••',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isProfitVisible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: () {
                            setState(() {
                              _isProfitVisible = !_isProfitVisible;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // 3 Small Cards Row
                  Row(
                    children: [
                      // Out of Stock Card
                      Expanded(
                        child: _buildInsightCard(
                          title: 'Out of Stock',
                          titleColor: const Color(0xFFFF5252),
                          value: '$_outOfStockCount',
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Item Sold Card
                      Expanded(
                        child: _buildInsightCard(
                          title: 'Item Sold',
                          titleColor: Colors.white,
                          value: '$_itemsSoldCount',
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Low Stock Card
                      Expanded(
                        child: _buildInsightCard(
                          title: 'Low Stock',
                          titleColor: const Color(0xFFFFD54F),
                          value: '$_lowStockCount',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
        onItemTapped: _handleTabSelection,
      ),
    );
  }

  Widget _buildInsightCard({
    required String title,
    required Color titleColor,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF092552), Color(0xFF1976D2)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Qty',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
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

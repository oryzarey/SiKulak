import 'dart:async';
import 'package:sikulak/widgets/glass_container.dart';

import 'widgets/app_header.dart';
import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'main.dart';
import 'models.dart';
import 'notification_page.dart';
import 'sales_checkout_page.dart';
import 'widgets/navbar.dart';

class PosPage extends StatefulWidget {
	const PosPage({super.key});

	@override
	State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
	final CartManager _cart = CartManager();
	final TextEditingController _searchController = TextEditingController();

	Timer? _debounce;
	StreamSubscription? _authStateSubscription;
	List<InventoryItem> _inventoryItems = [];
	List<Map<String, dynamic>> _transactions = [];
	List<Map<String, dynamic>> _bestSellers = [];
	Map<String, int> _salesCountMap = {};

	bool _isLoadingInventory = true;
	bool _isLoadingTransactions = true;
	bool _isLoadingBestSellers = true;
	bool _isRefreshing = false;
	String? _errorMessage;
	String _userName = 'User';
	String _selectedTab = 'Stock';
	String _stockFilter = 'Semua';
	String _salesTimeframe = 'Harian';

	final List<String> _stockFilters = const [
		'Semua',
		'Stok Tersedia',
		'Stok Sedikit',
		'Stok Habis',
	];

	final List<String> _salesTimeframes = const [
		'Harian',
		'Mingguan',
		'Bulanan',
		'Tahunan',
	];

	@override
	void initState() {
		super.initState();
		_authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
			if (!mounted) return;
			if (data.session != null) {
				setState(() {});
				_loadInitialData();
			}
		});
		_loadInitialData();
	}

	Stream<List<Map<String, dynamic>>> _notificationStream() {
		final userId = _currentUserId;
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
										builder: (_) => NotificationPage(onNotificationsMarkedRead: () {}),
									),
								);
								if (mounted) {
									setState(() {});
								}
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
		_debounce?.cancel();
		_authStateSubscription?.cancel();
		_searchController.dispose();
		super.dispose();
	}

	dynamic get _authUser => supabase.auth.currentUser ?? supabase.auth.currentSession?.user;
	String? get _currentUserId => _authUser?.id as String?;

	Future<void> _loadInitialData() async {
		await Future.wait([
			_fetchProfile(),
			_fetchInventoryItems(),
			_fetchTransactions(),
			_fetchBestSellers(),
		]);
	}

	Future<void> _refreshAll() async {
		if (!mounted) return;
		setState(() {
			_isRefreshing = true;
			_errorMessage = null;
		});

		await _loadInitialData();

		if (!mounted) return;
		setState(() {
			_isRefreshing = false;
		});
	}

	Future<void> _fetchProfile() async {
		try {
			final userId = _currentUserId;
			if (userId == null) {
				_setUserNameFromAuth();
				return;
			}

			final data = await supabase
					.from('profiles')
					.select('full_name')
					.eq('id', userId)
					.maybeSingle();

			if (!mounted) return;

			if (data != null) {
				final raw = (data['full_name'] ?? '').toString();
				setState(() {
					_userName = raw.isNotEmpty
							? (raw.length > 12 ? '${raw.substring(0, 12)}...' : raw)
							: _userName;
				});
			} else {
				_setUserNameFromAuth();
			}
		} catch (_) {
			_setUserNameFromAuth();
		}
	}

	Stream<UserProfile?> _profileStream() {
		final userId = _currentUserId;
		if (userId == null) return const Stream.empty();
		return supabase
				.from('profiles')
				.stream(primaryKey: ['id'])
				.eq('id', userId)
				.map((data) => data.isNotEmpty ? UserProfile.fromJson(data.first) : null);
	}

	void _setUserNameFromAuth() {
		final user = _authUser;
		if (user == null) return;
		final meta = user.userMetadata;
		final raw = (meta?['full_name'] ?? meta?['nama'] ?? meta?['name'] ?? user.email ?? 'User')
				.toString()
				.split('@')
				.first;

		if (!mounted) return;
		setState(() {
			_userName = raw.length > 12 ? '${raw.substring(0, 12)}...' : raw;
		});
	}

	Future<void> _ensureInventorySeeded() async {
		try {
			final userId = _currentUserId;
			if (userId == null) return;

			final existing = await supabase
					.from('inventories')
					.select('id')
					.eq('user_id', userId)
					.limit(1);

			if ((existing as List).isNotEmpty) return;

			final globalProducts = await supabase.from('products').select('*, categories(id, name)');
			final products = globalProducts as List;

			for (final p in products) {
				final price = (p['price'] as num?)?.toDouble() ?? 10000.0;
				
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

				await supabase.from('inventories').insert({
					'user_id': userId,
					'name': p['name'],
					'qty_available': (p['stock'] as num?)?.toInt() ?? 15,
					'capital_price': price * 0.90,
					'selling_price': price,
					'exp_date': null,
					'image_url': p['image_url'],
					'brand': p['brand'],
					'rating': p['rating'],
					'lead_time': p['lead_time'],
					'category_id': p['category_id'],
					'category_name': catName.isNotEmpty ? catName : (p['category_name'] ?? ''),
				});
			}
		} catch (e) {
			debugPrint('[SiKulak] Inventory seed skipped: $e');
		}
	}

	Future<void> _fetchInventoryItems() async {
		try {
			final userId = _currentUserId;
			if (userId == null) {
				if (!mounted) return;
				setState(() {
					_inventoryItems = [];
					_isLoadingInventory = false;
					_errorMessage = 'Menunggu sesi login...';
				});
				return;
			}

			await _ensureInventorySeeded();

			// Fetch global products for fallbacks
			final globalProductsData = await supabase.from('products').select('name, image_url');
			final Map<String, String> nameToImage = {};
			for (final p in globalProductsData as List) {
				final name = (p['name'] ?? '') as String;
				final imageUrl = p['image_url'] as String?;
				if (name.isNotEmpty && imageUrl != null && imageUrl.isNotEmpty) {
					nameToImage[name] = imageUrl;
				}
			}

			final data = await supabase
					.from('inventories')
					.select()
					.eq('user_id', userId)
					.order('name');

			if (!mounted) return;
			final list = data as List;
			final mappedItems = list.map((json) {
				final name = (json['name'] ?? '') as String;
				final imageUrl = json['image_url'] as String?;
				if ((imageUrl == null || imageUrl.isEmpty) && nameToImage.containsKey(name)) {
					final mutableJson = Map<String, dynamic>.from(json);
					mutableJson['image_url'] = nameToImage[name];
					return InventoryItem.fromJson(mutableJson);
				}
				return InventoryItem.fromJson(json);
			}).toList();

			setState(() {
				_inventoryItems = mappedItems;
				_isLoadingInventory = false;
				_errorMessage = null;
			});
		} catch (e) {
			debugPrint('[SiKulak] Error loading inventory for POS: $e');
			if (!mounted) return;
			setState(() {
				_inventoryItems = [];
				_isLoadingInventory = false;
				_errorMessage = 'Gagal memuat data stok: $e';
			});
		}
	}

	Future<void> _fetchTransactions() async {
		try {
			final userId = _currentUserId;
			debugPrint('[SiKulak] _fetchTransactions - userId: $userId');
			if (userId == null) {
				if (!mounted) return;
				setState(() {
					_transactions = [];
					_isLoadingTransactions = false;
				});
				return;
			}

			// Fetch pos_orders simple dulu
			debugPrint('[SiKulak] Fetching pos_orders...');
			final data = await supabase
				.from('pos_orders')
				.select('*')
				.eq('user_id', userId)
				.order('created_at', ascending: false)
				.limit(150);

			debugPrint('[SiKulak] Raw data: $data');
			debugPrint('[SiKulak] Fetched ${(data as List).length} orders');

			// Untuk setiap order, fetch items
			final List<Map<String, dynamic>> ordersWithItems = [];
			for (final order in data as List) {
				final orderId = order['id'];
				debugPrint('[SiKulak] Processing order: $orderId');
				try {
					final items = await supabase
						.from('pos_order_items')
						.select('*, inventories(id, name, image_url, capital_price)')
						.eq('order_id', orderId);
					
					order['pos_order_items'] = items;

					// Calculate actual profit on the fly for backwards compatibility with old records
					double calculatedProfit = 0.0;
					for (final it in items) {
						final qty = (it['qty'] as num?)?.toInt() ?? 0;
						final price = (it['price_at_sale'] as num?)?.toDouble() ?? 0.0;
						final capital = (it['inventories']?['capital_price'] as num?)?.toDouble() ?? 
										(it['profit_at_sale'] != null ? (price - (it['profit_at_sale'] as num).toDouble()) : (price * 0.90));
						calculatedProfit += (price - capital) * qty;
					}
					order['total_profit'] = calculatedProfit;

					debugPrint('[SiKulak] Order $orderId has ${(items as List).length} items');
				} catch (itemsError) {
					debugPrint('[SiKulak] Error fetching items for order $orderId: $itemsError');
					order['pos_order_items'] = [];
				}
				ordersWithItems.add(order as Map<String, dynamic>);
			}

			debugPrint('[SiKulak] Total orders with items: ${ordersWithItems.length}');

			if (!mounted) return;
			setState(() {
				_transactions = ordersWithItems;
				_isLoadingTransactions = false;
			});
		} catch (e) {
			debugPrint('[SiKulak] Error loading POS transactions: $e');
			debugPrint('[SiKulak] Stack trace: ${StackTrace.current}');
			if (!mounted) return;
			setState(() {
				_transactions = [];
				_isLoadingTransactions = false;
			});
		}
	}

	Future<void> _fetchBestSellers() async {
		try {
			final userId = _currentUserId;
			if (userId == null) {
				if (!mounted) return;
				setState(() {
					_bestSellers = [];
					_salesCountMap = {};
					_isLoadingBestSellers = false;
				});
				return;
			}

			// Fetch global products for fallbacks
			final globalProductsData = await supabase.from('products').select('name, image_url');
			final Map<String, String> nameToImage = {};
			for (final p in globalProductsData as List) {
				final name = (p['name'] ?? '') as String;
				final imageUrl = p['image_url'] as String?;
				if (name.isNotEmpty && imageUrl != null && imageUrl.isNotEmpty) {
					nameToImage[name] = imageUrl;
				}
			}

			// Fetch all pos_order_items for this user's orders
			final data = await supabase
					.from('pos_order_items')
					.select('qty, inventories!inner(id, name, image_url, selling_price, qty_available, user_id, lead_time)')
					.eq('inventories.user_id', userId);

			final List<Map<String, dynamic>> itemsList = List<Map<String, dynamic>>.from(data as List);

			// Group by inventory_id and sum qty
			final Map<String, Map<String, dynamic>> grouped = {};
			final Map<String, int> salesMap = {};
			for (final item in itemsList) {
				final inv = item['inventories'] as Map<String, dynamic>?;
				if (inv == null) continue;

				final String id = inv['id']?.toString() ?? '';
				if (id.isEmpty) continue;

				final int qty = (item['qty'] as num?)?.toInt() ?? 0;
				salesMap[id] = (salesMap[id] ?? 0) + qty;

				final name = inv['name']?.toString() ?? 'Produk';
				String? imageUrl = inv['image_url']?.toString();
				if ((imageUrl == null || imageUrl.isEmpty) && nameToImage.containsKey(name)) {
					imageUrl = nameToImage[name];
				}

				if (grouped.containsKey(id)) {
					grouped[id]!['total_sold'] = (grouped[id]!['total_sold'] as int) + qty;
				} else {
					grouped[id] = {
						'id': id,
						'name': name,
						'image_url': imageUrl,
						'selling_price': (inv['selling_price'] as num?)?.toDouble() ?? 0.0,
						'qty_available': (inv['qty_available'] as num?)?.toInt() ?? 0,
						'lead_time': (inv['lead_time'] as num?)?.toInt() ?? 0,
						'total_sold': qty,
					};
				}
			}

			// Convert to list and sort by total_sold descending
			final sortedList = grouped.values.toList()
				..sort((a, b) => (b['total_sold'] as int).compareTo(a['total_sold'] as int));

			if (!mounted) return;
			setState(() {
				_salesCountMap = salesMap;
				_bestSellers = sortedList;
				_isLoadingBestSellers = false;
			});
		} catch (e) {
			debugPrint('[SiKulak] Error loading best sellers: $e');
			if (!mounted) return;
			setState(() {
				_bestSellers = [];
				_salesCountMap = {};
				_isLoadingBestSellers = false;
			});
		}
	}

	List<Map<String, dynamic>> get _filteredBestSellers {
		final query = _searchController.text.trim().toLowerCase();
		if (query.isEmpty) return _bestSellers;
		return _bestSellers.where((item) {
			final name = (item['name'] as String? ?? '').toLowerCase();
			return name.contains(query);
		}).toList();
	}

	void _onSearchChanged(String value) {
		_debounce?.cancel();
		_debounce = Timer(const Duration(milliseconds: 250), () {
			if (mounted) setState(() {});
		});
	}

	List<InventoryItem> get _filteredItems {
		final query = _searchController.text.trim().toLowerCase();
		final filtered = _inventoryItems.where((item) {
			final matchesQuery = query.isEmpty || item.name.toLowerCase().contains(query);
			final matchesFilter = switch (_stockFilter) {
				'Stok Tersedia' => item.qtyAvailable > 10,
				'Stok Sedikit' => item.qtyAvailable > 0 && item.qtyAvailable <= 10,
				'Stok Habis' => item.qtyAvailable == 0,
				_ => true,
			};
			return matchesQuery && matchesFilter;
		}).toList();

		filtered.sort((a, b) {
			final aSales = _salesCountMap[a.id] ?? 0;
			final bSales = _salesCountMap[b.id] ?? 0;
			if (aSales != bSales) {
				return bSales.compareTo(aSales);
			}
			return a.name.toLowerCase().compareTo(b.name.toLowerCase());
		});

		return filtered;
	}

	int get _lowStockCount =>
			_inventoryItems.where((item) => item.qtyAvailable > 0 && item.qtyAvailable <= 5).length;

	int get _outOfStockCount =>
			_inventoryItems.where((item) => item.qtyAvailable == 0).length;

	Future<void> _addItemToCart(InventoryItem item) async {
		final currentQty = _cart.quantityOf(item.id);
		if (item.qtyAvailable <= 0) {
			_showSnackBar('Stok barang habis.');
			return;
		}
		if (currentQty >= item.qtyAvailable) {
			_showSnackBar('Jumlah melebihi stok tersedia.');
			return;
		}

		setState(() {
			_cart.add(
				item.id,
				name: item.name,
				price: item.sellingPrice,
				capitalPrice: item.capitalPrice,
				imageUrl: item.imageUrl,
			);
		});
	}

	void _removeItemFromCart(String productId) {
		if (_cart.quantityOf(productId) == 0) return;
		setState(() {
			_cart.remove(productId);
		});
	}

	void _showSnackBar(String message) {
		if (!mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text(message)),
		);
	}

	Future<void> _openCheckoutPage() async {
		if (_cart.isEmpty) {
			_showSnackBar('Keranjang masih kosong.');
			return;
		}

		final result = await Navigator.of(context).push<bool>(
			MaterialPageRoute(builder: (_) => const SalesCheckoutPage()),
		);

		if (result == true) {
			await _refreshAll();
			if (!mounted) return;
			setState(() => _selectedTab = 'Riwayat Penjualan');
			_showSnackBar('Penjualan berhasil dicatat.');
		}
	}

	static const List<String> _monthNames = [
		'Januari',
		'Februari',
		'Maret',
		'April',
		'Mei',
		'Juni',
		'Juli',
		'Agustus',
		'September',
		'Oktober',
		'November',
		'Desember',
	];

	String _monthName(int month) {
		if (month < 1 || month > 12) return '-';
		return _monthNames[month - 1];
	}

	String _historyGroupKey(DateTime date) {
		switch (_salesTimeframe) {
			case 'Mingguan':
				final weekOfMonth = ((date.day - 1) ~/ 7) + 1;
				return '${date.year}-${date.month.toString().padLeft(2, '0')}-W$weekOfMonth';
			case 'Bulanan':
				return '${date.year}-${date.month.toString().padLeft(2, '0')}';
			case 'Tahunan':
				return '${date.year}';
			case 'Harian':
			default:
				return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
		}
	}

	String _historyGroupLabel(DateTime date) {
		switch (_salesTimeframe) {
			case 'Mingguan':
				final weekOfMonth = ((date.day - 1) ~/ 7) + 1;
				return '${_monthName(date.month)} ${date.year} (Minggu $weekOfMonth)';
			case 'Bulanan':
				return '${_monthName(date.month)} ${date.year}';
			case 'Tahunan':
				return '${date.year}';
			case 'Harian':
			default:
				return '${date.day} ${_monthName(date.month)} ${date.year}';
		}
	}

	Widget _buildHistoryGroupHeader(String label) {
		return Padding(
			padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
			child: Row(
				children: [
					const Icon(Icons.expand_more, size: 18, color: Colors.black87),
					const SizedBox(width: 8),
					Text(
						label,
						style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
					),
				],
			),
		);
	}

	Color _stockColor(InventoryItem item) {
		if (item.qtyAvailable == 0) return const Color(0xFFDC2626); // Merah - Habis
		if (item.qtyAvailable <= item.safetyStock) return const Color(0xFFEAB308); // Kuning - Di bawah Safety Stock
		return const Color(0xFF16A34A); // Hijau - Aman
	}

	String _stockLabel(int qty, String satuan) {
		if (qty == 0) return '0 $satuan';
		return '$qty $satuan';
	}


	Widget _buildSearchPanel() {
		return Container(
			margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
			padding: const EdgeInsets.all(12),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(18),
				boxShadow: [
					BoxShadow(
						color: Colors.black.withValues(alpha: 0.06),
						blurRadius: 18,
						offset: const Offset(0, 8),
					),
				],
			),
			child: Column(
				children: [
					Container(
						height: 50,
						padding: const EdgeInsets.symmetric(horizontal: 14),
						decoration: BoxDecoration(
							color: const Color(0xFFF8FAFC),
							borderRadius: BorderRadius.circular(16),
							border: Border.all(color: const Color(0xFF2979FF).withValues(alpha: 0.18)),
						),
						child: Row(
							children: [
								const Icon(Icons.search_rounded, color: Color(0xFF2979FF), size: 28),
								const SizedBox(width: 10),
								Expanded(
									child: TextField(
										controller: _searchController,
										onChanged: _onSearchChanged,
										decoration: const InputDecoration(
											hintText: 'Cari barang anda',
											hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
											border: InputBorder.none,
										),
									),
								),
								GestureDetector(
									onTap: _showStockFilterSheet,
									child: const Icon(Icons.filter_alt_rounded, color: Color(0xFF2979FF), size: 26),
								),
							],
						),
					),
					const SizedBox(height: 12),
					Row(
						children: [
							Expanded(
								child: _buildTabButton('Stock', _selectedTab == 'Stock', () {
									setState(() => _selectedTab = 'Stock');
								}),
							),
							const SizedBox(width: 8),
							Expanded(
								child: _buildTabButton('Riwayat Penjualan', _selectedTab == 'Riwayat Penjualan', () {
									setState(() => _selectedTab = 'Riwayat Penjualan');
								}),
							),
							const SizedBox(width: 8),
							Expanded(
								child: _buildTabButton('Sering Terjual', _selectedTab == 'Sering Terjual', () {
									setState(() => _selectedTab = 'Sering Terjual');
								}),
							),
						],
					),
				],
			),
		);
	}

	Widget _buildTabButton(String label, bool isSelected, VoidCallback onTap) {
		return GestureDetector(
			onTap: onTap,
			child: AnimatedContainer(
				duration: const Duration(milliseconds: 220),
				padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
				decoration: BoxDecoration(
					color: isSelected ? const Color(0xFF2979FF) : Colors.white,
					borderRadius: BorderRadius.circular(999),
					border: Border.all(color: const Color(0xFF2979FF), width: 1.2),
					boxShadow: isSelected
						? [
							BoxShadow(
								color: const Color(0xFF2979FF).withValues(alpha: 0.16),
								blurRadius: 10,
								offset: const Offset(0, 6),
							),
						]
						: [
							BoxShadow(
								color: Colors.black.withValues(alpha: 0.03),
								blurRadius: 6,
								offset: const Offset(0, 2),
							),
						],
				),
				child: Text(
					label,
					textAlign: TextAlign.center,
					style: TextStyle(
						color: isSelected ? Colors.white : const Color(0xFF2979FF),
						fontSize: 12,
						fontWeight: FontWeight.w800,
					),
				),
			),
		);
	}

	void _showStockFilterSheet() {
		showModalBottomSheet(
			context: context,
			backgroundColor: Colors.white,
			shape: const RoundedRectangleBorder(
				borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
			),
			builder: (context) => Padding(
				padding: const EdgeInsets.all(20),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const Text(
							'Filter Stok',
							style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
						),
						const SizedBox(height: 16),
						Wrap(
							spacing: 10,
							runSpacing: 10,
							children: _stockFilters.map((filter) {
								final selected = _stockFilter == filter;
								return ChoiceChip(
									label: Text(filter),
									selected: selected,
									onSelected: (_) {
										setState(() => _stockFilter = filter);
										Navigator.pop(context);
									},
								);
							}).toList(),
						),
						const SizedBox(height: 10),
					],
				),
			),
		);
	}

	List<Widget> _buildStockSlivers() {
		if (_isLoadingInventory && !_isRefreshing) {
			return const [
				SliverToBoxAdapter(
					child: Padding(
						padding: EdgeInsets.only(top: 60),
						child: Center(child: CircularProgressIndicator()),
					),
				),
			];
		}

		if (_errorMessage != null && _inventoryItems.isEmpty) {
			return [
				SliverToBoxAdapter(
					child: Padding(
						padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
						child: Text(
							_errorMessage!,
							textAlign: TextAlign.center,
							style: const TextStyle(color: Colors.redAccent),
						),
					),
				),
			];
		}

		final items = _filteredItems;

		if (items.isEmpty) {
			return [
				SliverToBoxAdapter(
					child: Padding(
						padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
						child: Container(
							padding: const EdgeInsets.all(24),
							decoration: BoxDecoration(
								color: Colors.white,
								borderRadius: BorderRadius.circular(18),
							),
							child: const Column(
								children: [
									Icon(Icons.inventory_2_outlined, size: 48, color: Colors.black26),
									SizedBox(height: 12),
									Text(
										'Tidak ada barang yang cocok.',
										style: TextStyle(fontWeight: FontWeight.w600),
									),
								],
							),
						),
					),
				),
			];
		}

		return [
			SliverToBoxAdapter(
				child: Padding(
					padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
					child: Row(
						children: [
							Expanded(
								child: _buildStatCard(
									'Total Barang',
									'${_inventoryItems.length}',
									const Color(0xFF2979FF),
								),
							),
							const SizedBox(width: 10),
							Expanded(
								child: _buildStatCard(
									'Stok Rendah',
									'$_lowStockCount',
									const Color(0xFFF59E0B),
								),
							),
							const SizedBox(width: 10),
							Expanded(
								child: _buildStatCard(
									'Habis',
									'$_outOfStockCount',
									const Color(0xFFEF4444),
								),
							),
						],
					),
				),
			),
			SliverPadding(
				padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
				sliver: SliverList(
					delegate: SliverChildBuilderDelegate(
						(context, index) => Padding(
							padding: const EdgeInsets.only(bottom: 12),
							child: _buildInventoryCard(items[index]),
						),
						childCount: items.length,
					),
				),
			),
		];
	}

	Widget _buildStatCard(String label, String value, Color color) {
		return Container(
			padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(16),
				boxShadow: [
					BoxShadow(
						color: Colors.black.withValues(alpha: 0.05),
						blurRadius: 12,
						offset: const Offset(0, 6),
					),
				],
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(
						label,
						style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
					),
					const SizedBox(height: 8),
					Text(
						value,
						style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w800),
						maxLines: 1,
						overflow: TextOverflow.ellipsis,
					),
				],
			),
		);
	}

	Widget _buildInventoryCard(InventoryItem item) {
		final cartQty = _cart.quantityOf(item.id);
		final hasImage = (item.imageUrl ?? '').trim().isNotEmpty;

		return Container(
			padding: const EdgeInsets.all(12),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(18),
				boxShadow: [
					BoxShadow(
						color: Colors.black.withValues(alpha: 0.08),
						blurRadius: 14,
						offset: const Offset(0, 6),
					),
				],
			),
			child: Row(
				children: [
					Container(
						width: 72,
						height: 72,
						decoration: BoxDecoration(
							color: const Color(0xFFF1F5F9),
							borderRadius: BorderRadius.circular(14),
						),
						child: hasImage
								? ClipRRect(
										borderRadius: BorderRadius.circular(14),
										child: Image.network(
											item.imageUrl!,
											fit: BoxFit.cover,
											errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_rounded, color: Color(0xFF94A3B8)),
										),
									)
								: const Icon(Icons.inventory_2_rounded, color: Color(0xFF94A3B8)),
					),
					const SizedBox(width: 14),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Row(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Expanded(
											child: Text(
												item.name,
												maxLines: 2,
												overflow: TextOverflow.ellipsis,
												style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.1),
											),
										),
										const SizedBox(width: 8),
										Text(
											CartManager.formatPrice(item.sellingPrice),
											style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
										),
									],
								),
								const SizedBox(height: 10),
								SizedBox(
									width: double.infinity,
									child: Wrap(
										spacing: 8,
										runSpacing: 6,
										alignment: WrapAlignment.spaceBetween,
										crossAxisAlignment: WrapCrossAlignment.center,
										children: [
											Container(
												padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
												decoration: BoxDecoration(
													color: _stockColor(item),
													borderRadius: BorderRadius.circular(8),
												),
												child: Text(
													_stockLabel(item.qtyAvailable, item.satuan),
													style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
												),
											),
											Container(
												decoration: BoxDecoration(
													color: const Color(0xFFF8FAFC),
													borderRadius: BorderRadius.circular(18),
													border: Border.all(color: const Color(0xFF2979FF).withValues(alpha: 0.6)),
												),
												child: Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														_buildStepperButton(
															icon: Icons.remove,
															enabled: cartQty > 0,
															onTap: () => _removeItemFromCart(item.id),
														),
														Container(
															width: 28,
															alignment: Alignment.center,
															child: Text(
																'$cartQty',
																style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
															),
														),
														_buildStepperButton(
															icon: Icons.add,
															enabled: item.qtyAvailable > cartQty,
															onTap: () => _addItemToCart(item),
														),
													],
												),
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

	Widget _buildStepperButton({
		required IconData icon,
		required bool enabled,
		required VoidCallback onTap,
	}) {
		return GestureDetector(
			onTap: enabled ? onTap : null,
			child: Container(
				width: 30,
				height: 30,
				decoration: BoxDecoration(
					color: enabled ? const Color(0xFF2979FF) : const Color(0xFFE2E8F0),
					shape: BoxShape.circle,
				),
				child: Icon(icon, color: Colors.white, size: 18),
			),
		);
	}

	List<Widget> _buildHistorySlivers() {
		if (_isLoadingTransactions && !_isRefreshing) {
			return const [
				SliverToBoxAdapter(
					child: Padding(
						padding: EdgeInsets.only(top: 60),
						child: Center(child: CircularProgressIndicator()),
					),
				),
			];
		}

		final now = DateTime.now();
		final filteredTransactions = _transactions.where((tx) {
			final createdAt = tx['created_at']?.toString();
			if (createdAt == null) return false;
			final dt = DateTime.tryParse(createdAt)?.toLocal();
			if (dt == null) return false;

			switch (_salesTimeframe) {
				case 'Harian':
					return dt.year == now.year && dt.month == now.month && dt.day == now.day;
				case 'Mingguan':
					final difference = now.difference(dt).inDays;
					return difference >= 0 && difference < 7;
				case 'Bulanan':
					return dt.year == now.year && dt.month == now.month;
				case 'Tahunan':
					return dt.year == now.year;
				default:
					return true;
			}
		}).toList();

		if (filteredTransactions.isEmpty) {
			return [
				SliverToBoxAdapter(
					child: Padding(
						padding: const EdgeInsets.fromLTRB(16, 18, 16, 2),
						child: Row(
							children: [
								Expanded(child: _buildStatCard('Penjualan', CartManager.formatPrice(0.0), const Color(0xFF2979FF))),
								const SizedBox(width: 8),
								Expanded(child: _buildStatCard('Profit', CartManager.formatPrice(0.0), const Color(0xFF16A34A))),
								const SizedBox(width: 8),
								Expanded(child: _buildStatCard('Terjual', '0', const Color(0xFFF59E0B))),
							],
						),
					),
				),
				SliverToBoxAdapter(
					child: Padding(
						padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
						child: Row(
							spacing: 10,
							mainAxisAlignment: MainAxisAlignment.spaceBetween,
							children: _salesTimeframes.map((timeframe) {
								final selected = _salesTimeframe == timeframe;
								return Expanded(
									child: GestureDetector(
										onTap: () => setState(() => _salesTimeframe = timeframe),
										child: Container(
											padding: const EdgeInsets.symmetric(vertical: 6),
											margin: const EdgeInsets.symmetric(horizontal: 2),
											decoration: BoxDecoration(
												color: selected ? const Color(0xFF2979FF) : Colors.white,
												borderRadius: BorderRadius.circular(999),
												border: Border.all(color: const Color(0xFF2979FF), width: 1),
											),
											child: Text(
												timeframe,
												textAlign: TextAlign.center,
												style: TextStyle(
													fontSize: 11,
													fontWeight: FontWeight.w700,
													color: selected ? Colors.white : const Color(0xFF2979FF),
												),
											),
										),
									),
								);
							}).toList(),
						),
					),
				),
				SliverToBoxAdapter(
					child: Padding(
						padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
						child: Center(
							child: Text(
								_transactions.isEmpty
										? 'Belum ada riwayat penjualan.'
										: 'Tidak ada penjualan untuk periode ini.',
								style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600),
							),
						),
					),
				),
			];
		}

		final totalSales = filteredTransactions.fold<double>(
			0,
			(sum, tx) => sum + ((tx['total_gross'] as num?)?.toDouble() ?? 0.0),
		);
		final totalProfit = filteredTransactions.fold<double>(
			0,
			(sum, tx) => sum + ((tx['total_profit'] as num?)?.toDouble() ?? 0.0),
		);
		final itemsSold = filteredTransactions.fold<int>(
			0,
			(sum, tx) {
				final items = tx['pos_order_items'] as List? ?? const [];
				return sum + items.fold<int>(0, (itemSum, item) {
					return itemSum + ((item['qty'] as num?)?.toInt() ?? 0);
				});
			},
		);

		final groupedTransactions = <String, List<Map<String, dynamic>>>{};
		final groupedLabels = <String, String>{};

		for (final tx in filteredTransactions) {
			final createdAt = tx['created_at']?.toString();
			final createdDate = createdAt == null ? null : DateTime.tryParse(createdAt)?.toLocal();
			final key = createdDate == null ? 'unknown' : _historyGroupKey(createdDate);
			groupedLabels[key] = createdDate == null ? 'Tanpa Tanggal' : _historyGroupLabel(createdDate);
			groupedTransactions.putIfAbsent(key, () => []).add(tx);
		}

		final historyWidgets = <Widget>[];
		for (final entry in groupedTransactions.entries) {
			historyWidgets.add(_buildHistoryGroupHeader(groupedLabels[entry.key] ?? 'Tanpa Tanggal'));
			historyWidgets.addAll(
				entry.value.map(
					(tx) => Padding(
						padding: const EdgeInsets.only(bottom: 12),
						child: _buildTransactionCard(tx),
					),
				),
			);
		}

		return [
			SliverToBoxAdapter(
				child: Padding(
					padding: const EdgeInsets.fromLTRB(16, 18, 16, 2),
					child: Row(
						children: [
							Expanded(child: _buildStatCard('Penjualan', CartManager.formatPrice(totalSales), const Color(0xFF2979FF))),
							const SizedBox(width: 8),
							Expanded(child: _buildStatCard('Profit', CartManager.formatPrice(totalProfit), const Color(0xFF16A34A))),
							const SizedBox(width: 8),
							Expanded(child: _buildStatCard('Terjual', '$itemsSold', const Color(0xFFF59E0B))),
						],
					),
				),
			),
			SliverToBoxAdapter(
				child: Padding(
					padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
					child: Row(
						spacing: 10,
						mainAxisAlignment: MainAxisAlignment.spaceBetween,
						children: _salesTimeframes.map((timeframe) {
							final selected = _salesTimeframe == timeframe;
							return Expanded(
								child: GestureDetector(
									onTap: () => setState(() => _salesTimeframe = timeframe),
									child: Container(
										padding: const EdgeInsets.symmetric(vertical: 6),
										margin: const EdgeInsets.symmetric(horizontal: 2),
										decoration: BoxDecoration(
											color: selected ? const Color(0xFF2979FF) : Colors.white,
											borderRadius: BorderRadius.circular(999),
											border: Border.all(color: const Color(0xFF2979FF), width: 1),
										),
										child: Text(
											timeframe,
											textAlign: TextAlign.center,
											style: TextStyle(
												fontSize: 11,
												fontWeight: FontWeight.w700,
												color: selected ? Colors.white : const Color(0xFF2979FF),
											),
										),
									),
								),
							);
						}).toList(),
					),
				),
			),
			SliverToBoxAdapter(
				child: Padding(
					padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
					child: Column(
						children: historyWidgets,
					),
				),
			),
		];
	}

	Widget _buildTransactionCard(Map<String, dynamic> transaction) {
		final createdAt = transaction['created_at']?.toString();
		final createdDate = createdAt == null ? null : DateTime.tryParse(createdAt);
		final items = transaction['pos_order_items'] as List? ?? const [];
		final txCode = (transaction['invoice_number'] ?? transaction['code'] ?? transaction['id'] ?? 'TRANSACTION').toString();
		final totalGross = (transaction['total_gross'] as num?)?.toDouble() ?? 0.0;

		return Container(
			margin: const EdgeInsets.only(bottom: 12),
			padding: const EdgeInsets.all(14),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(12),
				boxShadow: [
					BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
				],
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Row(
						children: [
							Expanded(
								child: Text(
									txCode.toString().toUpperCase(),
									style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
								),
							),
							if (createdDate != null)
								Text(
									'${createdDate.hour.toString().padLeft(2, '0')}:${createdDate.minute.toString().padLeft(2, '0')}',
									style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
								),
						],
					),
					const SizedBox(height: 10),
					const Divider(height: 1),
					const SizedBox(height: 10),
					...items.map((it) {
						final qty = (it['qty'] as num?)?.toInt() ?? 0;
						final price = (it['price_at_sale'] as num?)?.toDouble() ?? 0.0;
						final productName = (it['inventories']?['name'] ?? it['product_name'] ?? 'Produk').toString();
						return Padding(
							padding: const EdgeInsets.symmetric(vertical: 6),
							child: Row(
								children: [
									Expanded(
										child: Text(
											'${qty}x $productName',
											style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
										),
									),
									Text(
										CartManager.formatPrice(price * qty),
										style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
									),
								],
							),
						);
					}),
					const SizedBox(height: 8),
					const Divider(height: 1),
					const SizedBox(height: 8),
					Row(
						children: [
							const Expanded(
								child: Text('TOTAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
							),
							Text(CartManager.formatPrice(totalGross), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
						],
					),
				],
			),
		);
	}


	Widget _buildCheckoutBar() {
		return Padding(
			padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
			child: Container(
				padding: const EdgeInsets.all(14),
				decoration: BoxDecoration(
					color: Colors.white,
					borderRadius: BorderRadius.circular(18),
					boxShadow: [
						BoxShadow(
							color: Colors.black.withValues(alpha: 0.08),
							blurRadius: 14,
							offset: const Offset(0, 6),
						),
					],
				),
				child: Row(
					children: [
						Expanded(
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								mainAxisSize: MainAxisSize.min,
								children: [
									Text(
										'${_cart.totalItems} barang dipilih',
										style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
									),
									const SizedBox(height: 4),
									Text(
										_cart.formattedTotalPrice,
										style: const TextStyle(fontSize: 18, color: Color(0xFF2979FF), fontWeight: FontWeight.w800),
									),
								],
							),
						),
						const SizedBox(width: 12),
						ElevatedButton(
							onPressed: _openCheckoutPage,
							style: ElevatedButton.styleFrom(
								backgroundColor: const Color(0xFF2979FF),
								foregroundColor: Colors.white,
								padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
								shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
								elevation: 0,
							),
							child: const Text(
								'Checkout',
								style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
							),
						),
					],
				),
			),
		);
	}

	Widget _buildBestSellerCard(int rank, Map<String, dynamic> item) {
		final name = item['name'] as String? ?? 'Produk';
		final imageUrl = item['image_url'] as String?;
		final sellingPrice = item['selling_price'] as double? ?? 0.0;
		final qtyAvailable = item['qty_available'] as int? ?? 0;
		final totalSold = item['total_sold'] as int? ?? 0;
		final leadTime = item['lead_time'] as int? ?? 0;
		final satuan = item['satuan'] as String? ?? 'pcs';
		final hasImage = (imageUrl ?? '').trim().isNotEmpty;

		final Color rankColor = switch (rank) {
			1 => const Color(0xFFFFD700), // Emas
			2 => const Color(0xFFC0C0C0), // Perak
			3 => const Color(0xFFCD7F32), // Perunggu
			_ => const Color(0xFF64748B), // Slate/Grey
		};

		final String rankLabel = '#$rank';

		Color getStockColor(int qty) {
			if (qty == 0) return const Color(0xFFDC2626); // Merah
			if (qty <= leadTime) return const Color(0xFFEAB308); // Kuning
			return const Color(0xFF16A34A); // Hijau
		}

		return Container(
			padding: const EdgeInsets.all(12),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(18),
				boxShadow: [
					BoxShadow(
						color: Colors.black.withValues(alpha: 0.08),
						blurRadius: 14,
						offset: const Offset(0, 6),
					),
				],
			),
			child: Row(
				children: [
					Container(
						width: 52,
						height: 48,
						alignment: Alignment.center,
						decoration: BoxDecoration(
							color: rankColor.withValues(alpha: 0.15),
							borderRadius: BorderRadius.circular(12),
							border: Border.all(color: rankColor.withValues(alpha: 0.6), width: 1.5),
						),
						child: Text(
							rankLabel,
							style: TextStyle(
								fontSize: rank <= 3 ? 11 : 13,
								fontWeight: FontWeight.bold,
								color: rankColor,
							),
						),
					),
					const SizedBox(width: 12),
					Container(
						width: 64,
						height: 64,
						decoration: BoxDecoration(
							color: const Color(0xFFF1F5F9),
							borderRadius: BorderRadius.circular(12),
						),
						child: hasImage
								? ClipRRect(
										borderRadius: BorderRadius.circular(12),
										child: Image.network(
											imageUrl!,
											fit: BoxFit.cover,
											errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_rounded, color: Color(0xFF94A3B8)),
										),
									)
								: const Icon(Icons.inventory_2_rounded, color: Color(0xFF94A3B8)),
					),
					const SizedBox(width: 12),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(
									name,
									maxLines: 2,
									overflow: TextOverflow.ellipsis,
									style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.1),
								),
								const SizedBox(height: 6),
								SizedBox(
									width: double.infinity,
									child: Wrap(
										spacing: 8,
										runSpacing: 4,
										alignment: WrapAlignment.spaceBetween,
										crossAxisAlignment: WrapCrossAlignment.center,
										children: [
											Text(
												CartManager.formatPrice(sellingPrice),
												style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
											),
											Container(
												padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
												decoration: BoxDecoration(
													color: const Color(0xFFEFF6FF),
													borderRadius: BorderRadius.circular(8),
													border: Border.all(color: const Color(0xFF2979FF).withValues(alpha: 0.2)),
												),
												child: Text(
													'Terjual: $totalSold',
													style: const TextStyle(fontSize: 11, color: Color(0xFF2979FF), fontWeight: FontWeight.w800),
												),
											),
										],
									),
								),
								const SizedBox(height: 4),
								Row(
									children: [
										Icon(Icons.inventory_2_outlined, size: 12, color: getStockColor(qtyAvailable)),
										const SizedBox(width: 4),
										Text(
											'Stok: ${_stockLabel(qtyAvailable, satuan)}',
											style: TextStyle(
												fontSize: 11,
												fontWeight: FontWeight.bold,
												color: getStockColor(qtyAvailable),
											),
										),
									],
								),
							],
						),
					),
				],
			),
		);
	}

	List<Widget> _buildBestSellersSlivers() {
		if (_isLoadingBestSellers && !_isRefreshing) {
			return const [
				SliverToBoxAdapter(
					child: Padding(
						padding: EdgeInsets.only(top: 60),
						child: Center(child: CircularProgressIndicator()),
					),
				),
			];
		}

		final items = _filteredBestSellers;

		if (items.isEmpty) {
			return const [
				SliverToBoxAdapter(
					child: Padding(
						padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
						child: Center(
							child: Text(
								'Belum ada produk yang terjual.',
								style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600),
							),
						),
					),
				),
			];
		}

		return [
			SliverToBoxAdapter(
				child: Padding(
					padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
					child: Row(
						children: [
							const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 22),
							const SizedBox(width: 8),
							const Expanded(
								child: Text(
									'Produk Terlaris',
									maxLines: 1,
									overflow: TextOverflow.ellipsis,
									style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
								),
							),
							const SizedBox(width: 8),
							Text(
								'${items.length} Produk',
								style: const TextStyle(fontSize: 13, color: Colors.black45, fontWeight: FontWeight.w600),
							),
						],
					),
				),
			),
			SliverPadding(
				padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
				sliver: SliverList(
					delegate: SliverChildBuilderDelegate(
						(context, index) => Padding(
							padding: const EdgeInsets.only(bottom: 12),
							child: _buildBestSellerCard(index + 1, items[index]),
						),
						childCount: items.length,
					),
				),
			),
		];
	}

	@override
	Widget build(BuildContext context) {
		final bodySlivers = switch (_selectedTab) {
			'Stock' => _buildStockSlivers(),
			'Riwayat Penjualan' => _buildHistorySlivers(),
			'Sering Terjual' => _buildBestSellersSlivers(),
			_ => _buildStockSlivers(),
		};

		return Scaffold(
			extendBody: true,
			extendBodyBehindAppBar: true,
			backgroundColor: const Color(0xFFF1F5F9),
			body: RefreshIndicator(
				onRefresh: _refreshAll,
				child: CustomScrollView(
					physics: const AlwaysScrollableScrollPhysics(),
					slivers: [
            AppHeader(
              profileStream: _profileStream(),
              fallbackUserName: _userName,
              notificationWidget: _buildNotificationBadgeIcon(),

              // Optional
              onProfileTap: () {
                Navigator.pop(context, 4);
              },
            ),

            SliverToBoxAdapter(
              child: _buildSearchPanel(),
            ),

            ...bodySlivers,
          ],
				),
			),
			bottomNavigationBar: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					if (_cart.isNotEmpty) _buildCheckoutBar(),
					CustomNavBar(
						selectedIndex: 2,
						onItemTapped: (index) {
							if (index == 2) return;
							Navigator.pop(context, index);
						},
					),
				],
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
			child: GlassContainer(
				padding: EdgeInsets.zero,
				borderRadius: BorderRadius.circular(50),
				child: Center(child: Icon(icon, color: Colors.white, size: 24)),
			),
		);
	}
}

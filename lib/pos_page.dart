import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

	bool _isLoadingInventory = true;
	bool _isLoadingTransactions = true;
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
				return GestureDetector(
					onTap: () async {
						await Navigator.of(context).push(
							MaterialPageRoute(
								builder: (_) => NotificationPage(onNotificationsMarkedRead: () {}),
							),
						);
					},
					child: Stack(
						clipBehavior: Clip.none,
						alignment: Alignment.center,
						children: [
							Container(
								width: 48,
								height: 48,
								decoration: BoxDecoration(
									shape: BoxShape.circle,
									color: Colors.white.withValues(alpha: 0.15),
									border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
								),
								child: const Center(
									child: Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
								),
							),
							if (count > 0)
								Positioned(
									right: -1,
									top: -1,
									child: Container(
										constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
										padding: const EdgeInsets.symmetric(horizontal: 3),
										decoration: BoxDecoration(
											color: Color(0xFFEF4444),
											shape: BoxShape.circle,
											border: Border.all(color: Colors.white, width: 1.2),
											boxShadow: [
												BoxShadow(
													color: Colors.black.withValues(alpha: 0.16),
													blurRadius: 6,
													offset: Offset(0, 2),
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
					),
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
 		final userId = _currentUserId;
		if (userId == null) return;

		try {
			final existing = await supabase
					.from('inventories')
					.select('id')
					.eq('user_id', userId)
					.limit(1);

			if ((existing as List).isNotEmpty) return;

			final globalProducts = await supabase.from('products').select();
			final products = globalProducts as List;

			for (final p in products) {
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

			final data = await supabase
					.from('inventories')
					.select()
					.eq('user_id', userId)
					.order('name');

			if (!mounted) return;
			setState(() {
				_inventoryItems = (data as List)
						.map((json) => InventoryItem.fromJson(json))
						.toList();
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
				.limit(50);

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
						.select('*, inventories(id, name, image_url)')
						.eq('order_id', orderId);
					
					order['pos_order_items'] = items;
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

	void _onSearchChanged(String value) {
		_debounce?.cancel();
		_debounce = Timer(const Duration(milliseconds: 250), () {
			if (mounted) setState(() {});
		});
	}

	List<InventoryItem> get _filteredItems {
		final query = _searchController.text.trim().toLowerCase();
		return _inventoryItems.where((item) {
			final matchesQuery = query.isEmpty || item.name.toLowerCase().contains(query);
			final matchesFilter = switch (_stockFilter) {
				'Stok Tersedia' => item.qtyAvailable > 10,
				'Stok Sedikit' => item.qtyAvailable > 0 && item.qtyAvailable <= 10,
				'Stok Habis' => item.qtyAvailable == 0,
				_ => true,
			};
			return matchesQuery && matchesFilter;
		}).toList();
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

	Color _stockColor(int qty) {
		if (qty == 0) return const Color(0xFFDC2626); // Merah - Habis
		if (qty <= 10) return const Color(0xFFEAB308); // Kuning - Stok Rendah
		return const Color(0xFF16A34A); // Hijau - Tersedia
	}

	String _stockLabel(int qty) {
		if (qty == 0) return '0 Sachet';
		return '$qty Sachet';
	}

	String _formatDateTime(DateTime dateTime) {
		final local = dateTime.toLocal();
		final day = local.day.toString().padLeft(2, '0');
		final month = local.month.toString().padLeft(2, '0');
		return '$day/$month/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
	}

	Widget _buildHeader() {
		return Container(
			padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
			decoration: const BoxDecoration(
				gradient: LinearGradient(
					colors: [Color(0xFF2979FF), Color(0xFF4C9BFF)],
					begin: Alignment.topCenter,
					end: Alignment.bottomCenter,
				),
			),
			child: SafeArea(
				bottom: false,
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const Text(
							'POS - Stock',
							style: TextStyle(
								color: Colors.white70,
								fontSize: 13,
								fontWeight: FontWeight.w500,
							),
						),
						const SizedBox(height: 14),
						Row(
							children: [
								Expanded(
									child: Container(
										padding: const EdgeInsets.all(14),
										decoration: BoxDecoration(
											color: Colors.white.withValues(alpha: 0.18),
											borderRadius: BorderRadius.circular(16),
											border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
										),
										child: Row(
											children: [
												Container(
													width: 32,
													height: 32,
													decoration: BoxDecoration(
														color: Colors.white.withValues(alpha: 0.85),
														shape: BoxShape.circle,
													),
												),
												const SizedBox(width: 12),
												Expanded(
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.start,
														children: [
															const Text(
																'Selamat datang',
																style: TextStyle(
																	color: Colors.white,
																	fontSize: 12,
																	fontWeight: FontWeight.w600,
																),
															),
															Text(
																_userName,
																style: const TextStyle(
																	color: Colors.white,
																	fontSize: 14,
																	fontWeight: FontWeight.w700,
																),
																overflow: TextOverflow.ellipsis,
															),
														],
													),
												),
											],
										),
									),
								),
								const SizedBox(width: 10),
								_buildNotificationBadgeIcon(),
							],
						),
					],
				),
			),
		);
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
							const SizedBox(width: 12),
							Expanded(
								child: _buildTabButton('Riwayat Penjualan', _selectedTab == 'Riwayat Penjualan', () {
									setState(() => _selectedTab = 'Riwayat Penjualan');
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
				padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
				decoration: BoxDecoration(
					color: isSelected ? const Color(0xFF2979FF) : Colors.white,
					borderRadius: BorderRadius.circular(999),
					border: Border.all(color: const Color(0xFF2979FF), width: 1.2),
					boxShadow: isSelected
						? [
							BoxShadow(
								color: const Color(0xFF2979FF).withOpacity(0.16),
								blurRadius: 10,
								offset: const Offset(0, 6),
							),
						]
						: [
							BoxShadow(
								color: Colors.black.withOpacity(0.03),
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
						fontSize: 14,
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
						style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.w800),
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
								Row(
									children: [
										Container(
											padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
											decoration: BoxDecoration(
												color: _stockColor(item.qtyAvailable),
												borderRadius: BorderRadius.circular(8),
											),
											child: Text(
												_stockLabel(item.qtyAvailable),
												style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
											),
										),
										const Spacer(),
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

		final totalProfit = _transactions.fold<double>(
			0,
			(sum, tx) => sum + ((tx['total_profit'] as num?)?.toDouble() ?? 0.0),
		);
		final itemsSold = _transactions.fold<int>(
			0,
			(sum, tx) {
				final items = tx['pos_order_items'] as List? ?? const [];
				return sum + items.fold<int>(0, (itemSum, item) {
					return itemSum + ((item['qty'] as num?)?.toInt() ?? 0);
				});
			},
		);

		if (_transactions.isEmpty) {
			return const [
				SliverToBoxAdapter(
					child: Padding(
						padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
						child: Center(
							child: Text(
								'Belum ada riwayat penjualan.',
								style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600),
							),
						),
					),
				),
			];
		}

		final groupedTransactions = <String, List<Map<String, dynamic>>>{};
		final groupedLabels = <String, String>{};

		for (final tx in _transactions) {
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
							Expanded(child: _buildStatCard('Profit', CartManager.formatPrice(totalProfit), const Color(0xFF16A34A))),
							const SizedBox(width: 10),
							Expanded(child: _buildStatCard('Terjual', '$itemsSold', const Color(0xFF2979FF))),
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
					BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
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
											'${qty}x ${productName}',
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
					}).toList(),
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

	Widget _buildMiniChip(String label) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
			decoration: BoxDecoration(
				color: const Color(0xFFEFF6FF),
				borderRadius: BorderRadius.circular(999),
			),
			child: Text(
				label,
				style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
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

	@override
	Widget build(BuildContext context) {
		final bodySlivers = _selectedTab == 'Stock' ? _buildStockSlivers() : _buildHistorySlivers();

		return Scaffold(
			extendBody: true,
			backgroundColor: const Color(0xFFF1F5F9),
			body: RefreshIndicator(
				onRefresh: _refreshAll,
				child: CustomScrollView(
					physics: const AlwaysScrollableScrollPhysics(),
					slivers: [
						SliverToBoxAdapter(child: _buildHeader()),
						SliverToBoxAdapter(child: _buildSearchPanel()),
						...bodySlivers,
						const SliverToBoxAdapter(child: SizedBox(height: 110)),
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

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/navbar.dart';
import 'main.dart';
import 'models.dart';
import 'cart_manager.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _selectedYear = '2026';
  String _selectedMonth = 'Mei';
  String _selectedDate = 'Semua Tanggal';

  final List<String> _years = ['2024', '2025', '2026'];
  final List<String> _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  late List<String> _dates;

  // Raw data lists from Supabase
  List<dynamic> _rawProducts = [];
  List<dynamic> _rawTransactions = [];
  List<dynamic> _rawTransactionItems = [];

  // Computed stats
  int _totalItemsCount = 0;
  int _outOfStockCount = 0;
  int _lowStockCount = 0;
  int _itemsSoldCount = 0;
  double _totalProfit = 0.0;
  String _userName = 'User';
  String _userEmail = 'user@gmail.com';

  // ABC Analysis data
  Map<String, double> _abcRevenueData = {'A': 0.0, 'B': 0.0, 'C': 0.0};
  double _totalRevenueForAbc = 0.0;

  // Chart spots & configurations
  List<FlSpot> _chartSpots = const [
    FlSpot(0, 1),
    FlSpot(1, 2.5),
    FlSpot(2, 1.8),
    FlSpot(3, 3.5),
    FlSpot(4, 3.2),
    FlSpot(5, 4.8),
    FlSpot(6, 6),
  ];
  double _chartMaxY = 6.0;

  List<BarChartGroupData> _barGroups = [];
  double _barMaxY = 20.0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year.toString();
    _selectedMonth = _getMonthNameIndonesian(now.month);
    _dates = ['Semua Tanggal', ...List.generate(31, (index) => (index + 1).toString())];
    _loadData();
  }

  String _getMonthNameIndonesian(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return 'Januari';
  }

  Future<void> _loadData() async {
    await Future.wait([
      _fetchProfile(),
      _fetchStats(),
    ]);
  }

  Future<void> _fetchProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _setUserNameFromAuth();
        return;
      }
      _userEmail = user.email ?? 'user@gmail.com';

      final data = await supabase
          .from('profiles')
          .select('full_name, avatar_url, updated_at')
          .eq('id', user.id)
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
    final user = supabase.auth.currentUser;
    if (user == null) return const Stream.empty();
    return supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
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
        _userEmail = user.email ?? 'user@gmail.com';
      });
    }
  }

  Future<void> _fetchStats() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      final productsResponse = await supabase
          .from('inventories')
          .select('id, qty_available')
          .eq('user_id', userId);

      final txsResponse = await supabase
          .from('pos_orders')
          .select('total_profit, created_at, pos_order_items(qty, price_at_sale, profit_at_sale, created_at, inventories(capital_price))')
          .eq('user_id', userId);

      _rawProducts = productsResponse as List;
      _rawTransactions = txsResponse as List;

      // Extract transaction items from transactions response
      final List<dynamic> txItems = [];
      final Map<String, double> abcRev = {'A': 0.0, 'B': 0.0, 'C': 0.0};
      double totalRev = 0.0;

      for (final tx in _rawTransactions) {
        final items = tx['pos_order_items'] as List? ?? [];
        for (final item in items) {
          txItems.add({
            'quantity': item['qty'] ?? item['quantity'],
            'created_at': tx['created_at'] ?? item['created_at'],
          });

          // ABC Calculation for Dashboard
          final price = (item['price_at_sale'] as num?)?.toDouble() ?? 0.0;
          final qty = (item['qty'] as num?)?.toInt() ?? 0;
          final rev = price * qty;
          final inv = item['inventories'] as Map<String, dynamic>?;
          final abcClass = inv?['abc_class']?.toString() ?? 'C';
          
          abcRev[abcClass] = (abcRev[abcClass] ?? 0.0) + rev;
          totalRev += rev;
        }
      }
      _rawTransactionItems = txItems;
      _abcRevenueData = abcRev;
      _totalRevenueForAbc = totalRev;

      _calculateFilteredStats();
    } catch (e) {
      debugPrint('[SiKulak] Dashboard fetch stats failed: $e');
      _rawProducts = [];
      _rawTransactions = [];
      _rawTransactionItems = [];
      _calculateFilteredStats();
    }
  }

  int _getMonthNumber(String monthName) {
    switch (monthName) {
      case 'Januari': return 1;
      case 'Februari': return 2;
      case 'Maret': return 3;
      case 'April': return 4;
      case 'Mei': return 5;
      case 'Juni': return 6;
      case 'Juli': return 7;
      case 'Agustus': return 8;
      case 'September': return 9;
      case 'Oktober': return 10;
      case 'November': return 11;
      case 'Desember': return 12;
      default: return 1;
    }
  }

  void _calculateFilteredStats() {
    // 1. Calculate overall metrics from products
    int totalItems = _rawProducts.length;
    int outOfStock = 0;
    int lowStock = 0;
    for (final p in _rawProducts) {
      final stock = (p['qty_available'] as num?)?.toInt() ?? (p['stock'] as num?)?.toInt() ?? 0;
      if (stock == 0) {
        outOfStock++;
      } else if (stock <= 5) {
        lowStock++;
      }
    }

    // 2. Parse selected filter dimensions
    final yearInt = int.tryParse(_selectedYear) ?? 2026;
    final monthInt = _getMonthNumber(_selectedMonth);
    final dateInt = _selectedDate == 'Semua Tanggal' ? null : int.tryParse(_selectedDate);

    // 3. Filter transactions based on date/month/year
    double totalProfit = 0.0;
    final filteredTxs = <Map<String, dynamic>>[];
    for (final tx in _rawTransactions) {
      final createdAtStr = tx['created_at']?.toString();
      if (createdAtStr == null) continue;
      final dt = DateTime.tryParse(createdAtStr);
      if (dt == null) continue;

      if (dt.year != yearInt) continue;
      if (dt.month != monthInt) continue;
      if (dateInt != null && dt.day != dateInt) continue;

      // Calculate actual profit on the fly for backwards compatibility with old records
      double txProfit = 0.0;
      final items = tx['pos_order_items'] as List? ?? [];
      for (final item in items) {
        final qty = (item['qty'] as num?)?.toInt() ?? 0;
        final price = (item['price_at_sale'] as num?)?.toDouble() ?? 0.0;
        final inv = item['inventories'] as Map<String, dynamic>?;
        final capital = (inv?['capital_price'] as num?)?.toDouble() ??
                        (item['profit_at_sale'] != null ? (price - (item['profit_at_sale'] as num).toDouble()) : (price * 0.90));
        txProfit += (price - capital) * qty;
      }

      final txMap = Map<String, dynamic>.from(tx);
      txMap['total_profit'] = txProfit;
      filteredTxs.add(txMap);
      totalProfit += txProfit;
    }

    // 4. Filter transaction items based on date/month/year
    int itemsSold = 0;
    for (final item in _rawTransactionItems) {
      final createdAtStr = item['created_at']?.toString();
      if (createdAtStr == null) continue;
      final dt = DateTime.tryParse(createdAtStr);
      if (dt == null) continue;

      if (dt.year != yearInt) continue;
      if (dt.month != monthInt) continue;
      if (dateInt != null && dt.day != dateInt) continue;

      itemsSold += (item['quantity'] as num?)?.toInt() ?? 0;
    }

    // 5. Generate line chart spots (7 buckets)
    final spotsData = List<double>.filled(7, 0.0);
    for (final tx in filteredTxs) {
      final dt = DateTime.tryParse(tx['created_at']?.toString() ?? '');
      if (dt == null) continue;
      final profit = (tx['total_profit'] as num?)?.toDouble() ?? 0.0;

      int bucket = 0;
      if (dateInt != null) {
        bucket = (dt.hour ~/ 4).clamp(0, 6);
      } else {
        bucket = ((dt.day - 1) ~/ 5).clamp(0, 6);
      }
      spotsData[bucket] += profit;
    }

    double maxSpotVal = 0.0;
    for (final v in spotsData) {
      if (v > maxSpotVal) maxSpotVal = v;
    }

    List<FlSpot> spots = [];
    double chartMaxY = 6.0;
    if (maxSpotVal == 0.0) {
      spots = List.generate(7, (i) => FlSpot(i.toDouble(), 0));
      chartMaxY = 10.0;
    } else {
      spots = List.generate(7, (i) => FlSpot(i.toDouble(), spotsData[i]));
      chartMaxY = maxSpotVal * 1.2;
    }

    // 6. Generate sales trend bar chart (days 1 to 7 of selected month)
    final salesData = List<double>.filled(7, 0.0);
    for (final item in _rawTransactionItems) {
      final dt = DateTime.tryParse(item['created_at']?.toString() ?? '');
      if (dt == null) continue;
      if (dt.year != yearInt || dt.month != monthInt) continue;
      if (dt.day >= 1 && dt.day <= 7) {
        salesData[dt.day - 1] += (item['quantity'] as num?)?.toDouble() ?? 0.0;
      }
    }

    double maxSalesVal = 0.0;
    for (final v in salesData) {
      if (v > maxSalesVal) maxSalesVal = v;
    }

    List<BarChartGroupData> barGroups = [];
    double barMaxY = 20.0;
    if (maxSalesVal == 0.0) {
      barGroups = List.generate(7, (i) {
        return BarChartGroupData(x: i, barRods: [
          BarChartRodData(
            toY: 0.0,
            color: Colors.blue,
            width: 12,
            borderRadius: BorderRadius.circular(4),
          )
        ]);
      });
      barMaxY = 10.0;
    } else {
      int maxIndex = 0;
      double currentMax = -1.0;
      for (int i = 0; i < 7; i++) {
        if (salesData[i] > currentMax) {
          currentMax = salesData[i];
          maxIndex = i;
        }
      }

      barGroups = List.generate(7, (i) {
        Color color = Colors.blue;
        if (i == maxIndex) {
          color = Colors.green;
        } else if (i == 5 || i == 6) {
          color = Colors.amber;
        }

        return BarChartGroupData(x: i, barRods: [
          BarChartRodData(
            toY: salesData[i],
            color: color,
            width: 12,
            borderRadius: BorderRadius.circular(4),
          )
        ]);
      });
      barMaxY = maxSalesVal * 1.2;
    }

    if (mounted) {
      setState(() {
        _totalItemsCount = totalItems;
        _outOfStockCount = outOfStock;
        _lowStockCount = lowStock;
        _itemsSoldCount = itemsSold;
        _totalProfit = totalProfit;
        _chartSpots = spots;
        _chartMaxY = chartMaxY;
        _barGroups = barGroups;
        _barMaxY = barMaxY;
      });
    }
  }

  // Helper to generate a soft modern BoxShadow
  List<BoxShadow> _getCustomShadow() {
    return [
      BoxShadow(
        color: const Color(0xFF0F172A).withValues(alpha: 0.06),
        blurRadius: 16,
        spreadRadius: 0,
        offset: const Offset(0, 8),
      ),
    ];
  }

  Widget _buildTimeFilter(String value, List<String> items, ValueChanged<String?> onChanged, {required bool isDark}) {
    final textColor = isDark ? Colors.white : const Color(0xFF2979FF);
    final borderColor = isDark ? Colors.white30 : const Color(0xFF2979FF).withValues(alpha: 0.3);
    final bgColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: isDark ? const Color(0xFF0F223C) : Colors.white,
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: textColor),
          style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
          onChanged: onChanged,
          items: items.map((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(val),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, double value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              Text(
                'Rp ${CartManager.formatPrice(value).replaceFirst('Rp. ', '')}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── Blue Gradient Header with Stacked Overlapping Card ──
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // Gradient Header Box
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2979FF), Color(0xFF4C9BFF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                  alignment: Alignment.topLeft,
                  child: const Text(
                    'Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                // Overlapping White Card
                Container(
                  margin: const EdgeInsets.only(top: 140),
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context, 4);
                    },
                    child: StreamBuilder<UserProfile?>(
                      stream: _profileStream(),
                      builder: (context, snapshot) {
                        final profile = snapshot.data;
                        final userName = profile?.fullName ?? _userName;
                        final avatarUrl = profile?.avatarUrl;

                        return Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                              ),
                              child: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        '$avatarUrl?t=${profile?.updatedAt.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(Icons.person,
                                              size: 36, color: Colors.grey);
                                        },
                                      ),
                                    )
                                  : const Icon(Icons.person, size: 36, color: Colors.grey),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2979FF),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _userEmail,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Stats Section ────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 24, top: 16, right: 24, bottom: 8),
              child: const Text(
                'Stats',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),

          // ── Total Keuntungan Card with Line Chart ────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06152B), Color(0xFF0D3365), Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: _getCustomShadow(),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Keuntungan',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${CartManager.formatPrice(_totalProfit)},00',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Time Dimension Filters
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTimeFilter(_selectedDate, _dates, (val) {
                            setState(() => _selectedDate = val!);
                            _calculateFilteredStats();
                          }, isDark: true),
                          const SizedBox(width: 8),
                          _buildTimeFilter(_selectedMonth, _months, (val) {
                            setState(() => _selectedMonth = val!);
                            _calculateFilteredStats();
                          }, isDark: true),
                          const SizedBox(width: 8),
                          _buildTimeFilter(_selectedYear, _years, (val) {
                            setState(() => _selectedYear = val!);
                            _calculateFilteredStats();
                          }, isDark: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Line Chart for Profit Trend
                    SizedBox(
                      height: 160,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: _chartMaxY / 4 > 0 ? _chartMaxY / 4 : 2,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.white.withValues(alpha: 0.08),
                                strokeWidth: 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                interval: 2,
                                getTitlesWidget: (double value, TitleMeta meta) {
                                  const style = TextStyle(color: Colors.white60, fontWeight: FontWeight.bold, fontSize: 10);
                                  
                                  // Prevent duplicate labels for fractional values
                                  if (value % 2 != 0) return const SizedBox.shrink();

                                  String text = '';
                                  if (_selectedDate != 'Semua Tanggal') {
                                    // Jam (Hourly)
                                    switch (value.toInt()) {
                                      case 0: text = '08:00'; break;
                                      case 2: text = '12:00'; break;
                                      case 4: text = '16:00'; break;
                                      case 6: text = '20:00'; break;
                                    }
                                  } else {
                                    // Tanggal (Daily)
                                    String monthAbbr = _selectedMonth.length > 3 ? _selectedMonth.substring(0, 3) : _selectedMonth;
                                    switch (value.toInt()) {
                                      case 0: text = '01/$monthAbbr'; break;
                                      case 2: text = '10/$monthAbbr'; break;
                                      case 4: text = '20/$monthAbbr'; break;
                                      case 6: text = '30/$monthAbbr'; break;
                                    }
                                  }
                                  return SideTitleWidget(meta: meta, space: 4, child: Text(text, style: style));
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: 6,
                          minY: 0,
                          maxY: _chartMaxY,
                          lineBarsData: [
                            LineChartBarData(
                              spots: _chartSpots,
                              isCurved: true,
                              color: const Color(0xFF00E676),
                              barWidth: 4,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: const Color(0xFF00E676).withValues(alpha: 0.15),
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
          ),

          // ── Stats Grid ───────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final stats = [
                    {'label': 'Items', 'value': _totalItemsCount.toString(), 'color': const Color(0xFF2979FF), 'icon': Icons.inventory_2_outlined},
                    {'label': 'Out of Stock', 'value': _outOfStockCount.toString(), 'color': const Color(0xFFEF4444), 'icon': Icons.remove_circle_outline},
                    {'label': 'Low Stock', 'value': _lowStockCount.toString(), 'color': const Color(0xFFF59E0B), 'icon': Icons.warning_amber_rounded},
                    {'label': 'Items Sold', 'value': _itemsSoldCount.toString(), 'color': const Color(0xFF10B981), 'icon': Icons.shopping_bag_outlined},
                  ];

                  final stat = stats[index];
                  return _StatCard(
                    label: stat['label'] as String,
                    value: stat['value'] as String,
                    color: stat['color'] as Color,
                    icon: stat['icon'] as IconData,
                    shadow: _getCustomShadow(),
                  );
                },
                childCount: 4,
              ),
            ),
          ),

          // ── ABC Performance Summary (Pie Chart) ──────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _getCustomShadow(),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ringkasan Performa Stok',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kontribusi Omzet berdasarkan Kelas ABC',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        // Pie Chart
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 4,
                              centerSpaceRadius: 35,
                              sections: [
                                PieChartSectionData(
                                  value: _abcRevenueData['A'] ?? 0,
                                  color: const Color(0xFF2979FF),
                                  title: '${((_abcRevenueData['A'] ?? 0) / (_totalRevenueForAbc > 0 ? _totalRevenueForAbc : 1) * 100).toStringAsFixed(0)}%',
                                  radius: 40,
                                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                PieChartSectionData(
                                  value: _abcRevenueData['B'] ?? 0,
                                  color: const Color(0xFFF59E0B),
                                  title: '${((_abcRevenueData['B'] ?? 0) / (_totalRevenueForAbc > 0 ? _totalRevenueForAbc : 1) * 100).toStringAsFixed(0)}%',
                                  radius: 35,
                                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                PieChartSectionData(
                                  value: _abcRevenueData['C'] ?? 0,
                                  color: const Color(0xFF64748B),
                                  title: '${((_abcRevenueData['C'] ?? 0) / (_totalRevenueForAbc > 0 ? _totalRevenueForAbc : 1) * 100).toStringAsFixed(0)}%',
                                  radius: 30,
                                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Legend
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLegendItem('Kelas A (Paling Laku)', const Color(0xFF2979FF), _abcRevenueData['A'] ?? 0),
                              const SizedBox(height: 12),
                              _buildLegendItem('Kelas B (Wajar)', const Color(0xFFF59E0B), _abcRevenueData['B'] ?? 0),
                              const SizedBox(height: 12),
                              _buildLegendItem('Kelas C (Jarang)', const Color(0xFF64748B), _abcRevenueData['C'] ?? 0),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Sales Trend Card with Bar Chart ──────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _getCustomShadow(),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tren Penjualan Mingguan',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Periode: 01 $_selectedMonth - 07 $_selectedMonth',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Bar Chart for Sales
                    SizedBox(
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: _barMaxY,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                reservedSize: 38,
                                getTitlesWidget: (double value, TitleMeta meta) {
                                  const style = TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11);
                                  Widget text;
                                  switch (value.toInt()) {
                                    case 0: text = const Text('Sen\n01', style: style, textAlign: TextAlign.center); break;
                                    case 1: text = const Text('Sel\n02', style: style, textAlign: TextAlign.center); break;
                                    case 2: text = const Text('Rab\n03', style: style, textAlign: TextAlign.center); break;
                                    case 3: text = const Text('Kam\n04', style: style, textAlign: TextAlign.center); break;
                                    case 4: text = const Text('Jum\n05', style: style, textAlign: TextAlign.center); break;
                                    case 5: text = const Text('Sab\n06', style: style, textAlign: TextAlign.center); break;
                                    case 6: text = const Text('Min\n07', style: style, textAlign: TextAlign.center); break;
                                    default: text = const Text('', style: style); break;
                                  }
                                  return SideTitleWidget(meta: meta, space: 4, child: text);
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: _barMaxY / 4 > 0 ? _barMaxY / 4 : 5,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.grey.withValues(alpha: 0.1),
                                strokeWidth: 1,
                              );
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: _barGroups,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: const SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: CustomNavBar(
        selectedIndex: 3, // 3 for Dashboard (grid_view icon)
        onItemTapped: (index) {
          if (index == 3) return; // Already on dashboard
          Navigator.pop(context, index);
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final List<BoxShadow> shadow;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.shadow,
  });

  Widget _buildLegendItem(String label, Color color, double value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              Text(
                'Rp ${CartManager.formatPrice(value).replaceFirst('Rp. ', '')}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: shadow,
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
        ],
      ),
    );
  }
}

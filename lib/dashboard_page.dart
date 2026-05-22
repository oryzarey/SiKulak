import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/navbar.dart';
import 'main.dart';
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
    _dates = ['Semua Tanggal', ...List.generate(31, (index) => (index + 1).toString())];
    _loadData();
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
          .select('full_name')
          .eq('id', user.id)
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
        _userEmail = user.email ?? 'user@gmail.com';
      });
    }
  }

  Future<void> _fetchStats() async {
    try {
      final productsResponse = await supabase.from('products').select('id, stock');
      final txsResponse = await supabase.from('transactions').select('total_profit, created_at');
      final txItemsResponse = await supabase.from('transaction_items').select('quantity, created_at');

      _rawProducts = productsResponse as List;
      _rawTransactions = txsResponse as List;
      _rawTransactionItems = txItemsResponse as List;

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
    if (_rawProducts.isEmpty && _rawTransactions.isEmpty && _rawTransactionItems.isEmpty) {
      if (mounted) {
        setState(() {
          _totalItemsCount = 100;
          _outOfStockCount = 4;
          _lowStockCount = 4;
          _itemsSoldCount = 60;
          _totalProfit = 15000000.0;
          _chartSpots = const [
            FlSpot(0, 1),
            FlSpot(1, 2.5),
            FlSpot(2, 1.8),
            FlSpot(3, 3.5),
            FlSpot(4, 3.2),
            FlSpot(5, 4.8),
            FlSpot(6, 6),
          ];
          _chartMaxY = 6.0;
          _barMaxY = 20.0;
          _barGroups = List.generate(7, (i) {
            final color = i == 5 ? Colors.amber : (i == 6 ? Colors.green : Colors.blue);
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: [8.0, 10.0, 14.0, 15.0, 13.0, 10.0, 18.0][i],
                color: color,
                width: 12,
                borderRadius: BorderRadius.circular(4),
              )
            ]);
          });
        });
      }
      return;
    }

    // 1. Calculate overall metrics from products
    int totalItems = _rawProducts.length;
    int outOfStock = 0;
    int lowStock = 0;
    for (final p in _rawProducts) {
      final stock = (p['stock'] as num?)?.toInt() ?? 0;
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

      filteredTxs.add(Map<String, dynamic>.from(tx));
      totalProfit += (tx['total_profit'] as num?)?.toDouble() ?? 0.0;
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
      spots = const [
        FlSpot(0, 1),
        FlSpot(1, 2.5),
        FlSpot(2, 1.8),
        FlSpot(3, 3.5),
        FlSpot(4, 3.2),
        FlSpot(5, 4.8),
        FlSpot(6, 6),
      ];
      chartMaxY = 6.0;
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
      final mockY = [8.0, 10.0, 14.0, 15.0, 13.0, 10.0, 18.0];
      barGroups = List.generate(7, (i) {
        final color = i == 5 ? Colors.amber : (i == 6 ? Colors.green : Colors.blue);
        return BarChartGroupData(x: i, barRods: [
          BarChartRodData(
            toY: mockY[i],
            color: color,
            width: 12,
            borderRadius: BorderRadius.circular(4),
          )
        ]);
      });
      barMaxY = 20.0;
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

  // Helper to generate the exact BoxShadow requested by user
  List<BoxShadow> _getCustomShadow() {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.15),
        blurRadius: 4,
        spreadRadius: 0,
        offset: const Offset(0, 0),
      ),
    ];
  }

  Widget _buildTimeFilter(String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.blue),
          style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
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
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 40),
              child: const Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // ── User Profile Card ────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _getCustomShadow(),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(Icons.person, size: 40, color: Colors.grey[400]),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _userName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2979FF),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.verified, color: Color(0xFF2979FF), size: 20),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userEmail,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Stats Section ────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Text(
                'Stats',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // ── Total Keuntungan Card with Line Chart ────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: _getCustomShadow(),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Keuntungan',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.green[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CartManager.formatPrice(_totalProfit),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
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
                          }),
                          const SizedBox(width: 8),
                          _buildTimeFilter(_selectedMonth, _months, (val) {
                            setState(() => _selectedMonth = val!);
                            _calculateFilteredStats();
                          }),
                          const SizedBox(width: 8),
                          _buildTimeFilter(_selectedYear, _years, (val) {
                            setState(() => _selectedYear = val!);
                            _calculateFilteredStats();
                          }),
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
                            horizontalInterval: 2,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.grey.withValues(alpha: 0.2),
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
                                  const style = TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 10);
                                  
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
                              color: Colors.green[500],
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.green[100]?.withValues(alpha: 0.3),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    {'label': 'Items', 'value': _totalItemsCount.toString(), 'color': Colors.blue},
                    {'label': 'Out of Stock', 'value': _outOfStockCount.toString(), 'color': Colors.red},
                    {'label': 'Low Stock', 'value': _lowStockCount.toString(), 'color': Colors.amber},
                    {'label': 'Items Sold', 'value': _itemsSoldCount.toString(), 'color': Colors.blue},
                  ];

                  final stat = stats[index];
                  return _StatCard(
                    label: stat['label'] as String,
                    value: stat['value'] as String,
                    color: stat['color'] as Color,
                    shadow: _getCustomShadow(),
                  );
                },
                childCount: 4,
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
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: _getCustomShadow(),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grafik Penjualan (01 $_selectedMonth - 07 $_selectedMonth)',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
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
                            horizontalInterval: 5,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.grey.withValues(alpha: 0.2),
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
          // Pop back to Home for any other tab — Home handles all routing
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final List<BoxShadow> shadow;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: shadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

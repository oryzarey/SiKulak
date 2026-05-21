import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/navbar.dart';

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

  @override
  void initState() {
    super.initState();
    _dates = ['Semua Tanggal', ...List.generate(31, (index) => (index + 1).toString())];
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
                          const Row(
                            children: [
                              Text(
                                'Ahul Gans',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2979FF),
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.verified, color: Color(0xFF2979FF), size: 20),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'AhulGans12@gmail.com',
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
                    const Text(
                      'Rp. 15.000.000',
                      style: TextStyle(
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
                          _buildTimeFilter(_selectedDate, _dates, (val) => setState(() => _selectedDate = val!)),
                          const SizedBox(width: 8),
                          _buildTimeFilter(_selectedMonth, _months, (val) => setState(() => _selectedMonth = val!)),
                          const SizedBox(width: 8),
                          _buildTimeFilter(_selectedYear, _years, (val) => setState(() => _selectedYear = val!)),
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
                          maxY: 6,
                          lineBarsData: [
                            LineChartBarData(
                              spots: const [
                                FlSpot(0, 1),
                                FlSpot(1, 2.5),
                                FlSpot(2, 1.8),
                                FlSpot(3, 3.5),
                                FlSpot(4, 3.2),
                                FlSpot(5, 4.8),
                                FlSpot(6, 6),
                              ],
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
                    {'label': 'Items', 'value': '100', 'color': Colors.blue},
                    {'label': 'Out of Stock', 'value': '4', 'color': Colors.red},
                    {'label': 'Low Stock', 'value': '4', 'color': Colors.amber},
                    {'label': 'Items Sold', 'value': '60', 'color': Colors.blue},
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
                          maxY: 20,
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
                          barGroups: [
                            BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 8, color: Colors.blue, width: 12, borderRadius: BorderRadius.circular(4))]),
                            BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 10, color: Colors.blue, width: 12, borderRadius: BorderRadius.circular(4))]),
                            BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 14, color: Colors.blue, width: 12, borderRadius: BorderRadius.circular(4))]),
                            BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 15, color: Colors.blue, width: 12, borderRadius: BorderRadius.circular(4))]),
                            BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 13, color: Colors.blue, width: 12, borderRadius: BorderRadius.circular(4))]),
                            BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 10, color: Colors.amber, width: 12, borderRadius: BorderRadius.circular(4))]), // Highlight weekend
                            BarChartGroupData(x: 6, barRods: [BarChartRodData(toY: 18, color: Colors.green, width: 12, borderRadius: BorderRadius.circular(4))]), // Highlight highest
                          ],
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
        selectedIndex: 1, // 1 for Dashboard
        onItemTapped: (index) {
          if (index == 1) return; // Already on dashboard
          if (index == 0) {
            Navigator.pop(context); // Go back to Home
          } else {
            // Placeholder for other pages
          }
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

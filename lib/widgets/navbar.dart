import 'package:flutter/material.dart';

class CustomNavBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  State<CustomNavBar> createState() => _CustomNavBarState();
}

class _CustomNavBarState extends State<CustomNavBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _fromIndex = 0.0;
  double _toIndex = 0.0;
  int _prevIndex = 0;

  IconData _getSelectedIcon(int index) {
    switch (index) {
      case 0:
        return Icons.home;
      case 1:
        return Icons.inventory_2;
      case 2:
        return Icons.work;
      case 3:
        return Icons.bar_chart;
      case 4:
        return Icons.person;
      default:
        return Icons.home;
    }
  }

  IconData _getUnselectedIcon(int index) {
    switch (index) {
      case 0:
        return Icons.home_outlined;
      case 1:
        return Icons.inventory_2_outlined;
      case 2:
        return Icons.work_outline;
      case 3:
        return Icons.bar_chart_outlined;
      case 4:
        return Icons.person_outline;
      default:
        return Icons.home_outlined;
    }
  }

  String _getLabel(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Inventory';
      case 2:
        return 'POS';
      case 3:
        return 'Dashboard';
      case 4:
        return 'Profile';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.selectedIndex.toDouble();
    _toIndex = widget.selectedIndex.toDouble();
    _prevIndex = widget.selectedIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void didUpdateWidget(CustomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _prevIndex = oldWidget.selectedIndex;
      _fromIndex = _fromIndex + (_toIndex - _fromIndex) * _controller.value;
      _toIndex = widget.selectedIndex.toDouble();
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final tabWidth = w / 5;

            return AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final animIndexValue = _fromIndex + (_toIndex - _fromIndex) * _animation.value;
                final animCenterX = (animIndexValue + 0.5) * tabWidth;

                final currentIconIndex = _animation.value < 0.5 ? _prevIndex : widget.selectedIndex;
                final double iconScale = ((_animation.value - 0.5).abs() * 2.0).clamp(0.0, 1.0);

                return SizedBox(
                  height: 90,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 1. Animated background paint positioned at bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 60,
                        child: CustomPaint(
                          size: Size(w, 60),
                          painter: NavBarPainter(
                            color: const Color(0xFF2979FF),
                          ),
                        ),
                      ),

                      // 2. Row of buttons (clicks and labels are handled here)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 60,
                        child: Row(
                          children: List.generate(5, (index) {
                            final distance = (index - animIndexValue).abs();
                            final opacity = distance.clamp(0.0, 1.0);

                            return SizedBox(
                              width: tabWidth,
                              height: 60,
                              child: GestureDetector(
                                onTap: () => widget.onItemTapped(index),
                                behavior: HitTestBehavior.opaque,
                                child: Opacity(
                                  opacity: opacity,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 4),
                                      // Icon container
                                      SizedBox(
                                        height: 24,
                                        child: Icon(
                                          _getUnselectedIcon(index),
                                          color: Colors.white.withValues(alpha: 0.9),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      // Text label
                                      Text(
                                        _getLabel(index),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                      // 3. Animated active white circular container (drawn on top of the Row)
                      Positioned(
                        left: animCenterX - 30,
                        bottom: 22,
                        child: IgnorePointer(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: const Color(0xFF2979FF).withValues(alpha: 0.24),
                                  blurRadius: 16,
                                  spreadRadius: -1,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Transform.scale(
                                scale: iconScale,
                                child: Icon(
                                  _getSelectedIcon(currentIconIndex),
                                  color: const Color(0xFF2979FF),
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class NavBarPainter extends CustomPainter {
  final Color color;

  NavBarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final r = size.height / 2; // radius for pill ends
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(r),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant NavBarPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

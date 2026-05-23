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
                  height: 56,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Animated background paint
                      CustomPaint(
                        size: Size(w, 56),
                        painter: NavBarPainter(
                          color: const Color(0xFF2979FF),
                        ),
                      ),

                      // Animated active white circular container
                      Positioned(
                        left: animCenterX - 24,
                        bottom: 4,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Transform.scale(
                              scale: iconScale,
                              child: Icon(
                                _getSelectedIcon(currentIconIndex),
                                color: const Color(0xFF2979FF),
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Row of buttons (clicks are handled here)
                      Row(
                        children: List.generate(5, (index) {
                          final distance = (index - animIndexValue).abs();
                          final opacity = distance.clamp(0.0, 1.0);

                          return SizedBox(
                            width: tabWidth,
                            height: 56,
                            child: GestureDetector(
                              onTap: () => widget.onItemTapped(index),
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: Opacity(
                                  opacity: opacity,
                                  child: Icon(
                                    _getUnselectedIcon(index),
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 26,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
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

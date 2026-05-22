import 'dart:async';
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
        return Icons.search;
      case 2:
        return Icons.receipt_long;
      case 3:
        return Icons.grid_view;
      default:
        return Icons.home;
    }
  }

  IconData _getUnselectedIcon(int index) {
    switch (index) {
      case 0:
        return Icons.home_outlined;
      case 1:
        return Icons.search;
      case 2:
        return Icons.receipt_long_outlined;
      case 3:
        return Icons.grid_view_outlined;
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
            final tabWidth = w / 4;

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
                          centerX: animCenterX,
                          color: const Color(0xFF2979FF),
                        ),
                      ),

                      // Animated active white house-shaped container
                      Positioned(
                        left: animCenterX - 25,
                        bottom: 6,
                        child: CustomPaint(
                          size: const Size(50, 52),
                          painter: HousePainter(
                            borderColor: const Color(0xFF2979FF),
                            fillColor: Colors.white,
                          ),
                          child: SizedBox(
                            width: 50,
                            height: 52,
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
                      ),

                      // Row of buttons (clicks are handled here)
                      Row(
                        children: List.generate(4, (index) {
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
                                    color: Colors.white.withOpacity(0.9),
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

class HousePainter extends CustomPainter {
  final Color borderColor;
  final Color fillColor;

  HousePainter({
    required this.borderColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintFill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Start at bottom left
    path.moveTo(6, h - 2);
    path.lineTo(w - 6, h - 2);
    // Bottom right corner
    path.quadraticBezierTo(w - 2, h - 2, w - 2, h - 6);
    // Right wall
    path.lineTo(w - 2, 20);
    // Right roof eave
    path.quadraticBezierTo(w - 2, 16, w - 6, 14);
    // Right roof slope
    path.lineTo(w / 2 + 3, 3);
    // Roof peak
    path.quadraticBezierTo(w / 2, 1, w / 2 - 3, 3);
    // Left roof slope
    path.lineTo(6, 14);
    // Left roof eave
    path.quadraticBezierTo(2, 16, 2, 20);
    // Left wall
    path.lineTo(2, h - 6);
    // Bottom left corner
    path.quadraticBezierTo(2, h - 2, 6, h - 2);
    path.close();

    // Draw shadow first
    final shadowPath = path.shift(const Offset(0, 3));
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withOpacity(0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Draw fill
    canvas.drawPath(path, paintFill);

    // Draw border
    canvas.drawPath(path, paintBorder);
  }

  @override
  bool shouldRepaint(covariant HousePainter oldDelegate) {
    return oldDelegate.borderColor != borderColor || oldDelegate.fillColor != fillColor;
  }
}

class NavBarPainter extends CustomPainter {
  final double centerX;
  final Color color;

  NavBarPainter({required this.centerX, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final r = size.height / 2; // radius for pill ends
    final w = size.width;
    final h = size.height;

    // Start at top left
    path.moveTo(r, 0);

    // Line to start of curve dip
    path.lineTo(centerX - 42, 0);

    // Curve down into the dip
    path.cubicTo(
      centerX - 24, 0,
      centerX - 20, 24,
      centerX, 24,
    );

    // Curve up out of the dip
    path.cubicTo(
      centerX + 20, 24,
      centerX + 24, 0,
      centerX + 42, 0,
    );

    // Line to top right corner start
    path.lineTo(w - r, 0);

    // Top right arc
    path.arcToPoint(
      Offset(w, r),
      radius: Radius.circular(r),
    );

    // Line to bottom right corner
    path.lineTo(w, h - r);

    // Bottom right arc
    path.arcToPoint(
      Offset(w - r, h),
      radius: Radius.circular(r),
    );

    // Line to bottom left corner
    path.lineTo(r, h);

    // Bottom left arc
    path.arcToPoint(
      Offset(0, h - r),
      radius: Radius.circular(r),
    );

    // Line to top left corner start
    path.lineTo(0, r);

    // Top left arc
    path.arcToPoint(
      Offset(r, 0),
      radius: Radius.circular(r),
    );

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant NavBarPainter oldDelegate) {
    return oldDelegate.centerX != centerX || oldDelegate.color != color;
  }
}

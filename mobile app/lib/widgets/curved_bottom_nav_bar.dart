import "dart:math" as math;

import "package:flutter/material.dart";

import "../utils/app_colors.dart";
import "../utils/app_palette.dart";

class CurvedNavItem {
  const CurvedNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class CurvedBottomNavBar extends StatefulWidget {
  const CurvedBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  }) : assert(
         items.length >= 3 && items.length <= 5,
         "CurvedBottomNavBar must contain between 3 and 5 items "
         "(each slot must remain >= 48dp touch target; 5 items fits small "
         "320dp devices safely).",
       );

  final List<CurvedNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  State<CurvedBottomNavBar> createState() => _CurvedBottomNavBarState();
}

class _CurvedBottomNavBarState extends State<CurvedBottomNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _position;

  int _previousIndex = 0;

  static const Duration _duration = Duration(milliseconds: 620);
  static const Curve _curve = Curves.easeOutBack;

  static const double _outerMargin = 14;
  static const double _barHeight = 76;
  static const double _bumpHeight = 26;
  static const double _radius = 22;
  static const double _iconSize = 26;
  static const double _bubbleSize = 58;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
    _controller = AnimationController(vsync: this, duration: _duration);
    _position = AlwaysStoppedAnimation<double>(widget.currentIndex.toDouble());
  }

  @override
  void didUpdateWidget(CurvedBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _animateTo(widget.currentIndex);
    }
  }

  void _animateTo(int newIndex) {
    final Tween<double> tween = Tween<double>(
      begin: _previousIndex.toDouble(),
      end: newIndex.toDouble(),
    );
    _position = tween.animate(
      CurvedAnimation(parent: _controller, curve: _curve),
    );
    _previousIndex = newIndex;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppColors.of(context);
    final Color primary = Theme.of(context).colorScheme.primary;
    final Color inactive = palette.textSecondary;
    final Color background = palette.cardBackground;
    final Color border = palette.border;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(
          left: _outerMargin,
          right: _outerMargin,
          bottom: _outerMargin,
        ),
        child: SizedBox(
          height: _barHeight + _bumpHeight,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth;
              final double segment = width / widget.items.length;

              return AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? child) {
                  final double t = _position.value;
                  final double centerX = (t + 0.5) * segment;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: PhysicalModel(
                          color: background,
                          elevation: 10,
                          shadowColor: palette.shadowSoft,
                          borderRadius: BorderRadius.circular(_radius),
                          child: Container(
                            height: _barHeight,
                            decoration: BoxDecoration(
                              color: background,
                              borderRadius: BorderRadius.circular(_radius),
                              border: Border.all(color: border),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        top: 0,
                        child: CustomPaint(
                          painter: _CurvedHighlightPainter(
                            centerX: centerX,
                            barTopY: _bumpHeight,
                            color: primary,
                            bubbleRadius: _bubbleSize / 2,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SizedBox(
                          height: _barHeight,
                          child: Row(
                            children: List<Widget>.generate(
                              widget.items.length,
                              (int index) {
                                final bool isSelected =
                                    index == widget.currentIndex;
                                return Expanded(
                                  child: InkWell(
                                    onTap: () => widget.onTap(index),
                                    customBorder: const CircleBorder(),
                                    child: Center(
                                      child: AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        opacity: isSelected ? 0 : 1,
                                        child: Icon(
                                          widget.items[index].icon,
                                          size: _iconSize,
                                          color: inactive,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: math.max(0, centerX - (_bubbleSize / 2)),
                        child: SizedBox(
                          width: _bubbleSize,
                          height: _bubbleSize,
                          child: Center(
                            child: Icon(
                              widget.items[widget.currentIndex].icon,
                              size: _iconSize + 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CurvedHighlightPainter extends CustomPainter {
  const _CurvedHighlightPainter({
    required this.centerX,
    required this.barTopY,
    required this.color,
    required this.bubbleRadius,
  });

  final double centerX;
  final double barTopY;
  final Color color;
  final double bubbleRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;

    final double bubbleCenterY = barTopY;
    canvas.drawCircle(Offset(centerX, bubbleCenterY), bubbleRadius, paint);

    final double capWidth = bubbleRadius * 1.65;
    final Rect capRect = Rect.fromLTWH(
      centerX - capWidth / 2,
      bubbleCenterY,
      capWidth,
      bubbleRadius,
    );
    canvas.drawRect(capRect, paint);
  }

  @override
  bool shouldRepaint(covariant _CurvedHighlightPainter oldDelegate) {
    return oldDelegate.centerX != centerX ||
        oldDelegate.barTopY != barTopY ||
        oldDelegate.color != color ||
        oldDelegate.bubbleRadius != bubbleRadius;
  }
}

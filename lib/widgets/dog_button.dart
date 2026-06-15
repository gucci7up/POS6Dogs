import 'package:flutter/material.dart';

class DogButton extends StatefulWidget {
  final int number;
  final bool isSelected;
  final bool isDimmed;
  final VoidCallback? onTap;
  final double? height;

  const DogButton({
    super.key,
    required this.number,
    this.isSelected = false,
    this.isDimmed = false,
    this.onTap,
    this.height,
  });

  @override
  State<DogButton> createState() => _DogButtonState();
}

class _DogButtonState extends State<DogButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Determine opacity based on selection state
    double opacity = 1.0;
    if (widget.isDimmed && !widget.isSelected) {
      opacity = 0.3; // Dimmed state
    }

    final child = Opacity(
      opacity: opacity,
      child: Container(
        decoration: widget.isSelected
            ? BoxDecoration(
                border: Border.all(color: Colors.white, width: 2.5),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              )
            : null,
        child: Image.asset(
          'assets/resources/botonnumero${widget.number}.png',
          fit: BoxFit.contain,
        ),
      ),
    );

    final sizedChild = SizedBox(
      height: widget.height ?? 95,
      child: child,
    );

    if (widget.onTap == null) {
      return sizedChild;
    }

    return Semantics(
      label: 'Perro ${widget.number}',
      button: true,
      selected: widget.isSelected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: sizedChild,
          ),
        ),
      ),
    );
  }
}

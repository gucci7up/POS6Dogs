import 'package:flutter/material.dart';

class ActionButton extends StatefulWidget {
  final Widget? child;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final String? semanticLabel;

  const ActionButton({
    super.key,
    this.child,
    this.onTap,
    this.width = 168,
    this.height = 138,
    this.semanticLabel,
  });

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _isHovered || _isPressed;
    final bgAsset = isActive
        ? 'assets/resources/formabotonactionclara.png'
        : 'assets/resources/formabotonaction.png';

    return Semantics(
      label: widget.semanticLabel,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(bgAsset),
                  fit: BoxFit.fill,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

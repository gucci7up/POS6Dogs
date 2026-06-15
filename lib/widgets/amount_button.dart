import 'package:flutter/material.dart';

class AmountButton extends StatefulWidget {
  final double amount;
  final VoidCallback onTap;
  final double width;
  final double height;

  const AmountButton({
    super.key,
    required this.amount,
    required this.onTap,
    this.width = 220,
    this.height = 145,
  });

  @override
  State<AmountButton> createState() => _AmountButtonState();
}

class _AmountButtonState extends State<AmountButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgAsset = _isHovered
        ? 'assets/resources/verdepeque%C3%B1oclaro.png'
        : 'assets/resources/verdepeque%C3%B1o.png';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
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
              padding: const EdgeInsets.only(bottom: 4), // Visual adjustment for tilted background
              child: Text(
                widget.amount.toInt().toString(),
                style: const TextStyle(
                  fontFamily: 'DinNextLtPro',
                  color: Colors.white,
                  fontSize: 58,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

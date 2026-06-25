import 'package:flutter/material.dart';

class DogOddsCard extends StatefulWidget {
  final int number;
  final String name;
  final String color;
  final double ganarOdds;
  final double exactaOdds;
  final double trifectaOdds;
  final bool isSelected;
  final bool isDimmed;
  final VoidCallback? onTap;
  final double width;

  const DogOddsCard({
    super.key,
    required this.number,
    required this.name,
    required this.color,
    required this.ganarOdds,
    required this.exactaOdds,
    required this.trifectaOdds,
    this.isSelected = false,
    this.isDimmed = false,
    this.onTap,
    this.width = 180,
  });

  @override
  State<DogOddsCard> createState() => _DogOddsCardState();
}

class _DogOddsCardState extends State<DogOddsCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    double opacity = 1.0;
    if (widget.isDimmed && !widget.isSelected) {
      opacity = 0.3;
    }

    final s = widget.width / 220;

    final card = Opacity(
      opacity: opacity,
      child: Container(
        width: widget.width,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isSelected ? const Color(0xFFD4AF37) : Colors.white24,
            width: widget.isSelected ? 2.5 : 1,
          ),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dog photo con número badge más grande
            Stack(
              children: [
                Container(
                  height: 130 * s,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/resources/dog_${widget.number}.png',
                    height: 130 * s,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  left: 6 * s,
                  top: 6 * s,
                  child: Image.asset(
                    'assets/resources/botonnumero${widget.number}.png',
                    height: 54 * s,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
            // Nombre del perro
            Padding(
              padding: EdgeInsets.fromLTRB(10 * s, 6 * s, 10 * s, 8 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: Colors.white,
                      fontSize: 18 * s,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.color,
                    style: TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: Colors.white60,
                      fontSize: 12 * s,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.onTap == null) {
      return card;
    }

    return Semantics(
      label: 'Perro ${widget.number} ${widget.name}',
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
            scale: _isPressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: card,
          ),
        ),
      ),
    );
  }

}

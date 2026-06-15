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
            // Dog photo with number badge overlay
            Stack(
              children: [
                Container(
                  height: 105 * s,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/resources/dog_${widget.number}.png',
                    height: 105 * s,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  left: 6 * s,
                  top: 6 * s,
                  child: Image.asset(
                    'assets/resources/botonnumero${widget.number}.png',
                    height: 40 * s,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
            // Name / color
            Padding(
              padding: EdgeInsets.fromLTRB(10 * s, 6 * s, 10 * s, 4 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: Colors.white,
                      fontSize: 15 * s,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.color,
                    style: TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: Colors.white60,
                      fontSize: 11 * s,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Stats row: GANAR / EXACTA / TRIFECTA
            Container(
              margin: EdgeInsets.fromLTRB(10 * s, 0, 10 * s, 8 * s),
              padding: EdgeInsets.symmetric(vertical: 6 * s),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(child: _statColumn('GANAR', widget.ganarOdds, s)),
                  Expanded(child: _statColumn('EXACTA', widget.exactaOdds, s)),
                  Expanded(child: _statColumn('TRIFECTA', widget.trifectaOdds, s)),
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

  Widget _statColumn(String label, double value, double s) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'DinNextLtPro',
            color: Colors.white54,
            fontSize: 10 * s,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2 * s),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontFamily: 'DinNextLtPro',
            color: Colors.white,
            fontSize: 14 * s,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

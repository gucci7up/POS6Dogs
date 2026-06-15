import 'package:flutter/material.dart';

class TopNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;

  const TopNavigation({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> tabs = ['JUGADA', 'RESULTADOS', 'CUOTAS', 'VENTAS'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(tabs.length, (index) {
        final isActive = index == currentIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onTabChanged(index),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tabs[index],
                    style: TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: isActive ? Colors.white : const Color(0xFFB0A261), // Gold text
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Bottom indicator line
                  Container(
                    width: 65,
                    height: 2.5,
                    color: isActive ? Colors.white : Colors.transparent,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

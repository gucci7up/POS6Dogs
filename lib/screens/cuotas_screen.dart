import 'package:flutter/material.dart';
import 'package:pos/widgets/dog_button.dart';
import 'package:pos/state/pos_state.dart';

class CuotasScreen extends StatefulWidget {
  final PosState state;

  const CuotasScreen({super.key, required this.state});

  @override
  State<CuotasScreen> createState() => _CuotasScreenState();
}

class _CuotasScreenState extends State<CuotasScreen> {
  // Hovers for the 3 print buttons
  final List<bool> _hovers = [false, false, false];

  @override
  Widget build(BuildContext context) {
    final odds = widget.state.oddsHistory;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Odds Table
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Table Header
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF7E7E7E), // Gray header
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'CARRERAS Nu.',
                          style: TextStyle(
                            fontFamily: 'DinNextLtPro',
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Dog button headers 1 to 6
                      Expanded(
                        flex: 6,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            return Expanded(
                              child: Center(
                                child: DogButton(number: index + 1, height: 28),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),

                // Table Rows
                Expanded(
                  child: ListView.builder(
                    itemCount: odds.length,
                    itemBuilder: (context, index) {
                      final item = odds[index];
                      // Alternating rows
                      final isEven = index % 2 == 0;
                      final rowBg = isEven
                          ? Colors.white.withOpacity(0.07)
                          : Colors.white.withOpacity(0.03);

                      return Container(
                        decoration: BoxDecoration(
                          color: rowBg,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withOpacity(0.05),
                              width: 1,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
                        child: Row(
                          children: [
                            // Race Number
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${item.raceNumber}',
                                style: const TextStyle(
                                  fontFamily: 'DinNextLtPro',
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // Odds values
                            Expanded(
                              flex: 6,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(6, (dogIndex) {
                                  return Expanded(
                                    child: Center(
                                      child: Text(
                                        item.odds[dogIndex].toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontFamily: 'DinNextLtPro',
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),

          // Right: Odds Print Buttons (Print 5, Print 10, Print 20)
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                final hoverBg = _hovers[index]
                    ? 'assets/resources/botonprinterclaro.png'
                    : 'assets/resources/botonprinter.png';

                final printValues = [5, 10, 20];
                final value = printValues[index];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _hovers[index] = true),
                    onExit: (_) => setState(() => _hovers[index] = false),
                    child: GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Imprimiendo $value cuotas...'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        width: 210,
                        height: 90,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage(hoverBg),
                            fit: BoxFit.fill,
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 45.0, bottom: 4.0), // Offset to the right of baked-in printer icon
                            child: Text(
                              '$value',
                              style: const TextStyle(
                                fontFamily: 'DinNextLtPro',
                                color: Colors.black87,
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

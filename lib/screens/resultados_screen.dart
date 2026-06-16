import 'package:flutter/material.dart';
import 'package:pos/widgets/dog_button.dart';
import 'package:pos/state/pos_state.dart';
import 'package:pos/services/print_service.dart';

class ResultadosScreen extends StatefulWidget {
  final PosState state;

  const ResultadosScreen({super.key, required this.state});

  @override
  State<ResultadosScreen> createState() => _ResultadosScreenState();
}

class _ResultadosScreenState extends State<ResultadosScreen> {
  bool _hoverPrint = false;

  @override
  Widget build(BuildContext context) {
    final results = widget.state.resultsHistory;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Results Table
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
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
                  child: const Row(
                    children: [
                      Expanded(
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
                      Expanded(
                        flex: 4,
                        child: Center(
                          child: Text(
                            'TRIFECTA',
                            style: TextStyle(
                              fontFamily: 'DinNextLtPro',
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'BONUS',
                            style: TextStyle(
                              fontFamily: 'DinNextLtPro',
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Table Rows
                Expanded(
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final item = results[index];
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
                        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 24.0),
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
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // Trifecta: 3 perros
                            Expanded(
                              flex: 4,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  DogButton(number: item.winner1, height: 36),
                                  const SizedBox(width: 8),
                                  DogButton(number: item.winner2, height: 36),
                                  const SizedBox(width: 8),
                                  if (item.winner3 > 0)
                                    DogButton(number: item.winner3, height: 36),
                                ],
                              ),
                            ),

                            // Bonus
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  item.bonus.isNotEmpty ? item.bonus : '-',
                                  style: TextStyle(
                                    fontFamily: 'DinNextLtPro',
                                    color: item.bonus.isNotEmpty ? Colors.white : Colors.white38,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
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

          // Right: Print Button (resultados del día)
          SizedBox(
            width: 220,
            child: Center(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hoverPrint = true),
                onExit: (_) => setState(() => _hoverPrint = false),
                child: GestureDetector(
                  onTap: () {
                    PrintService.printResultados(
                      widget.state.resultsHistory,
                      widget.state.agencyName,
                      widget.state.currentUser,
                    );
                  },
                  child: Container(
                    width: 200,
                    height: 90,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(
                          _hoverPrint
                              ? 'assets/resources/botonprinterclaro.png'
                              : 'assets/resources/botonprinter.png',
                        ),
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

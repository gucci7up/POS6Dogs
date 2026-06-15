import 'package:flutter/material.dart';
import 'package:pos/state/pos_state.dart';

class VentasScreen extends StatefulWidget {
  final PosState state;

  const VentasScreen({super.key, required this.state});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  bool _isBalanceHovered = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final tickets = state.salesHistory;

    return Container(
      padding: const EdgeInsets.only(left: 48.0, right: 48.0, top: 16.0, bottom: 24.0),
      child: Column(
        children: [
          // Table Section
          Expanded(
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
                  padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 24.0),
                  child: Row(
                    children: [
                      const Expanded(flex: 1, child: Text('Nu.', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold))),
                      const Expanded(flex: 2, child: Text('Fecha/Hora', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold))),
                      const Expanded(flex: 3, child: Text('Jugadas', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold))),
                      const Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('Monto', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)))),
                      const Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('Inversión', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)))),
                      const Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('Pagar', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)))),
                      const Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('Balance', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)))),
                      const Expanded(flex: 2, child: Center(child: Text('Juego', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)))),
                      const Expanded(flex: 1, child: Center(child: Text('Estado', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)))),
                      Icon(Icons.more_vert, color: Colors.black.withOpacity(0.8), size: 20),
                    ],
                  ),
                ),

                // Table Content
                Expanded(
                  child: Container(
                    color: Colors.black.withOpacity(0.2),
                    child: tickets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'No hay tickets disponibles',
                                  style: TextStyle(
                                    fontFamily: 'DinNextLtPro',
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: tickets.length,
                            itemBuilder: (context, index) {
                              final ticket = tickets[index];
                              final isEven = index % 2 == 0;
                              final rowBg = isEven
                                  ? Colors.white.withOpacity(0.07)
                                  : Colors.white.withOpacity(0.03);

                              // Build plays summary string
                              final playsStr = ticket.plays
                                  .map((p) => '${p.dog2 != null ? '${p.dog1}-${p.dog2}' : '${p.dog1}'} (\$${p.amount.toInt()})')
                                  .join(', ');

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
                                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 24.0),
                                child: Row(
                                  children: [
                                    // Ticket Number
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        '${ticket.ticketNumber}',
                                        style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    // Date Time
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        ticket.dateTime,
                                        style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white70, fontSize: 13),
                                      ),
                                    ),
                                    // Plays
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        playsStr,
                                        style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Monto
                                    Expanded(
                                      flex: 1,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          ticket.amount.toStringAsFixed(2),
                                          style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    // Inversión
                                    Expanded(
                                      flex: 1,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          ticket.investment.toStringAsFixed(2),
                                          style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    // Pagar
                                    Expanded(
                                      flex: 1,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          ticket.pay.toStringAsFixed(2),
                                          style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    // Balance
                                    Expanded(
                                      flex: 1,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          ticket.balance.toStringAsFixed(2),
                                          style: const TextStyle(
                                            fontFamily: 'DinNextLtPro',
                                            color: Colors.redAccent,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Juego
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: Text(
                                          ticket.game,
                                          style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white70, fontSize: 13),
                                        ),
                                      ),
                                    ),
                                    // Estado Icon
                                    Expanded(
                                      flex: 1,
                                      child: Center(
                                        child: Image.asset(
                                          _getStatusAsset(ticket.status),
                                          height: 22,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20), // Placeholder for three-dots spacer
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bottom Area: Yellow Summary Bar & BALANCE Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left: Yellow Summary Bar
              Expanded(
                child: Container(
                  height: 65,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD4AF37), // Solid yellow/gold background
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSummaryItem('Jugadas', '${tickets.length}'),
                      _buildSummaryItem('Monto', state.totalMonto.toStringAsFixed(2)),
                      _buildSummaryItem('Inversión', state.totalInversion.toStringAsFixed(2)),
                      _buildSummaryItem('Pagar', state.totalPagar.toStringAsFixed(2)),
                      _buildSummaryItem('Balance', state.totalBalance.toStringAsFixed(2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 45),

              // Right: Large Yellow BALANCE Button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isBalanceHovered = true),
                onExit: (_) => setState(() => _isBalanceHovered = false),
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Calculando balance general: \$${state.totalBalance.toStringAsFixed(2)}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    width: 250,
                    height: 90,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(
                          _isBalanceHovered
                              ? 'assets/resources/balancebuttomclara.png'
                              : 'assets/resources/balancebuttom.png',
                        ),
                        fit: BoxFit.fill,
                      ),
                    ),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 4), // tilt offset
                        child: Text(
                          'BALANCE',
                          style: TextStyle(
                            fontFamily: 'DinNextLtPro',
                            color: Colors.black,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'DinNextLtPro',
            color: Colors.black.withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'DinNextLtPro',
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getStatusAsset(TicketStatus status) {
    switch (status) {
      case TicketStatus.approved:
        return 'assets/resources/statusaproved.png';
      case TicketStatus.winner:
        return 'assets/resources/statuswinner.png';
      case TicketStatus.loser:
        return 'assets/resources/statusloser.png';
      case TicketStatus.paid:
        return 'assets/resources/statuspaid.png';
      case TicketStatus.annulled:
        return 'assets/resources/statusanulled.png';
    }
  }
}

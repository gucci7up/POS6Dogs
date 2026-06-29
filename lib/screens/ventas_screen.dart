import 'package:flutter/material.dart';
import 'package:pos/state/pos_state.dart';
import 'package:pos/services/print_service.dart';

class VentasScreen extends StatefulWidget {
  final PosState state;

  const VentasScreen({super.key, required this.state});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  bool _isBalanceHovered = false;
  bool _isPrinterHovered = false;
  DateTime _selectedDate = DateTime.now();

  List<Ticket> _filtered() {
    final d = _selectedDate;
    return widget.state.salesHistory.where((t) {
      // dateTime format: dd/MM/yyyy HH:mm:ss
      final parts = t.dateTime.split(' ');
      if (parts.isEmpty) return false;
      final dateParts = parts[0].split('/');
      if (dateParts.length < 3) return false;
      final day   = int.tryParse(dateParts[0]) ?? -1;
      final month = int.tryParse(dateParts[1]) ?? -1;
      final year  = int.tryParse(dateParts[2]) ?? -1;
      return day == d.day && month == d.month && year == d.year;
    }).toList();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.day == now.day &&
        _selectedDate.month == now.month &&
        _selectedDate.year == now.year;
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFD4AF37),
            onPrimary: Colors.black,
            surface: Color(0xFF1B1B1B),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();

    final monto   = filtered.fold(0.0, (s, t) => s + t.amount);
    final pagar   = filtered.fold(0.0, (s, t) => s + t.pay);
    final balance = monto - pagar;

    return Container(
      padding: const EdgeInsets.only(left: 48.0, right: 48.0, top: 16.0, bottom: 24.0),
      child: Column(
        children: [
          // ── Selector de fecha ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Día anterior
                _DateNavBtn(
                  icon: Icons.chevron_left,
                  onTap: () => setState(() =>
                      _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
                ),
                const SizedBox(width: 8),
                // Fecha tocable → DatePicker
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B1B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, color: Color(0xFFD4AF37), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _isToday ? 'HOY  ${_formatDate(_selectedDate)}' : _formatDate(_selectedDate),
                            style: const TextStyle(
                              fontFamily: 'DinNextLtPro',
                              color: Color(0xFFD4AF37),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Día siguiente (bloqueado si es hoy)
                _DateNavBtn(
                  icon: Icons.chevron_right,
                  onTap: _isToday
                      ? null
                      : () => setState(() =>
                          _selectedDate = _selectedDate.add(const Duration(days: 1))),
                ),
                if (!_isToday) ...[
                  const SizedBox(width: 12),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDate = DateTime.now()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'HOY',
                          style: TextStyle(
                            fontFamily: 'DinNextLtPro',
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Tabla ──────────────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Header
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF7E7E7E),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 24.0),
                  child: Row(
                    children: [
                      const Expanded(flex: 1, child: Text('Nu.', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold))),
                      const Expanded(flex: 2, child: Text('Fecha/Hora', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold))),
                      const Expanded(flex: 3, child: Text('Jugadas', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold))),
                      const Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('Monto', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)))),
                      const Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('Inversión', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)))),
                      const Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('Pagar', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)))),
                      const Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('Balance', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)))),
                      const Expanded(flex: 2, child: Center(child: Text('Juego', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)))),
                      const Expanded(flex: 1, child: Center(child: Text('Estado', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)))),
                      const SizedBox(width: 60, child: Center(child: Text('Reimpr.', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)))),
                    ],
                  ),
                ),

                // Rows
                Expanded(
                  child: Container(
                    color: Colors.black.withOpacity(0.2),
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'Sin ventas el ${_formatDate(_selectedDate)}',
                              style: TextStyle(
                                fontFamily: 'DinNextLtPro',
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final ticket = filtered[index];
                              final isEven = index % 2 == 0;
                              final rowBg = isEven
                                  ? Colors.white.withOpacity(0.07)
                                  : Colors.white.withOpacity(0.03);

                              final playsStr = ticket.plays.map((p) {
                                final sel = p.dog3 != null
                                    ? '${p.dog1}-${p.dog2}-${p.dog3}'
                                    : p.dog2 != null
                                        ? '${p.dog1}-${p.dog2}'
                                        : '${p.dog1}';
                                return '$sel (\$${p.amount.toInt()})';
                              }).join(', ');

                              return Container(
                                decoration: BoxDecoration(
                                  color: rowBg,
                                  border: Border(
                                    bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 24.0),
                                child: Row(
                                  children: [
                                    Expanded(flex: 1, child: Text('${ticket.ticketNumber}', style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                                    Expanded(flex: 2, child: Text(ticket.dateTime, style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white70, fontSize: 19))),
                                    Expanded(flex: 3, child: Text(playsStr, style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text(ticket.amount.toStringAsFixed(2), style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)))),
                                    Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text(ticket.investment.toStringAsFixed(2), style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)))),
                                    Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: _buildPagarCell(ticket))),
                                    Expanded(
                                      flex: 1,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          ticket.balance.toStringAsFixed(2),
                                          style: TextStyle(
                                            fontFamily: 'DinNextLtPro',
                                            color: ticket.balance >= 0 ? const Color(0xFF5EE97A) : Colors.redAccent,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(flex: 2, child: Center(child: Text(ticket.game, style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white70, fontSize: 19)))),
                                    Expanded(flex: 1, child: Center(child: Image.asset(_getStatusAsset(ticket.status), height: 28, fit: BoxFit.contain))),
                                    SizedBox(
                                      width: 60,
                                      child: Center(
                                        child: IconButton(
                                          icon: const Icon(Icons.print_outlined, color: Color(0xFFD4AF37), size: 20),
                                          tooltip: 'Reimprimir ticket',
                                          onPressed: () => PrintService.printTicketReceipt(
                                            ticket: ticket,
                                            agencyName: widget.state.agencyName,
                                            cashier: widget.state.currentUser,
                                            ticketId: ticket.id,
                                            printerName: widget.state.selectedPrinter,
                                            paperWidthMm: widget.state.selectedPaperWidth,
                                            isReprint: true,
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Barra resumen + botones ────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  height: 65,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD4AF37),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSummaryItem('Jugadas', '${filtered.length}'),
                      _buildSummaryItem('Monto', monto.toStringAsFixed(2)),
                      _buildSummaryItem('Inversión', monto.toStringAsFixed(2)),
                      _buildSummaryItem('Pagar', pagar.toStringAsFixed(2)),
                      _buildSummaryItem('Balance', balance.toStringAsFixed(2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Imprimir (solo tickets del día filtrado)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isPrinterHovered = true),
                onExit: (_) => setState(() => _isPrinterHovered = false),
                child: GestureDetector(
                  onTap: () {
                    PrintService.printVentas(
                      filtered,
                      agencyName: widget.state.agencyName,
                      cashier: widget.state.currentUser,
                      totalMonto: monto,
                      totalInversion: monto,
                      totalPagar: pagar,
                      totalBalance: balance,
                      paperWidthMm: widget.state.selectedPaperWidth,
                    );
                  },
                  child: Container(
                    width: 200,
                    height: 90,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(
                          _isPrinterHovered
                              ? 'assets/resources/botonprinterclaro.png'
                              : 'assets/resources/botonprinter.png',
                        ),
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // BALANCE
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isBalanceHovered = true),
                onExit: (_) => setState(() => _isBalanceHovered = false),
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Balance del ${_formatDate(_selectedDate)}: \$${balance.toStringAsFixed(2)}'),
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
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          'BALANCE',
                          style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 26, fontWeight: FontWeight.bold),
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

  Widget _buildPagarCell(Ticket ticket) {
    switch (ticket.status) {
      case TicketStatus.winner:
      case TicketStatus.paid:
        return Text(ticket.pay.toStringAsFixed(2), style: const TextStyle(fontFamily: 'DinNextLtPro', color: Color(0xFF5EE97A), fontSize: 20, fontWeight: FontWeight.bold));
      case TicketStatus.approved:
        return Text(ticket.potentialPrize.toStringAsFixed(2), style: const TextStyle(fontFamily: 'DinNextLtPro', color: Color(0xFFD4AF37), fontSize: 20, fontWeight: FontWeight.bold));
      default:
        return Text('—', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white.withOpacity(0.3), fontSize: 18));
    }
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _getStatusAsset(TicketStatus status) {
    switch (status) {
      case TicketStatus.approved: return 'assets/resources/statusaproved.png';
      case TicketStatus.winner:   return 'assets/resources/statuswinner.png';
      case TicketStatus.loser:    return 'assets/resources/statusloser.png';
      case TicketStatus.paid:     return 'assets/resources/statuspaid.png';
      case TicketStatus.annulled: return 'assets/resources/statusanulled.png';
    }
  }
}

// ── Botón de navegación de fecha ──────────────────────────────────────────────

class _DateNavBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _DateNavBtn({required this.icon, required this.onTap});

  @override
  State<_DateNavBtn> createState() => _DateNavBtnState();
}

class _DateNavBtnState extends State<_DateNavBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hovered && enabled ? const Color(0xFFD4AF37).withOpacity(0.2) : const Color(0xFF1B1B1B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: enabled ? const Color(0xFFD4AF37) : Colors.white24, width: 1.5),
          ),
          child: Icon(widget.icon, color: enabled ? const Color(0xFFD4AF37) : Colors.white24, size: 20),
        ),
      ),
    );
  }
}

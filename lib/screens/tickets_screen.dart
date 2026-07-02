import 'package:flutter/material.dart';
import 'package:pos/services/api_client.dart';
import 'package:pos/services/print_service.dart';
import 'package:pos/state/pos_state.dart';

class TicketsScreen extends StatefulWidget {
  final PosState state;
  const TicketsScreen({super.key, required this.state});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final ApiClient _api = ApiClient();
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = true;
  String? _error;
  String? _cancellingId;

  static const _gold = Color(0xFFD4AF37);
  static const _red  = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _api.setToken(widget.state.authToken);
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final raceId = widget.state.currentRaceId;
      if (raceId == null) {
        setState(() { _tickets = []; _isLoading = false; });
        return;
      }
      final raw = await _api.getTicketsByRace(raceId);
      setState(() {
        _tickets = raw.cast<Map<String, dynamic>>()
          ..sort((a, b) => (b['ticketNumber'] as int).compareTo(a['ticketNumber'] as int));
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = 'No se pudieron cargar los tickets.'; _isLoading = false; });
    }
  }

  Future<void> _cancel(Map<String, dynamic> ticket) async {
    final number = ticket['ticketNumber'];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar anulación', style: TextStyle(color: Colors.white, fontFamily: 'DinNextLtPro', fontWeight: FontWeight.bold)),
        content: Text(
          '¿Anular el ticket #$number?\nEsta acción no se puede deshacer.',
          style: const TextStyle(color: Colors.white70, fontFamily: 'DinNextLtPro', fontSize: 15),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ANULAR', style: TextStyle(fontFamily: 'DinNextLtPro', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() { _cancellingId = ticket['id'] as String; });
    try {
      await _api.cancelTicket(ticket['id'] as String);
      // Imprimir comprobante de anulación
      PrintService.printCancelledReceipt(
        ticketNumber: number as int,
        ticketId:     ticket['id'] as String,
        details:      (ticket['details'] as List<dynamic>?) ?? [],
        totalAmount:  double.tryParse(ticket['totalAmount']?.toString() ?? '0') ?? 0.0,
        agencyName:   widget.state.agencyName,
        cashier:      widget.state.currentUser,
        printerName:  widget.state.selectedPrinter,
        paperWidthMm: widget.state.selectedPaperWidth,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: _gold, content: Text('Ticket #$number anulado', style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontWeight: FontWeight.bold))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: _red, content: Text(e.toString().replaceAll('ApiException: ', ''), style: const TextStyle(fontFamily: 'DinNextLtPro'))),
        );
      }
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'PENDING': return 'PENDIENTE';
      case 'WON':     return 'GANADO';
      case 'LOST':    return 'PERDIDO';
      case 'PAID':    return 'PAGADO';
      case 'CANCELLED': return 'ANULADO';
      default: return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'PENDING': return Colors.white70;
      case 'WON':
      case 'PAID':    return const Color(0xFF4CAF50);
      case 'CANCELLED': return _red;
      default:        return Colors.white38;
    }
  }

  String _formatPlays(List<dynamic> details) {
    return details.map((d) {
      final sel = d['selection'] as String;
      final amt = double.tryParse(d['amount']?.toString() ?? '0') ?? 0.0;
      final type = d['betType'] as String? ?? '';
      final prefix = type == 'TRIFECTA' ? 'T:' : type == 'WINNER' ? 'G:' : '';
      return '$prefix$sel (\$${amt.toInt()})';
    }).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = widget.state.raceStatus == 'OPEN';

    return Container(
      padding: const EdgeInsets.only(left: 48, right: 48, top: 16, bottom: 24),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TICKETS — CARRERA #${widget.state.currentRace}',
                  style: const TextStyle(fontFamily: 'DinNextLtPro', color: _gold, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                Text(
                  isOpen ? 'Puedes anular tickets mientras la carrera esté ABIERTA' : 'Carrera en curso — anulación no disponible',
                  style: TextStyle(fontFamily: 'DinNextLtPro', color: isOpen ? Colors.white54 : _red, fontSize: 12),
                ),
              ]),
              const Spacer(),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: _isLoading ? null : _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Actualizar', style: TextStyle(fontFamily: 'DinNextLtPro', fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cabecera tabla
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF7E7E7E),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
            child: const Row(children: [
              Expanded(flex: 1, child: Text('Nu.', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold))),
              Expanded(flex: 4, child: Text('Jugadas', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold))),
              Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('Monto', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)))),
              Expanded(flex: 1, child: Center(child: Text('Estado', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)))),
              Expanded(flex: 1, child: Center(child: Text('Acción', style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)))),
            ]),
          ),

          // Filas
          Expanded(
            child: Container(
              color: Colors.black.withOpacity(0.2),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _gold))
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: _red, fontFamily: 'DinNextLtPro')))
                      : _tickets.isEmpty
                          ? const Center(child: Text('No hay tickets para esta carrera', style: TextStyle(color: Colors.white54, fontFamily: 'DinNextLtPro', fontSize: 16)))
                          : ListView.builder(
                              itemCount: _tickets.length,
                              itemBuilder: (ctx, i) {
                                final t = _tickets[i];
                                final status = t['status'] as String? ?? '';
                                final isPending = status == 'PENDING';
                                final canCancel = isOpen && isPending;
                                final isCancelling = _cancellingId == t['id'];
                                final details = (t['details'] as List<dynamic>?) ?? [];
                                final amount = double.tryParse(t['totalAmount']?.toString() ?? '0') ?? 0.0;
                                final isEven = i % 2 == 0;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: status == 'CANCELLED'
                                        ? _red.withOpacity(0.05)
                                        : isEven ? Colors.white.withOpacity(0.05) : Colors.transparent,
                                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                                  child: Row(children: [
                                    Expanded(flex: 1, child: Text('#${t['ticketNumber']}',
                                      style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                                    Expanded(flex: 4, child: Text(_formatPlays(details),
                                      style: TextStyle(fontFamily: 'DinNextLtPro', color: status == 'CANCELLED' ? Colors.white38 : Colors.white, fontSize: 21),
                                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    Expanded(flex: 1, child: Align(alignment: Alignment.centerRight,
                                      child: Text('\$${amount.toStringAsFixed(2)}',
                                        style: TextStyle(fontFamily: 'DinNextLtPro', color: status == 'CANCELLED' ? Colors.white38 : Colors.white, fontSize: 22, fontWeight: FontWeight.bold)))),
                                    Expanded(flex: 1, child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: _statusColor(status).withOpacity(0.5))),
                                        child: Text(_statusLabel(status), style: TextStyle(fontFamily: 'DinNextLtPro', color: _statusColor(status), fontSize: 17, fontWeight: FontWeight.bold)),
                                      ),
                                    )),
                                    Expanded(flex: 1, child: Center(
                                      child: canCancel
                                          ? SizedBox(height: 38,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: _red.withOpacity(0.15), foregroundColor: _red, side: const BorderSide(color: _red), padding: const EdgeInsets.symmetric(horizontal: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                                                onPressed: isCancelling ? null : () => _cancel(t),
                                                child: isCancelling
                                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                                                    : const Text('ANULAR', style: TextStyle(fontFamily: 'DinNextLtPro', fontWeight: FontWeight.bold, fontSize: 15)),
                                              ))
                                          : const SizedBox.shrink(),
                                    )),
                                  ]),
                                );
                              }),
            ),
          ),

          // Totales
          if (_tickets.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), border: Border(top: BorderSide(color: _gold.withOpacity(0.3)))),
              child: Row(children: [
                Text('${_tickets.where((t) => t['status'] != 'CANCELLED').length} tickets activos',
                  style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white70, fontSize: 18)),
                const Spacer(),
                Text(
                  'Total: \$${_tickets.where((t) => t['status'] != 'CANCELLED').fold(0.0, (s, t) => s + (double.tryParse(t['totalAmount']?.toString() ?? '0') ?? 0.0)).toStringAsFixed(2)}',
                  style: const TextStyle(fontFamily: 'DinNextLtPro', color: _gold, fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

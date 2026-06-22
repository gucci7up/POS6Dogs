import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos/services/api_client.dart';
import 'package:pos/state/pos_state.dart';

class PremiosScreen extends StatefulWidget {
  final PosState state;

  const PremiosScreen({super.key, required this.state});

  @override
  State<PremiosScreen> createState() => _PremiosScreenState();
}

class _PremiosScreenState extends State<PremiosScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<Map<String, dynamic>> _pendingTickets = [];
  Map<String, dynamic>? _searchedTicket;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isPaying = false;
  String? _error;
  String? _searchError;
  String? _successMessage;
  String? _payingTicketId;

  static const _gold = Color(0xFFD4AF37);
  static const _green = Color(0xFF4CAF50);
  static const _red = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _api.setToken(widget.state.authToken);
    _loadPending();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadPending() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final raw = await _api.getPendingPaymentTickets();
      setState(() {
        _pendingTickets = raw.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      setState(() { _error = 'No se pudo cargar los premios pendientes.'; _isLoading = false; });
    }
  }

  Future<void> _searchByNumber() async {
    final text = _searchController.text.trim();
    if (text.isEmpty) return;
    final num = int.tryParse(text);
    if (num == null) {
      setState(() { _searchError = 'Ingresa un número de ticket válido.'; });
      return;
    }
    setState(() { _isSearching = true; _searchError = null; _searchedTicket = null; });
    try {
      final ticket = await _api.getTicketByNumber(num);
      setState(() {
        _searchedTicket = ticket;
        _isSearching = false;
      });
    } on ApiException catch (e) {
      setState(() { _searchError = e.message; _isSearching = false; });
    } catch (_) {
      setState(() { _searchError = 'No se encontró el ticket.'; _isSearching = false; });
    }
  }

  Future<void> _payTicket(Map<String, dynamic> ticket) async {
    final ticketId = ticket['id'] as String;
    final number = ticket['ticketNumber'];
    final prize = double.tryParse(ticket['prizeAmount']?.toString() ?? '0') ?? 0.0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar pago', style: TextStyle(color: Colors.white, fontFamily: 'DinNextLtPro', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ticket #$number', style: const TextStyle(color: Colors.white70, fontFamily: 'DinNextLtPro', fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Monto a pagar: \$${prize.toStringAsFixed(2)}',
              style: const TextStyle(color: _gold, fontFamily: 'DinNextLtPro', fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('PAGAR', style: TextStyle(fontFamily: 'DinNextLtPro', fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() { _isPaying = true; _payingTicketId = ticketId; _successMessage = null; _error = null; });
    try {
      await _api.payTicket(ticketId);
      setState(() {
        _successMessage = 'Ticket #$number pagado — \$${prize.toStringAsFixed(2)}';
        _pendingTickets.removeWhere((t) => t['id'] == ticketId);
        if (_searchedTicket?['id'] == ticketId) {
          _searchedTicket = {..._searchedTicket!, 'status': 'PAID'};
        }
        _isPaying = false;
        _payingTicketId = null;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _isPaying = false; _payingTicketId = null; });
    } catch (_) {
      setState(() { _error = 'No se pudo procesar el pago.'; _isPaying = false; _payingTicketId = null; });
    }
  }

  String _formatPlays(List<dynamic> details) {
    return details.map((d) {
      final sel = d['selection'] as String;
      final amt = double.tryParse(d['amount']?.toString() ?? '0') ?? 0.0;
      final type = d['betType'] as String? ?? '';
      final prefix = type == 'TRIFECTA' ? 'T:' : type == 'EXACTA' ? '' : type == 'WINNER' ? 'G:' : '';
      return '$prefix$sel (\$${amt.toInt()})';
    }).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 48, right: 48, top: 16, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              const Text('PREMIOS PENDIENTES',
                style: TextStyle(fontFamily: 'DinNextLtPro', color: _gold, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const Spacer(),
              // Buscador por número
              SizedBox(
                width: 220,
                height: 40,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Colors.white, fontFamily: 'DinNextLtPro', fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'N° de ticket...',
                    hintStyle: TextStyle(color: Colors.white38, fontFamily: 'DinNextLtPro'),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _gold.withOpacity(0.4))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _gold.withOpacity(0.3))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _gold)),
                  ),
                  onSubmitted: (_) => _searchByNumber(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onPressed: _isSearching ? null : _searchByNumber,
                  child: _isSearching
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('BUSCAR', style: TextStyle(fontFamily: 'DinNextLtPro', fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 40,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: _isLoading ? null : _loadPending,
                  child: const Text('↺ Actualizar', style: TextStyle(fontFamily: 'DinNextLtPro', fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Resultado de búsqueda ───────────────────────────────────────
          if (_searchError != null)
            _banner(_searchError!, isError: true),
          if (_searchedTicket != null) ...[
            _TicketCard(
              ticket: _searchedTicket!,
              playsStr: _formatPlays((_searchedTicket!['details'] as List<dynamic>?) ?? []),
              isPaying: _payingTicketId == _searchedTicket!['id'],
              onPay: _searchedTicket!['status'] == 'WON' ? () => _payTicket(_searchedTicket!) : null,
            ),
            const SizedBox(height: 16),
          ],

          // ── Mensajes globales ────────────────────────────────────────────
          if (_successMessage != null) _banner(_successMessage!, isError: false),
          if (_error != null) _banner(_error!, isError: true),

          // ── Tabla de pendientes ──────────────────────────────────────────
          _TableHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _gold))
                : _pendingTickets.isEmpty
                    ? Center(
                        child: Text(
                          'No hay premios pendientes de pago',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontFamily: 'DinNextLtPro', fontSize: 18),
                        ),
                      )
                    : Container(
                        color: Colors.black.withOpacity(0.2),
                        child: ListView.builder(
                          itemCount: _pendingTickets.length,
                          itemBuilder: (ctx, i) {
                            final t = _pendingTickets[i];
                            final isEven = i % 2 == 0;
                            return _TicketRow(
                              ticket: t,
                              playsStr: _formatPlays((t['details'] as List<dynamic>?) ?? []),
                              isEven: isEven,
                              isPaying: _payingTicketId == t['id'],
                              onPay: () => _payTicket(t),
                            );
                          },
                        ),
                      ),
          ),

          // ── Totales ─────────────────────────────────────────────────────
          if (_pendingTickets.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildTotals(),
          ],
        ],
      ),
    );
  }

  Widget _banner(String msg, {required bool isError}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: (isError ? _red : _green).withOpacity(0.15),
        border: Border.all(color: (isError ? _red : _green).withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(msg, style: TextStyle(color: isError ? _red : _green, fontFamily: 'DinNextLtPro', fontSize: 14)),
    );
  }

  Widget _buildTotals() {
    final total = _pendingTickets.fold(0.0, (sum, t) => sum + (double.tryParse(t['prizeAmount']?.toString() ?? '0') ?? 0.0));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        border: Border(top: BorderSide(color: _gold.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Text('${_pendingTickets.length} ticket${_pendingTickets.length != 1 ? 's' : ''} pendientes',
            style: const TextStyle(color: Colors.white70, fontFamily: 'DinNextLtPro', fontSize: 14)),
          const Spacer(),
          const Text('Total a pagar: ', style: TextStyle(color: Colors.white70, fontFamily: 'DinNextLtPro', fontSize: 16)),
          Text('\$${total.toStringAsFixed(2)}',
            style: const TextStyle(color: _gold, fontFamily: 'DinNextLtPro', fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF7E7E7E),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: const Row(
        children: [
          Expanded(flex: 1, child: Text('Nu.', style: style)),
          Expanded(flex: 2, child: Text('Fecha/Hora', style: style)),
          Expanded(flex: 3, child: Text('Jugadas', style: style)),
          Expanded(flex: 1, child: Text('Carrera', style: style)),
          Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('Apostado', style: style))),
          Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('PREMIO', style: style))),
          Expanded(flex: 1, child: Center(child: Text('Acción', style: style))),
        ],
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final String playsStr;
  final bool isEven;
  final bool isPaying;
  final VoidCallback onPay;

  const _TicketRow({
    required this.ticket,
    required this.playsStr,
    required this.isEven,
    required this.isPaying,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final number = ticket['ticketNumber'];
    final prize = double.tryParse(ticket['prizeAmount']?.toString() ?? '0') ?? 0.0;
    final total = double.tryParse(ticket['totalAmount']?.toString() ?? '0') ?? 0.0;
    final raceNum = ticket['race']?['numero'] ?? '—';
    final createdAt = DateTime.tryParse(ticket['createdAt'] as String? ?? '')?.toLocal();
    final dateStr = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')} '
          '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.03),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text('$number', style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text(dateStr, style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white70, fontSize: 13))),
          Expanded(flex: 3, child: Text(playsStr, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white, fontSize: 13))),
          Expanded(flex: 1, child: Text('$raceNum', style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white70, fontSize: 13))),
          Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white, fontSize: 13)))),
          Expanded(flex: 1, child: Align(alignment: Alignment.centerRight,
            child: Text('\$${prize.toStringAsFixed(2)}',
              style: const TextStyle(fontFamily: 'DinNextLtPro', color: Color(0xFF4CAF50), fontSize: 15, fontWeight: FontWeight.bold)))),
          Expanded(
            flex: 1,
            child: Center(
              child: SizedBox(
                height: 34,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: isPaying ? null : onPay,
                  child: isPaying
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('PAGAR', style: TextStyle(fontFamily: 'DinNextLtPro', fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final String playsStr;
  final bool isPaying;
  final VoidCallback? onPay;

  const _TicketCard({required this.ticket, required this.playsStr, required this.isPaying, this.onPay});

  @override
  Widget build(BuildContext context) {
    final number = ticket['ticketNumber'];
    final prize = double.tryParse(ticket['prizeAmount']?.toString() ?? '0') ?? 0.0;
    final total = double.tryParse(ticket['totalAmount']?.toString() ?? '0') ?? 0.0;
    final status = ticket['status'] as String? ?? '';
    final raceNum = ticket['race']?['numero'] ?? '—';

    final statusColor = status == 'WON' ? const Color(0xFF4CAF50)
        : status == 'PAID' ? const Color(0xFF2196F3)
        : status == 'LOST' ? const Color(0xFFE53935)
        : Colors.white54;
    final statusLabel = status == 'WON' ? 'GANADO' : status == 'PAID' ? 'PAGADO' : status == 'LOST' ? 'PERDIDO' : status;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ticket #$number · Carrera $raceNum',
              style: const TextStyle(color: Colors.white70, fontFamily: 'DinNextLtPro', fontSize: 14)),
            const SizedBox(height: 4),
            Text(playsStr, style: const TextStyle(color: Colors.white, fontFamily: 'DinNextLtPro', fontSize: 14)),
            const SizedBox(height: 4),
            Text('Apostado: \$${total.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white54, fontFamily: 'DinNextLtPro', fontSize: 13)),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                border: Border.all(color: statusColor.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statusLabel, style: TextStyle(color: statusColor, fontFamily: 'DinNextLtPro', fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Text('\$${prize.toStringAsFixed(2)}',
              style: const TextStyle(color: Color(0xFF4CAF50), fontFamily: 'DinNextLtPro', fontSize: 28, fontWeight: FontWeight.bold)),
            if (onPay != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isPaying ? null : onPay,
                  child: isPaying
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('PAGAR PREMIO', style: TextStyle(fontFamily: 'DinNextLtPro', fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ] else if (status == 'PAID')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Ya pagado', style: TextStyle(color: Color(0xFF2196F3), fontFamily: 'DinNextLtPro', fontSize: 13)),
              ),
          ]),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pos/services/api_client.dart';
import 'package:pos/services/print_service.dart';
import 'package:pos/state/pos_state.dart';

class PremiosScreen extends StatefulWidget {
  final PosState state;

  const PremiosScreen({super.key, required this.state});

  @override
  State<PremiosScreen> createState() => _PremiosScreenState();
}

class _PremiosScreenState extends State<PremiosScreen> {
  final ApiClient _api = ApiClient();

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

  Future<void> _loadPending() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final raw = await _api.getPendingPaymentTickets();
      setState(() { _pendingTickets = raw.cast<Map<String, dynamic>>(); _isLoading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      setState(() { _error = 'No se pudo cargar los premios pendientes.'; _isLoading = false; });
    }
  }

  Future<void> _openNumPad() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _NumPadDialog(),
    );
    if (result == null || result.isEmpty) return;
    final num = int.tryParse(result);
    if (num == null) {
      setState(() { _searchError = 'Número de ticket inválido.'; });
      return;
    }
    setState(() { _isSearching = true; _searchError = null; _searchedTicket = null; });
    try {
      final ticket = await _api.getTicketByNumber(num);
      setState(() { _searchedTicket = ticket; _isSearching = false; });
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
            Text('\$${prize.toStringAsFixed(2)}',
              style: const TextStyle(color: _gold, fontFamily: 'DinNextLtPro', fontSize: 28, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54, fontFamily: 'DinNextLtPro', fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
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
      // Imprimir comprobante de pago — solo la jugada ganadora
      PrintService.printPaidReceipt(
        ticketNumber:  number as int,
        ticketId:      ticketId,
        prizeAmount:   prize,
        details:       _winningDetails(ticket),
        agencyName:    widget.state.agencyName,
        cashier:       widget.state.currentUser,
        printerName:   widget.state.selectedPrinter,
        paperWidthMm:  widget.state.selectedPaperWidth,
      );
    } on ApiException catch (e) {
      setState(() { _error = e.message; _isPaying = false; _payingTicketId = null; });
    } catch (_) {
      setState(() { _error = 'No se pudo procesar el pago.'; _isPaying = false; _payingTicketId = null; });
    }
  }

  String _formatPlays(List<dynamic> details) {
    return details.map((d) {
      final sel  = d['selection'] as String;
      final amt  = double.tryParse(d['amount']?.toString() ?? '0') ?? 0.0;
      final type = d['betType'] as String? ?? '';
      final prefix = type == 'TRIFECTA' ? 'T:' : type == 'WINNER' ? 'G:' : '';
      return '$prefix$sel (\$${amt.toInt()})';
    }).join(', ');
  }

  // Retorna solo la(s) jugada(s) que coinciden con el resultado de la carrera
  List<dynamic> _winningDetails(Map<String, dynamic> ticket) {
    final details   = (ticket['details'] as List<dynamic>?) ?? [];
    final resultado = ticket['race']?['resultado'] as String? ?? '';
    final parts     = resultado.split('-');
    if (parts.length < 2) return details;

    final w1 = parts[0];
    final w2 = parts.length > 1 ? parts[1] : '';
    final w3 = parts.length > 2 ? parts[2] : '';

    final winning = details.where((d) {
      final type = d['betType'] as String? ?? '';
      final sel  = d['selection'] as String? ?? '';
      switch (type) {
        case 'WINNER':   return sel == w1;
        case 'EXACTA':   return sel == '$w1-$w2';
        case 'TRIFECTA': return sel == '$w1-$w2-$w3';
        default:         return false;
      }
    }).toList();

    return winning.isNotEmpty ? winning : details;
  }

  String _winningPlaysStr(Map<String, dynamic> ticket) =>
      _formatPlays(_winningDetails(ticket));

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
                style: TextStyle(fontFamily: 'DinNextLtPro', color: _gold, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const Spacer(),
              // Botón táctil para abrir numpad
              GestureDetector(
                onTap: _openNumPad,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(color: _gold.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: _gold, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _isSearching ? 'Buscando...' : 'Buscar por N° de ticket',
                        style: TextStyle(
                          color: _isSearching ? _gold : Colors.white54,
                          fontFamily: 'DinNextLtPro',
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
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

          // ── Resultado de búsqueda ────────────────────────────────────────
          if (_searchError != null) _banner(_searchError!, isError: true),
          if (_searchedTicket != null) ...[
            _TicketCard(
              ticket: _searchedTicket!,
              playsStr: _winningPlaysStr(_searchedTicket!),
              isPaying: _payingTicketId == _searchedTicket!['id'],
              onPay: _searchedTicket!['status'] == 'WON' ? () => _payTicket(_searchedTicket!) : null,
            ),
            const SizedBox(height: 12),
          ],

          // ── Mensajes globales ────────────────────────────────────────────
          if (_successMessage != null) _banner(_successMessage!, isError: false),
          if (_error != null) _banner(_error!, isError: true),

          // ── Tabla ────────────────────────────────────────────────────────
          _TableHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _gold))
                : _pendingTickets.isEmpty
                    ? Center(
                        child: Text('No hay premios pendientes de pago',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontFamily: 'DinNextLtPro', fontSize: 18)))
                    : Container(
                        color: Colors.black.withOpacity(0.2),
                        child: ListView.builder(
                          itemCount: _pendingTickets.length,
                          itemBuilder: (ctx, i) {
                            final t = _pendingTickets[i];
                            return _TicketRow(
                              ticket: t,
                              playsStr: _winningPlaysStr(t),
                              isEven: i % 2 == 0,
                              isPaying: _payingTicketId == t['id'],
                              onPay: () => _payTicket(t),
                            );
                          },
                        ),
                      ),
          ),

          // ── Totales ──────────────────────────────────────────────────────
          if (_pendingTickets.isNotEmpty) _buildTotals(),
        ],
      ),
    );
  }

  Widget _banner(String msg, {required bool isError}) => Container(
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
          const Text('Total a pagar: ', style: TextStyle(color: Colors.white70, fontFamily: 'DinNextLtPro', fontSize: 20)),
          Text('\$${total.toStringAsFixed(2)}',
            style: const TextStyle(color: _gold, fontFamily: 'DinNextLtPro', fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ── Diálogo con teclado numérico ────────────────────────────────────────────

class _NumPadDialog extends StatefulWidget {
  @override
  State<_NumPadDialog> createState() => _NumPadDialogState();
}

class _NumPadDialogState extends State<_NumPadDialog> {
  String _value = '';

  void _typeDigit(String d) {
    if (_value.length < 8) setState(() => _value += d);
  }

  void _backspace() {
    if (_value.isNotEmpty) setState(() => _value = _value.substring(0, _value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1F14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('N° de ticket', style: TextStyle(color: Colors.white70, fontFamily: 'DinNextLtPro', fontSize: 16, letterSpacing: 1.2)),
              const SizedBox(height: 16),
              // Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _value.isEmpty ? '—' : _value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _value.isEmpty ? Colors.white30 : Colors.white,
                    fontFamily: 'DinNextLtPro',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Numpad
              SizedBox(
                height: 280,
                child: _NumPad(onDigit: _typeDigit, onBackspace: _backspace),
              ),
              const SizedBox(height: 16),
              // Botones
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar', style: TextStyle(color: Colors.white54, fontFamily: 'DinNextLtPro', fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _value.isEmpty ? null : () => Navigator.pop(context, _value),
                      child: const Text('BUSCAR', style: TextStyle(fontFamily: 'DinNextLtPro', fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── NumPad y NumKey (mismo estilo que login) ─────────────────────────────────

class _NumPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _NumPad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    const sp = 14.0;
    return Column(
      children: [
        Expanded(child: Row(children: [
          Expanded(child: _NumKey(label: '1', onTap: () => onDigit('1'))),
          const SizedBox(width: sp),
          Expanded(child: _NumKey(label: '2', onTap: () => onDigit('2'))),
          const SizedBox(width: sp),
          Expanded(child: _NumKey(label: '3', onTap: () => onDigit('3'))),
        ])),
        const SizedBox(height: sp),
        Expanded(child: Row(children: [
          Expanded(child: _NumKey(label: '4', onTap: () => onDigit('4'))),
          const SizedBox(width: sp),
          Expanded(child: _NumKey(label: '5', onTap: () => onDigit('5'))),
          const SizedBox(width: sp),
          Expanded(child: _NumKey(label: '6', onTap: () => onDigit('6'))),
        ])),
        const SizedBox(height: sp),
        Expanded(child: Row(children: [
          Expanded(child: _NumKey(label: '7', onTap: () => onDigit('7'))),
          const SizedBox(width: sp),
          Expanded(child: _NumKey(label: '8', onTap: () => onDigit('8'))),
          const SizedBox(width: sp),
          Expanded(child: _NumKey(label: '9', onTap: () => onDigit('9'))),
        ])),
        const SizedBox(height: sp),
        Expanded(child: Row(children: [
          Expanded(flex: 2, child: _NumKey(icon: Icons.backspace_outlined, highlighted: true, onTap: onBackspace)),
          const SizedBox(width: sp),
          Expanded(child: _NumKey(label: '0', onTap: () => onDigit('0'))),
        ])),
      ],
    );
  }
}

class _NumKey extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final bool highlighted;
  final VoidCallback onTap;

  const _NumKey({this.label, this.icon, this.highlighted = false, required this.onTap});

  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final BoxDecoration deco;
    final Color contentColor;

    if (widget.highlighted) {
      deco = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _pressed
              ? [const Color(0xFFE6C75B), const Color(0xFFB8902C)]
              : [const Color(0xFFD4AF37), const Color(0xFFA67C1F)],
        ),
        borderRadius: BorderRadius.circular(10),
      );
      contentColor = const Color(0xFF12241A);
    } else {
      deco = BoxDecoration(
        color: Colors.white.withOpacity(_pressed ? 0.14 : 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(_pressed ? 0.8 : 0.35), width: 1.5),
      );
      contentColor = Colors.white;
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: deco,
        child: Center(
          child: widget.icon != null
              ? Icon(widget.icon, color: contentColor, size: 22)
              : Text(widget.label!, style: TextStyle(color: contentColor, fontFamily: 'DinNextLtPro', fontSize: 24, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// ── Tabla header ─────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: 'DinNextLtPro', color: Colors.black, fontSize: 25, fontWeight: FontWeight.bold);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF7E7E7E),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: const Row(children: [
        Expanded(flex: 1, child: Text('Nu.', style: style)),
        Expanded(flex: 2, child: Text('Fecha/Hora', style: style)),
        Expanded(flex: 3, child: Text('Jugadas', style: style)),
        Expanded(flex: 1, child: Text('Carrera', style: style)),
        Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('Apostado', style: style))),
        Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('PREMIO', style: style))),
        Expanded(flex: 1, child: Center(child: Text('Acción', style: style))),
      ]),
    );
  }
}

// ── Fila de ticket ────────────────────────────────────────────────────────────

class _TicketRow extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final String playsStr;
  final bool isEven;
  final bool isPaying;
  final VoidCallback onPay;

  const _TicketRow({required this.ticket, required this.playsStr, required this.isEven, required this.isPaying, required this.onPay});

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
      child: Row(children: [
        Expanded(flex: 1, child: Text('$number', style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold))),
        Expanded(flex: 2, child: Text(dateStr, style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white70, fontSize: 23))),
        Expanded(flex: 3, child: Text(playsStr, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white, fontSize: 23))),
        Expanded(flex: 1, child: Text('$raceNum', style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white70, fontSize: 23))),
        Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white, fontSize: 23)))),
        Expanded(flex: 1, child: Align(alignment: Alignment.centerRight,
          child: Text('\$${prize.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'DinNextLtPro', color: Color(0xFF4CAF50), fontSize: 23, fontWeight: FontWeight.bold)))),
        Expanded(flex: 1, child: Center(
          child: SizedBox(
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: isPaying ? null : onPay,
              child: isPaying
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('PAGAR', style: TextStyle(fontFamily: 'DinNextLtPro', fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
        )),
      ]),
    );
  }
}

// ── Card de ticket buscado ───────────────────────────────────────────────────

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
    final statusLabel = status == 'WON' ? 'GANADO — PENDIENTE DE PAGO'
        : status == 'PAID' ? 'PAGADO'
        : status == 'LOST' ? 'PERDIDO'
        : status;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ticket #$number · Carrera $raceNum',
              style: const TextStyle(color: Colors.white70, fontFamily: 'DinNextLtPro', fontSize: 14)),
            const SizedBox(height: 4),
            Text(playsStr, style: const TextStyle(color: Colors.white, fontFamily: 'DinNextLtPro', fontSize: 14)),
            const SizedBox(height: 4),
            Text('Apostado: \$${total.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white54, fontFamily: 'DinNextLtPro', fontSize: 13)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              border: Border.all(color: statusColor.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontFamily: 'DinNextLtPro', fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Text('\$${prize.toStringAsFixed(2)}',
            style: const TextStyle(color: Color(0xFF4CAF50), fontFamily: 'DinNextLtPro', fontSize: 30, fontWeight: FontWeight.bold)),
          if (onPay != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isPaying ? null : onPay,
                child: isPaying
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('PAGAR PREMIO', style: TextStyle(fontFamily: 'DinNextLtPro', fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ] else if (status == 'PAID')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Ya pagado ✓', style: TextStyle(color: Color(0xFF2196F3), fontFamily: 'DinNextLtPro', fontSize: 14)),
            ),
        ]),
      ]),
    );
  }
}

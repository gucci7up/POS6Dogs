import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pos/state/pos_state.dart';

/// Genera e imprime recibos en formato térmico 80 mm.
class PrintService {
  static const _fmt = PdfPageFormat(
    80 * PdfPageFormat.mm,
    double.infinity,
    marginAll: 5 * PdfPageFormat.mm,
  );

  // ── Helpers de estilo ──────────────────────────────────────────────────────

  static pw.TextStyle _bold({double size = 9}) =>
      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: size);

  static pw.TextStyle _reg({double size = 9}) =>
      pw.TextStyle(fontSize: size);

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  static String _money(double v) => v.toStringAsFixed(2);

  static String _line([String char = '-']) => char * 38;

  static pw.Widget _hr([double thickness = 0.4]) =>
      pw.Divider(thickness: thickness, color: PdfColors.black);

  // ── Cabecera común ─────────────────────────────────────────────────────────

  static List<pw.Widget> _header(
      String title, String agencyName, String cashier) {
    final now = DateTime.now();
    return [
      pw.Center(
        child: pw.Text('MBSPORT RACING DOGS', style: _bold(size: 12)),
      ),
      pw.Center(child: pw.Text('Racing Dogs - Sistema POS', style: _reg(size: 8))),
      pw.SizedBox(height: 6),
      _hr(0.8),
      pw.Center(child: pw.Text(title, style: _bold(size: 11))),
      _hr(0.8),
      pw.SizedBox(height: 4),
      _infoRow('Fecha', _date(now)),
      _infoRow('Hora', _time(now)),
      _infoRow('Agencia', agencyName),
      _infoRow('Cajero', cashier),
      pw.SizedBox(height: 4),
      _hr(),
    ];
  }

  // ── Pie de página común ────────────────────────────────────────────────────

  static List<pw.Widget> _footer() => [
        pw.SizedBox(height: 6),
        _hr(0.8),
        pw.Center(child: pw.Text('** MBSPORT RACING DOGS 2026 **', style: _bold(size: 7))),
        pw.Center(child: pw.Text('www.mbsport.lat', style: _reg(size: 7))),
        pw.SizedBox(height: 8),
      ];

  static pw.Widget _infoRow(String label, String value) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: _bold(size: 8)),
          pw.Text(value, style: _reg(size: 8)),
        ],
      );

  static pw.Widget _summaryRow(String label, String value,
      {bool highlight = false}) =>
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: highlight ? _bold(size: 9) : _reg(size: 8)),
          pw.Text(value, style: highlight ? _bold(size: 9) : _reg(size: 8)),
        ],
      );

  // ══════════════════════════════════════════════════════════════════════════
  // RESULTADOS DEL DÍA
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> printResultados(
    List<RaceResult> results,
    String agencyName,
    String cashier,
  ) async {
    final pdf = pw.Document(title: 'Resultados del Dia');

    pdf.addPage(
      pw.Page(
        pageFormat: _fmt,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            ..._header('RESULTADOS DEL DIA', agencyName, cashier),

            // Encabezado de tabla
            pw.Row(children: [
              pw.SizedBox(
                width: 30,
                child: pw.Text('N°', style: _bold(size: 8)),
              ),
              pw.Expanded(
                child: pw.Center(
                  child: pw.Text('TRIFECTA', style: _bold(size: 8)),
                ),
              ),
              pw.SizedBox(
                width: 42,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('BONUS', style: _bold(size: 8)),
                ),
              ),
            ]),
            _hr(0.3),

            // Filas de resultados
            ...results.map((r) {
              final trifecta = r.winner3 > 0
                  ? '${r.winner1} - ${r.winner2} - ${r.winner3}'
                  : '${r.winner1} - ${r.winner2}';
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                child: pw.Row(children: [
                  pw.SizedBox(
                    width: 30,
                    child: pw.Text('${r.raceNumber}', style: _reg(size: 8)),
                  ),
                  pw.Expanded(
                    child: pw.Center(
                      child: pw.Text(trifecta,
                          style: _bold(size: 8)),
                    ),
                  ),
                  pw.SizedBox(
                    width: 42,
                    child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        r.bonus.isNotEmpty ? r.bonus : '-',
                        style: _reg(size: 8),
                      ),
                    ),
                  ),
                ]),
              );
            }),

            _hr(0.3),
            pw.SizedBox(height: 4),
            _summaryRow('Total carreras', '${results.length}', highlight: true),

            ..._footer(),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VENTAS DEL DÍA
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> printVentas(
    List<Ticket> tickets, {
    required String agencyName,
    required String cashier,
    required double totalMonto,
    required double totalInversion,
    required double totalPagar,
    required double totalBalance,
  }) async {
    final pdf = pw.Document(title: 'Ventas del Dia');

    pdf.addPage(
      pw.Page(
        pageFormat: _fmt,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            ..._header('VENTAS DEL DIA', agencyName, cashier),

            // Encabezado de tabla
            pw.Row(children: [
              pw.SizedBox(width: 26, child: pw.Text('N°', style: _bold(size: 7))),
              pw.SizedBox(width: 36, child: pw.Text('HORA', style: _bold(size: 7))),
              pw.Expanded(child: pw.Text('JUGADA', style: _bold(size: 7))),
              pw.SizedBox(
                  width: 38,
                  child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text('MONTO', style: _bold(size: 7)))),
              pw.SizedBox(
                  width: 36,
                  child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text('PAGAR', style: _bold(size: 7)))),
            ]),
            _hr(0.3),

            // Filas de tickets
            ...tickets.map((t) {
              final plays = t.plays.map((p) {
                if (p.dog3 != null) return '${p.dog1}-${p.dog2}-${p.dog3}';
                if (p.dog2 != null) return '${p.dog1}-${p.dog2}';
                return '${p.dog1}';
              }).join('  ');

              final timeParts = t.dateTime.split(' ');
              final rawTime = timeParts.length > 1 ? timeParts.last : t.dateTime;
              final shortTime = rawTime.length >= 5 ? rawTime.substring(0, 5) : rawTime;

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                          width: 26,
                          child: pw.Text('${t.ticketNumber}', style: _reg(size: 7))),
                      pw.SizedBox(
                          width: 36,
                          child: pw.Text(shortTime, style: _reg(size: 7))),
                      pw.Expanded(
                          child: pw.Text(
                        plays.isNotEmpty ? plays : '-',
                        style: _reg(size: 7),
                      )),
                      pw.SizedBox(
                          width: 38,
                          child: pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text(_money(t.amount),
                                  style: _reg(size: 7)))),
                      pw.SizedBox(
                          width: 36,
                          child: pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child:
                                  pw.Text(_money(t.pay), style: _reg(size: 7)))),
                    ],
                  ),
                  pw.Text('  ${_statusLabel(t.status)}',
                      style: _reg(size: 6)),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1),
                    child: pw.Divider(thickness: 0.2, color: PdfColors.grey400),
                  ),
                ],
              );
            }),

            pw.SizedBox(height: 6),

            // Resumen de totales
            pw.Container(
              padding: const pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
              child: pw.Column(
                children: [
                  _summaryRow('Total jugadas', '${tickets.length}'),
                  _summaryRow('Monto total', _money(totalMonto)),
                  _summaryRow('Inversion', _money(totalInversion)),
                  _summaryRow('Total a pagar', _money(totalPagar)),
                  _hr(0.5),
                  _summaryRow('BALANCE', _money(totalBalance), highlight: true),
                ],
              ),
            ),

            ..._footer(),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RECIBO DE TICKET INDIVIDUAL
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> printTicketReceipt({
    required Ticket ticket,
    required String agencyName,
    required String cashier,
    String? ticketId,
    String printerName = 'Impresora predeterminada',
  }) async {
    final pdf = pw.Document(title: 'Ticket #${ticket.ticketNumber}');

    final qrUrl = ticketId != null
        ? 'https://tickets6.mbsport.lat/?id=$ticketId'
        : null;

    // Cargar logo desde assets
    final logoBytes = await rootBundle.load('assets/resources/logo_principal.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final now = DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: _fmt,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo
            pw.Center(
              child: pw.Image(logoImage, width: 120, height: 60, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(height: 6),
            _hr(0.8),
            pw.Center(child: pw.Text('TICKET DE APUESTA', style: _bold(size: 11))),
            _hr(0.8),
            pw.SizedBox(height: 4),
            _infoRow('Fecha', _date(now)),
            _infoRow('Hora', _time(now)),
            _infoRow('Agencia', agencyName),
            _infoRow('Cajero', cashier),
            pw.SizedBox(height: 4),
            _hr(),

            _infoRow('Ticket N°', '#${ticket.ticketNumber}'),
            pw.SizedBox(height: 4),
            _hr(),

            // Jugadas
            pw.Text('JUGADAS', style: _bold(size: 8)),
            pw.SizedBox(height: 4),
            ...ticket.plays.map((play) {
              String sel;
              if (play.dog3 != null) {
                sel = '${play.dog1}-${play.dog2}-${play.dog3}';
              } else if (play.dog2 != null) {
                sel = '${play.dog1}-${play.dog2}';
              } else {
                sel = '${play.dog1}';
              }
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(sel, style: _bold(size: 9)),
                    pw.Text(
                      '\$${_money(play.amount)} × ${play.odds.toStringAsFixed(2)}',
                      style: _reg(size: 8),
                    ),
                  ],
                ),
              );
            }),
            _hr(0.3),

            pw.SizedBox(height: 4),
            _summaryRow('Total apostado', '\$${_money(ticket.amount)}', highlight: true),
            pw.SizedBox(height: 2),
            _summaryRow('Premio potencial', '\$${_money(ticket.potentialPrize)}'),
            pw.SizedBox(height: 4),
            _hr(),

            // QR al pie — escanear lleva directo al resultado del ticket
            if (qrUrl != null) ...[
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrUrl,
                  width: 72,
                  height: 72,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Escanea para ver tu resultado',
                  style: _reg(size: 7),
                ),
              ),
              pw.SizedBox(height: 2),
            ],

            ..._footer(),
          ],
        ),
      ),
    );

    // Impresión directa — sin diálogo de sistema
    final printers = await Printing.listPrinters();
    Printer? target;
    if (printerName != 'Impresora predeterminada') {
      target = printers.where((p) => p.name.contains(printerName)).firstOrNull;
    }
    target ??= printers.where((p) => p.isDefault).firstOrNull ?? printers.firstOrNull;

    if (target != null) {
      await Printing.directPrintPdf(
        printer: target,
        onLayout: (_) async => await pdf.save(),
      );
    } else {
      // Fallback: mostrar diálogo si no se encuentra ninguna impresora
      await Printing.layoutPdf(onLayout: (_) => pdf.save());
    }
  }

  // ── Helpers internos ────────────────────────────────────────────────────────

  static String _statusLabel(TicketStatus s) {
    switch (s) {
      case TicketStatus.approved:
        return 'APROBADO';
      case TicketStatus.winner:
        return 'GANADOR';
      case TicketStatus.loser:
        return 'PERDEDOR';
      case TicketStatus.paid:
        return 'PAGADO';
      case TicketStatus.annulled:
        return 'ANULADO';
    }
  }
}

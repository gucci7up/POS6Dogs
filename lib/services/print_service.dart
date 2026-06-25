import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pos/state/pos_state.dart';

/// Genera e imprime recibos en formato térmico 58 mm u 80 mm.
class PrintService {
  static PdfPageFormat _fmt(int widthMm) => widthMm <= 58
      ? PdfPageFormat(
          widthMm * PdfPageFormat.mm,
          double.infinity,
          marginLeft: 3 * PdfPageFormat.mm,
          marginRight: 5 * PdfPageFormat.mm,
          marginTop: 2 * PdfPageFormat.mm,
          marginBottom: 2 * PdfPageFormat.mm,
        )
      : PdfPageFormat(
          widthMm * PdfPageFormat.mm,
          double.infinity,
          marginAll: 5 * PdfPageFormat.mm,
        );

  // Reduce tamaño de fuente en 1pt para papel de 58mm, mínimo 7pt
  static double _s(double size, int widthMm) =>
      widthMm <= 58 ? (size - 1).clamp(7, 20) : size;

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

  static pw.Widget _hr([double thickness = 0.4]) =>
      pw.Divider(thickness: thickness, color: PdfColors.black);

  // ── Cabecera común ─────────────────────────────────────────────────────────

  static List<pw.Widget> _header(
      String title, String agencyName, String cashier, int widthMm) {
    final now = DateTime.now();
    return [
      pw.Center(
        child: pw.Text('MBSPORT RACING DOGS', style: _bold(size: _s(12, widthMm))),
      ),
      pw.Center(child: pw.Text('Racing Dogs - Sistema POS', style: _reg(size: _s(7, widthMm)))),
      pw.SizedBox(height: 4),
      _hr(0.8),
      pw.Center(child: pw.Text(title, style: _bold(size: _s(10, widthMm)))),
      _hr(0.8),
      pw.SizedBox(height: 3),
      _infoRow('Fecha', _date(now), widthMm),
      _infoRow('Hora', _time(now), widthMm),
      _infoRow('Agencia', agencyName, widthMm),
      _infoRow('Cajero', cashier, widthMm),
      pw.SizedBox(height: 3),
      _hr(),
    ];
  }

  // ── Pie de página para ticket de jugadas ──────────────────────────────────

  static List<pw.Widget> _footer(int widthMm) => [
        pw.SizedBox(height: 6),
        _hr(0.8),
        pw.Center(child: pw.Text('*** IMPORTANTE ***', style: _bold(size: _s(8, widthMm)))),
        pw.SizedBox(height: 2),
        pw.Center(child: pw.Text('CONSERVE SU TICKET', style: _reg(size: _s(7, widthMm)))),
        pw.Center(child: pw.Text('LOS PREMIOS SE PAGAN', style: _reg(size: _s(7, widthMm)))),
        pw.Center(child: pw.Text('UNICAMENTE CONTRA LA', style: _reg(size: _s(7, widthMm)))),
        pw.Center(child: pw.Text('PRESENTACION DEL TICKET', style: _reg(size: _s(7, widthMm)))),
        pw.Center(child: pw.Text('ORIGINAL.', style: _reg(size: _s(7, widthMm)))),
        pw.SizedBox(height: 6),
        _hr(0.8),
        pw.Center(child: pw.Text('** MBSPORT RACING DOGS 2026 **', style: _bold(size: _s(7, widthMm)))),
        pw.Center(child: pw.Text('www.mbsport.lat', style: _reg(size: _s(7, widthMm)))),
        pw.SizedBox(height: 6),
      ];

  // ── Pie de página para cuadre diario (ventas) ─────────────────────────────

  static List<pw.Widget> _footerVentas(int widthMm) => [
        pw.SizedBox(height: 6),
        _hr(0.8),
        pw.Center(child: pw.Text('CUADRE DIARIO', style: _bold(size: _s(10, widthMm)))),
        pw.SizedBox(height: 6),
        _hr(0.8),
        pw.Center(child: pw.Text('** MBSPORT RACING DOGS 2026 **', style: _bold(size: _s(7, widthMm)))),
        pw.Center(child: pw.Text('www.mbsport.lat', style: _reg(size: _s(7, widthMm)))),
        pw.SizedBox(height: 6),
      ];

  // Fila etiqueta | valor — el valor usa Flexible para no desbordar
  static pw.Widget _infoRow(String label, String value, int widthMm) {
    final sz = _s(8, widthMm);
    return pw.Row(
      children: [
        pw.Text(label, style: _bold(size: sz)),
        pw.SizedBox(width: 4),
        pw.Flexible(
          child: pw.Text(
            value,
            style: _reg(size: sz),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  static pw.Widget _summaryRow(String label, String value,
      {bool highlight = false, int widthMm = 80}) {
    final style = highlight ? _bold(size: _s(9, widthMm)) : _reg(size: _s(8, widthMm));
    return pw.Row(
      children: [
        pw.SizedBox(
          width: widthMm <= 58 ? 90 : 120,
          child: pw.Text(label, style: style),
        ),
        pw.Text(value, style: style),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RESULTADOS DEL DÍA
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> printResultados(
    List<RaceResult> results,
    String agencyName,
    String cashier, {
    int paperWidthMm = 80,
  }) async {
    final pdf = pw.Document(title: 'Resultados del Dia');

    pdf.addPage(
      pw.Page(
        pageFormat: _fmt(paperWidthMm),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            ..._header('RESULTADOS DEL DIA', agencyName, cashier, paperWidthMm),

            // Encabezado de tabla
            pw.Row(children: [
              pw.SizedBox(
                width: 26,
                child: pw.Text('N°', style: _bold(size: _s(8, paperWidthMm))),
              ),
              pw.Expanded(
                child: pw.Center(
                  child: pw.Text('TRIFECTA', style: _bold(size: _s(8, paperWidthMm))),
                ),
              ),
              pw.SizedBox(
                width: 34,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('BONUS', style: _bold(size: _s(8, paperWidthMm))),
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
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(children: [
                  pw.SizedBox(
                    width: 26,
                    child: pw.Text('${r.raceNumber}', style: _reg(size: _s(8, paperWidthMm))),
                  ),
                  pw.Expanded(
                    child: pw.Center(
                      child: pw.Text(trifecta, style: _bold(size: _s(8, paperWidthMm))),
                    ),
                  ),
                  pw.SizedBox(
                    width: 34,
                    child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        r.bonus.isNotEmpty ? r.bonus : '-',
                        style: _reg(size: _s(8, paperWidthMm)),
                      ),
                    ),
                  ),
                ]),
              );
            }),

            _hr(0.3),
            pw.SizedBox(height: 4),
            _summaryRow('Total carreras', '${results.length}', highlight: true, widthMm: paperWidthMm),

            ..._footer(paperWidthMm),
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
    int paperWidthMm = 80,
  }) async {
    final pdf = pw.Document(title: 'Ventas del Dia');

    pdf.addPage(
      pw.Page(
        pageFormat: _fmt(paperWidthMm),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            ..._header('VENTAS DEL DIA', agencyName, cashier, paperWidthMm),

            // Encabezado de tabla
            pw.Row(children: [
              pw.SizedBox(width: 22, child: pw.Text('N°', style: _bold(size: _s(7, paperWidthMm)))),
              pw.SizedBox(width: 28, child: pw.Text('HORA', style: _bold(size: _s(7, paperWidthMm)))),
              pw.Expanded(child: pw.Text('JUGADA', style: _bold(size: _s(7, paperWidthMm)))),
              pw.SizedBox(
                  width: 32,
                  child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text('MONTO', style: _bold(size: _s(7, paperWidthMm))))),
              pw.SizedBox(
                  width: 30,
                  child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text('PAGAR', style: _bold(size: _s(7, paperWidthMm))))),
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
                          width: 22,
                          child: pw.Text('${t.ticketNumber}', style: _reg(size: _s(7, paperWidthMm)))),
                      pw.SizedBox(
                          width: 28,
                          child: pw.Text(shortTime, style: _reg(size: _s(7, paperWidthMm)))),
                      pw.Expanded(
                          child: pw.Text(
                        plays.isNotEmpty ? plays : '-',
                        style: _reg(size: _s(7, paperWidthMm)),
                      )),
                      pw.SizedBox(
                          width: 32,
                          child: pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text(_money(t.amount),
                                  style: _reg(size: _s(7, paperWidthMm))))),
                      pw.SizedBox(
                          width: 30,
                          child: pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text(_money(t.pay), style: _reg(size: _s(7, paperWidthMm))))),
                    ],
                  ),
                  pw.Text('  ${_statusLabel(t.status)}', style: _reg(size: _s(6, paperWidthMm))),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1),
                    child: pw.Divider(thickness: 0.2, color: PdfColors.grey400),
                  ),
                ],
              );
            }),

            pw.SizedBox(height: 4),

            // Resumen de totales
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
              child: pw.Column(
                children: [
                  _summaryRow('Total jugadas', '${tickets.length}', widthMm: paperWidthMm),
                  _summaryRow('Monto total', _money(totalMonto), widthMm: paperWidthMm),
                  _summaryRow('Inversion', _money(totalInversion), widthMm: paperWidthMm),
                  _summaryRow('Total a pagar', _money(totalPagar), widthMm: paperWidthMm),
                  _hr(0.5),
                  _summaryRow('BALANCE', _money(totalBalance), highlight: true, widthMm: paperWidthMm),
                ],
              ),
            ),

            ..._footerVentas(paperWidthMm),
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
    int paperWidthMm = 80,
  }) async {
    final pdf = pw.Document(title: 'Ticket #${ticket.ticketNumber}');

    final qrUrl = ticketId != null
        ? 'https://tickets6.mbsport.lat/?id=$ticketId'
        : null;

    // Cargar logo desde assets
    final logoBytes = await rootBundle.load('assets/resources/logo_principal.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final now = DateTime.now();
    final logoWidth  = paperWidthMm <= 58 ? 100.0 : 150.0;
    final logoHeight = paperWidthMm <= 58 ?  50.0 :  75.0;
    final qrSize     = paperWidthMm <= 58 ? 52.0 :  72.0;

    pdf.addPage(
      pw.Page(
        pageFormat: _fmt(paperWidthMm),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo
            pw.Center(
              child: pw.Image(logoImage, width: logoWidth, height: logoHeight, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(height: 4),
            _hr(0.8),
            pw.Center(child: pw.Text('TICKET DE APUESTA', style: _bold(size: _s(10, paperWidthMm)))),
            _hr(0.8),
            pw.SizedBox(height: 3),
            _infoRow('Fecha', _date(now), paperWidthMm),
            _infoRow('Hora', _time(now), paperWidthMm),
            _infoRow('Agencia', agencyName, paperWidthMm),
            _infoRow('Cajero', cashier, paperWidthMm),
            pw.SizedBox(height: 3),
            _hr(),

            _infoRow('#CARRERA', '${ticket.raceNumber}', paperWidthMm),
            _infoRow('#TICKET', '${ticket.ticketNumber}', paperWidthMm),
            pw.SizedBox(height: 3),
            _hr(),

            // Tabla de jugadas: # | Tipo | Num | Cuota | Monto
            // Todos los anchos fijos para evitar que Monto se corte
            pw.Row(children: [
              pw.SizedBox(width: 10,  child: pw.Text('#',     style: _bold(size: 7))),
              pw.SizedBox(width: paperWidthMm <= 58 ? 30 : 40,
                                       child: pw.Text('Tipo',  style: _bold(size: 7))),
              pw.SizedBox(width: paperWidthMm <= 58 ? 20 : 26,
                                       child: pw.Text('Num',   style: _bold(size: 7))),
              pw.SizedBox(width: paperWidthMm <= 58 ? 24 : 30,
                          child: pw.Align(alignment: pw.Alignment.centerRight,
                              child: pw.Text('Cuota', style: _bold(size: 7)))),
              pw.SizedBox(width: paperWidthMm <= 58 ? 36 : 46,
                          child: pw.Align(alignment: pw.Alignment.centerRight,
                              child: pw.Text('Monto', style: _bold(size: 7)))),
            ]),
            _hr(0.3),
            ...ticket.plays.asMap().entries.map((entry) {
              final i    = entry.key + 1;
              final play = entry.value;
              String sel;
              String tipo;
              if (play.dog3 != null) {
                sel  = '${play.dog1}-${play.dog2}-${play.dog3}';
                tipo = 'Tripleta';
              } else if (play.dog2 != null) {
                sel  = '${play.dog1}-${play.dog2}';
                tipo = 'Pale';
              } else {
                sel  = '${play.dog1}';
                tipo = 'Quiniela';
              }
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                child: pw.Row(children: [
                  pw.SizedBox(width: 10,
                      child: pw.Text('$i', style: _reg(size: 7))),
                  pw.SizedBox(width: paperWidthMm <= 58 ? 30 : 40,
                      child: pw.Text(tipo, style: _bold(size: 7))),
                  pw.SizedBox(width: paperWidthMm <= 58 ? 20 : 26,
                      child: pw.Text(sel,  style: _reg(size: 7))),
                  pw.SizedBox(width: paperWidthMm <= 58 ? 24 : 30,
                      child: pw.Align(alignment: pw.Alignment.centerRight,
                          child: pw.Text(play.odds.toStringAsFixed(2),
                              style: _reg(size: 7)))),
                  pw.SizedBox(width: paperWidthMm <= 58 ? 36 : 46,
                      child: pw.Align(alignment: pw.Alignment.centerRight,
                          child: pw.Text('\$${_money(play.amount)}',
                              style: _bold(size: 7)))),
                ]),
              );
            }),
            _hr(0.3),

            pw.SizedBox(height: 3),
            _summaryRow('Total apostado', '\$${_money(ticket.amount)}', highlight: true, widthMm: paperWidthMm),
            pw.SizedBox(height: 2),
            _summaryRow('Premio potencial', '\$${_money(ticket.potentialPrize)}', widthMm: paperWidthMm),
            pw.SizedBox(height: 3),
            _hr(),

            // QR al pie — escanear lleva directo al resultado del ticket
            if (qrUrl != null) ...[
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrUrl,
                  width: qrSize,
                  height: qrSize,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  'Escanea para ver tu resultado',
                  style: _reg(size: _s(7, paperWidthMm)),
                ),
              ),
              pw.SizedBox(height: 2),
            ],

            ..._footer(paperWidthMm),
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

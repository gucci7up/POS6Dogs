import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pos/state/pos_state.dart';

class RightPanel extends StatefulWidget {
  final PosState state;
  final VoidCallback onLogout;

  const RightPanel({super.key, required this.state, required this.onLogout});

  @override
  State<RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<RightPanel> {
  bool _isCogHovered = false;
  bool _isDisplayHovered = false;
  Process? _displayProcess; // rastrear proceso del display para traer al frente
  bool _displayInstalled = false;

  static const _displayExePath = r'C:\ProgramData\MBSport\display\display_mbsport.exe';

  @override
  void initState() {
    super.initState();
    unawaited(_checkDisplayInstalled());
  }

  Future<void> _checkDisplayInstalled() async {
    final exists = await File(_displayExePath).exists();
    if (mounted) setState(() => _displayInstalled = exists);
  }

  /// Trae la ventana del display al frente si ya está abierta (PowerShell)
  Future<bool> _bringDisplayToFront() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile', '-NonInteractive', '-Command',
        r'$w = Get-Process display_mbsport -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowHandle -ne 0} | Select-Object -First 1; if ($w) { Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.Interaction]::AppActivate($w.Id); $true } else { $false }',
      ]);
      return (result.stdout as String).trim().toLowerCase() == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> _openDisplay() async {
    // Si el proceso ya existe y sigue corriendo, traerlo al frente
    if (_displayProcess != null) {
      final brought = await _bringDisplayToFront();
      if (brought) return;
      _displayProcess = null; // proceso ya terminó, abrir de nuevo
    }

    if (!await File(_displayExePath).exists()) {
      if (mounted) setState(() => _displayInstalled = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El display MBSport no está instalado en este equipo.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }
    if (mounted) setState(() => _displayInstalled = true);

    final agencyId = widget.state.agencyId;
    _displayProcess = await Process.start(
      _displayExePath,
      ['--agencyId=$agencyId'],
      mode: ProcessStartMode.detached,
    );
  }

  Future<void> _openSettingsDialog() async {
    await _checkDisplayInstalled();
    String selectedLanguage = widget.state.selectedLanguage;
    String selectedPrinter = widget.state.selectedPrinter;
    int selectedPaperWidth = widget.state.selectedPaperWidth;
    bool displayInstalled = _displayInstalled;

    const languages = ['Español', 'English'];

    // Carga las impresoras reales del sistema
    List<String> printers = ['Impresora predeterminada'];
    try {
      final systemPrinters = await Printing.listPrinters();
      for (final p in systemPrinters) {
        if (p.name.isNotEmpty) printers.add(p.name);
      }
    } catch (_) {
      // Si no se puede listar, queda solo la opción por defecto
    }

    // Asegurar que el valor guardado siga siendo válido; si no, resetear
    if (!printers.contains(selectedPrinter)) {
      selectedPrinter = printers.first;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B1B1B),
              title: const Text(
                'Configuración',
                style: TextStyle(
                  fontFamily: 'DinNextLtPro',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Idioma',
                    style: TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButton<String>(
                    value: selectedLanguage,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1B1B1B),
                    style: const TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: Colors.white,
                    ),
                    items: languages
                        .map((lang) => DropdownMenuItem(
                              value: lang,
                              child: Text(lang),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedLanguage = value);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Impresora predeterminada',
                    style: TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButton<String>(
                    value: selectedPrinter,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1B1B1B),
                    style: const TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    items: printers
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                p,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedPrinter = value);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Ancho de papel',
                    style: TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [58, 80].map((mm) {
                      final selected = selectedPaperWidth == mm;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedPaperWidth = mm),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFFD4AF37) : const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFD4AF37),
                                width: selected ? 0 : 1,
                              ),
                            ),
                            child: Text(
                              '$mm mm',
                              style: TextStyle(
                                fontFamily: 'DinNextLtPro',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: selected ? Colors.black : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),

                  // ── Display MBSport ──────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Display MBSport',
                              style: TextStyle(
                                fontFamily: 'DinNextLtPro',
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              displayInstalled ? 'Detectado ✓' : 'No encontrado',
                              style: TextStyle(
                                fontFamily: 'DinNextLtPro',
                                color: displayInstalled ? Colors.greenAccent : Colors.redAccent,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await _checkDisplayInstalled();
                          setDialogState(() => displayInstalled = _displayInstalled);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF2A2A2A),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: const BorderSide(color: Color(0xFFD4AF37)),
                          ),
                        ),
                        child: const Text(
                          'VERIFICAR',
                          style: TextStyle(
                            fontFamily: 'DinNextLtPro',
                            color: Color(0xFFD4AF37),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _confirmLogout();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    child: const Text(
                      'CERRAR SESIÓN',
                      style: TextStyle(
                        fontFamily: 'DinNextLtPro',
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'CANCELAR',
                    style: TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: Colors.white70,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    widget.state.setLanguage(selectedLanguage);
                    widget.state.setPrinter(selectedPrinter);
                    widget.state.setPaperWidth(selectedPaperWidth);
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'GUARDAR',
                    style: TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: Color(0xFFD4AF37),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B1B1B),
          title: const Text(
            'Cerrar sesión',
            style: TextStyle(
              fontFamily: 'DinNextLtPro',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            '¿Seguro que deseas cerrar la sesión actual?',
            style: TextStyle(
              fontFamily: 'DinNextLtPro',
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'CANCELAR',
                style: TextStyle(
                  fontFamily: 'DinNextLtPro',
                  color: Colors.white70,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onLogout();
              },
              child: const Text(
                'CERRAR SESIÓN',
                style: TextStyle(
                  fontFamily: 'DinNextLtPro',
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Agency / User / Server status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'AGENCIA ${widget.state.agencyName}',
                style: const TextStyle(
                  fontFamily: 'DinNextLtPro',
                  color: Color(0xFFD4AF37),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.state.currentUser,
                style: const TextStyle(
                  fontFamily: 'DinNextLtPro',
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.state.isServerOnline
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.state.isServerOnline ? 'En línea' : 'Sin conexión',
                    style: TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: widget.state.isServerOnline
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Botón Display
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isDisplayHovered = true),
            onExit: (_) => setState(() => _isDisplayHovered = false),
            child: GestureDetector(
              onTap: _openDisplay,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isDisplayHovered
                      ? const Color(0xFFD4AF37)
                      : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFD4AF37),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tv,
                      size: 16,
                      color: _isDisplayHovered ? Colors.black : const Color(0xFFD4AF37),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'DISPLAY',
                      style: TextStyle(
                        fontFamily: 'DinNextLtPro',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: _isDisplayHovered ? Colors.black : const Color(0xFFD4AF37),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _displayInstalled ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Settings Gear Button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isCogHovered = true),
            onExit: (_) => setState(() => _isCogHovered = false),
            child: GestureDetector(
              onTap: _openSettingsDialog,
              child: Image.asset(
                _isCogHovered
                    ? 'assets/resources/configuracion_icon_amarilla.png'
                    : 'assets/resources/configuracion_icon.png',
                width: 40,
                height: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

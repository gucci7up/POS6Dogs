import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pos/services/api_client.dart';
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

  /// Usa PowerShell + System.Windows.Forms.Screen para obtener
  /// las coordenadas exactas de cada monitor según Windows.
  Future<({int x, int y, int w, int h})?> _detectSecondaryMonitor() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'Add-Type -AssemblyName System.Windows.Forms; '
            r'[System.Windows.Forms.Screen]::AllScreens | '
            r'ForEach-Object { "$($_.Primary)|$($_.Bounds.X)|$($_.Bounds.Y)|$($_.Bounds.Width)|$($_.Bounds.Height)" }',
      ]);
      if (result.exitCode != 0) return null;
      for (final raw in (result.stdout as String).split('\n')) {
        final line = raw.trim();
        if (line.isEmpty) continue;
        final parts = line.split('|');
        if (parts.length < 5) continue;
        final isPrimary = parts[0].trim().toLowerCase() == 'true';
        if (isPrimary) continue; // saltamos el monitor principal
        final x = int.tryParse(parts[1].trim());
        final y = int.tryParse(parts[2].trim());
        final w = int.tryParse(parts[3].trim());
        final h = int.tryParse(parts[4].trim());
        if (x != null && y != null && w != null && h != null) {
          return (x: x, y: y, w: w, h: h);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Busca Chrome o Edge en el sistema
  Future<String?> _findBrowser() async {
    final candidates = [
      r'C:\Program Files\Google\Chrome\Application\chrome.exe',
      r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
      r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
      r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
    ];
    for (final path in candidates) {
      if (await File(path).exists()) return path;
    }
    return null;
  }

  /// Trae la ventana del display al frente si ya está abierta (PowerShell)
  Future<bool> _bringDisplayToFront() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile', '-NonInteractive', '-Command',
        r'$w = Get-Process chrome,msedge -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowHandle -ne 0} | Select-Object -First 1; if ($w) { Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.Interaction]::AppActivate($w.Id); $true } else { $false }',
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

    final agencyId = widget.state.agencyId;
    final monitorConfig = widget.state.displayMonitor;
    final isLocal = widget.state.displayLocal;

    // URL según modo local o remoto
    final displayUrl = isLocal
        ? 'file:///C:/ProgramData/MBSport/display/index.html?agencyId=$agencyId'
        : 'https://display.mbsport.lat/?agencyId=$agencyId';

    // Calcular posición del monitor secundario
    String? positionArg;
    String? sizeArg;

    if (monitorConfig == 'auto') {
      final secondary = await _detectSecondaryMonitor();
      if (secondary != null) {
        positionArg = '--window-position=${secondary.x},${secondary.y}';
        sizeArg = '--window-size=${secondary.w},${secondary.h}';
      }
    } else if (monitorConfig == 'right') {
      positionArg = '--window-position=1920,0';
    } else if (monitorConfig == 'left') {
      positionArg = '--window-position=-1920,0';
    } else if (monitorConfig == 'top') {
      positionArg = '--window-position=0,-1080';
    } else if (monitorConfig == 'bottom') {
      positionArg = '--window-position=0,1080';
    }

    // Desactivar taskbar en monitores secundarios
    try {
      await Process.run('powershell', [
        '-NoProfile', '-NonInteractive', '-Command',
        r'''
$p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $p -Name MMTaskbarEnabled -Value 0 -Force
Add-Type -TypeDefinition @"
using System;using System.Runtime.InteropServices;
public class Shell32{
  [DllImport("user32.dll")]
  public static extern IntPtr SendMessageTimeout(IntPtr h,uint m,UIntPtr w,string l,uint f,uint t,out UIntPtr r);
  public static void Notify(){UIntPtr r;SendMessageTimeout(new IntPtr(0xffff),0x001A,UIntPtr.Zero,"TraySettings",2,1000,out r);}
}
"@
[Shell32]::Notify()
        ''',
      ]);
    } catch (_) {}

    final browserPath = await _findBrowser();
    if (browserPath != null) {
      final tempDir = Platform.environment['TEMP'] ?? 'C:\\Temp';
      final userDataDir = '$tempDir\\MBSportDisplayProfile';

      final args = [
        '--kiosk',
        displayUrl,
        '--start-fullscreen',
        '--user-data-dir=$userDataDir',
        '--no-first-run',
        '--disable-infobars',
        '--disable-extensions',
        '--allow-running-insecure-content',
        if (positionArg != null) positionArg,
        if (sizeArg != null) sizeArg,
      ];
      _displayProcess = await Process.start(
        browserPath, args,
        mode: ProcessStartMode.detached,
      );
    } else {
      final uri = Uri.parse(displayUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  static const _localVideosPath = r'C:\ProgramData\MBSport\videos';

  Future<int?> _countLocalVideos() async {
    try {
      final dir = Directory(_localVideosPath);
      if (!await dir.exists()) return null;
      final files = await dir
          .list()
          .where((e) => e is File && e.path.toLowerCase().endsWith('.mp4'))
          .length;
      return files;
    } catch (_) {
      return null;
    }
  }

  Future<({int synced, int missing})?> _compareWithServer() async {
    try {
      final api = ApiClient();
      api.setToken(widget.state.authToken);
      final serverVideos = await api.getVideos();
      final dir = Directory(_localVideosPath);
      if (!await dir.exists()) return null;

      final localNames = <String>{};
      await for (final e in dir.list()) {
        if (e is File && e.path.toLowerCase().endsWith('.mp4')) {
          localNames.add(e.uri.pathSegments.last.replaceAll('.mp4', '').toLowerCase());
        }
      }

      int synced = 0, missing = 0;
      for (final v in serverVideos) {
        final nombre = (v['nombre'] as String? ?? '').toLowerCase();
        if (localNames.contains(nombre)) {
          synced++;
        } else {
          missing++;
        }
      }
      return (synced: synced, missing: missing);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openSettingsDialog() async {
    String selectedLanguage = widget.state.selectedLanguage;
    String selectedPrinter = widget.state.selectedPrinter;
    int selectedPaperWidth = widget.state.selectedPaperWidth;
    String selectedMonitor = widget.state.displayMonitor;
    bool selectedDisplayLocal = widget.state.displayLocal;
    int? localVideoCount;
    String? localScanMsg;
    String? compareMsg;

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
                  const Text(
                    'Monitor del Display',
                    style: TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButton<String>(
                    value: selectedMonitor,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1B1B1B),
                    style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'auto',    child: Text('Automático (detectar monitor 2)')),
                      DropdownMenuItem(value: 'right',   child: Text('Monitor a la DERECHA (x=1920)')),
                      DropdownMenuItem(value: 'left',    child: Text('Monitor a la IZQUIERDA (x=-1920)')),
                      DropdownMenuItem(value: 'top',     child: Text('Monitor ARRIBA (y=-1080)')),
                      DropdownMenuItem(value: 'bottom',  child: Text('Monitor ABAJO (y=1080)')),
                      DropdownMenuItem(value: 'primary', child: Text('Monitor principal (mismo que POS)')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => selectedMonitor = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),

                  // ── Modo Local ──────────────────────────────────────────
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Modo Local',
                              style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white70, fontSize: 14)),
                            Text('Display desde archivo local en este PC',
                              style: TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                      Switch(
                        value: selectedDisplayLocal,
                        activeColor: const Color(0xFFD4AF37),
                        onChanged: (val) async {
                          setDialogState(() {
                            selectedDisplayLocal = val;
                            localScanMsg = null;
                            compareMsg = null;
                          });
                          if (val) {
                            final count = await _countLocalVideos();
                            setDialogState(() {
                              if (count == null) {
                                localScanMsg = 'Ruta no encontrada: $_localVideosPath';
                              } else {
                                localScanMsg = '$count videos .mp4 encontrados';
                                localVideoCount = count;
                              }
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (localScanMsg != null) ...[
                    const SizedBox(height: 4),
                    Text(localScanMsg!,
                      style: TextStyle(
                        fontFamily: 'DinNextLtPro',
                        color: localVideoCount != null ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 12,
                      )),
                  ],
                  if (compareMsg != null) ...[
                    const SizedBox(height: 4),
                    Text(compareMsg!,
                      style: const TextStyle(fontFamily: 'DinNextLtPro', color: Colors.white70, fontSize: 12)),
                  ],
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  // Sincronizar videos locales (servidor local antiguo)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Videos locales',
                              style: TextStyle(
                                fontFamily: 'DinNextLtPro',
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              widget.state.localServerRunning
                                  ? 'Servidor activo en puerto 8765'
                                  : 'Servidor inactivo',
                              style: TextStyle(
                                fontFamily: 'DinNextLtPro',
                                color: widget.state.localServerRunning
                                    ? Colors.greenAccent
                                    : Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: widget.state.isSyncing
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                _startSync();
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
                          'SINCRONIZAR',
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
                  onPressed: () async {
                    widget.state.setLanguage(selectedLanguage);
                    widget.state.setPrinter(selectedPrinter);
                    widget.state.setPaperWidth(selectedPaperWidth);
                    widget.state.setDisplayMonitor(selectedMonitor);
                    await widget.state.setDisplayLocal(selectedDisplayLocal);
                    // Si modo local activo → comparar con servidor
                    if (selectedDisplayLocal) {
                      setDialogState(() => compareMsg = 'Comparando con servidor...');
                      final result = await _compareWithServer();
                      if (result != null) {
                        setDialogState(() => compareMsg =
                          '${result.synced} videos sincronizados · ${result.missing} faltantes en local');
                      } else {
                        setDialogState(() => compareMsg = 'No se pudo comparar con el servidor');
                      }
                    } else {
                      Navigator.of(context).pop();
                    }
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

  void _startSync() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          final done = widget.state.syncDone;
          final total = widget.state.syncTotal;
          final current = widget.state.syncCurrent;
          final syncing = widget.state.isSyncing;
          final progress = total > 0 ? done / total : 0.0;

          return AlertDialog(
            backgroundColor: const Color(0xFF1B1B1B),
            title: Text(
              syncing ? 'Sincronizando videos...' : 'Sincronización completa',
              style: const TextStyle(
                fontFamily: 'DinNextLtPro',
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: syncing && total == 0 ? null : progress,
                  backgroundColor: const Color(0xFF2A2A2A),
                  color: const Color(0xFFD4AF37),
                ),
                const SizedBox(height: 12),
                Text(
                  total > 0 ? '$done / $total videos' : 'Obteniendo lista...',
                  style: const TextStyle(
                    fontFamily: 'DinNextLtPro',
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                if (current.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    current,
                    style: const TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
            actions: syncing
                ? null
                : [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'CERRAR',
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
      ),
    );

    // Iniciar la sincronización
    widget.state.syncVideos().catchError((e) {
      if (mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    });
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

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> _openDisplay() async {
    final agencyId = widget.state.agencyId;
    final uri = Uri.parse('https://display.mbsport.lat/?agencyId=$agencyId');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openSettingsDialog() {
    String selectedLanguage = widget.state.selectedLanguage;
    String selectedPrinter = widget.state.selectedPrinter;

    const languages = ['Español', 'English'];
    const printers = [
      'Impresora predeterminada',
      'EPSON TM-T20',
      'EPSON TM-T88',
      'Generic / Text Only',
    ];

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
                    'Impresora',
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
                    ),
                    items: printers
                        .map((printer) => DropdownMenuItem(
                              value: printer,
                              child: Text(printer),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedPrinter = value);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
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

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

// Botones de minimizar/maximizar/cerrar para la ventana sin bordes (solo desktop)
class WindowControls extends StatefulWidget {
  const WindowControls({super.key});

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> with WindowListener {
  bool _isMaximized = true;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      windowManager.isMaximized().then((maximized) {
        if (mounted) setState(() => _isMaximized = maximized);
      });
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ControlButton(
          icon: Icons.remove,
          onTap: () => windowManager.minimize(),
        ),
        _ControlButton(
          icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
          onTap: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
        ),
        _ControlButton(
          icon: Icons.close,
          hoverColor: const Color(0xFFE81123),
          onTap: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _ControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? hoverColor;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.hoverColor,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 36,
          alignment: Alignment.center,
          color: _isHovered
              ? (widget.hoverColor ?? Colors.white24)
              : Colors.transparent,
          child: Icon(widget.icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}

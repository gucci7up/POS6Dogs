import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pos/widgets/window_controls.dart';

class DesktopScrollBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // Hides default scrollbars completely
  }
}

bool get _isDesktopWindow =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

class DesktopLayout extends StatelessWidget {
  final Widget child;

  const DesktopLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          if (_isDesktopWindow) const _TitleBar(),
          Expanded(
            child: ScrollConfiguration(
              behavior: DesktopScrollBehavior(),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: 1920,
                    height: 1080,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Barra de título propia para la ventana sin bordes, compartida por todas las pantallas
class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: const Color(0xFF0A1626),
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(child: Container(height: 36)),
          ),
          const WindowControls(),
        ],
      ),
    );
  }
}

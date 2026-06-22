import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pos/layouts/main_layout.dart';
import 'package:pos/screens/login_screen.dart';
import 'package:pos/screens/jugada_screen.dart';
import 'package:pos/screens/resultados_screen.dart';
import 'package:pos/screens/cuotas_screen.dart';
import 'package:pos/screens/ventas_screen.dart';
import 'package:pos/screens/premios_screen.dart';
import 'package:pos/services/api_client.dart';
import 'package:pos/state/pos_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1920, 1080),
      minimumSize: Size(1024, 768),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle:
          TitleBarStyle.hidden, // sin bordes; barra propia en DesktopLayout
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.maximize();
    });
  }

  runApp(const RacingDogsApp());
}

class RacingDogsApp extends StatelessWidget {
  const RacingDogsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Racing Dogs POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'DinNextLtPro',
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4AF37), // Gold
          secondary: Color(0xFF1E3A1E), // Dark green
          surface: Colors.black,
        ),
      ),
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  final ApiClient _apiClient = ApiClient();
  AuthResult? _auth;
  bool _sessionLocked = false;
  Timer? _inactivityTimer;

  static const _inactivityTimeout = Duration(minutes: 5);

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (_auth != null && !_sessionLocked) {
      _inactivityTimer = Timer(_inactivityTimeout, _lockSession);
    }
  }

  void _lockSession() {
    if (!mounted) return;
    _inactivityTimer?.cancel();
    setState(() => _sessionLocked = true);
  }

  Future<String?> _handleLogin(String username, String password) async {
    try {
      final auth = await _apiClient.login(username, password);
      setState(() {
        _auth = auth;
        _sessionLocked = false;
      });
      _resetInactivityTimer();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'No se pudo conectar con el servidor';
    }
  }

  void _handleLogout() {
    _inactivityTimer?.cancel();
    _apiClient.setToken(null);
    setState(() {
      _auth = null;
      _sessionLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = _auth;

    // Sin sesión activa: pantalla de login pura
    if (auth == null) {
      return LoginScreen(onLogin: _handleLogin);
    }

    // Sesión activa: MainScreen siempre en el árbol (datos preservados).
    // Cuando se bloquea, se superpone el LoginScreen como overlay.
    return Listener(
      onPointerDown: (_) => _resetInactivityTimer(),
      onPointerMove: (_) => _resetInactivityTimer(),
      child: Stack(
        children: [
          MainScreen(
            key: ValueKey(auth.userId),
            apiClient: _apiClient,
            auth: auth,
            onLogout: _handleLogout,
          ),
          if (_sessionLocked)
            LoginScreen(
              onLogin: _handleLogin,
              isLocked: true,
            ),
        ],
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final ApiClient apiClient;
  final AuthResult auth;
  final VoidCallback onLogout;

  const MainScreen({
    super.key,
    required this.apiClient,
    required this.auth,
    required this.onLogout,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentTabIndex = 0;
  late final PosState _state;

  @override
  void initState() {
    super.initState();
    _state = PosState(api: widget.apiClient, auth: widget.auth);
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, child) {
        // Resolve active tab screen widget
        Widget activeScreen;
        switch (_currentTabIndex) {
          case 0:
            activeScreen = JugadaScreen(state: _state);
            break;
          case 1:
            activeScreen = ResultadosScreen(state: _state);
            break;
          case 2:
            activeScreen = CuotasScreen(state: _state);
            break;
          case 3:
            activeScreen = VentasScreen(state: _state);
            break;
          case 4:
            activeScreen = PremiosScreen(state: _state);
            break;
          default:
            activeScreen = JugadaScreen(state: _state);
        }

        return MainLayout(
          currentTabIndex: _currentTabIndex,
          onTabChanged: (index) {
            setState(() {
              _currentTabIndex = index;
            });
          },
          state: _state,
          onLogout: widget.onLogout,
          child: activeScreen,
        );
      },
    );
  }
}

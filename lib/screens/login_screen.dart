import 'package:flutter/material.dart';
import 'package:pos/layouts/desktop_layout.dart';

class LoginScreen extends StatefulWidget {
  final Future<String?> Function(String username, String password) onLogin;
  final Future<String?> Function(String pin)? onUnlock;
  final String lockedUsername;
  final bool isLocked;

  const LoginScreen({
    super.key,
    required this.onLogin,
    this.onUnlock,
    this.lockedUsername = '',
    this.isLocked = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _ActiveField { account, password }

const int _accountDigits = 12;

class _LoginScreenState extends State<LoginScreen> {
  String _account = '';
  String _password = '';
  _ActiveField _active = _ActiveField.account;
  bool _isLoading = false;
  String? _error;

  void _typeDigit(String digit) {
    setState(() {
      if (_active == _ActiveField.account) {
        if (_account.length < _accountDigits) {
          _account += digit;
        }
      } else {
        _password += digit;
      }
    });
  }

  String get _formattedAccount {
    final buffer = StringBuffer();
    for (int i = 0; i < _account.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write('-');
      buffer.write(_account[i]);
    }
    return buffer.toString();
  }

  @override
  void initState() {
    super.initState();
    // Si está bloqueado, ir directo al campo PIN
    if (widget.isLocked) {
      _active = _ActiveField.password;
    }
  }

  Future<void> _handleAccess() async {
    // Modo desbloqueo: solo valida el PIN con el usuario guardado
    if (widget.isLocked && widget.onUnlock != null) {
      if (_password.isEmpty) {
        setState(() => _error = 'Ingresa tu PIN.');
        return;
      }
      setState(() { _isLoading = true; _error = null; });
      final result = await widget.onUnlock!(_password);
      if (!mounted) return;
      setState(() { _isLoading = false; _error = result; });
      return;
    }

    // Modo login normal
    if (_account.length != _accountDigits || _password.isEmpty) {
      setState(() {
        _error = 'Complete el número de acceso (12 dígitos) y el PIN.';
      });
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    final result = await widget.onLogin(_formattedAccount, _password);
    if (!mounted) return;
    setState(() { _isLoading = false; _error = result; });
  }

  void _backspace() {
    setState(() {
      if (_active == _ActiveField.account) {
        if (_account.isNotEmpty) {
          _account = _account.substring(0, _account.length - 1);
        }
      } else {
        if (_password.isNotEmpty) {
          _password = _password.substring(0, _password.length - 1);
        }
      }
    });
  }

  void _clearAccount() {
    setState(() {
      _account = '';
      _active = _ActiveField.account;
    });
  }

  void _clearPassword() {
    setState(() {
      _password = '';
      _active = _ActiveField.password;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      child: Stack(
        children: [
          // Fondo de marca
          Positioned.fill(
            child: Image.asset(
              'assets/resources/background_login.png',
              fit: BoxFit.cover,
            ),
          ),
          // Franja inferior con imágenes de carreras
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/resources/games_img.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 2,
                      color: const Color(0xFFD4AF37).withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Banner de sesión bloqueada
          if (widget.isLocked)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                color: const Color(0xFFB8860B).withOpacity(0.92),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_clock, color: Colors.white, size: 22),
                    SizedBox(width: 12),
                    Text(
                      'SESIÓN BLOQUEADA POR INACTIVIDAD — Vuelva a ingresar su PIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Contenido principal
          Padding(
            padding: const EdgeInsets.fromLTRB(90, 30, 90, 240),
            child: Column(
              children: [
                Image.asset('assets/resources/logo_principal.png', height: 240),
                const SizedBox(height: 30),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Modo bloqueo: mostrar usuario guardado, no el campo de cuenta
                            if (widget.isLocked) ...[
                              const _FieldLabel('USUARIO'),
                              const SizedBox(height: 12),
                              Container(
                                height: 56,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B2E20),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5)),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    widget.lockedUsername,
                                    style: const TextStyle(
                                      fontFamily: 'DinNextLtPro',
                                      color: Color(0xFFD4AF37),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              const _FieldLabel('NÚMERO DE ACCESO'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _LoginField(
                                      text: _formattedAccount,
                                      isPassword: false,
                                      isActive: _active == _ActiveField.account,
                                      onTap: () => setState(
                                        () => _active = _ActiveField.account,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  _ClearButton(onTap: _clearAccount),
                                ],
                              ),
                            ],
                            const SizedBox(height: 36),
                            const _FieldLabel('PIN DE ACCESO'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _LoginField(
                                    text: _password,
                                    isPassword: true,
                                    isActive: _active == _ActiveField.password,
                                    onTap: () => setState(
                                      () => _active = _ActiveField.password,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                _ClearButton(onTap: _clearPassword),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_error != null)
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFE57373),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const SizedBox(height: 16),
                            _AccesoButton(
                              onTap: _isLoading ? null : _handleAccess,
                              isLoading: _isLoading,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 70),
                      Expanded(
                        flex: 2,
                        child: _NumPad(
                          onDigit: _typeDigit,
                          onBackspace: _backspace,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFD4AF37),
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 4,
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  final String text;
  final bool isPassword;
  final bool isActive;
  final VoidCallback onTap;

  const _LoginField({
    required this.text,
    required this.isPassword,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final display = isPassword ? '•' * text.length : text;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 78,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: const Color(0xFF0F2138).withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? const Color(0xFFD4AF37)
                : const Color(0xFFD4AF37).withOpacity(0.45),
            width: isActive ? 2.5 : 1.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.35),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Text(
          display,
          style: TextStyle(
            fontSize: 32,
            letterSpacing: isPassword ? 8 : 2,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ClearButton extends StatefulWidget {
  final VoidCallback onTap;

  const _ClearButton({required this.onTap});

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 78,
          height: 78,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _isHovered
                  ? [const Color(0xFFA8362C), const Color(0xFF7A1F1F)]
                  : [const Color(0xFF8E2A22), const Color(0xFF601717)],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: const Text(
            'X',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccesoButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const _AccesoButton({required this.onTap, this.isLoading = false});

  @override
  State<_AccesoButton> createState() => _AccesoButtonState();
}

class _AccesoButtonState extends State<_AccesoButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          children: [
            // Cuadro dorado con icono de candado
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 78,
              height: 78,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _isHovered
                      ? [const Color(0xFFE6C75B), const Color(0xFFB8902C)]
                      : [const Color(0xFFD4AF37), const Color(0xFFA67C1F)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock, color: Color(0xFF12241A), size: 34),
            ),
            const SizedBox(width: 12),
            // Botón ACCESO
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: 78,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF0F2138,
                  ).withOpacity(_isHovered ? 0.85 : 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                ),
                child: widget.isLoading
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xFFD4AF37),
                        ),
                      )
                    : const Text(
                        'ACCESO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _NumPad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    const spacing = 18.0;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _NumKey(label: '1', onTap: () => onDigit('1')),
              ),
              const SizedBox(width: spacing),
              Expanded(
                child: _NumKey(label: '2', onTap: () => onDigit('2')),
              ),
              const SizedBox(width: spacing),
              Expanded(
                child: _NumKey(label: '3', onTap: () => onDigit('3')),
              ),
            ],
          ),
        ),
        const SizedBox(height: spacing),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _NumKey(label: '4', onTap: () => onDigit('4')),
              ),
              const SizedBox(width: spacing),
              Expanded(
                child: _NumKey(label: '5', onTap: () => onDigit('5')),
              ),
              const SizedBox(width: spacing),
              Expanded(
                child: _NumKey(label: '6', onTap: () => onDigit('6')),
              ),
            ],
          ),
        ),
        const SizedBox(height: spacing),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _NumKey(label: '7', onTap: () => onDigit('7')),
              ),
              const SizedBox(width: spacing),
              Expanded(
                child: _NumKey(label: '8', onTap: () => onDigit('8')),
              ),
              const SizedBox(width: spacing),
              Expanded(
                child: _NumKey(label: '9', onTap: () => onDigit('9')),
              ),
            ],
          ),
        ),
        const SizedBox(height: spacing),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _NumKey(
                  icon: Icons.arrow_back,
                  highlighted: true,
                  onTap: onBackspace,
                ),
              ),
              const SizedBox(width: spacing),
              Expanded(
                flex: 1,
                child: _NumKey(label: '0', onTap: () => onDigit('0')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NumKey extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final bool highlighted;
  final VoidCallback onTap;

  const _NumKey({
    this.label,
    this.icon,
    this.highlighted = false,
    required this.onTap,
  });

  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final BoxDecoration decoration;
    final Color contentColor;

    if (widget.highlighted) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _isHovered
              ? [const Color(0xFFE6C75B), const Color(0xFFB8902C)]
              : [const Color(0xFFD4AF37), const Color(0xFFA67C1F)],
        ),
        borderRadius: BorderRadius.circular(10),
      );
      contentColor = const Color(0xFF12241A);
    } else {
      decoration = BoxDecoration(
        color: Colors.white.withOpacity(_isHovered ? 0.12 : 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(_isHovered ? 0.7 : 0.35),
          width: 1.5,
        ),
      );
      contentColor = Colors.white;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: decoration,
          alignment: Alignment.center,
          child: widget.icon != null
              ? Icon(widget.icon, color: contentColor, size: 32)
              : Text(
                  widget.label!,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: contentColor,
                  ),
                ),
        ),
      ),
    );
  }
}

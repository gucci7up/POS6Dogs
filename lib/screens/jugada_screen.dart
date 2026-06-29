import 'package:flutter/material.dart';
import 'package:pos/widgets/dog_odds_card.dart';
import 'package:pos/widgets/action_button.dart';
import 'package:pos/widgets/amount_button.dart';
import 'package:pos/state/pos_state.dart';
import 'package:pos/services/print_service.dart';

class JugadaScreen extends StatefulWidget {
  final PosState state;

  const JugadaScreen({super.key, required this.state});

  @override
  State<JugadaScreen> createState() => _JugadaScreenState();
}

const Map<int, Map<String, String>> _dogInfo = {
  1: {'name': 'BRAVO', 'color': 'ROJO'},
  2: {'name': 'RELAMPAGO', 'color': 'AZUL'},
  3: {'name': 'TIGRE', 'color': 'BLANCO'},
  4: {'name': 'NEGRO', 'color': 'NEGRO'},
  5: {'name': 'FURIA', 'color': 'NARANJA'},
  6: {'name': 'BANDIDO', 'color': 'BLANCO/NEGRO'},
};

class _JugadaScreenState extends State<JugadaScreen> {
  bool _isDeleteHovered = false;
  bool _isDeletePressed = false;
  bool _isPrintHovered = false;
  bool _isPrintPressed = false;
  bool _isTicketOpen = false;
  int _lastTicketLength = 0;
  int? _pressedPlayIndex;
  String _repeatInput = '';

  @override
  void initState() {
    super.initState();
    _lastTicketLength = widget.state.currentTicketPlays.length;
    widget.state.addListener(_onStateChanged);
  }

  Widget _buildTicketPlayBadge(Bet play) {
    if (play.dog2 == null) {
      return Image.asset(
        'assets/resources/botonnumero${play.dog1}.png',
        height: 36,
        fit: BoxFit.contain,
      );
    }
    final height = play.dog3 != null ? 18.0 : 28.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/resources/botonnumero${play.dog1}.png',
          height: height,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 4),
        Image.asset(
          'assets/resources/botonnumero${play.dog2}.png',
          height: height,
          fit: BoxFit.contain,
        ),
        if (play.dog3 != null) ...[
          const SizedBox(height: 4),
          Image.asset(
            'assets/resources/botonnumero${play.dog3}.png',
            height: height,
            fit: BoxFit.contain,
          ),
        ],
      ],
    );
  }

  // Abre teclado numérico táctil y busca el ticket
  Future<void> _openRepeatNumpad(PosState state) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _RepeatTicketDialog(initial: _repeatInput),
    );
    if (result == null) return;
    setState(() => _repeatInput = result);
    if (result.isEmpty) return;
    final ticket = await state.findTicketByNumber(result);
    if (!mounted) return;
    if (ticket != null) {
      state.repeatTicket(ticket);
      setState(() => _repeatInput = '');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket no encontrado'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Imprime el ticket directo — sin modal intermedio
  Future<void> _handlePrintTicket(PosState state) async {
    if (!state.isSalesOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ventas cerradas para esta carrera'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final result = await state.printTicket();
    if (!mounted) return;
    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error!), duration: const Duration(seconds: 3)),
      );
      return;
    }
    final ticketNumber = result.ticketNumber ?? 0;
    final ticket = state.salesHistory
        .where((t) => t.ticketNumber == ticketNumber)
        .firstOrNull;
    if (ticket != null) {
      PrintService.printTicketReceipt(
        ticket: ticket,
        agencyName: state.agencyName,
        cashier: state.currentUser,
        ticketId: result.ticketId,
        printerName: state.selectedPrinter,
        paperWidthMm: state.selectedPaperWidth,
      );
    }
  }

  // Cuadrito para escribir un N° de ticket y recargar esa jugada
  Widget _buildRepeatTicketBox(PosState state) {
    final hasNumber = _repeatInput.isNotEmpty;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openRepeatNumpad(state),
        child: Container(
          width: 145,
          height: 145,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD4AF37), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'REPETIR\nTICKET',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'DinNextLtPro',
                  color: Color(0xFFD4AF37),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasNumber ? _repeatInput : 'N° / ID',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'DinNextLtPro',
                    color: hasNumber ? Colors.white : Colors.white38,
                    fontSize: hasNumber ? 16 : 12,
                    fontWeight: hasNumber ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Icon(Icons.dialpad, color: Color(0xFFD4AF37), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    final newLength = widget.state.currentTicketPlays.length;
    if (newLength != _lastTicketLength) {
      setState(() { _lastTicketLength = newLength; });
    }
    // Mostrar error si las cuotas no se pudieron cargar
    final err = widget.state.oddsLoadError;
    if (err != null) {
      widget.state.clearOddsLoadError();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFFE53935),
        duration: const Duration(seconds: 4),
        content: Text(err, style: const TextStyle(fontFamily: 'DinNextLtPro', fontWeight: FontWeight.bold, fontSize: 15)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return Stack(
      children: [
        // Main Board Content
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Selection Area (Dog rows + Right action buttons)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48.0),
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Dog Rows
                  Expanded(
                    child: Column(
                      children: [
                        // 1° Lugar Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 100,
                              child: Text(
                                '1°',
                                style: TextStyle(
                                  fontFamily: 'DinNextLtPro',
                                  color: Colors.white,
                                  fontSize: 76,
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(6, (index) {
                                  final dogNum = index + 1;
                                  final info = _dogInfo[dogNum]!;
                                  final isSelected = state.selectedDog1 == dogNum;
                                  final isDimmed = state.selectedDog1 != null;
                                  return DogOddsCard(
                                    number: dogNum,
                                    name: info['name']!,
                                    color: info['color']!,
                                    ganarOdds: state.getGanarOdds(dogNum),
                                    exactaOdds: state.getExactaOdds(dogNum),
                                    trifectaOdds: state.getTrifectaOdds(dogNum),
                                    width: 210,
                                    isSelected: isSelected,
                                    isDimmed: isDimmed,
                                    onTap: state.isSalesOpen
                                        ? () => state.selectDog1(dogNum)
                                        : null,
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 2° Lugar Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 100,
                              child: Text(
                                '2°',
                                style: TextStyle(
                                  fontFamily: 'DinNextLtPro',
                                  color: Colors.white,
                                  fontSize: 76,
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(6, (index) {
                                  final dogNum = index + 1;
                                  final info = _dogInfo[dogNum]!;
                                  final isSelected = state.selectedDog2 == dogNum;
                                  final isDimmed = state.selectedDog2 != null;
                                  return DogOddsCard(
                                    number: dogNum,
                                    name: info['name']!,
                                    color: info['color']!,
                                    ganarOdds: state.getGanarOdds(dogNum),
                                    exactaOdds: state.getExactaOdds(dogNum),
                                    trifectaOdds: state.getTrifectaOdds(dogNum),
                                    width: 210,
                                    isSelected: isSelected,
                                    isDimmed: isDimmed,
                                    onTap: state.isSalesOpen
                                        ? () => state.selectDog2(dogNum)
                                        : null,
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 3° Lugar Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 100,
                              child: Text(
                                '3°',
                                style: TextStyle(
                                  fontFamily: 'DinNextLtPro',
                                  color: Colors.white,
                                  fontSize: 76,
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(6, (index) {
                                  final dogNum = index + 1;
                                  final info = _dogInfo[dogNum]!;
                                  final isSelected = state.selectedDog3 == dogNum;
                                  final isDimmed = state.selectedDog3 != null;
                                  return DogOddsCard(
                                    number: dogNum,
                                    name: info['name']!,
                                    color: info['color']!,
                                    ganarOdds: state.getGanarOdds(dogNum),
                                    exactaOdds: state.getExactaOdds(dogNum),
                                    trifectaOdds: state.getTrifectaOdds(dogNum),
                                    width: 210,
                                    isSelected: isSelected,
                                    isDimmed: isDimmed,
                                    onTap: state.isSalesOpen
                                        ? () => state.selectDog3(dogNum)
                                        : null,
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Action Buttons Panel (2x2 grid)
                  Column(
                    children: [
                      Row(
                        children: [
                          ActionButton(
                            onTap: state.isSalesOpen ? state.playReverse : null,
                            semanticLabel: 'Jugada reversa: agrega también la combinación 2°/1°',
                            child: Image.asset('assets/resources/felchaarribaabajo.png'),
                          ),
                          const SizedBox(width: 20),
                          ActionButton(
                            onTap: state.isSalesOpen ? state.playAllCombinations : null,
                            semanticLabel: 'Combina el perro de 1° lugar con todos los demás en 2°',
                            child: Image.asset('assets/resources/flechadelado.png'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          ActionButton(
                            onTap: state.isSalesOpen ? state.playR : null,
                            semanticLabel: 'Jugada R: combina con todos los perros en ambos sentidos, total \$350',
                            child: Image.asset('assets/resources/imagen_r.png'),
                          ),
                          const SizedBox(width: 20),
                          ActionButton(
                            onTap: state.isSalesOpen ? state.playR2 : null,
                            semanticLabel: 'Jugada R/2: igual que R pero a mitad de precio, total \$175',
                            child: Image.asset('assets/resources/imagen_r2.png'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                ),
              ),

              const Spacer(flex: 2),

              // Bottom Bar Area
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Left: Apuesta Ticket Box (State 1 - CLOSED)
                  if (!_isTicketOpen)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isTicketOpen = true;
                          });
                        },
                        child: Transform(
                          transform: Matrix4.skewX(-0.18),
                          child: SizedBox(
                            width: 350,
                            height: 230,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Yellow header bar
                                Container(
                                  width: double.infinity,
                                  height: 48,
                                  color: const Color(0xFFD4AF37),
                                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                  alignment: Alignment.centerLeft,
                                  child: Transform(
                                    transform: Matrix4.skewX(0.18),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'APUESTA',
                                          style: TextStyle(
                                            fontFamily: 'DinNextLtPro',
                                            color: Colors.black,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (state.currentTicketTotal > 0)
                                          Text(
                                            state.currentTicketTotal.toStringAsFixed(2),
                                            style: const TextStyle(
                                              fontFamily: 'DinNextLtPro',
                                              color: Colors.black,
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Grey translucent body
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    color: Colors.white.withOpacity(0.12),
                                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
                                    child: Transform(
                                      transform: Matrix4.skewX(0.18),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Spacer(),
                                          if (state.currentTicketPlays.isNotEmpty)
                                            SizedBox(
                                              height: 64,
                                              child: SingleChildScrollView(
                                                scrollDirection: Axis.horizontal,
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    for (int i = 0; i < state.currentTicketPlays.length; i++) ...[
                                                      if (i > 0)
                                                        Container(
                                                          width: 1,
                                                          height: 56,
                                                          margin: const EdgeInsets.symmetric(horizontal: 14),
                                                          color: Colors.white24,
                                                        ),
                                                      _buildTicketPlayBadge(state.currentTicketPlays[i]),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            )
                                          else if (state.selectedDog1 != null && state.selectedDog2 != null)
                                            Text(
                                              'JUGADA: ${state.selectedDog1} - ${state.selectedDog2}'
                                              '${state.selectedDog3 != null ? " - ${state.selectedDog3}" : ""}',
                                              style: const TextStyle(
                                                fontFamily: 'DinNextLtPro',
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          else if (state.currentBetAmount > 0)
                                            Text(
                                              'MONTO: \$${state.currentBetAmount.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontFamily: 'DinNextLtPro',
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          else
                                            const Text(
                                              'SIN SELECCION',
                                              style: TextStyle(
                                                fontFamily: 'DinNextLtPro',
                                                color: Colors.white60,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          const Spacer(),
                                          const Text(
                                            'PULSE PARA ABRIR EL TICKET',
                                            style: TextStyle(
                                              fontFamily: 'DinNextLtPro',
                                              color: Colors.white70,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    // Spacer placeholder to maintain visual alignment of other elements
                    const SizedBox(width: 350, height: 230),

                  const SizedBox(width: 24),

                  // Center: Quick Amount Buttons
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        AmountButton(
                          amount: 25,
                          onTap: state.isSalesOpen ? () => state.addBetAmount(25) : () {},
                        ),
                        const SizedBox(width: 20),
                        AmountButton(
                          amount: 50,
                          onTap: state.isSalesOpen ? () => state.addBetAmount(50) : () {},
                        ),
                        const SizedBox(width: 20),
                        AmountButton(
                          amount: 100,
                          onTap: state.isSalesOpen ? () => state.addBetAmount(100) : () {},
                        ),
                        const SizedBox(width: 20),
                        AmountButton(
                          amount: 200,
                          onTap: state.isSalesOpen ? () => state.addBetAmount(200) : () {},
                        ),
                        const SizedBox(width: 20),
                        _buildRepeatTicketBox(state),
                      ],
                    ),
                  ),
                  const SizedBox(width: 30),

                  // Right: Ticket buttons (Delete, Print)
                  Row(
                    children: [
                      // Delete Button (also clears any in-progress bet amount)
                      Semantics(
                        label: 'Eliminar ticket actual',
                        button: true,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _isDeleteHovered = true),
                          onExit: (_) => setState(() => _isDeleteHovered = false),
                          child: GestureDetector(
                            onTap: () {
                              state.clearBetAmount();
                              state.deleteCurrentTicket();
                            },
                            onTapDown: (_) => setState(() => _isDeletePressed = true),
                            onTapUp: (_) => setState(() => _isDeletePressed = false),
                            onTapCancel: () => setState(() => _isDeletePressed = false),
                            child: AnimatedScale(
                              scale: _isDeletePressed ? 0.96 : 1.0,
                              duration: const Duration(milliseconds: 100),
                              curve: Curves.easeOut,
                              child: Container(
                                width: 145,
                                height: 110,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage(
                                      (_isDeleteHovered || _isDeletePressed)
                                          ? 'assets/resources/botondeleteclaro.png'
                                          : 'assets/resources/botondelete.png',
                                    ),
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Print Button
                      Semantics(
                        label: 'Imprimir ticket',
                        button: true,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _isPrintHovered = true),
                          onExit: (_) => setState(() => _isPrintHovered = false),
                          child: GestureDetector(
                            onTap: () => _handlePrintTicket(state),
                            onTapDown: (_) => setState(() => _isPrintPressed = true),
                            onTapUp: (_) => setState(() => _isPrintPressed = false),
                            onTapCancel: () => setState(() => _isPrintPressed = false),
                            child: AnimatedScale(
                              scale: _isPrintPressed ? 0.96 : 1.0,
                              duration: const Duration(milliseconds: 100),
                              curve: Curves.easeOut,
                              child: Container(
                                width: 220,
                                height: 200,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage(
                                      (_isPrintHovered || _isPrintPressed)
                                          ? 'assets/resources/botonprinterclaro.png'
                                          : 'assets/resources/botonprinter.png',
                                    ),
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Sliding Ticket Drawer (State 2 - OPEN)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          left: _isTicketOpen ? 0 : -1880, // Fully offscreen when closed
          top: 0,
          bottom: 0,
          width: 1880,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1B1B1B), // Opaque backing so the drawer fully hides the content behind it
              image: DecorationImage(
                image: AssetImage('assets/resources/big_forma_ventas.png'),
                fit: BoxFit.fill,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Grey Bar Row
                Container(
                  height: 52,
                  color: const Color(0xFF7E7E7E), // Grey background header
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const SizedBox(width: 220), // Left spacer align
                      const SizedBox(
                        width: 60,
                        child: Text(
                          'Nu.',
                          style: TextStyle(
                            fontFamily: 'DinNextLtPro',
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 100,
                        child: Text(
                          'Cuotas',
                          style: TextStyle(
                            fontFamily: 'DinNextLtPro',
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 100,
                        child: Text(
                          'Monto',
                          style: TextStyle(
                            fontFamily: 'DinNextLtPro',
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Text(
                        'TICKET',
                        style: TextStyle(
                          fontFamily: 'DinNextLtPro',
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      
                      // Yellow Total Box (skewed)
                      Transform(
                        transform: Matrix4.skewX(-0.18),
                        child: Container(
                          width: 150,
                          height: 52,
                          color: const Color(0xFFD4AF37), // Solid Yellow
                          alignment: Alignment.center,
                          child: Transform(
                            transform: Matrix4.skewX(0.18), // Un-skew text
                            child: Text(
                              state.currentTicketTotal.toStringAsFixed(2),
                              style: const TextStyle(
                                fontFamily: 'DinNextLtPro',
                                color: Colors.black,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 80), // Keep spacing from slanted edge
                    ],
                  ),
                ),

                // Scrollable plays list
                Expanded(
                  child: state.currentTicketPlays.isEmpty
                      ? const SizedBox()
                      : ListView.builder(
                          itemCount: state.currentTicketPlays.length,
                          padding: const EdgeInsets.only(top: 16.0),
                          itemBuilder: (context, index) {
                            final play = state.currentTicketPlays[index];
                            return Container(
                              height: 55,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  const SizedBox(width: 220),
                                  // Nu.
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        fontFamily: 'DinNextLtPro',
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  // Odds (Cuotas)
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      play.odds.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontFamily: 'DinNextLtPro',
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  // Monto
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      play.amount.toInt().toString(),
                                      style: const TextStyle(
                                        fontFamily: 'DinNextLtPro',
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  // Combination (Dogs)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/resources/botonnumero${play.dog1}.png',
                                        height: 38,
                                        fit: BoxFit.contain,
                                      ),
                                      if (play.dog2 != null) ...[
                                        const SizedBox(width: 6),
                                        Image.asset(
                                          'assets/resources/botonnumero${play.dog2}.png',
                                          height: 38,
                                          fit: BoxFit.contain,
                                        ),
                                      ],
                                      if (play.dog3 != null) ...[
                                        const SizedBox(width: 6),
                                        Image.asset(
                                          'assets/resources/botonnumero${play.dog3}.png',
                                          height: 38,
                                          fit: BoxFit.contain,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const Spacer(),
                                  // Row Delete Button
                                  Semantics(
                                    label: 'Eliminar jugada ${index + 1}',
                                    button: true,
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () => state.deletePlayAtIndex(index),
                                        onTapDown: (_) => setState(() => _pressedPlayIndex = index),
                                        onTapUp: (_) => setState(() => _pressedPlayIndex = null),
                                        onTapCancel: () => setState(() => _pressedPlayIndex = null),
                                        child: AnimatedScale(
                                          scale: _pressedPlayIndex == index ? 0.92 : 1.0,
                                          duration: const Duration(milliseconds: 100),
                                          curve: Curves.easeOut,
                                          child: Container(
                                            width: 64,
                                            height: 48,
                                            decoration: const BoxDecoration(
                                              image: DecorationImage(
                                                image: AssetImage('assets/resources/botondelete.png'),
                                                fit: BoxFit.fill,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 111), // Spacing from slant
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Bottom Bar: Close instruction + Delete/Print buttons
                Padding(
                  padding: const EdgeInsets.only(left: 220, right: 90, bottom: 24.0, top: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isTicketOpen = false;
                            });
                          },
                          child: const Text(
                            'HAGA CLICK O DESLICE PARA CERRAR EL TICKET',
                            style: TextStyle(
                              fontFamily: 'DinNextLtPro',
                              color: Colors.white70,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Delete Ticket Button
                      Semantics(
                        label: 'Eliminar ticket actual',
                        button: true,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _isDeleteHovered = true),
                          onExit: (_) => setState(() => _isDeleteHovered = false),
                          child: GestureDetector(
                            onTap: () {
                              state.clearBetAmount();
                              state.deleteCurrentTicket();
                            },
                            onTapDown: (_) => setState(() => _isDeletePressed = true),
                            onTapUp: (_) => setState(() => _isDeletePressed = false),
                            onTapCancel: () => setState(() => _isDeletePressed = false),
                            child: AnimatedScale(
                              scale: _isDeletePressed ? 0.96 : 1.0,
                              duration: const Duration(milliseconds: 100),
                              curve: Curves.easeOut,
                              child: Container(
                                width: 145,
                                height: 110,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage(
                                      (_isDeleteHovered || _isDeletePressed)
                                          ? 'assets/resources/botondeleteclaro.png'
                                          : 'assets/resources/botondelete.png',
                                    ),
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Print Ticket Button (also closes the drawer)
                      Semantics(
                        label: 'Imprimir ticket',
                        button: true,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _isPrintHovered = true),
                          onExit: (_) => setState(() => _isPrintHovered = false),
                          child: GestureDetector(
                            onTap: () {
                              _handlePrintTicket(state);
                              setState(() {
                                _isTicketOpen = false;
                              });
                            },
                            onTapDown: (_) => setState(() => _isPrintPressed = true),
                            onTapUp: (_) => setState(() => _isPrintPressed = false),
                            onTapCancel: () => setState(() => _isPrintPressed = false),
                            child: AnimatedScale(
                              scale: _isPrintPressed ? 0.96 : 1.0,
                              duration: const Duration(milliseconds: 100),
                              curve: Curves.easeOut,
                              child: Container(
                                width: 220,
                                height: 200,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage(
                                      (_isPrintHovered || _isPrintPressed)
                                          ? 'assets/resources/botonprinterclaro.png'
                                          : 'assets/resources/botonprinter.png',
                                    ),
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Aviso de ventas cerradas (carrera cerrada/en curso)
        if (!state.isSalesOpen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                width: double.infinity,
                color: const Color(0xFFD32F2F),
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                alignment: Alignment.center,
                child: const Text(
                  'VENTAS CERRADAS PARA ESTA CARRERA',
                  style: TextStyle(
                    fontFamily: 'DinNextLtPro',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Diálogo teclado numérico para REPETIR TICKET ──────────────────────────────

class _RepeatTicketDialog extends StatefulWidget {
  final String initial;
  const _RepeatTicketDialog({required this.initial});

  @override
  State<_RepeatTicketDialog> createState() => _RepeatTicketDialogState();
}

class _RepeatTicketDialogState extends State<_RepeatTicketDialog> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  void _type(String d) {
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
        width: 340,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'REPETIR TICKET',
                style: TextStyle(color: Color(0xFFD4AF37), fontFamily: 'DinNextLtPro', fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
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
              SizedBox(height: 260, child: _NumPad(onDigit: _type, onBackspace: _backspace)),
              const SizedBox(height: 16),
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
        color: Colors.white.withOpacity(_pressed ? 0.12 : 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(_pressed ? 0.7 : 0.35), width: 1.5),
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

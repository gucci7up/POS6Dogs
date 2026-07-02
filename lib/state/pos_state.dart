import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pos/services/api_client.dart';

class PrintResult {
  final String? error;
  final String? ticketId;
  final int? ticketNumber;
  const PrintResult({this.error, this.ticketId, this.ticketNumber});
  bool get isSuccess => error == null;
}

class Bet {
  final int dog1;
  final int? dog2;
  final int? dog3;
  final double amount;
  final double odds;

  Bet({
    required this.dog1,
    this.dog2,
    this.dog3,
    required this.amount,
    required this.odds,
  });
}

enum TicketStatus {
  approved,
  winner,
  loser,
  paid,
  annulled,
}

class Ticket {
  final String id;
  final int ticketNumber;
  final int raceNumber;
  final String dateTime;
  final List<Bet> plays;
  final double amount;
  final double investment;
  final double pay;
  final double balance;
  final String game;
  final TicketStatus status;

  Ticket({
    required this.id,
    required this.ticketNumber,
    required this.raceNumber,
    required this.dateTime,
    required this.plays,
    required this.amount,
    required this.investment,
    required this.pay,
    required this.balance,
    required this.game,
    required this.status,
  });

  double get potentialPrize =>
      plays.fold(0.0, (sum, b) => sum + b.amount * b.odds);
}

class RaceResult {
  final int raceNumber;
  final int winner1;
  final int winner2;
  final int winner3;
  final String bonus;

  RaceResult({
    required this.raceNumber,
    required this.winner1,
    required this.winner2,
    required this.winner3,
    required this.bonus,
  });
}

class RaceOdds {
  final int raceNumber;
  final List<double> odds;

  RaceOdds({
    required this.raceNumber,
    required this.odds,
  });
}

class PosState extends ChangeNotifier {
  final ApiClient _api;
  final AuthResult _auth;

  PosState({required ApiClient api, required AuthResult auth})
      : _api = api,
        _auth = auth {
    // Primera consulta inmediata — garantiza que las cuotas de la matriz
    // estén disponibles antes del primer ticket
    _refreshRaceStatus().then((_) => _scheduleNextPoll());
    unawaited(_refreshSalesHistory());
    unawaited(_refreshResultsHistory());
    unawaited(_refreshOddsHistory());
  }

  int _currentRace = 0;
  int get currentRace => _currentRace;

  int _countdownSeconds = 0;
  int get countdownSeconds => _countdownSeconds;

  String? _currentRaceId;
  String? get currentRaceId => _currentRaceId;
  String _raceStatus = 'IDLE';
  String get raceStatus => _raceStatus;

  /// Indica si todavía se pueden hacer jugadas. El backend cierra la venta
  /// 5 segundos antes de que arranque la carrera (closedDelaySeconds), por
  /// lo que basta con permitir jugadas únicamente mientras está OPEN.
  bool get isSalesOpen => _raceStatus == 'OPEN';

  // Tiempo fijo entre el cierre de venta y el inicio de la siguiente carrera
  // (closedDelaySeconds + videoSeconds del backend: 5 + 50).
  static const int _postSaleSeconds = 55;

  DateTime? _nextRaceStartEstimate;

  /// Hora estimada (HH:mm:ss) en que abrirá la siguiente carrera, o '--:--:--'
  /// si no se conoce todavía.
  String get nextRaceStartLabel {
    final t = _nextRaceStartEstimate;
    if (t == null) return '--:--:--';
    final local = t.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// Estado de la carrera actual, en español, para mostrar en el panel.
  String get raceStatusLabel {
    switch (_raceStatus) {
      case 'OPEN':
        return 'ABIERTA';
      case 'CLOSED':
        return 'CERRADA';
      case 'RUNNING':
        return 'EN CURSO';
      case 'FINISHED':
        return 'FINALIZADA';
      default:
        return 'INACTIVA';
    }
  }

  String get authToken => _auth.accessToken;
  String get agencyId => _auth.agencyId ?? '-';
  String get agencyName => _auth.agencyName ?? _auth.agencyId ?? 'SIN AGENCIA';
  String get currentUser => _auth.username;

  bool _isServerOnline = true;
  bool get isServerOnline => _isServerOnline;

  String _selectedLanguage = 'Español';
  String get selectedLanguage => _selectedLanguage;

  String _selectedPrinter = 'Impresora predeterminada';
  String get selectedPrinter => _selectedPrinter;

  int _selectedPaperWidth = 80; // 58 o 80 mm
  int get selectedPaperWidth => _selectedPaperWidth;

  void setLanguage(String language) {
    _selectedLanguage = language;
    notifyListeners();
  }

  void setPrinter(String printer) {
    _selectedPrinter = printer;
    notifyListeners();
  }

  void setPaperWidth(int mm) {
    _selectedPaperWidth = mm;
    notifyListeners();
  }

  // Fila 1°: permite seleccionar varios perros a la vez (para reverse múltiple
  // y jugadas GANAR en lote). Los flujos EXACTA/TRIFECTA aplican solo cuando
  // hay exactamente un perro seleccionado.
  final Set<int> _selectedDogs1 = {};
  Set<int> get selectedDogs1 => _selectedDogs1;
  int? get _soloDog1 => _selectedDogs1.length == 1 ? _selectedDogs1.first : null;
  int? get selectedDog1 => _soloDog1;

  int? _selectedDog2;
  int? get selectedDog2 => _selectedDog2;

  int? _selectedDog3;
  int? get selectedDog3 => _selectedDog3;

  double _currentBetAmount = 0.0;
  double get currentBetAmount => _currentBetAmount;

  List<Bet> _currentTicketPlays = [];
  List<Bet> get currentTicketPlays => _currentTicketPlays;

  List<Ticket> _salesHistory = [];
  List<Ticket> get salesHistory => _salesHistory;

  List<RaceResult> _resultsHistory = [];
  List<RaceResult> get resultsHistory => _resultsHistory;

  List<RaceOdds> _oddsHistoryList = [];
  List<RaceOdds> get oddsHistory => _oddsHistoryList;

  // Cuotas en vivo de la carrera actual, indexadas como "WINNER:3", "EXACTA:1-2", "TRIFECTA:1-2-3"
  Map<String, double> _liveOdds = {};

  // X2: perro con cuota doble esta carrera (0 = ninguno), se anuncia al cerrar la venta
  int _x2Dog = 0;
  int get x2Dog => _x2Dog;

  // Jackpot: monto acumulado en el pozo (en vivo desde el backend)
  double _jackpotAmount = 0.0;
  double get jackpotAmount => _jackpotAmount;

  Timer? _timer;
  bool _isRefreshing = false;
  int _consecutiveFailures = 0;
  int _pollCount = 0; // para refrescar live odds periódicamente
  static const int _maxFailuresBeforeError = 3;

  // Intervalo adaptativo según estado de carrera
  Duration get _pollInterval {
    switch (_raceStatus) {
      case 'CLOSED':
      case 'RUNNING':
        return const Duration(seconds: 1); // momento crítico
      case 'OPEN':
        return const Duration(seconds: 2); // carrera abierta
      default:
        return const Duration(seconds: 5); // sin carrera activa
    }
  }

  void _scheduleNextPoll() {
    _timer?.cancel();
    _timer = Timer(_pollInterval, () async {
      await _refreshRaceStatus();
      _scheduleNextPoll(); // reagendar con el intervalo correcto según nuevo estado
    });
  }

  Future<void> _refreshRaceStatus() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final status = await _api.getRaceEngineStatus();
      _consecutiveFailures = 0; // resetear contador al éxito
      _isServerOnline = true;

      final currentRaceJson = status['currentRace'] as Map<String, dynamic>?;
      // Venta anticipada: mientras corre el video de la carrera actual, el
      // backend ya puede tener la próxima carrera abierta en 'nextRace'.
      // Si viene, el POS vende esa carrera de inmediato.
      final nextRaceJson = status['nextRace'] as Map<String, dynamic>?;
      final salesRaceJson = nextRaceJson ?? currentRaceJson;
      if (salesRaceJson != null) {
        _currentRace = (salesRaceJson['numero'] as num).toInt();
        if (nextRaceJson != null) {
          _raceStatus = 'OPEN';
          _countdownSeconds =
              (status['nextRaceRemainingSaleSeconds'] as num? ?? 0).toInt();
        } else {
          _raceStatus = (status['status'] ?? 'IDLE') as String;
          final remainingSale = status['remainingSaleSeconds'] as num?;
          final remainingVideo = status['remainingVideoSeconds'] as num?;
          _countdownSeconds = (remainingSale ?? remainingVideo ?? 0).toInt();
        }

        final saleEndAtStr = salesRaceJson['saleEndAt'] as String?;
        if (saleEndAtStr != null) {
          _nextRaceStartEstimate = DateTime.parse(saleEndAtStr)
              .add(const Duration(seconds: _postSaleSeconds));
        }

        // X2: viene en el top-level del status y pertenece a la carrera del
        // video; no aplica a la carrera nueva en venta anticipada.
        final x2Dog =
            nextRaceJson != null ? 0 : (status['x2Dog'] as num? ?? 0).toInt();
        if (x2Dog != _x2Dog) _x2Dog = x2Dog;

        final newRaceId = salesRaceJson['id'] as String?;
        if (newRaceId != _currentRaceId) {
          final hadPreviousRace = _currentRaceId != null;
          _currentRaceId = newRaceId;
          _x2Dog = 0; // reset X2 al cambiar de carrera
          if (hadPreviousRace) {
            unawaited(_refreshResultsHistory());
            unawaited(_refreshOddsHistory());
            unawaited(_refreshSalesHistory());
          }
          await _refreshLiveOdds();
        } else if (_raceStatus == 'OPEN') {
          // Refrescar cuotas de la matriz cada 5 polls para mantenerlas actualizadas
          _pollCount++;
          if (_pollCount >= 5) {
            _pollCount = 0;
            unawaited(_refreshLiveOdds());
          }
        }

        if (_raceStatus != 'OPEN' &&
            (_hasAnySelection || _currentTicketPlays.isNotEmpty)) {
          _resetSelection();
          _currentTicketPlays.clear();
        }
      }

      // Jackpot: actualizar monto acumulado desde el status global
      final jackpotRaw = status['jackpotAmount'];
      if (jackpotRaw != null) {
        _jackpotAmount = double.tryParse(jackpotRaw.toString()) ?? _jackpotAmount;
      }

      notifyListeners();
    } catch (_) {
      _consecutiveFailures++;
      // Solo marcar offline después de 3 fallos consecutivos
      if (_consecutiveFailures >= _maxFailuresBeforeError) {
        _isServerOnline = false;
        notifyListeners();
      }
      // Los datos anteriores se mantienen en pantalla (no se borran)
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _refreshLiveOdds() async {
    final raceId = _currentRaceId;
    if (raceId == null) return;
    try {
      final rows = await _api.getRaceOddsLive(raceId);
      final odds = <String, double>{};
      for (final row in rows) {
        final betType = row['betType'] as String;
        final selection = row['selection'] as String;
        // Usar currentOdds primero, finalOdds como fallback, ignorar nulos
        final rawOdds = row['currentOdds'] ?? row['finalOdds'];
        if (rawOdds == null) continue;
        final parsed = double.tryParse(rawOdds.toString()) ?? 0.0;
        if (parsed > 0) odds['$betType:$selection'] = parsed;
      }
      _liveOdds = odds;
      notifyListeners();
    } catch (_) {
      // Mantiene las cuotas anteriores si falla la actualización
    }
  }

  void selectDog1(int dogNumber) {
    if (_selectedDogs1.contains(dogNumber)) {
      _selectedDogs1.remove(dogNumber);
    } else {
      _selectedDogs1.add(dogNumber);
      // If same dog selected in 2° or 3°, clear it from there
      if (_selectedDog2 == dogNumber) {
        _selectedDog2 = null;
      }
      if (_selectedDog3 == dogNumber) {
        _selectedDog3 = null;
      }
    }
    notifyListeners();
  }

  void selectDog2(int dogNumber) {
    if (_selectedDog2 == dogNumber) {
      _selectedDog2 = null;
    } else {
      _selectedDog2 = dogNumber;
      // If same dog selected in 1° o 3°, clear it from there
      _selectedDogs1.remove(dogNumber);
      if (_selectedDog3 == dogNumber) {
        _selectedDog3 = null;
      }
    }
    notifyListeners();
  }

  void selectDog3(int dogNumber) {
    if (_selectedDog3 == dogNumber) {
      _selectedDog3 = null;
    } else {
      _selectedDog3 = dogNumber;
      // If same dog selected in 1° o 2°, clear it from there
      _selectedDogs1.remove(dogNumber);
      if (_selectedDog2 == dogNumber) {
        _selectedDog2 = null;
      }
    }
    notifyListeners();
  }

  bool get _hasAnySelection =>
      _selectedDogs1.isNotEmpty || _selectedDog2 != null || _selectedDog3 != null;

  /// Hay una jugada lista para agregar (selección + monto), pendiente de
  /// confirmarse con el botón AGREGAR JUGADA.
  bool get hasPendingPlay => _hasAnySelection && _currentBetAmount > 0;

  bool _loadingOddsForBet = false;

  Future<void> addBetAmount(double amount) async {
    // Sin selección activa + hay jugadas → sumar al último play del ticket
    if (!_hasAnySelection && _currentTicketPlays.isNotEmpty) {
      _addAmountToLastPlay(amount);
      return;
    }
    _currentBetAmount += amount;
    notifyListeners();
  }

  void _addAmountToLastPlay(double amount) {
    final last = _currentTicketPlays.last;
    _currentTicketPlays[_currentTicketPlays.length - 1] = Bet(
      dog1: last.dog1,
      dog2: last.dog2,
      dog3: last.dog3,
      amount: last.amount + amount,
      odds: last.odds,
    );
    notifyListeners();
  }

  void clearBetAmount() {
    _currentBetAmount = 0.0;
    notifyListeners();
  }

  // Cuota "GANAR": cuota del perro solo. Si es el perro X2, se duplica al liquidar.
  double getGanarOdds(int dog) {
    final base = _liveOdds['WINNER:$dog'] ?? 1.5;
    return (_x2Dog > 0 && dog == _x2Dog) ? base * 2.0 : base;
  }

  // Cuota "EXACTA": usa la cuota real de la matriz si está disponible y > 1
  double getExactaOdds(int dog) {
    final other = dog % 6 + 1;
    final matrix = _liveOdds['EXACTA:$dog-$other'] ?? 0.0;
    return matrix > 1 ? matrix : _exactaOddsFromWinners(dog, other);
  }

  // Cuota exacta de un par específico (dog1 1°, dog2 2°)
  double getExactaOddsPair(int dog1, int dog2) {
    final matrix = _liveOdds['EXACTA:$dog1-$dog2'] ?? 0.0;
    return matrix > 1 ? matrix : _exactaOddsFromWinners(dog1, dog2);
  }

  // Cuota "TRIFECTA": usa la cuota real de la matriz si está disponible y > 1
  double getTrifectaOdds(int dog) {
    final next1 = dog % 6 + 1;
    final next2 = next1 % 6 + 1;
    final matrix = _liveOdds['TRIFECTA:$dog-$next1-$next2'] ?? 0.0;
    return matrix > 1 ? matrix : _trifectaOddsFromWinners(dog, next1, next2);
  }

  // Calcula cuota EXACTA usando probabilidad condicional desde odds WINNER
  // Igual que la fórmula del backend virtual-odds.service.ts
  // P(a gana 1°) × P(b gana 2° | a ganó) con margen casa 15%
  double _exactaOddsFromWinners(int dog1, int dog2) {
    final pa = (0.9 / getGanarOdds(dog1)).clamp(0.01, 0.99);
    final pb = (0.9 / getGanarOdds(dog2)).clamp(0.01, 0.99);
    final pExacta = pa * (pb / (1 - pa).clamp(0.01, 0.99));
    if (pExacta <= 0) return getGanarOdds(dog1) + getGanarOdds(dog2);
    return double.parse((0.85 / pExacta).toStringAsFixed(2));
  }

  // Calcula cuota TRIFECTA usando probabilidad condicional encadenada
  double _trifectaOddsFromWinners(int dog1, int dog2, int dog3) {
    final pa = (0.9 / getGanarOdds(dog1)).clamp(0.01, 0.99);
    final pb = (0.9 / getGanarOdds(dog2)).clamp(0.01, 0.99);
    final pc = (0.9 / getGanarOdds(dog3)).clamp(0.01, 0.99);
    final pExacta = pa * (pb / (1 - pa).clamp(0.01, 0.99));
    final pTrifecta = pExacta * (pc / (1 - pa - pb).clamp(0.01, 0.99));
    if (pTrifecta <= 0) return getGanarOdds(dog1) + getGanarOdds(dog2) + getGanarOdds(dog3);
    return double.parse((0.80 / pTrifecta).toStringAsFixed(2));
  }

  void _addCalculatedPlay(int dog1, int dog2, double amount) {
    // Usar ÚNICAMENTE la cuota real de la matriz — nunca inventar valores
    final odds = _liveOdds['EXACTA:$dog1-$dog2'] ?? 0.0;
    if (odds <= 1) return; // cuota inválida — no crear la jugada
    _currentTicketPlays.add(Bet(dog1: dog1, dog2: dog2, amount: amount, odds: odds));
  }

  void _addCalculatedTrifectaPlay(int dog1, int dog2, int dog3, double amount) {
    final odds = _liveOdds['TRIFECTA:$dog1-$dog2-$dog3'] ?? 0.0;
    if (odds <= 1) return; // cuota inválida — no crear la jugada
    _currentTicketPlays.add(Bet(dog1: dog1, dog2: dog2, dog3: dog3, amount: amount, odds: odds));
  }

  void _addSinglePlay(int dog, double amount) {
    final odds = _liveOdds['WINNER:$dog'] ?? 1.5;

    _currentTicketPlays.add(Bet(
      dog1: dog,
      dog2: null,
      amount: amount,
      odds: odds,
    ));
  }

  void _resetSelection() {
    _selectedDogs1.clear();
    _selectedDog2 = null;
    _selectedDog3 = null;
    _currentBetAmount = 0.0;
  }

  // Refresca odds si hace falta antes de crear jugadas
  Future<void> _ensureOddsLoaded() async {
    if (_currentRaceId == null || _loadingOddsForBet) return;
    _loadingOddsForBet = true;
    await _refreshLiveOdds();
    _loadingOddsForBet = false;
  }

  // Jugada reversa:
  // - Con 2+ perros seleccionados en fila 1°: combina todos entre sí en ambos
  //   sentidos (parejas ordenadas, sin repetir el mismo perro).
  // - Con 1 perro en 1° y otro en 2°: juega ambos sentidos (1/2 y 2/1).
  void playReverse() {
    final amount = _currentBetAmount > 0 ? _currentBetAmount : 25.0;

    if (_selectedDogs1.length >= 2) {
      final dogs = _selectedDogs1.toList()..sort();
      for (final a in dogs) {
        for (final b in dogs) {
          if (a == b) continue;
          _addCalculatedPlay(a, b, amount);
        }
      }
      _resetSelection();
      notifyListeners();
      return;
    }

    final d1 = _soloDog1;
    if (d1 == null || _selectedDog2 == null) return;
    _addCalculatedPlay(d1, _selectedDog2!, amount);
    _addCalculatedPlay(_selectedDog2!, d1, amount);
    _resetSelection();
    notifyListeners();
  }

  // Combina el perro seleccionado en 1° con todos los demás en 2°
  void playAllCombinations() {
    final dog = _soloDog1 ?? _selectedDog2;
    if (dog == null) return;
    final amount = _currentBetAmount > 0 ? _currentBetAmount : 25.0;
    for (int other = 1; other <= 6; other++) {
      if (other == dog) continue;
      _addCalculatedPlay(dog, other, amount);
    }
    _currentBetAmount = amount;
    _resetSelection();
    notifyListeners();
  }

  // Jugada R: combina el perro seleccionado con todos los demás en ambos sentidos ($25 c/u, total $350)
  void playR() {
    final dog = _soloDog1 ?? _selectedDog2;
    if (dog == null) return;
    _playCombinedR(dog, 25.0);
  }

  // Jugada R/2: igual que R pero cada pale vale $12.5 (total $175)
  void playR2() {
    final dog = _soloDog1 ?? _selectedDog2;
    if (dog == null) return;
    _playCombinedR(dog, 12.5);
  }

  void _playCombinedR(int dog, double amountPerPlay) {
    for (int other = 1; other <= 6; other++) {
      if (other == dog) continue;
      final o1 = _liveOdds['EXACTA:$dog-$other'] ?? 0.0;
      final o2 = _liveOdds['EXACTA:$other-$dog'] ?? 0.0;
      if (o1 > 1) _currentTicketPlays.add(Bet(dog1: dog, dog2: other, amount: amountPerPlay, odds: o1));
      if (o2 > 1) _currentTicketPlays.add(Bet(dog1: other, dog2: dog, amount: amountPerPlay, odds: o2));
    }
    _resetSelection();
    notifyListeners();
  }

  String? _oddsLoadError;
  String? get oddsLoadError => _oddsLoadError;
  void clearOddsLoadError() { _oddsLoadError = null; }

  // Obtiene la cuota de una selección consultando directamente la DB vía API
  Future<double?> _fetchOddsForSelection(String betType, String selection) async {
    if (_currentRaceId == null) return null;
    try {
      return await _api.getSelectionOdds(_currentRaceId!, betType, selection);
    } catch (_) {
      return null;
    }
  }

  void addPlayToTicket() {
    if (_currentBetAmount <= 0) return;
    _oddsLoadError = null;

    // Varios perros en fila 1° → una jugada GANAR por cada uno
    if (_selectedDogs1.length > 1) {
      final dogs = _selectedDogs1.toList()..sort();
      for (final dog in dogs) {
        _addSinglePlay(dog, _currentBetAmount);
      }
      _resetSelection();
      notifyListeners();
      return;
    }

    final d1 = _soloDog1;
    final d2 = _selectedDog2;
    final d3 = _selectedDog3;

    if (d1 != null && d2 != null && d3 != null) {
      // TRIFECTA: usar cuota del caché local (actualizado por polling)
      final odds = _liveOdds['TRIFECTA:$d1-$d2-$d3'] ?? 0.0;
      if (odds <= 1) {
        _oddsLoadError = 'Cuota de TRIPLETA no disponible aún. Espera un momento e inténtalo de nuevo.';
        notifyListeners();
        return;
      }
      _currentTicketPlays.add(Bet(dog1: d1, dog2: d2, dog3: d3, amount: _currentBetAmount, odds: odds));

    } else if (d1 != null && d2 != null) {
      // EXACTA: usar cuota del caché local (actualizado por polling)
      final odds = _liveOdds['EXACTA:$d1-$d2'] ?? 0.0;
      if (odds <= 1) {
        _oddsLoadError = 'Cuota de PALE no disponible aún. Espera un momento e inténtalo de nuevo.';
        notifyListeners();
        return;
      }
      _currentTicketPlays.add(Bet(dog1: d1, dog2: d2, amount: _currentBetAmount, odds: odds));

    } else if (d1 != null) {
      _addSinglePlay(d1, _currentBetAmount);
    } else if (d2 != null) {
      _addSinglePlay(d2, _currentBetAmount);
    } else if (d3 != null) {
      _addSinglePlay(d3, _currentBetAmount);
    } else {
      return;
    }
    _resetSelection();
    notifyListeners();
  }

  // Convierte una jugada local en el detalle que espera POST /tickets
  Map<String, String> _betToDetail(Bet b) {
    if (b.dog3 != null) {
      return {
        'betType': 'TRIFECTA',
        'selection': '${b.dog1}-${b.dog2}-${b.dog3}',
        'amount': b.amount.toStringAsFixed(2),
      };
    } else if (b.dog2 != null) {
      return {
        'betType': 'EXACTA',
        'selection': '${b.dog1}-${b.dog2}',
        'amount': b.amount.toStringAsFixed(2),
      };
    } else {
      return {
        'betType': 'WINNER',
        'selection': '${b.dog1}',
        'amount': b.amount.toStringAsFixed(2),
      };
    }
  }

  // Busca un ticket por su número en el backend
  Future<Ticket?> findTicketByNumber(String query) async {
    final trimmed = query.trim();
    final ticketNumber = int.tryParse(trimmed);
    if (ticketNumber == null) return null;
    try {
      final json = await _api.getTicketByNumber(ticketNumber);
      return _ticketFromJson(json);
    } catch (_) {
      return null;
    }
  }

  // Recarga las jugadas de un ticket recalculando cuotas actuales de la matriz
  void repeatTicket(Ticket ticket) {
    for (final play in ticket.plays) {
      if (play.dog3 != null) {
        // TRIFECTA: recalcular con cuota actual de la matriz
        _addCalculatedTrifectaPlay(play.dog1, play.dog2!, play.dog3!, play.amount);
      } else if (play.dog2 != null) {
        // EXACTA: recalcular con cuota actual de la matriz
        _addCalculatedPlay(play.dog1, play.dog2!, play.amount);
      } else {
        // GANADOR: cuota actual del perro
        _addSinglePlay(play.dog1, play.amount);
      }
    }
    notifyListeners();
  }

  void deletePlayAtIndex(int index) {
    if (index >= 0 && index < _currentTicketPlays.length) {
      _currentTicketPlays.removeAt(index);
      notifyListeners();
    }
  }

  double get currentTicketTotal {
    return _currentTicketPlays.fold(0.0, (sum, play) => sum + play.amount);
  }

  void deleteCurrentTicket() {
    _currentTicketPlays.clear();
    _selectedDogs1.clear();
    _selectedDog2 = null;
    _selectedDog3 = null;
    _currentBetAmount = 0.0;
    notifyListeners();
  }

  // Crea el ticket en el backend. Devuelve PrintResult con el ID del ticket creado,
  // o con un mensaje de error si algo falla.
  Future<PrintResult> printTicket() async {
    if (_currentTicketPlays.isEmpty &&
        _hasAnySelection &&
        _currentBetAmount > 0) {
      addPlayToTicket();
    }

    if (_currentTicketPlays.isEmpty) return const PrintResult();

    final raceId = _currentRaceId;
    if (raceId == null) {
      return const PrintResult(error: 'No hay una carrera activa para crear el ticket.');
    }

    try {
      final created = await _api.createTicket(
        raceId: raceId,
        details: _currentTicketPlays.map(_betToDetail).toList(),
      );
      _currentTicketPlays.clear();
      notifyListeners();
      await _refreshSalesHistory();
      return PrintResult(
        ticketId: created['id'] as String?,
        ticketNumber: (created['ticketNumber'] as num?)?.toInt(),
      );
    } on ApiException catch (e) {
      return PrintResult(error: e.message);
    } catch (_) {
      return const PrintResult(error: 'No se pudo conectar con el servidor');
    }
  }

  Future<void> _refreshSalesHistory() async {
    try {
      final tickets = await _api.getTickets();
      _salesHistory = tickets.map((t) => _ticketFromJson(t as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (_) {
      // Mantiene el historial anterior si falla la actualización
    }
  }

  Future<void> _refreshResultsHistory() async {
    try {
      final races = await _api.getRaceHistory(limit: 13);
      _resultsHistory = races.map((race) {
        final parts = (race['resultado'] as String).split('-');
        final jackpotWon = double.tryParse((race['jackpotWon'] ?? '0').toString()) ?? 0;
        final bonusLabel = (race['bonusLabel'] as String? ?? '');
        final bonus = jackpotWon > 0 ? 'JACKPOT' : bonusLabel;
        return RaceResult(
          raceNumber: (race['numero'] as num).toInt(),
          winner1: int.parse(parts[0]),
          winner2: int.parse(parts[1]),
          winner3: parts.length > 2 ? int.parse(parts[2]) : 0,
          bonus: bonus,
        );
      }).toList();
      notifyListeners();
    } catch (_) {
      // Mantiene el historial anterior si falla la actualización
    }
  }

  Future<void> _refreshOddsHistory() async {
    try {
      final races = await _api.getRaceHistory(limit: 13);
      final list = <RaceOdds>[];
      for (final race in races) {
        final oddsRows = await _api.getRaceOdds(race['id'] as String);
        final odds = List<double>.filled(6, 1.5);
        for (final row in oddsRows) {
          if (row['betType'] == 'WINNER') {
            final selection = int.tryParse(row['selection'] as String);
            if (selection != null && selection >= 1 && selection <= 6) {
              odds[selection - 1] = double.parse(row['odds'].toString());
            }
          }
        }
        list.add(RaceOdds(raceNumber: (race['numero'] as num).toInt(), odds: odds));
      }
      _oddsHistoryList = list;
      notifyListeners();
    } catch (_) {
      // Mantiene el historial anterior si falla la actualización
    }
  }

  Ticket _ticketFromJson(Map<String, dynamic> json) {
    final details = json['details'] as List<dynamic>? ?? [];
    final plays = details.map((d) {
      final betType = d['betType'] as String;
      final parts = (d['selection'] as String).split('-').map(int.parse).toList();
      final amount = double.parse(d['amount'].toString());
      final odds = double.parse(d['odds'].toString());
      switch (betType) {
        case 'TRIFECTA':
          return Bet(dog1: parts[0], dog2: parts[1], dog3: parts[2], amount: amount, odds: odds);
        case 'EXACTA':
          return Bet(dog1: parts[0], dog2: parts[1], amount: amount, odds: odds);
        default:
          return Bet(dog1: parts[0], amount: amount, odds: odds);
      }
    }).toList();

    final totalAmount = double.parse(json['totalAmount'].toString());
    final prizeAmount = double.parse((json['prizeAmount'] ?? '0').toString());

    final createdAt = DateTime.parse(json['createdAt'] as String).toLocal();
    final dateStr = "${createdAt.day.toString().padLeft(2, '0')}/"
        "${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} "
        "${createdAt.hour.toString().padLeft(2, '0')}:"
        "${createdAt.minute.toString().padLeft(2, '0')}:"
        "${createdAt.second.toString().padLeft(2, '0')}";

    final raceJson = json['race'] as Map<String, dynamic>?;
    final raceNumber = (raceJson?['numero'] as num?)?.toInt() ?? 0;

    return Ticket(
      id: json['id'] as String,
      ticketNumber: (json['ticketNumber'] as num).toInt(),
      raceNumber: raceNumber,
      dateTime: dateStr,
      plays: plays,
      amount: totalAmount,
      investment: totalAmount,
      pay: prizeAmount,
      balance: prizeAmount - totalAmount,
      game: 'Racing Dogs',
      status: _mapTicketStatus(json['status'] as String),
    );
  }

  TicketStatus _mapTicketStatus(String status) {
    switch (status) {
      case 'WON':
        return TicketStatus.winner;
      case 'LOST':
        return TicketStatus.loser;
      case 'PAID':
        return TicketStatus.paid;
      case 'CANCELLED':
        return TicketStatus.annulled;
      default:
        return TicketStatus.approved;
    }
  }

  // Summaries for Screen 4 (Ventas)
  double get totalMonto {
    return _salesHistory.fold(0.0, (sum, ticket) => sum + ticket.amount);
  }

  double get totalInversion {
    return _salesHistory.fold(0.0, (sum, ticket) => sum + ticket.investment);
  }

  double get totalPagar {
    return _salesHistory.fold(0.0, (sum, ticket) => sum + ticket.pay);
  }

  double get totalBalance {
    return _salesHistory.fold(0.0, (sum, ticket) => sum + ticket.balance);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

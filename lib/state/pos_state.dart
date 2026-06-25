import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pos/services/api_client.dart';
import 'package:pos/services/local_video_server.dart';
import 'package:pos/services/video_sync_service.dart';

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
    _refreshRaceStatus();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refreshRaceStatus());
    unawaited(_refreshSalesHistory());
    unawaited(_refreshResultsHistory());
    unawaited(_refreshOddsHistory());
    unawaited(_startLocalVideoServer());
  }

  // ── Servidor local de videos ──────────────────────────────────────────────

  String? _videosDir;
  String? get videosDir => _videosDir;

  bool _localServerRunning = false;
  bool get localServerRunning => _localServerRunning;

  // Estado de sincronización
  bool _syncing = false;
  bool get isSyncing => _syncing;

  int _syncDone = 0;
  int _syncTotal = 0;
  String _syncCurrent = '';

  int get syncDone => _syncDone;
  int get syncTotal => _syncTotal;
  String get syncCurrent => _syncCurrent;

  Future<void> _startLocalVideoServer() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      _videosDir = p.join(appDir.path, 'videos');

      // Obtener clave AES del servidor (requiere JWT válido)
      final keyData = await _api.getVideoEncryptionKey(_auth.accessToken);
      if (keyData != null) {
        LocalVideoServer.setKey(keyData['key']!, keyData['iv']!);
      }

      await LocalVideoServer.start(_videosDir!);
      _localServerRunning = LocalVideoServer.hasKey;
      notifyListeners();
    } catch (_) {
      _localServerRunning = false;
    }
  }

  Future<SyncResult> syncVideos() async {
    if (_syncing || _videosDir == null) {
      throw Exception('Sincronización ya en curso o servidor no iniciado');
    }
    _syncing = true;
    _syncDone = 0;
    _syncTotal = 0;
    _syncCurrent = '';
    notifyListeners();

    try {
      final result = await VideoSyncService.sync(
        accessToken: _auth.accessToken,
        videosDir: _videosDir!,
        onProgress: (done, total, current) {
          _syncDone = done;
          _syncTotal = total;
          _syncCurrent = current;
          notifyListeners();
        },
      );
      return result;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  int _currentRace = 0;
  int get currentRace => _currentRace;

  int _countdownSeconds = 0;
  int get countdownSeconds => _countdownSeconds;

  String? _currentRaceId;
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

  int? _selectedDog1;
  int? get selectedDog1 => _selectedDog1;

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

  Future<void> _refreshRaceStatus() async {
    if (_isRefreshing) return; // evita peticiones simultáneas
    _isRefreshing = true;
    try {
      final status = await _api.getRaceEngineStatus();
      _isServerOnline = true;

      final currentRaceJson = status['currentRace'] as Map<String, dynamic>?;
      if (currentRaceJson != null) {
        _currentRace = (currentRaceJson['numero'] as num).toInt();
        _raceStatus = (status['status'] ?? 'IDLE') as String;
        final remainingSale = status['remainingSaleSeconds'] as num?;
        final remainingVideo = status['remainingVideoSeconds'] as num?;
        _countdownSeconds = (remainingSale ?? remainingVideo ?? 0).toInt();

        final saleEndAtStr = currentRaceJson['saleEndAt'] as String?;
        if (saleEndAtStr != null) {
          _nextRaceStartEstimate = DateTime.parse(saleEndAtStr)
              .add(const Duration(seconds: _postSaleSeconds));
        }

        // X2: viene en el top-level del status, no dentro de currentRace
        final x2Dog = (status['x2Dog'] as num? ?? 0).toInt();
        if (x2Dog != _x2Dog) _x2Dog = x2Dog;

        final newRaceId = currentRaceJson['id'] as String?;
        if (newRaceId != _currentRaceId) {
          final hadPreviousRace = _currentRaceId != null;
          _currentRaceId = newRaceId;
          _x2Dog = 0; // reset X2 al cambiar de carrera
          if (hadPreviousRace) {
            unawaited(_refreshResultsHistory());
            unawaited(_refreshOddsHistory());
            unawaited(_refreshSalesHistory());
          }
          unawaited(_refreshLiveOdds());
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
      _isServerOnline = false;
      notifyListeners();
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
        odds['$betType:$selection'] = double.parse(row['currentOdds'].toString());
      }
      _liveOdds = odds;
      notifyListeners();
    } catch (_) {
      // Mantiene las cuotas anteriores si falla la actualización
    }
  }

  void selectDog1(int dogNumber) {
    if (_selectedDog1 == dogNumber) {
      _selectedDog1 = null;
    } else {
      _selectedDog1 = dogNumber;
      // If same dog selected in 2° or 3°, clear it from there
      if (_selectedDog2 == dogNumber) {
        _selectedDog2 = null;
      }
      if (_selectedDog3 == dogNumber) {
        _selectedDog3 = null;
      }
    }
    notifyListeners();
    if (_hasAnySelection && _currentBetAmount > 0) {
      addPlayToTicket();
    }
  }

  void selectDog2(int dogNumber) {
    if (_selectedDog2 == dogNumber) {
      _selectedDog2 = null;
    } else {
      _selectedDog2 = dogNumber;
      // If same dog selected in 1° o 3°, clear it from there
      if (_selectedDog1 == dogNumber) {
        _selectedDog1 = null;
      }
      if (_selectedDog3 == dogNumber) {
        _selectedDog3 = null;
      }
    }
    notifyListeners();
    if (_hasAnySelection && _currentBetAmount > 0) {
      addPlayToTicket();
    }
  }

  void selectDog3(int dogNumber) {
    if (_selectedDog3 == dogNumber) {
      _selectedDog3 = null;
    } else {
      _selectedDog3 = dogNumber;
      // If same dog selected in 1° o 2°, clear it from there
      if (_selectedDog1 == dogNumber) {
        _selectedDog1 = null;
      }
      if (_selectedDog2 == dogNumber) {
        _selectedDog2 = null;
      }
    }
    notifyListeners();
    if (_hasAnySelection && _currentBetAmount > 0) {
      addPlayToTicket();
    }
  }

  bool get _hasAnySelection =>
      _selectedDog1 != null || _selectedDog2 != null || _selectedDog3 != null;

  void addBetAmount(double amount) {
    // Sin selección activa + hay jugadas → sumar al último play del ticket
    if (!_hasAnySelection && _currentTicketPlays.isNotEmpty) {
      _addAmountToLastPlay(amount);
      return;
    }
    _currentBetAmount += amount;
    notifyListeners();
    if (_hasAnySelection && _currentBetAmount > 0) {
      addPlayToTicket();
    }
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

  // Cuota "EXACTA": usa la cuota real de la matriz si está disponible
  double getExactaOdds(int dog) {
    final other = dog % 6 + 1;
    final matrix = _liveOdds['EXACTA:$dog-$other'] ?? 0.0;
    return matrix > 0 ? matrix : getGanarOdds(dog) + getGanarOdds(other);
  }

  // Cuota exacta de un par específico (dog1 1°, dog2 2°)
  double getExactaOddsPair(int dog1, int dog2) =>
      _liveOdds['EXACTA:$dog1-$dog2'] ?? 0.0;

  // Cuota "TRIFECTA": usa la cuota real de la matriz si está disponible
  double getTrifectaOdds(int dog) {
    final next1 = dog % 6 + 1;
    final next2 = next1 % 6 + 1;
    final matrix = _liveOdds['TRIFECTA:$dog-$next1-$next2'] ?? 0.0;
    return matrix > 0 ? matrix : getGanarOdds(dog) + getGanarOdds(next1) + getGanarOdds(next2);
  }

  void _addCalculatedPlay(int dog1, int dog2, double amount) {
    // Usar cuota real de la matriz EXACTA; fallback a suma de winners si no hay
    final matrixOdds = _liveOdds['EXACTA:$dog1-$dog2'] ?? 0.0;
    final odds = matrixOdds > 0
        ? matrixOdds
        : getGanarOdds(dog1) + getGanarOdds(dog2);

    _currentTicketPlays.add(Bet(
      dog1: dog1,
      dog2: dog2,
      amount: amount,
      odds: odds,
    ));
  }

  void _addCalculatedTrifectaPlay(int dog1, int dog2, int dog3, double amount) {
    // Usar cuota real de la matriz TRIFECTA; fallback a suma de winners si no hay
    final matrixOdds = _liveOdds['TRIFECTA:$dog1-$dog2-$dog3'] ?? 0.0;
    final odds = matrixOdds > 0
        ? matrixOdds
        : getGanarOdds(dog1) + getGanarOdds(dog2) + getGanarOdds(dog3);

    _currentTicketPlays.add(Bet(
      dog1: dog1,
      dog2: dog2,
      dog3: dog3,
      amount: amount,
      odds: odds,
    ));
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
    _selectedDog1 = null;
    _selectedDog2 = null;
    _selectedDog3 = null;
    _currentBetAmount = 0.0;
  }

  // Jugada reversa: si hay 1° y 2° seleccionados, juega ambos sentidos (1/2 y 2/1)
  void playReverse() {
    if (_selectedDog1 == null || _selectedDog2 == null) return;
    final amount = _currentBetAmount > 0 ? _currentBetAmount : 25.0;
    _addCalculatedPlay(_selectedDog1!, _selectedDog2!, amount);
    _addCalculatedPlay(_selectedDog2!, _selectedDog1!, amount);
    _currentBetAmount = amount;
    _resetSelection();
    notifyListeners();
  }

  // Combina el perro seleccionado en 1° con todos los demás en 2°
  void playAllCombinations() {
    final dog = _selectedDog1 ?? _selectedDog2;
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
    final dog = _selectedDog1 ?? _selectedDog2;
    if (dog == null) return;
    _playCombinedR(dog, 25.0);
  }

  // Jugada R/2: igual que R pero cada pale vale $12.5 (total $175)
  void playR2() {
    final dog = _selectedDog1 ?? _selectedDog2;
    if (dog == null) return;
    _playCombinedR(dog, 12.5);
  }

  void _playCombinedR(int dog, double amountPerPlay) {
    for (int other = 1; other <= 6; other++) {
      if (other == dog) continue;
      _addCalculatedPlay(dog, other, amountPerPlay);
      _addCalculatedPlay(other, dog, amountPerPlay);
    }
    _resetSelection();
    notifyListeners();
  }

  void addPlayToTicket() {
    if (_currentBetAmount <= 0) return;
    if (_selectedDog1 != null && _selectedDog2 != null && _selectedDog3 != null) {
      _addCalculatedTrifectaPlay(_selectedDog1!, _selectedDog2!, _selectedDog3!, _currentBetAmount);
    } else if (_selectedDog1 != null && _selectedDog2 != null) {
      _addCalculatedPlay(_selectedDog1!, _selectedDog2!, _currentBetAmount);
    } else if (_selectedDog1 != null) {
      _addSinglePlay(_selectedDog1!, _currentBetAmount);
    } else if (_selectedDog2 != null) {
      _addSinglePlay(_selectedDog2!, _currentBetAmount);
    } else if (_selectedDog3 != null) {
      _addSinglePlay(_selectedDog3!, _currentBetAmount);
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
    _selectedDog1 = null;
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

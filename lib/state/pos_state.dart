import 'dart:async';
import 'package:flutter/material.dart';

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
    required this.dateTime,
    required this.plays,
    required this.amount,
    required this.investment,
    required this.pay,
    required this.balance,
    required this.game,
    required this.status,
  });
}

class RaceResult {
  final int raceNumber;
  final int winner1;
  final int winner2;
  final String bonus;

  RaceResult({
    required this.raceNumber,
    required this.winner1,
    required this.winner2,
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
  int _currentRace = 4226;
  int get currentRace => _currentRace;

  int _countdownSeconds = 300;
  int get countdownSeconds => _countdownSeconds;

  final String agencyId = 'a33698ac-4338-4ef0-9805-d8bbf07b15eb';
  final String currentUser = 'admin';
  final bool isServerOnline = true;

  String _selectedLanguage = 'Español';
  String get selectedLanguage => _selectedLanguage;

  String _selectedPrinter = 'Impresora predeterminada';
  String get selectedPrinter => _selectedPrinter;

  void setLanguage(String language) {
    _selectedLanguage = language;
    notifyListeners();
  }

  void setPrinter(String printer) {
    _selectedPrinter = printer;
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

  Timer? _timer;

  // Static Data lists
  final List<RaceResult> resultsHistory = [
    RaceResult(raceNumber: 4226, winner1: 6, winner2: 2, bonus: "x2"),
    RaceResult(raceNumber: 4225, winner1: 4, winner2: 6, bonus: ""),
    RaceResult(raceNumber: 4224, winner1: 6, winner2: 3, bonus: ""),
    RaceResult(raceNumber: 4223, winner1: 2, winner2: 1, bonus: ""),
    RaceResult(raceNumber: 4222, winner1: 6, winner2: 1, bonus: ""),
    RaceResult(raceNumber: 4221, winner1: 6, winner2: 4, bonus: ""),
    RaceResult(raceNumber: 4220, winner1: 3, winner2: 2, bonus: ""),
    RaceResult(raceNumber: 4219, winner1: 2, winner2: 1, bonus: "x2"),
    RaceResult(raceNumber: 4218, winner1: 6, winner2: 4, bonus: ""),
    RaceResult(raceNumber: 4217, winner1: 1, winner2: 2, bonus: ""),
    RaceResult(raceNumber: 4216, winner1: 6, winner2: 4, bonus: ""),
    RaceResult(raceNumber: 4215, winner1: 3, winner2: 2, bonus: ""),
    RaceResult(raceNumber: 4214, winner1: 1, winner2: 4, bonus: ""),
  ];

  final List<RaceOdds> oddsHistory = [
    RaceOdds(raceNumber: 4226, odds: [15.1, 3.8, 5.2, 7.3, 17.0, 9.1]),
    RaceOdds(raceNumber: 4225, odds: [11.2, 7.5, 6.2, 4.8, 13.8, 5.9]),
    RaceOdds(raceNumber: 4224, odds: [4.4, 11.3, 4.9, 16.4, 5.5, 8.4]),
    RaceOdds(raceNumber: 4223, odds: [5.5, 12.6, 9.9, 4.6, 7.5, 5.1]),
    RaceOdds(raceNumber: 4222, odds: [8.8, 7.0, 4.6, 14.0, 16.9, 5.8]),
    RaceOdds(raceNumber: 4221, odds: [4.9, 11.2, 16.5, 5.7, 4.6, 6.2]),
    RaceOdds(raceNumber: 4220, odds: [12.1, 8.1, 4.8, 4.5, 10.5, 6.2]),
    RaceOdds(raceNumber: 4219, odds: [2.6, 9.5, 17.0, 15.6, 13.0, 6.8]),
    RaceOdds(raceNumber: 4218, odds: [15.0, 7.8, 5.0, 6.3, 9.3, 4.1]),
    RaceOdds(raceNumber: 4217, odds: [4.9, 18.3, 6.1, 11.0, 9.0, 6.7]),
    RaceOdds(raceNumber: 4216, odds: [17.5, 5.6, 8.1, 11.1, 5.8, 4.9]),
    RaceOdds(raceNumber: 4215, odds: [10.4, 7.0, 13.4, 5.0, 18.2, 5.2]),
    RaceOdds(raceNumber: 4214, odds: [5.3, 15.5, 6.3, 8.5, 10.9, 17.8]),
  ];

  PosState() {
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        _countdownSeconds--;
        notifyListeners();
      } else {
        // Reset countdown to 300 and advance race
        _countdownSeconds = 300;
        _currentRace++;
        notifyListeners();
      }
    });
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
    _currentBetAmount += amount;
    notifyListeners();
    if (_hasAnySelection && _currentBetAmount > 0) {
      addPlayToTicket();
    }
  }

  void clearBetAmount() {
    _currentBetAmount = 0.0;
    notifyListeners();
  }

  RaceOdds get _currentOdds => oddsHistory.firstWhere(
        (o) => o.raceNumber == _currentRace,
        orElse: () => oddsHistory.first,
      );

  // Cuota "GANAR": cuota del perro solo
  double getGanarOdds(int dog) {
    final o = _currentOdds.odds[dog - 1];
    return double.parse(o.clamp(1.5, 99.9).toStringAsFixed(2));
  }

  // Cuota "EXACTA": cuota del palé combinado con el siguiente perro
  double getExactaOdds(int dog) {
    final other = dog % 6 + 1;
    final o1 = _currentOdds.odds[dog - 1];
    final o2 = _currentOdds.odds[other - 1];
    return double.parse((o1 * o2 * 0.4).clamp(1.5, 99.9).toStringAsFixed(2));
  }

  // Cuota "TRIFECTA": cuota del trío combinado con los dos siguientes perros
  double getTrifectaOdds(int dog) {
    final next1 = dog % 6 + 1;
    final next2 = next1 % 6 + 1;
    final o1 = _currentOdds.odds[dog - 1];
    final o2 = _currentOdds.odds[next1 - 1];
    final o3 = _currentOdds.odds[next2 - 1];
    return double.parse((o1 * o2 * o3 * 0.05).clamp(1.5, 99.9).toStringAsFixed(2));
  }

  void _addCalculatedPlay(int dog1, int dog2, double amount) {
    final o1 = _currentOdds.odds[dog1 - 1];
    final o2 = _currentOdds.odds[dog2 - 1];
    // Product of individual odds times a multiplier, clamped for realism
    final calculatedOdds = double.parse((o1 * o2 * 0.4).clamp(1.5, 99.9).toStringAsFixed(1));

    _currentTicketPlays.add(Bet(
      dog1: dog1,
      dog2: dog2,
      amount: amount,
      odds: calculatedOdds,
    ));
  }

  void _addCalculatedTrifectaPlay(int dog1, int dog2, int dog3, double amount) {
    final o1 = _currentOdds.odds[dog1 - 1];
    final o2 = _currentOdds.odds[dog2 - 1];
    final o3 = _currentOdds.odds[dog3 - 1];
    final calculatedOdds = double.parse((o1 * o2 * o3 * 0.05).clamp(1.5, 99.9).toStringAsFixed(1));

    _currentTicketPlays.add(Bet(
      dog1: dog1,
      dog2: dog2,
      dog3: dog3,
      amount: amount,
      odds: calculatedOdds,
    ));
  }

  void _addSinglePlay(int dog, double amount) {
    final o = _currentOdds.odds[dog - 1];
    final calculatedOdds = double.parse(o.clamp(1.5, 99.9).toStringAsFixed(1));

    _currentTicketPlays.add(Bet(
      dog1: dog,
      dog2: null,
      amount: amount,
      odds: calculatedOdds,
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
    if (_selectedDog1 != null && _selectedDog2 != null && _currentBetAmount > 0) {
      _addCalculatedPlay(_selectedDog1!, _selectedDog2!, _currentBetAmount);
      _addCalculatedPlay(_selectedDog2!, _selectedDog1!, _currentBetAmount);
      _resetSelection();
      notifyListeners();
    }
  }

  // Combina el perro seleccionado en 1° con todos los demás en 2°
  void playAllCombinations() {
    final dog = _selectedDog1 ?? _selectedDog2;
    if (dog == null || _currentBetAmount <= 0) return;

    for (int other = 1; other <= 6; other++) {
      if (other == dog) continue;
      _addCalculatedPlay(dog, other, _currentBetAmount);
    }
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

  // Busca un ticket por su ID ("T-1000") o por su número (1000)
  Ticket? findTicketByNumber(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    for (final ticket in _salesHistory) {
      if (ticket.id.toUpperCase() == trimmed.toUpperCase() ||
          ticket.ticketNumber.toString() == trimmed) {
        return ticket;
      }
    }
    return null;
  }

  // Recarga las jugadas de un ticket (perros, monto y cuotas) al ticket actual
  void repeatTicket(Ticket ticket) {
    for (final play in ticket.plays) {
      _currentTicketPlays.add(Bet(
        dog1: play.dog1,
        dog2: play.dog2,
        dog3: play.dog3,
        amount: play.amount,
        odds: play.odds,
      ));
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

  void printTicket() {
    if (_currentTicketPlays.isEmpty &&
        _hasAnySelection &&
        _currentBetAmount > 0) {
      addPlayToTicket();
    }

    if (_currentTicketPlays.isNotEmpty) {
      final now = DateTime.now();
      final dateStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} "
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      
      double totalAmount = 0;
      for (var play in _currentTicketPlays) {
        totalAmount += play.amount;
      }

      final int ticketNum = 1000 + _salesHistory.length;

      final ticket = Ticket(
        id: "T-$ticketNum",
        ticketNumber: ticketNum,
        dateTime: dateStr,
        plays: List.from(_currentTicketPlays),
        amount: totalAmount,
        investment: totalAmount,
        pay: 0.0,
        balance: -totalAmount,
        game: "Racing Dogs",
        status: TicketStatus.approved,
      );

      _salesHistory.insert(0, ticket);
      _currentTicketPlays.clear();
      notifyListeners();
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

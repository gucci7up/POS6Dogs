import 'package:flutter/material.dart';

class RaceInfoPanel extends StatelessWidget {
  final int raceNumber;
  final int countdownSeconds;
  final String nextRaceStartLabel;
  final String raceStatusLabel;
  final int x2Dog;
  final double jackpotAmount;

  const RaceInfoPanel({
    super.key,
    required this.raceNumber,
    required this.countdownSeconds,
    required this.nextRaceStartLabel,
    required this.raceStatusLabel,
    this.x2Dog = 0,
    this.jackpotAmount = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = (countdownSeconds / 300.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Carrera Info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CARRERA',
                style: TextStyle(
                  fontFamily: 'DinNextLtPro',
                  color: Color(0xFF9E9E9E),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$raceNumber',
                style: const TextStyle(
                  fontFamily: 'DinNextLtPro',
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(width: 45),

          // Empieza Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'EMPIEZA',
                style: TextStyle(
                  fontFamily: 'DinNextLtPro',
                  color: Color(0xFF9E9E9E),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                nextRaceStartLabel,
                style: const TextStyle(
                  fontFamily: 'DinNextLtPro',
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(width: 35),

          // Activo / Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ACTIVO',
                style: TextStyle(
                  fontFamily: 'DinNextLtPro',
                  color: Color(0xFFB0A261),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                raceStatusLabel,
                style: const TextStyle(
                  fontFamily: 'DinNextLtPro',
                  color: Color(0xFFD4AF37),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(width: 45),

          // Countdown Timer
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/resources/reloj_icon.png',
                width: 22,
                height: 22,
                color: Colors.white70,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SEG',
                    style: TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: Color(0xFF9E9E9E),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$countdownSeconds',
                    style: const TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 15),

          // Red Progress Bar
          Container(
            width: 200,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD32F2F).withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),

          // Jackpot counter
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'JACKPOT',
                style: TextStyle(
                  fontFamily: 'DinNextLtPro',
                  color: Color(0xFFB0A261),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '\$${jackpotAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'DinNextLtPro',
                  color: Color(0xFFD4AF37),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // X2 badge — solo visible cuando la carrera está cerrada/corriendo
          if (x2Dog > 0) ...[
            const SizedBox(width: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFFFF6B35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'X2',
                    style: TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Perro $x2Dog',
                    style: const TextStyle(
                      fontFamily: 'DinNextLtPro',
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

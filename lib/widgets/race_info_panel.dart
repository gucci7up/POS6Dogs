import 'package:flutter/material.dart';

class RaceInfoPanel extends StatelessWidget {
  final int raceNumber;
  final int countdownSeconds;

  const RaceInfoPanel({
    super.key,
    required this.raceNumber,
    required this.countdownSeconds,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate progress fraction for the red countdown bar
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
                  color: Color(0xFF9E9E9E), // Gray text
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
                _getEmpiezaTime(raceNumber),
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

          // Activo Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ACTIVO',
                style: TextStyle(
                  fontFamily: 'DinNextLtPro',
                  color: Color(0xFFB0A261), // Gold color
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '12:00:00',
                style: TextStyle(
                  fontFamily: 'DinNextLtPro',
                  color: Color(0xFFD4AF37), // Gold text
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

          // Red Progress Bar container
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
                      color: const Color(0xFFD32F2F), // Bright Red
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD32F2F).withOpacity(0.5),
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
        ],
      ),
    );
  }

  // Dynamic start time based on race number (e.g. 4226 -> 12:05:00)
  String _getEmpiezaTime(int raceNum) {
    final baseMinutes = (raceNum - 4226) * 5 + 5;
    final hours = 12 + (baseMinutes ~/ 60);
    final minutes = baseMinutes % 60;
    
    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    return "$hStr:$mStr:00";
  }
}

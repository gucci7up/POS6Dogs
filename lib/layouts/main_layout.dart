import 'package:flutter/material.dart';
import 'package:pos/layouts/desktop_layout.dart';
import 'package:pos/widgets/race_info_panel.dart';
import 'package:pos/widgets/right_panel.dart';
import 'package:pos/widgets/top_navigation.dart';
import 'package:pos/state/pos_state.dart';

class MainLayout extends StatelessWidget {
  final int currentTabIndex;
  final ValueChanged<int> onTabChanged;
  final PosState state;
  final Widget child;

  const MainLayout({
    super.key,
    required this.currentTabIndex,
    required this.onTabChanged,
    required this.state,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.black,
          image: DecorationImage(
            image: AssetImage('assets/resources/background.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Tabs in center, Right Panel on right
                  Row(
                    children: [
                      // Logo
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Image.asset(
                              'assets/resources/logo_principal.png',
                              height: 90,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      // Top Tabs
                      TopNavigation(
                        currentIndex: currentTabIndex,
                        onTabChanged: onTabChanged,
                      ),
                      const Expanded(child: SizedBox(height: 90)),
                      // Right Panel (Settings)
                      RightPanel(state: state),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Row 2: Race info on the left
                  Row(
                    children: [
                      RaceInfoPanel(
                        raceNumber: state.currentRace,
                        countdownSeconds: state.countdownSeconds,
                      ),
                      const Spacer(),
                    ],
                  ),
                ],
              ),
            ),
            
            // Screen Content Area
            Expanded(
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

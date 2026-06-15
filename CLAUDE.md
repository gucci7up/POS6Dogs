# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A Flutter desktop POS ("point of sale") app for a greyhound racing betting kiosk ("Racing Dogs"), branded in Spanish. Targets Windows/Linux/macOS desktop (and web) with a fixed 1920x1080 design canvas that is scaled to fit the window.

## Common commands

- Run the app: `flutter run -d windows` (or `-d chrome`, `-d linux`, etc.)
- Install dependencies: `flutter pub get`
- Static analysis/lint: `flutter analyze`
- Run all tests: `flutter test`
- Run a single test file: `flutter test test/widget_test.dart`

## Architecture

### State management
All app state lives in a single `ChangeNotifier`: `lib/state/pos_state.dart` (`PosState`). It is instantiated once in `main.dart`'s `_MainScreenState` and passed down to every screen/widget that needs it. Screens wrap themselves in `ListenableBuilder`/`addListener` to rebuild on state changes — there is no provider/bloc/riverpod, just plain `ChangeNotifier` + manual listeners.

`PosState` owns:
- The current race number and a 1-second countdown `Timer` that auto-advances the race when it hits zero.
- Dog selections (`selectedDog1`/`selectedDog2`, for 1st/2nd place picks) and the current bet amount.
- The in-progress ticket (`currentTicketPlays`, a list of `Bet`), auto-added when both dogs + an amount are selected.
- Sales history (`salesHistory`, a list of `Ticket`), appended when `printTicket()` is called.
- Static mock data: `resultsHistory` (past race results) and `oddsHistory` (per-race odds per dog, used to compute combination odds via `addPlayToTicket`).

There is no persistence or backend — all data is in-memory and resets on restart.

### Navigation / layout
- `main.dart` defines `MainScreen`, which holds `_currentTabIndex` and switches between the four screens in `lib/screens/`: Jugada (betting), Resultados (results), Cuotas (odds), Ventas (sales).
- `lib/layouts/main_layout.dart` (`MainLayout`) wraps the active screen with the shared header: `TopNavigation` (tab switcher), `RightPanel` (logo/settings), and `RaceInfoPanel` (race number + countdown), all driven by `PosState`.
- `lib/layouts/desktop_layout.dart` (`DesktopLayout`) is the outermost shell: it fixes the design at exactly 1920x1080 and uses `FittedBox` to scale/center it for any window size, and disables scrollbars. Any new screen content should be designed against this 1920x1080 canvas.

### Screens & widgets
- `lib/screens/jugada_screen.dart` is the main betting screen: dog selection grids for 1st/2nd place (`DogButton`), quick-amount buttons (`AmountButton`), action buttons (swap/random selection, `ActionButton`), and a slide-out ticket drawer showing `currentTicketPlays` with per-row delete and a print/delete-ticket action bar.
- `lib/widgets/` contains the small reusable pieces (`dog_button.dart`, `amount_button.dart`, `action_button.dart`, `race_info_panel.dart`, `right_panel.dart`, `top_navigation.dart`).
- UI is heavily asset/image-driven — most buttons render PNGs from `assets/resources/` (e.g. `botonnumero{N}.png` for dog number tiles, `botondelete*.png`, `botonprinter*.png`) rather than drawing custom shapes, including hover-state image swaps via `MouseRegion`.
- Theme: dark background, gold (`0xFFD4AF37`) primary / dark green secondary accents, custom font family `DinNextLtPro` (assets/fonts).

### Windowing
On desktop platforms (`main.dart`), `window_manager` is used to create a borderless (`TitleBarStyle.hidden`), maximized 1920x1080-minimum window — reinforcing the fixed-canvas design assumption above.

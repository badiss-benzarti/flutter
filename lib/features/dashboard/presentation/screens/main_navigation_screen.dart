import 'package:barber_shop_owner/core/sync/sync_controller.dart';
import 'package:barber_shop_owner/features/barbers/presentation/screens/barbers_screen.dart';
import 'package:barber_shop_owner/features/clients/presentation/screens/clients_screen.dart';
import 'package:barber_shop_owner/features/finance/presentation/screens/finance_screen.dart';
import 'package:barber_shop_owner/features/floor_plan/presentation/screens/floor_plan_screen.dart';
import 'package:barber_shop_owner/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  static const _floorIndex = 2;

  int _currentIndex = _floorIndex;

  static const List<Widget> _screens = [
    SettingsScreen(),
    FinanceScreen(),
    FloorPlanScreen(),
    BarbersScreen(),
    ClientsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Keeps cloud sync running while the salon is open.
    ref.watch(syncControllerProvider.select((s) => s.enabled));
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _RoomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

/// Rounded, outlined tab bar with the room (floor plan) as the center
/// home button.
class _RoomNavigationBar extends StatelessWidget {
  const _RoomNavigationBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _ink = Color(0xFF111111);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: _ink, width: 2),
          left: BorderSide(color: _ink, width: 2),
          right: BorderSide(color: _ink, width: 2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _item(0, Icons.settings_outlined, Icons.settings, 'Settings'),
              _item(
                1,
                Icons.monetization_on_outlined,
                Icons.monetization_on,
                'Finance',
              ),
              Expanded(child: _homeButton()),
              _item(3, Icons.groups_outlined, Icons.groups, 'Team'),
              _item(4, Icons.badge_outlined, Icons.badge, 'Clients'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int index, IconData icon, IconData activeIcon, String label) {
    final selected = currentIndex == index;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkResponse(
          onTap: () => onTap(index),
          radius: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  size: 28,
                  color: selected ? _ink : const Color(0xFF6B7280),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? _ink : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _homeButton() {
    final selected = currentIndex == _MainNavigationScreenState._floorIndex;
    return Semantics(
      selected: selected,
      button: true,
      label: 'Shop floor',
      child: GestureDetector(
        onTap: () => onTap(_MainNavigationScreenState._floorIndex),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: selected ? _ink : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _ink, width: 2),
              ),
              child: Icon(
                Icons.chair_outlined,
                color: selected ? Colors.white : _ink,
                size: 26,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Floor',
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

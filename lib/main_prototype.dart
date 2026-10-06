import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/floor_plan/presentation/widgets/room/salon_sign.dart';
import 'prototype/barber/barber_shell.dart';
import 'prototype/client/client_shell.dart';
import 'prototype/widgets/ui.dart';

/// Clickable prototype of the client and barber sides (roadmap step 0.3).
/// Runs on sample data only:
///   flutter run -t lib/main_prototype.dart
void main() {
  runApp(
    MaterialApp(
      title: 'Barber platform prototype',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _RolePicker(),
    ),
  );
}

class _RolePicker extends StatelessWidget {
  const _RolePicker();

  @override
  Widget build(BuildContext context) {
    void open(Widget screen) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => screen));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const SalonSign(name: 'Tunis Barbers'),
                const SizedBox(height: 24),
                const Text(
                  'Who are you?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Prototype with sample data. Nothing is saved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 24),
                _RoleCard(
                  icon: Icons.person_search_outlined,
                  title: "I'm a client",
                  subtitle:
                      'Find a salon on the map, see it live, book or go VIP',
                  onTap: () => open(const ClientShell()),
                ),
                const SizedBox(height: 12),
                _RoleCard(
                  icon: Icons.content_cut,
                  title: "I'm a barber",
                  subtitle: 'My requests, my earnings, my portfolio (as Sami)',
                  onTap: () => open(const BarberShell()),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tip: send a VIP offer at Blade & Crown as a client, then switch '
                  'to the barber side to accept it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: ink,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: muted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

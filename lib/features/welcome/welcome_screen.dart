import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prototype/barber/barber_shell.dart';
import '../../prototype/client/client_shell.dart';
import '../floor_plan/presentation/widgets/room/salon_sign.dart';
import 'entry_role.dart';

/// First screen of the app when nobody is signed in: "Who are you?".
///
/// Owners continue to sign-in. The barber and client sides open as previews
/// on sample data until they are connected to the server (roadmap phases 2
/// and 3).
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  static const appName = 'BarberFlow';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void preview(Widget screen) =>
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
                const SalonSign(name: appName),
                const SizedBox(height: 24),
                const Text(
                  'Who are you?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose your space. You can change it before signing in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 24),
                _RoleCard(
                  icon: Icons.storefront_outlined,
                  title: 'Salon owner',
                  subtitle: 'Run your floor, team, clients and finances',
                  onTap: () => ref
                      .read(entryRoleProvider.notifier)
                      .choose(EntryRole.owner),
                ),
                const SizedBox(height: 12),
                _RoleCard(
                  icon: Icons.content_cut,
                  title: 'Barber',
                  subtitle: 'Your agenda, your earnings, your portfolio',
                  preview: true,
                  onTap: () => preview(const BarberShell()),
                ),
                const SizedBox(height: 12),
                _RoleCard(
                  icon: Icons.person_search_outlined,
                  title: 'Client',
                  subtitle: 'Find a salon, see it live, book or go VIP',
                  preview: true,
                  onTap: () => preview(const ClientShell()),
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
    this.preview = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Not connected to the server yet: runs on sample data.
  final bool preview;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF111111),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (preview) ...[
                          const SizedBox(width: 8),
                          const _PreviewBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'PREVIEW',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          color: Color(0xFF92400E),
        ),
      ),
    );
  }
}

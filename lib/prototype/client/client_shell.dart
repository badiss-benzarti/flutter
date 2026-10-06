import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../mock_data.dart';
import '../widgets/ui.dart';
import 'salon_map_screen.dart';
import 'salon_page.dart';

/// Client side of the app: map, bookings, social feed and profile.
class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SafeArea(bottom: false, child: PrototypeBanner()),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [
                SalonMapScreen(),
                _BookingsScreen(),
                _SocialScreen(),
                _ProfileScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFF3E7C0),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'Social',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _BookingsScreen extends StatelessWidget {
  const _BookingsScreen();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<MockBooking>>(
      valueListenable: bookings,
      builder: (context, all, _) {
        final mine = all.where((b) => b.client == 'You').toList();
        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: AppBar(
            title: const Text('My bookings'),
            backgroundColor: Colors.white,
          ),
          body: mine.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No bookings yet.\nFind a salon on the map to join a queue, book or go VIP.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [for (final b in mine) BookingCard(booking: b)],
                ),
        );
      },
    );
  }
}

/// A booking as seen by its client (or, with [forBarber], by the barber).
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    this.forBarber = false,
    this.actions,
  });

  final MockBooking booking;
  final bool forBarber;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final (icon, kindLabel, kindColor) = switch (b.kind) {
      BookingKind.queue => (
        Icons.event_seat_outlined,
        'Queue',
        const Color(0xFF2563EB),
      ),
      BookingKind.appointment => (
        Icons.calendar_month_outlined,
        'Appointment',
        ink,
      ),
      BookingKind.priority => (Icons.verified_outlined, 'VIP pass', gold),
      BookingKind.offer => (Icons.local_offer_outlined, 'VIP offer', gold),
    };
    final (statusText, statusColor) = switch (b.status) {
      BookingStatus.pending => ('Waiting for answer', const Color(0xFFF59E0B)),
      BookingStatus.accepted => ('Confirmed', const Color(0xFF10B981)),
      BookingStatus.declined => ('Declined', const Color(0xFFEF4444)),
    };
    final today = DateTime.now();
    final sameDay = b.when.day == today.day && b.when.month == today.month;
    final when = sameDay
        ? 'Today ${DateFormat('HH:mm').format(b.when)}'
        : DateFormat('EEE d MMM · HH:mm').format(b.when);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: kindColor),
                const SizedBox(width: 8),
                Text(
                  kindLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: kindColor,
                  ),
                ),
                const Spacer(),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              forBarber ? b.client : b.salon,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            Text(
              [
                when,
                if (b.service != null) b.service!.name,
                if (!forBarber && b.barber != null) 'with ${b.barber}',
              ].join(' · '),
              style: const TextStyle(color: muted),
            ),
            if (b.price != null) ...[
              const SizedBox(height: 4),
              Text(
                dt(b.price!),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
            if (actions != null) ...[const SizedBox(height: 10), actions!],
          ],
        ),
      ),
    );
  }
}

class _SocialScreen extends StatelessWidget {
  const _SocialScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Fresh cuts in Tunis'),
        backgroundColor: Colors.white,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.82,
        ),
        itemCount: photos.length,
        itemBuilder: (context, i) {
          final p = photos[i];
          final salon = salons.firstWhere((s) => s.name == p.salon);
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => SalonPage(salon: salon)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: PhotoTile(photo: p)),
                const SizedBox(height: 4),
                Text(
                  p.salon,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const InkCard(
            child: Row(
              children: [
                Avatar('Y', radius: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yassine J.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text('Client since 2026', style: TextStyle(color: muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Favorite barbers'),
          Wrap(
            spacing: 10,
            children: [
              for (final name in ['Sami', 'Walid', 'Malek'])
                Chip(avatar: Avatar(name, radius: 10), label: Text(name)),
            ],
          ),
          const SectionTitle('Reliability'),
          const InkCard(
            child: Text(
              '0 missed appointments. After 2 no-shows, booking is paused for 7 days.',
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Switch role (prototype)'),
          ),
        ],
      ),
    );
  }
}

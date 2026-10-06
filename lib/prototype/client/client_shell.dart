import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/ui/dashboard_widgets.dart';
import '../../core/ui/room_navigation_bar.dart';
import '../../features/floor_plan/domain/station.dart';
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
  static const _mapIndex = 2;

  int _tab = _mapIndex;

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
                _ProfileScreen(),
                _BookingsScreen(),
                SalonMapScreen(),
                _SocialScreen(),
                _FavoritesScreen(),
              ],
            ),
          ),
        ],
      ),
      // Same bar as the owner app, with the map as the home button.
      bottomNavigationBar: RoomNavigationBar(
        items: const [
          RoomNavItem(Icons.person_outline, Icons.person, 'Profile'),
          RoomNavItem(Icons.event_note_outlined, Icons.event_note, 'Bookings'),
          RoomNavItem(Icons.map_outlined, Icons.map, 'Map'),
          RoomNavItem(
            Icons.photo_library_outlined,
            Icons.photo_library,
            'Social',
          ),
          RoomNavItem(Icons.favorite_border, Icons.favorite, 'Favorites'),
        ],
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
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
          appBar: AppBar(title: const Text('My bookings')),
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

/// Fresh cuts from the city's barbers, with a search to find a barber and
/// see them live in their salon.
class _SocialScreen extends StatefulWidget {
  const _SocialScreen();

  @override
  State<_SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<_SocialScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<(MockBarber, MockSalon)> get _matches {
    final q = _query.trim().toLowerCase();
    return [
      for (final salon in salons)
        for (final barber in salon.barbers)
          if ([
            barber.name,
            barber.specialty,
            salon.name,
            salon.area,
          ].any((field) => field.toLowerCase().contains(q)))
            (barber, salon),
    ];
  }

  void _openLive(MockSalon salon, String barber) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalonPage(salon: salon, highlightBarber: barber),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fresh cuts in Tunis')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search a barber, a style or a salon',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
          ),
          Expanded(child: _query.trim().isEmpty ? _feed() : _barberResults()),
        ],
      ),
    );
  }

  Widget _feed() {
    return GridView.builder(
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
          onTap: () => _openLive(salon, p.barber),
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
    );
  }

  Widget _barberResults() {
    final matches = _matches;
    if (matches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: EmptyBox('No barber matches your search.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle(
          matches.length == 1 ? '1 barber' : '${matches.length} barbers',
        ),
        for (final (barber, salon) in matches) _resultCard(barber, salon),
      ],
    );
  }

  Widget _resultCard(MockBarber barber, MockSalon salon) {
    final station = salon.stations
        .where((s) => s.activeBarberName == barber.name)
        .firstOrNull;
    final (where, color) = !salon.open || !barber.onDuty
        ? ('Not working now', muted)
        : station == null
        ? ('In the salon', const Color(0xFF10B981))
        : station.status == ChairStatus.occupied
        ? ('Busy at chair #${station.chairNumber}', const Color(0xFFF59E0B))
        : ('Free at chair #${station.chairNumber}', const Color(0xFF10B981));
    final cuts = photos.where((p) => p.barber == barber.name).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _openLive(salon, barber.name),
        leading: Avatar(barber.name, dimmed: !barber.onDuty),
        title: _highlighted(barber.name),
        subtitle: Text(
          '${barber.specialty} · ${salon.name}'
          '${cuts == 0 ? '' : ' · $cuts cut${cuts == 1 ? '' : 's'}'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Stars(barber.rating, size: 12),
            const SizedBox(height: 2),
            Text(
              where,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The barber's name with the searched letters marked in gold.
  Widget _highlighted(String name) {
    const base = TextStyle(
      fontWeight: FontWeight.bold,
      color: ink,
      fontSize: 16,
    );
    final q = _query.trim().toLowerCase();
    final at = name.toLowerCase().indexOf(q);
    if (q.isEmpty || at < 0) return Text(name, style: base);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: name.substring(0, at)),
          TextSpan(
            text: name.substring(at, at + q.length),
            style: const TextStyle(backgroundColor: Color(0xFFDCFCE7)),
          ),
          TextSpan(text: name.substring(at + q.length)),
        ],
      ),
    );
  }
}

/// Laid out like the owner's Settings: identity, then grouped cards.
class _ProfileScreen extends StatefulWidget {
  const _ProfileScreen();

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  bool _turnAlerts = true;
  bool _offers = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Avatar('Y', radius: 26),
              title: Text(
                'Yassine J.',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
              subtitle: Text('Client since 2026 · +216 20 123 456'),
              trailing: Icon(Icons.edit_outlined),
            ),
          ),
          const SectionTitle('Notifications'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('My turn is coming'),
                  subtitle: const Text('When 2 clients are left before you'),
                  value: _turnAlerts,
                  onChanged: (v) => setState(() => _turnAlerts = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Offers from my salons'),
                  value: _offers,
                  onChanged: (v) => setState(() => _offers = v),
                ),
              ],
            ),
          ),
          const SectionTitle('Reliability'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.verified_outlined, color: Color(0xFF10B981)),
              title: Text(
                '0 missed appointments',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('After 2 no-shows, booking is paused for 7 days.'),
            ),
          ),
          const SectionTitle('Account'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.language),
                  title: Text('Language'),
                  trailing: Text('Français'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: const Text('Switch role (prototype)'),
                  onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Salons and barbers the client follows.
class _FavoritesScreen extends StatelessWidget {
  const _FavoritesScreen();

  static const _salonIds = ['blade', 'lac'];
  static const _barbers = [
    ('Sami', 'blade'),
    ('Walid', 'lac'),
    ('Malek', 'ennasr'),
  ];

  @override
  Widget build(BuildContext context) {
    void openSalon(MockSalon salon) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => SalonPage(salon: salon)));
    MockSalon salonById(String id) => salons.firstWhere((s) => s.id == id);

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('Salons'),
          for (final id in _salonIds)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => openSalon(salonById(id)),
                leading: const CircleAvatar(
                  backgroundColor: ink,
                  child: Icon(Icons.storefront_outlined, color: Colors.white),
                ),
                title: Text(
                  salonById(id).name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [StatusPill(salonById(id))]),
                ),
                trailing: Stars(salonById(id).rating),
              ),
            ),
          const SectionTitle('Barbers'),
          Card(
            child: Column(
              children: [
                for (final (name, salonId) in _barbers)
                  ListTile(
                    onTap: () => openSalon(salonById(salonId)),
                    leading: Avatar(name),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(salonById(salonId).name),
                    trailing: const Icon(Icons.chevron_right),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

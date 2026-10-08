import 'package:flutter/material.dart';

import '../../core/ui/dashboard_widgets.dart';
import '../../core/ui/room_navigation_bar.dart';
import '../../features/finance/domain/service_ticket.dart';
import '../../features/finance/presentation/screens/finance_screen.dart'
    show paymentStyle;
import '../../features/floor_plan/presentation/widgets/room/room_view.dart';
import '../client/client_shell.dart';
import '../client/salon_page.dart';
import '../mock_data.dart';
import '../widgets/ui.dart';

/// Barber side of the app, signed in as Sami from Blade & Crown. Same layout
/// as the owner app, with the salon floor as the home tab.
class BarberShell extends StatefulWidget {
  const BarberShell({super.key});

  static const me = 'Sami';

  @override
  State<BarberShell> createState() => _BarberShellState();
}

class _BarberShellState extends State<BarberShell> {
  static const _salonIndex = 2;

  int _tab = _salonIndex;

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
                _EarningsScreen(),
                _SalonFloorScreen(),
                _TodayScreen(),
                _PortfolioScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: RoomNavigationBar(
        items: const [
          RoomNavItem(Icons.person_outline, Icons.person, 'Profile'),
          RoomNavItem(
            Icons.account_balance_wallet_outlined,
            Icons.account_balance_wallet,
            'Earnings',
          ),
          RoomNavItem(Icons.chair_outlined, Icons.chair_outlined, 'Salon'),
          RoomNavItem(Icons.today_outlined, Icons.today, 'Agenda'),
          RoomNavItem(
            Icons.photo_camera_outlined,
            Icons.photo_camera,
            'Portfolio',
          ),
        ],
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

MockSalon get _mySalon => salons.firstWhere((s) => s.id == 'blade');

// -----------------------------------------------------------------------------
// Salon: the live floor, as on the owner's home tab
// -----------------------------------------------------------------------------

class _SalonFloorScreen extends StatelessWidget {
  const _SalonFloorScreen();

  @override
  Widget build(BuildContext context) {
    final salon = _mySalon;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: RoomView(
          shopName: salon.name,
          established: 2026,
          stations: salon.stations,
          totalChairs: salon.chairs,
          waitingCount: salon.waiting,
          // Barbers don't assign chairs: free ones read "Free chair".
          anonymizeClients: true,
          reserveLabel: 'ADD A WALK-IN',
          onReserveTap: () =>
              showDone(context, 'Walk-in added to the waiting list.'),
          onQueueViewTap: () =>
              showDone(context, '${salon.waiting} clients are waiting.'),
          onStationTap: (s) {
            final barber = s.activeBarberName;
            showDone(
              context,
              barber == BarberShell.me
                  ? 'Your chair #${s.chairNumber}.'
                  : barber == null
                  ? 'Chair #${s.chairNumber} is free.'
                  : 'Chair #${s.chairNumber} · $barber.',
            );
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Profile, laid out like the owner's Settings
// -----------------------------------------------------------------------------

class _ProfileScreen extends StatefulWidget {
  const _ProfileScreen();

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  bool _newRequests = true;
  bool _vipOffers = true;

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
              leading: Avatar(BarberShell.me, radius: 26),
              title: Text(
                BarberShell.me,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
              subtitle: Text('Skin fades · ★ 4.9 · 214 reviews'),
              trailing: Icon(Icons.edit_outlined),
            ),
          ),
          const SectionTitle('My salon'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(
                    _mySalon.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Chair #1 · Commission 60%'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SalonPage(salon: _mySalon),
                    ),
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.schedule),
                  title: Text('Working hours'),
                  trailing: Text('Tue–Sun · 9:00–20:00'),
                ),
              ],
            ),
          ),
          const SectionTitle('Notifications'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('New booking requests'),
                  value: _newRequests,
                  onChanged: (v) => setState(() => _newRequests = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('VIP offers'),
                  subtitle: const Text('They expire after 5 minutes'),
                  value: _vipOffers,
                  onChanged: (v) => setState(() => _vipOffers = v),
                ),
              ],
            ),
          ),
          const SectionTitle('Account'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Change space'),
              onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Agenda: duty, requests and next clients
// -----------------------------------------------------------------------------

class _TodayScreen extends StatefulWidget {
  const _TodayScreen();

  @override
  State<_TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<_TodayScreen> {
  bool _onDuty = true;

  void _answer(MockBooking b, bool accept) {
    b.status = accept ? BookingStatus.accepted : BookingStatus.declined;
    bookings.value = [...bookings.value];
    showDone(
      context,
      accept
          ? '${b.client} confirmed${b.price != null ? ' · ${dt(b.price!)}' : ''}.'
          : 'Declined. ${b.client} is notified.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text('Hi Sami', style: TextStyle(fontWeight: FontWeight.w900)),
            Text(
              'Blade & Crown · Chair #1',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
      ),
      body: ValueListenableBuilder<List<MockBooking>>(
        valueListenable: bookings,
        builder: (context, all, _) {
          final mine = all
              .where(
                (b) => b.barber == BarberShell.me && b.salon == 'Blade & Crown',
              )
              .toList();
          final requests = mine
              .where((b) => b.status == BookingStatus.pending)
              .toList();
          final upcoming =
              mine.where((b) => b.status == BookingStatus.accepted).toList()
                ..sort((a, b) => a.when.compareTo(b.when));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              InkCard(
                color: _onDuty ? const Color(0xFFECFDF5) : Colors.white,
                child: Row(
                  children: [
                    Icon(
                      _onDuty ? Icons.check_circle : Icons.pause_circle_outline,
                      color: _onDuty ? const Color(0xFF10B981) : muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _onDuty
                            ? 'On duty · clients can book you'
                            : 'Off duty · hidden from bookings',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Switch(
                      value: _onDuty,
                      onChanged: (v) => setState(() => _onDuty = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const InkCard(
                child: Row(
                  children: [
                    _Kpi('6', 'clients today'),
                    _Kpi('3', 'in queue'),
                    _Kpi('128 DT', 'earned today'),
                  ],
                ),
              ),
              SectionTitle('Requests (${requests.length})'),
              if (requests.isEmpty)
                const Text(
                  'No pending requests.',
                  style: TextStyle(color: muted),
                )
              else
                for (final b in requests)
                  BookingCard(
                    booking: b,
                    forBarber: true,
                    actions: Row(
                      children: [
                        if (b.kind == BookingKind.offer)
                          const Expanded(
                            child: Text(
                              'Expires in 4:32',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        TextButton(
                          onPressed: () => _answer(b, false),
                          child: const Text('Decline'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: ink),
                          onPressed: () => _answer(b, true),
                          child: const Text('Accept'),
                        ),
                      ],
                    ),
                  ),
              const SectionTitle('Up next'),
              for (final b in upcoming)
                BookingCard(booking: b, forBarber: true),
              if (upcoming.isEmpty)
                const Text(
                  'Nothing scheduled.',
                  style: TextStyle(color: muted),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text(label, style: const TextStyle(fontSize: 11, color: muted)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Earnings, built from the same blocks as the owner's Finance screen
// -----------------------------------------------------------------------------

class _EarningsScreen extends StatefulWidget {
  const _EarningsScreen();

  @override
  State<_EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<_EarningsScreen> {
  int _period = 1;

  static const _periods = ['Today', 'This week', 'This month'];
  // (commission, tips, vip extras, clients)
  static const _figures = [
    (98.0, 18.0, 12.0, 6),
    (612.0, 104.0, 75.0, 38),
    (2480.0, 395.0, 310.0, 151),
  ];
  static const _week = [62.0, 88.0, 74.0, 120.0, 156.0, 182.0, 128.0];
  // (client, service, my share, VIP extra, payment, minutes ago)
  static const _ledger = [
    ('Omar B.', 'Haircut + Beard', 21.0, 0.0, PaymentMethod.cash, 25),
    ('Aziz G.', 'Haircut · VIP', 15.0, 15.0, PaymentMethod.card, 70),
    ('Mehdi T.', 'Haircut', 15.0, 0.0, PaymentMethod.cash, 115),
    ('Rami H.', 'Beard Trim', 9.0, 0.0, PaymentMethod.card, 160),
  ];

  @override
  Widget build(BuildContext context) {
    final (commission, tips, vip, clients) = _figures[_period];
    final total = commission + tips + vip;

    return Scaffold(
      appBar: AppBar(title: const Text('My Earnings')),
      body: Column(
        children: [
          PeriodChips<int>(
            options: [for (var i = 0; i < 3; i++) (_periods[i], i)],
            selected: _period,
            onSelected: (i) => setState(() => _period = i),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MoneyHeroCard(
                  label: '${_periods[_period]} · you earned',
                  amount: dt(total),
                  stats: [
                    HeroStat('Commission', dt(commission), MoneyHeroCard.blue),
                    HeroStat('Tips', dt(tips), MoneyHeroCard.green),
                    HeroStat('VIP extras', dt(vip), MoneyHeroCard.gold),
                    HeroStat('Clients Served', '$clients'),
                  ],
                ),
                const SectionHeading('Breakdown'),
                Row(
                  children: [
                    Expanded(
                      child: AmountCard(
                        title: 'Commission',
                        amount: dt(commission),
                        icon: Icons.content_cut,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AmountCard(
                        title: 'Tips',
                        amount: dt(tips),
                        icon: Icons.volunteer_activism_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AmountCard(
                        title: 'VIP extras',
                        amount: dt(vip),
                        icon: Icons.verified_outlined,
                        accent: gold,
                      ),
                    ),
                  ],
                ),
                const SectionHeading('Last 7 days'),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(8, 16, 8, 12),
                    child: WeekBarChart(_week),
                  ),
                ),
                const SectionHeading('Service Ledger'),
                for (final (client, service, share, extra, method, ago)
                    in _ledger)
                  _ledgerTile(client, service, share, extra, method, ago),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledgerTile(
    String client,
    String service,
    double share,
    double extra,
    PaymentMethod method,
    int minutesAgo,
  ) {
    final (bg, fg, icon) = paymentStyle(method);
    final time = TimeOfDay.fromDateTime(
      DateTime.now().subtract(Duration(minutes: minutesAgo)),
    ).format(context);
    return LedgerTile(
      icon: icon,
      iconBackground: bg,
      iconColor: fg,
      title: client,
      subtitle: '$service • Chair #1 • $time',
      amount: dt(share + extra),
      note: extra > 0 ? '+${dt(extra)} VIP' : 'My share',
      noteColor: extra > 0 ? gold : const Color(0xFF10B981),
    );
  }
}

// -----------------------------------------------------------------------------
// Portfolio
// -----------------------------------------------------------------------------

class _PortfolioScreen extends StatefulWidget {
  const _PortfolioScreen();

  @override
  State<_PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<_PortfolioScreen> {
  final _mine = [
    for (final style in [
      HaircutStyle.fade,
      HaircutStyle.crop,
      HaircutStyle.pompadour,
      HaircutStyle.beard,
    ])
      MockPhoto(style, BarberShell.me, 'Blade & Crown', 40 + style.index * 23),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My portfolio')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ink,
        foregroundColor: Colors.white,
        onPressed: _addPhoto,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add a cut'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: _mine.length,
        itemBuilder: (_, i) => PhotoTile(photo: _mine[i]),
      ),
    );
  }

  Future<void> _addPhoto() async {
    final added = await showModalBottomSheet<HaircutStyle>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _UploadSheet(),
    );
    if (added == null || !mounted) return;
    setState(
      () =>
          _mine.insert(0, MockPhoto(added, BarberShell.me, 'Blade & Crown', 0)),
    );
    showDone(context, 'Published. Clients can see it on your salon page.');
  }
}

class _UploadSheet extends StatefulWidget {
  const _UploadSheet();

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  HaircutStyle _style = HaircutStyle.fade;
  bool _consent = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a cut',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const Text(
              'Prototype: pick a style instead of taking a photo.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final s in HaircutStyle.values)
                    GestureDetector(
                      onTap: () => setState(() => _style = s),
                      child: Container(
                        width: 92,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _style == s ? gold : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: PhotoTile(
                            photo: MockPhoto(s, BarberShell.me, '', 0),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              title: const Text(
                'The client agreed to have this photo published',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Required when the face is visible (personal data law).',
              ),
            ),
            const SizedBox(height: 8),
            primaryButton(
              'Publish',
              _consent ? () => Navigator.pop(context, _style) : null,
              icon: Icons.cloud_upload_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

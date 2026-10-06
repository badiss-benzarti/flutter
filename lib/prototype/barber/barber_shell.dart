import 'package:flutter/material.dart';

import '../client/client_shell.dart';
import '../client/salon_page.dart';
import '../mock_data.dart';
import '../widgets/ui.dart';

/// Barber side of the app, signed in as Sami from Blade & Crown.
class BarberShell extends StatefulWidget {
  const BarberShell({super.key});

  static const me = 'Sami';

  @override
  State<BarberShell> createState() => _BarberShellState();
}

class _BarberShellState extends State<BarberShell> {
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
                _TodayScreen(),
                _EarningsScreen(),
                _PortfolioScreen(),
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
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_camera_outlined),
            selectedIcon: Icon(Icons.photo_camera),
            label: 'Portfolio',
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Today
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
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
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
// Earnings
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

  @override
  Widget build(BuildContext context) {
    final (commission, tips, vip, clients) = _figures[_period];
    final total = commission + tips + vip;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('My earnings'),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<int>(
            segments: [
              for (var i = 0; i < 3; i++)
                ButtonSegment(value: i, label: Text(_periods[i])),
            ],
            selected: {_period},
            onSelectionChanged: (v) => setState(() => _period = v.first),
          ),
          const SizedBox(height: 14),
          InkCard(
            color: ink,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_periods[_period].toUpperCase()} · YOU EARNED',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dt(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '$clients clients',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Part('Commission', commission, ink),
              const SizedBox(width: 8),
              _Part('Tips', tips, const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _Part('VIP extras', vip, gold),
            ],
          ),
          const SectionTitle('Last 7 days'),
          InkCard(
            child: SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < _week.length; i++)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${_week[i].toInt()}',
                            style: const TextStyle(fontSize: 10, color: muted),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 100 * _week[i] / 182,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: i == _week.length - 1 ? gold : ink,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SectionTitle('Recent'),
          for (final (client, service, amount, vipExtra) in const [
            ('Omar B.', 'Haircut + Beard', 21.0, 0.0),
            ('Aziz G.', 'Haircut · VIP', 15.0, 15.0),
            ('Mehdi T.', 'Haircut', 15.0, 0.0),
            ('Rami H.', 'Beard Trim', 9.0, 0.0),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Avatar(client, radius: 18),
              title: Text(
                client,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(service),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    dt(amount + vipExtra),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (vipExtra > 0)
                    Text(
                      '+${dt(vipExtra)} VIP',
                      style: const TextStyle(
                        fontSize: 11,
                        color: gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Part extends StatelessWidget {
  const _Part(this.label, this.amount, this.color);

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 18, height: 4, color: color),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: muted)),
            Text(
              dt(amount),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ],
        ),
      ),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My portfolio'),
        backgroundColor: Colors.white,
      ),
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

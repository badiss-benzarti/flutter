import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/floor_plan/domain/station.dart';
import '../../features/floor_plan/presentation/widgets/room/room_view.dart';
import '../mock_data.dart';
import '../widgets/haircut_art.dart';
import '../widgets/ui.dart';

/// What a client sees after tapping a salon on the map.
class SalonPage extends StatelessWidget {
  const SalonPage({super.key, required this.salon});

  final MockSalon salon;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            children: [
              Text(
                salon.name,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                salon.area,
                style: const TextStyle(
                  fontSize: 12,
                  color: muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          bottom: const TabBar(
            labelColor: ink,
            indicatorColor: ink,
            labelStyle: TextStyle(fontWeight: FontWeight.w800),
            tabs: [
              Tab(text: 'Live'),
              Tab(text: 'Barbers'),
              Tab(text: 'Prices'),
              Tab(text: 'Photos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _LiveTab(salon: salon),
            _BarbersTab(salon: salon),
            const _PricesTab(),
            _PhotosTab(salon: salon),
          ],
        ),
        bottomNavigationBar: salon.open
            ? _ActionBar(salon: salon)
            : const _ClosedBar(),
      ),
    );
  }
}

class _LiveTab extends StatelessWidget {
  const _LiveTab({required this.salon});

  final MockSalon salon;

  @override
  Widget build(BuildContext context) {
    if (!salon.open) {
      return const Center(
        child: Text('Closed now. Book an appointment for another day.'),
      );
    }
    return RoomView(
      shopName: salon.name,
      established: 2026,
      stations: salon.stations,
      totalChairs: salon.chairs,
      waitingCount: salon.waiting,
      anonymizeClients: true,
      reserveLabel: 'JOIN THE QUEUE',
      onReserveTap: () => showJoinQueue(context, salon),
      onQueueViewTap: () => showJoinQueue(context, salon),
      onStationTap: (s) {
        if (s.activeBarberName == null) return;
        final barber = salon.barbers.firstWhere(
          (b) => b.name == s.activeBarberName,
        );
        showBarberSheet(
          context,
          salon,
          barber,
          busy: s.status == ChairStatus.occupied,
        );
      },
    );
  }
}

class _BarbersTab extends StatelessWidget {
  const _BarbersTab({required this.salon});

  final MockSalon salon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final b in salon.barbers)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkCard(
              onTap: () => showBarberSheet(context, salon, b),
              child: Row(
                children: [
                  Avatar(b.name, radius: 24, dimmed: !b.onDuty),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(b.specialty, style: const TextStyle(color: muted)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Stars(b.rating),
                      Text(
                        b.onDuty ? 'On duty' : 'Off today',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: b.onDuty ? const Color(0xFF10B981) : muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PricesTab extends StatelessWidget {
  const _PricesTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final s in services)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.content_cut),
            title: Text(
              s.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('${s.minutes} min'),
            trailing: Text(
              dt(s.price),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
      ],
    );
  }
}

class _PhotosTab extends StatelessWidget {
  const _PhotosTab({required this.salon});

  final MockSalon salon;

  @override
  Widget build(BuildContext context) {
    final mine = photos.where((p) => p.salon == salon.name).toList();
    final shown = mine.isEmpty ? photos.take(4).toList() : mine;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: shown.length,
      itemBuilder: (_, i) => PhotoTile(photo: shown[i]),
    );
  }
}

class PhotoTile extends StatelessWidget {
  const PhotoTile({super.key, required this.photo});

  final MockPhoto photo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          HaircutArt(style: photo.style),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xAA000000)],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'by ${photo.barber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Icon(Icons.favorite, size: 14, color: Colors.white),
                  const SizedBox(width: 3),
                  Text(
                    '${photo.likes}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.salon});

  final MockSalon salon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ink, width: 1.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ink,
                  minimumSize: const Size(0, 50),
                  side: const BorderSide(color: ink, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => showBooking(context, salon),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text(
                  'Book',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: ink,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: ink, width: 1.5),
                  ),
                ),
                onPressed: () => showVip(context, salon),
                icon: const Icon(Icons.bolt_rounded),
                label: const Text(
                  'VIP',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosedBar extends StatelessWidget {
  const _ClosedBar();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'This salon is closed right now.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Sheets
// -----------------------------------------------------------------------------

Future<void> _sheet(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: child,
      ),
    ),
  );
}

Widget _sheetTitle(String title, String subtitle) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      title,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
    ),
    const SizedBox(height: 2),
    Text(subtitle, style: const TextStyle(color: muted)),
  ],
);

void showBarberSheet(
  BuildContext context,
  MockSalon salon,
  MockBarber barber, {
  bool busy = false,
}) {
  _sheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Avatar(barber.name, radius: 28),
            const SizedBox(width: 14),
            Expanded(child: _sheetTitle(barber.name, barber.specialty)),
            Stars(barber.rating),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          !barber.onDuty
              ? 'Off today.'
              : busy
              ? 'Cutting right now. Free in about 15 min.'
              : 'Free now. Join the queue to sit next.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SectionTitle('Recent work'),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final p
                  in photos
                      .where((p) => p.barber == barber.name)
                      .followedBy(photos.take(3))
                      .take(4))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(width: 120, child: PhotoTile(photo: p)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (sheetContext) =>
              primaryButton('Book with ${barber.name}', () {
                Navigator.pop(sheetContext);
                showBooking(context, salon, barber: barber);
              }, icon: Icons.calendar_month_outlined),
        ),
      ],
    ),
  );
}

void showJoinQueue(BuildContext context, MockSalon salon) {
  _sheet(context, _JoinQueueForm(salon: salon, rootContext: context));
}

class _JoinQueueForm extends StatefulWidget {
  const _JoinQueueForm({required this.salon, required this.rootContext});

  final MockSalon salon;
  final BuildContext rootContext;

  @override
  State<_JoinQueueForm> createState() => _JoinQueueFormState();
}

class _JoinQueueFormState extends State<_JoinQueueForm> {
  MockService _service = services.first;

  @override
  Widget build(BuildContext context) {
    final salon = widget.salon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetTitle('Join the queue', salon.name),
        const SizedBox(height: 16),
        InkCard(
          color: const Color(0xFFF9FAFB),
          child: Row(
            children: [
              _BigStat('#${salon.waiting + 1}', 'your place'),
              _BigStat('~${salon.waitMinutes + 10} min', 'estimated wait'),
            ],
          ),
        ),
        const SectionTitle('Service'),
        _ServicePicker(
          value: _service,
          onChanged: (s) => setState(() => _service = s),
        ),
        const SizedBox(height: 10),
        const Text(
          "We'll notify you when it's almost your turn, so you can wait at home. "
          'Pay at the salon.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        primaryButton('Join the queue', () {
          addBooking(
            MockBooking(
              salon: salon.name,
              kind: BookingKind.queue,
              when: DateTime.now().add(
                Duration(minutes: salon.waitMinutes + 10),
              ),
              service: _service,
              status: BookingStatus.accepted,
            ),
          );
          Navigator.pop(context);
          showDone(
            widget.rootContext,
            "You're #${salon.waiting + 1} in line at ${salon.name}.",
          );
        }, icon: Icons.event_seat_outlined),
      ],
    );
  }
}

void showBooking(BuildContext context, MockSalon salon, {MockBarber? barber}) {
  _sheet(
    context,
    _BookingForm(salon: salon, barber: barber, rootContext: context),
  );
}

class _BookingForm extends StatefulWidget {
  const _BookingForm({
    required this.salon,
    required this.rootContext,
    this.barber,
  });

  final MockSalon salon;
  final MockBarber? barber;
  final BuildContext rootContext;

  @override
  State<_BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends State<_BookingForm> {
  late MockBarber? _barber = widget.barber;
  MockService _service = services.first;
  int _day = 1;
  String? _time;

  @override
  Widget build(BuildContext context) {
    final salon = widget.salon;
    final today = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetTitle('Book an appointment', salon.name),
        const SectionTitle('Day'),
        _DayPicker(
          value: _day,
          onChanged: (d) => setState(() {
            _day = d;
            _time = null;
          }),
        ),
        const SectionTitle('Barber'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Any barber'),
              selected: _barber == null,
              onSelected: (_) => setState(() => _barber = null),
            ),
            for (final b in salon.barbers)
              ChoiceChip(
                avatar: Avatar(b.name, radius: 10),
                label: Text(b.name),
                selected: _barber == b,
                onSelected: (_) => setState(() => _barber = b),
              ),
          ],
        ),
        const SectionTitle('Service'),
        _ServicePicker(
          value: _service,
          onChanged: (s) => setState(() => _service = s),
        ),
        const SectionTitle('Time'),
        _TimeGrid(
          seed: _day + (_barber?.name.length ?? 0),
          value: _time,
          onChanged: (t) => setState(() => _time = t),
        ),
        const SizedBox(height: 18),
        primaryButton(
          _time == null
              ? 'Pick a time'
              : 'Request ${_dayLabel(today, _day)} at $_time',
          _time == null
              ? null
              : () {
                  final parts = _time!.split(':');
                  final when = DateTime(
                    today.year,
                    today.month,
                    today.day + _day,
                    int.parse(parts[0]),
                    int.parse(parts[1]),
                  );
                  addBooking(
                    MockBooking(
                      salon: salon.name,
                      kind: BookingKind.appointment,
                      when: when,
                      barber: _barber?.name ?? salon.barbers.first.name,
                      service: _service,
                    ),
                  );
                  Navigator.pop(context);
                  showDone(
                    widget.rootContext,
                    'Request sent. ${_barber?.name ?? 'The salon'} will confirm.',
                  );
                },
        ),
      ],
    );
  }
}

void showVip(BuildContext context, MockSalon salon) {
  _sheet(context, _VipForm(salon: salon, rootContext: context));
}

class _VipForm extends StatefulWidget {
  const _VipForm({required this.salon, required this.rootContext});

  final MockSalon salon;
  final BuildContext rootContext;

  @override
  State<_VipForm> createState() => _VipFormState();
}

class _VipFormState extends State<_VipForm> {
  bool _offer = false;
  int _day = 0;
  late double _bonus = widget.salon.minOffer + 5;
  MockService _service = services.first;
  String? _time;

  @override
  Widget build(BuildContext context) {
    final salon = widget.salon;
    final now = _day == 0;
    final extra = _offer ? _bonus : salon.priorityPrice;
    final total = _service.price + extra;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, color: gold, size: 30),
            const SizedBox(width: 6),
            Expanded(
              child: _sheetTitle(
                'VIP treatment',
                'No waiting at ${salon.name}',
              ),
            ),
          ],
        ),
        const SectionTitle('When'),
        _DayPicker(
          value: _day,
          includeNow: true,
          onChanged: (d) => setState(() {
            _day = d;
            _time = null;
          }),
        ),
        if (!now) ...[
          const SectionTitle('Guaranteed time'),
          _TimeGrid(
            seed: _day * 3,
            value: _time,
            onChanged: (t) => setState(() => _time = t),
          ),
        ],
        const SectionTitle('Service'),
        _ServicePicker(
          value: _service,
          onChanged: (s) => setState(() => _service = s),
        ),
        const SectionTitle('Price'),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Priority pass'),
              icon: Icon(Icons.verified_outlined),
            ),
            ButtonSegment(
              value: true,
              label: Text('Make an offer'),
              icon: Icon(Icons.local_offer_outlined),
            ),
          ],
          selected: {_offer},
          onSelectionChanged: (v) => setState(() => _offer = v.first),
        ),
        const SizedBox(height: 12),
        if (!_offer)
          Text(
            'Fixed VIP fee set by the salon: +${dt(salon.priorityPrice)}. '
            '${now ? 'You go next.' : 'Your slot is guaranteed, no waiting.'}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          )
        else ...[
          Text(
            'Your extra: +${dt(_bonus)}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          Slider(
            value: _bonus,
            min: salon.minOffer,
            max: salon.minOffer * 4,
            divisions: (salon.minOffer * 3).round(),
            label: '+${dt(_bonus)}',
            activeColor: ink,
            onChanged: (v) => setState(() => _bonus = v.roundToDouble()),
          ),
          Text(
            'Minimum +${dt(salon.minOffer)}. The barber accepts or declines within 5 minutes; '
            'if nobody answers, the offer expires and nothing is charged.',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        const InkCard(
          color: Color(0xFFFFF8E1),
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.balance_rounded, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Fair line: max 1 VIP per barber per hour, so walk-ins keep moving. '
                  '1 VIP slot left this hour.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(
              dt(total),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const Text(
          'Pay at the salon',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        primaryButton(
          _offer ? 'Send my offer' : 'Get the priority pass',
          !now && _time == null
              ? null
              : () {
                  final today = DateTime.now();
                  final parts = (_time ?? '00:00').split(':');
                  addBooking(
                    MockBooking(
                      salon: salon.name,
                      kind: _offer ? BookingKind.offer : BookingKind.priority,
                      when: now
                          ? today.add(const Duration(minutes: 10))
                          : DateTime(
                              today.year,
                              today.month,
                              today.day + _day,
                              int.parse(parts[0]),
                              int.parse(parts[1]),
                            ),
                      barber: salon.barbers.first.name,
                      service: _service,
                      price: total,
                      status: _offer
                          ? BookingStatus.pending
                          : BookingStatus.accepted,
                    ),
                  );
                  Navigator.pop(context);
                  showDone(
                    widget.rootContext,
                    _offer
                        ? 'Offer sent (+${dt(_bonus)}). Waiting for the barber.'
                        : 'VIP confirmed. ${now ? "You're next!" : 'See you at $_time.'}',
                  );
                },
          icon: Icons.bolt_rounded,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Pickers
// -----------------------------------------------------------------------------

String _dayLabel(DateTime today, int offset) {
  if (offset == 0) return 'today';
  if (offset == 1) return 'tomorrow';
  return DateFormat('EEE d MMM').format(today.add(Duration(days: offset)));
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.value,
    required this.onChanged,
    this.includeNow = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool includeNow;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var d = includeNow ? 0 : 1; d <= 7; d++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(d),
                child: Container(
                  width: 62,
                  decoration: BoxDecoration(
                    color: value == d ? ink : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ink, width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        d == 0
                            ? 'NOW'
                            : DateFormat('EEE')
                                  .format(today.add(Duration(days: d)))
                                  .toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: value == d ? Colors.white70 : muted,
                        ),
                      ),
                      if (d == 0)
                        Icon(
                          Icons.bolt_rounded,
                          size: 22,
                          color: value == d ? gold : ink,
                        )
                      else
                        Text(
                          '${today.add(Duration(days: d)).day}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: value == d ? Colors.white : ink,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServicePicker extends StatelessWidget {
  const _ServicePicker({required this.value, required this.onChanged});

  final MockService value;
  final ValueChanged<MockService> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in services)
          ChoiceChip(
            label: Text('${s.name} · ${dt(s.price)}'),
            selected: value == s,
            onSelected: (_) => onChanged(s),
          ),
      ],
    );
  }
}

class _TimeGrid extends StatelessWidget {
  const _TimeGrid({
    required this.seed,
    required this.value,
    required this.onChanged,
  });

  final int seed;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final slots = [
      for (var h = 9; h < 20; h++)
        for (final m in const [0, 30])
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < slots.length; i++)
          ChoiceChip(
            label: Text(slots[i]),
            selected: value == slots[i],
            // Some slots are already taken in the sample data.
            onSelected: (i * 7 + seed) % 5 == 0
                ? null
                : (_) => onChanged(slots[i]),
          ),
      ],
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          Text(label, style: const TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    );
  }
}

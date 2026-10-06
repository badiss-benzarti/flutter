import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../features/floor_plan/domain/station.dart';

/// Sample data for the clickable client / barber prototype (roadmap step
/// 0.3). Nothing here touches the real database.

String dt(num amount) =>
    '${amount % 1 == 0 ? amount.toInt() : amount.toStringAsFixed(1)} DT';

class MockBarber {
  const MockBarber(
    this.name,
    this.rating,
    this.specialty, {
    this.onDuty = true,
  });

  final String name;
  final double rating;
  final String specialty;
  final bool onDuty;
}

class MockService {
  const MockService(this.name, this.price, this.minutes);

  final String name;
  final double price;
  final int minutes;
}

/// A portfolio photo, drawn as an illustration until real photos exist.
class MockPhoto {
  const MockPhoto(this.style, this.barber, this.salon, this.likes);

  final HaircutStyle style;
  final String barber;
  final String salon;
  final int likes;
}

enum HaircutStyle { fade, buzz, pompadour, curly, beard, crop }

class MockSalon {
  const MockSalon({
    required this.id,
    required this.name,
    required this.area,
    required this.position,
    required this.rating,
    required this.reviews,
    required this.waitMinutes,
    required this.waiting,
    required this.chairs,
    required this.barbers,
    required this.stations,
    required this.priorityPrice,
    required this.minOffer,
    this.open = true,
  });

  final String id;
  final String name;
  final String area;
  final LatLng position;
  final double rating;
  final int reviews;
  final int waitMinutes;
  final int waiting;
  final int chairs;
  final List<MockBarber> barbers;
  final List<Station> stations;
  final double priorityPrice;
  final double minOffer;
  final bool open;

  SalonStatus get status => !open
      ? SalonStatus.closed
      : waitMinutes >= 30
      ? SalonStatus.busy
      : SalonStatus.available;
}

enum SalonStatus { available, busy, closed }

const services = [
  MockService('Haircut', 25, 30),
  MockService('Beard Trim', 15, 20),
  MockService('Haircut + Beard', 35, 45),
  MockService('Kids Haircut', 20, 25),
  MockService('Hot Towel Shave', 18, 25),
];

List<Station> _floor(String id, List<(int, ChairStatus, String?)> chairs) {
  final now = DateTime.now();
  return [
    for (final (n, status, barber) in chairs)
      Station(
        chairNumber: n,
        shopId: id,
        status: status,
        activeBarberId: barber,
        activeBarberName: barber,
        activeClientName: status == ChairStatus.occupied ? 'Client' : null,
        serviceStartTime: status == ChairStatus.occupied
            ? now.subtract(Duration(minutes: 4 + n * 3))
            : null,
      ),
  ];
}

final salons = <MockSalon>[
  MockSalon(
    id: 'blade',
    name: 'Blade & Crown',
    area: 'Centre Ville',
    position: const LatLng(36.8008, 10.1800),
    rating: 4.8,
    reviews: 214,
    waitMinutes: 15,
    waiting: 3,
    chairs: 8,
    priorityPrice: 15,
    minOffer: 10,
    barbers: const [
      MockBarber('Sami', 4.9, 'Skin fades'),
      MockBarber('Karim', 4.7, 'Beards'),
      MockBarber('Youssef', 4.8, 'Classic cuts'),
      MockBarber('Nour', 4.6, 'Curly hair'),
      MockBarber('Ali', 4.5, 'Kids', onDuty: false),
    ],
    stations: _floor('blade', [
      (1, ChairStatus.available, 'Sami'),
      (3, ChairStatus.occupied, 'Karim'),
      (6, ChairStatus.occupied, 'Youssef'),
      (7, ChairStatus.available, 'Nour'),
    ]),
  ),
  MockSalon(
    id: 'marsa',
    name: 'La Marsa Cuts',
    area: 'La Marsa',
    position: const LatLng(36.8782, 10.3247),
    rating: 4.6,
    reviews: 128,
    waitMinutes: 40,
    waiting: 6,
    chairs: 6,
    priorityPrice: 20,
    minOffer: 12,
    barbers: const [
      MockBarber('Hedi', 4.7, 'Pompadours'),
      MockBarber('Mehdi', 4.6, 'Fades'),
      MockBarber('Aymen', 4.4, 'Beards'),
    ],
    stations: _floor('marsa', [
      (1, ChairStatus.occupied, 'Hedi'),
      (2, ChairStatus.occupied, 'Mehdi'),
      (4, ChairStatus.occupied, 'Aymen'),
    ]),
  ),
  MockSalon(
    id: 'lac',
    name: 'Lac Gentlemen',
    area: 'Les Berges du Lac',
    position: const LatLng(36.8475, 10.2706),
    rating: 4.9,
    reviews: 301,
    waitMinutes: 5,
    waiting: 1,
    chairs: 4,
    priorityPrice: 25,
    minOffer: 15,
    barbers: const [
      MockBarber('Walid', 5.0, 'Luxury shave'),
      MockBarber('Rami', 4.8, 'Textured crops'),
    ],
    stations: _floor('lac', [
      (1, ChairStatus.occupied, 'Walid'),
      (3, ChairStatus.available, 'Rami'),
    ]),
  ),
  MockSalon(
    id: 'menzah',
    name: 'Menzah Barber Club',
    area: 'El Menzah',
    position: const LatLng(36.8410, 10.1700),
    rating: 4.4,
    reviews: 87,
    waitMinutes: 25,
    waiting: 4,
    chairs: 6,
    priorityPrice: 12,
    minOffer: 8,
    barbers: const [
      MockBarber('Firas', 4.5, 'Fades'),
      MockBarber('Anis', 4.3, 'Classic cuts'),
      MockBarber('Seif', 4.4, 'Beards'),
    ],
    stations: _floor('menzah', [
      (1, ChairStatus.occupied, 'Firas'),
      (2, ChairStatus.available, 'Anis'),
      (5, ChairStatus.occupied, 'Seif'),
    ]),
  ),
  MockSalon(
    id: 'ennasr',
    name: 'Ennasr Fade House',
    area: 'Ennasr',
    position: const LatLng(36.8590, 10.1640),
    rating: 4.7,
    reviews: 156,
    waitMinutes: 35,
    waiting: 5,
    chairs: 8,
    priorityPrice: 18,
    minOffer: 10,
    barbers: const [
      MockBarber('Malek', 4.8, 'Skin fades'),
      MockBarber('Bilel', 4.6, 'Designs'),
      MockBarber('Nizar', 4.7, 'Curly hair'),
      MockBarber('Skander', 4.5, 'Beards'),
    ],
    stations: _floor('ennasr', [
      (1, ChairStatus.occupied, 'Malek'),
      (2, ChairStatus.occupied, 'Bilel'),
      (5, ChairStatus.occupied, 'Nizar'),
      (6, ChairStatus.available, 'Skander'),
    ]),
  ),
  const MockSalon(
    id: 'bardo',
    name: 'Bardo Classic',
    area: 'Le Bardo',
    position: LatLng(36.8092, 10.1340),
    rating: 4.2,
    reviews: 64,
    waitMinutes: 0,
    waiting: 0,
    chairs: 4,
    priorityPrice: 10,
    minOffer: 6,
    open: false,
    barbers: [MockBarber('Hamza', 4.3, 'Classic cuts')],
    stations: [],
  ),
];

const photos = [
  MockPhoto(HaircutStyle.fade, 'Sami', 'Blade & Crown', 132),
  MockPhoto(HaircutStyle.pompadour, 'Hedi', 'La Marsa Cuts', 98),
  MockPhoto(HaircutStyle.beard, 'Walid', 'Lac Gentlemen', 211),
  MockPhoto(HaircutStyle.curly, 'Nour', 'Blade & Crown', 76),
  MockPhoto(HaircutStyle.crop, 'Rami', 'Lac Gentlemen', 154),
  MockPhoto(HaircutStyle.buzz, 'Firas', 'Menzah Barber Club', 43),
  MockPhoto(HaircutStyle.fade, 'Malek', 'Ennasr Fade House', 187),
  MockPhoto(HaircutStyle.beard, 'Karim', 'Blade & Crown', 65),
  MockPhoto(HaircutStyle.pompadour, 'Youssef', 'Blade & Crown', 90),
];

enum BookingKind { queue, appointment, priority, offer }

enum BookingStatus { pending, accepted, declined }

class MockBooking {
  MockBooking({
    required this.salon,
    required this.kind,
    required this.when,
    this.barber,
    this.service,
    this.price,
    this.status = BookingStatus.pending,
    this.client = 'You',
  });

  final String salon;
  final BookingKind kind;
  final DateTime when;
  final String? barber;
  final MockService? service;
  final double? price;
  final String client;
  BookingStatus status;
}

/// In-memory bookings shared by the client and barber prototypes, so a
/// request made on the client side shows up on the barber side.
DateTime _at(int dayOffset, int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + dayOffset, hour, minute);
}

final bookings = ValueNotifier<List<MockBooking>>([
  MockBooking(
    salon: 'Blade & Crown',
    kind: BookingKind.offer,
    when: DateTime.now().add(const Duration(minutes: 20)),
    barber: 'Sami',
    service: services[0],
    price: 40,
    client: 'Aziz G.',
  ),
  MockBooking(
    salon: 'Blade & Crown',
    kind: BookingKind.appointment,
    when: _at(1, 14),
    barber: 'Sami',
    service: services[2],
    client: 'Hamza C.',
  ),
  MockBooking(
    salon: 'Blade & Crown',
    kind: BookingKind.appointment,
    when: _at(0, 17, 30),
    barber: 'Sami',
    service: services[1],
    status: BookingStatus.accepted,
    client: 'Omar B.',
  ),
]);

void addBooking(MockBooking booking) =>
    bookings.value = [booking, ...bookings.value];

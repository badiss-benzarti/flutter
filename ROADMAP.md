# Roadmap: client & barber platform

Turn the owner console into a platform with three roles (owner, barber,
client) on a free stack: **Supabase** (database, auth, realtime, storage),
**OpenStreetMap** via `flutter_map` (maps) and **Firebase Cloud Messaging**
(push notifications only). Payments happen at the salon until a business is
registered with a Tunisian gateway (Konnect / Flouci).

Defaults: one app with three roles, French + English, prices in DT, launch
city Tunis.

## Phase 0: Preparation
- [x] 0.1 Create the Supabase project (Frankfurt), share Project URL + anon key *(owner)*
- [ ] 0.2 Create a Firebase project for push notifications only *(owner)*
- [x] 0.3 Clickable prototype of client and barber screens (`lib/prototype`, opened from the welcome screen)
- [ ] 0.4 Validate the prototype and the VIP rules *(owner)*

## Phase 1: Cloud foundation
- [x] 1.1 Server schema: shops, chairs, barbers, services, tickets, queue + roles + shop location
- [x] 1.2 Row-level security: owner → own shop, barber → own earnings, client → public data
- [x] 1.3 Supabase auth (email) and salon setup on the server
- [ ] 1.3b Google sign-in *(needs a Google Cloud setup)*
- [x] 1.4 Offline mode for the owner: local SQLite copy that syncs
- [ ] 1.5 Onboarding: place the salon on the map
- [ ] 1.6 Demo shop on the server; tests against a test database

## Phase 2: Barber side
- [ ] 2.1 Invite code to join a salon
- [ ] 2.2 Barber home: next clients, queue, on-duty toggle
- [ ] 2.3 My earnings: day / week / month, commission + tips
- [ ] 2.4 Portfolio: photo upload with compression, client consent, delete / report

## Phase 3: Client side
- [ ] 3.1 Client sign-up / login
- [ ] 3.2 Map of salons with live status (open, busy, estimated wait): one small cached request per visible area, refreshed every minute while shown; no realtime on the map
- [ ] 3.2b Map tiles: move off the public OpenStreetMap servers before the beta (free tier provider or self-hosted Tunisia tiles)
- [ ] 3.3 Salon page: live room with anonymous clients, barbers, prices, photos
- [ ] 3.4 Join the queue remotely
- [ ] 3.5 Book an appointment (day, time, barber); barber accepts / declines
- [ ] 3.6 Push notifications (accepted, your turn soon, cancelled)
- [ ] 3.7 No-show rule (temporary block after 2 no-shows)

## Phase 4: VIP & priority
- [ ] 4.1 Priority pass at a fixed price set by the shop
- [ ] 4.2 "Propose a price" offers with accept / decline and automatic expiry
- [ ] 4.3 Server-enforced fairness: max priorities per barber per hour
- [ ] 4.4 VIP revenue in barber and owner finances

## Phase 5: Social
- [ ] 5.1 Social feed of barbers' photos
- [ ] 5.2 Reviews and ratings from verified visits
- [ ] 5.3 Follow barbers, report content

## Phase 6: Beta & launch
- [ ] 6.1 French interface (Arabic later)
- [ ] 6.2 Privacy policy and terms
- [ ] 6.3 Weekly data backup
- [ ] 6.4 Beta with 2–3 salons in Tunis
- [ ] 6.5 Play Store release

**Later, with revenue:** online payments, paid Supabase plan, App Store.

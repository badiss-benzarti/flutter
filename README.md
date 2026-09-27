# Barber Shop Owner Console

A Flutter app that lets a barbershop owner run the shop floor from one device:
see every chair, seat walk-ins from a waiting queue, check clients out with
automatic commission splits, and track revenue, payouts and client history.

All data is stored locally on the device (SQLite). No server or account
outside the device is needed.

## Features

| Area | What it does |
|---|---|
| **Accounts** | Owner registration/login. Passwords are hashed with PBKDF2-HMAC-SHA256 (100k iterations), and the session is kept in the platform keychain/keystore. |
| **Onboarding** | Wizard for shop details, chair count, first barbers and the services menu. |
| **Floor plan** | Live chair map: assign on-duty barbers, seat clients from the queue or as walk-ins, check out, or cancel a service. |
| **Checkout** | Multiple services, tip presets or a custom tip, and cash/card/transfer payments. Prices and commission are read from the database, and a service can only be charged once. |
| **Barbers** | Add, edit, set on/off duty, and remove from the roster. Removed barbers are archived, so their sales stay in reports. |
| **Finance** | Today / 7 days / 30 days / custom range; revenue, shop net, commissions, tips, register totals and a per-barber payout table. |
| **Clients** | Waiting queue plus a searchable history (visits, total spent, last visit). |
| **Settings** | Edit shop details and the services catalog; change the chair count safely. |

## Architecture

```
lib/
  core/
    database/      DatabaseService: single connection, schema + migrations
    repositories/  All SQL and business rules (one per aggregate)
    security/      PasswordHasher (PBKDF2) and SessionStorage
    providers/     App-wide Riverpod providers (DB, hasher, session)
    errors/        AppException: user-facing failures
    ui/            Shared UI helpers (error snackbars, sheets, money format)
  features/<feature>/
    domain/        Plain data models
    presentation/  Riverpod notifiers and screens/widgets
```

- **State:** Riverpod 3 (`AsyncNotifier`). Feature providers watch
  `currentShopIdProvider`, so they reset on logout or when the shop changes.
- **Rules live in repositories.** The UI never computes money that gets
  stored. Invariants such as "no double checkout", "no removing a busy chair"
  and "no moving a barber mid-service" are enforced inside SQL transactions
  and reported as `AppException`.
- **Migrations:** bump `DatabaseService.schemaVersion` and add a step in
  `_onUpgrade`. New installs run the same migration steps, so the two paths
  cannot drift apart.

### Data security

The database sits in the app's private storage directory and is **not
encrypted at rest**; it relies on the OS sandbox. If you need at-rest
encryption, switch to SQLCipher (`sqflite_sqlcipher`) and keep the key in
`flutter_secure_storage`.

## Development

Requires Flutter 3.47+ (Dart 3.13+).

```bash
flutter pub get
flutter run                 # pick a device: Android, iOS, Windows, macOS, Linux
flutter test                # unit, widget and SQLite integration tests
flutter analyze --fatal-infos
dart format .
```

The repository tests run against a real in-memory SQLite database through
`sqflite_common_ffi`, so they need no device or emulator.

## CI/CD

- `.github/workflows/ci.yml`: runs format, analysis and tests on pushes and
  PRs to `main`/`develop`.
- `.github/workflows/build_release.yml`: builds a release APK when you push a
  `v*.*.*` tag.

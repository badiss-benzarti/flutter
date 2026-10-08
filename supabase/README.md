# Supabase backend

The cloud database for the client & barber platform (see `ROADMAP.md`).

| Folder | Contents |
| --- | --- |
| `migrations/` | Schema changes, applied in order. Each file runs once. |
| `tests/` | Row-level security tests run against a throwaway Postgres. |

## Applying a migration

1. Open the project in the Supabase dashboard → **SQL Editor** → **New query**.
2. Paste the whole migration file and click **Run**.
3. It should finish with "Success. No rows returned".

Apply each file once, in number order. Never edit a migration that has
already been applied: add a new numbered file instead.

## Testing locally

With Docker running, from the repository root:

```sh
sh supabase/tests/run.sh
```

It starts a Postgres 17 container, adds a small stand-in for what Supabase
provides (`tests/supabase_stub.sql`), applies every migration and runs
`tests/rls_test.sql`, which acts as an owner, a barber, a client, a rival
owner and a signed-out visitor. The same check runs in CI on every push.

## Keys

The app uses the project URL and the **publishable** key
(`lib/core/config/supabase_config.dart`); both are public by design.
The **secret** key and the database password must never be committed or
shared.

## Live checks and the demo salon

These run against the real project, only when asked:

```sh
# Round trip: sign-up, salon upload, sync, what visitors can see.
# Creates a throwaway "live-check-..." user to delete afterwards.
flutter test test/live/supabase_live_test.dart --dart-define=LIVE_SUPABASE=true

# Public demo salon (listed on the client map), under its own account.
# Keep the password private: whoever has it can edit the public salon.
flutter test test/live/seed_demo_salon_test.dart \
  --dart-define=SEED_DEMO=true --dart-define=DEMO_PASSWORD=YOUR_SECRET
# Add --dart-define=DEMO_RESET=true to rebuild it with fresh sales history.
```

The in-app "Explore the demo shop" button stays on the device: its password
is shown on screen, so it is never uploaded.

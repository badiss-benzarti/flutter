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

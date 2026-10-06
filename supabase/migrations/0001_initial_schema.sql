-- =============================================================================
-- BarberFlow cloud schema, roadmap phase 1.1 (tables) + 1.2 (row-level security)
--
-- Run once in Supabase: SQL Editor → New query → paste this file → Run.
--
-- Design rules
-- * Every table has row-level security (RLS). Nothing is readable or writable
--   unless a policy below allows it.
-- * Data a client may see (salon, barbers, prices, chair status) and private
--   data (phones, commissions, client names, invite codes) live in separate
--   tables, so public tables can be read and streamed (Realtime) safely.
-- * A salon appears to clients only once its owner lists it (`is_listed`).
-- * Invariants that the local app enforced in Dart are enforced here too
--   (checks and triggers), so a modified app cannot break them.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Roles & profiles
-- -----------------------------------------------------------------------------

create type public.user_role as enum ('owner', 'barber', 'client');

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  role        public.user_role not null default 'client',
  full_name   text not null default '' check (char_length(full_name) <= 80),
  phone       text check (char_length(phone) <= 30),
  created_at  timestamptz not null default now()
);

comment on table public.profiles is
  'One row per account. The role is chosen at sign-up and cannot be changed by the user.';

-- Creates the profile when someone signs up. The app passes `role` and
-- `full_name` as sign-up metadata; anything unexpected becomes a client.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, role, full_name)
  values (
    new.id,
    case new.raw_user_meta_data ->> 'role'
      when 'owner'  then 'owner'::public.user_role
      when 'barber' then 'barber'::public.user_role
      else 'client'::public.user_role
    end,
    left(trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), 80)
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- Shops
-- -----------------------------------------------------------------------------

create table public.shops (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid not null references public.profiles (id) on delete cascade,
  name            text not null check (char_length(trim(name)) between 1 and 60),
  address         text not null default '' check (char_length(address) <= 160),
  phone           text not null default '' check (char_length(phone) <= 30),
  total_chairs    int not null default 8 check (total_chairs between 2 and 16),
  latitude        double precision check (latitude between -90 and 90),
  longitude       double precision check (longitude between -180 and 180),
  is_open         boolean not null default true,
  is_listed       boolean not null default false,
  priority_price  numeric(10, 2) check (priority_price >= 0),
  min_offer       numeric(10, 2) check (min_offer >= 0),
  -- Maintained by a trigger on `queue`; read by the client map.
  waiting_count   int not null default 0,
  created_at      timestamptz not null default now(),
  constraint shops_location_complete check ((latitude is null) = (longitude is null)),
  constraint shops_listed_needs_location check (not is_listed or latitude is not null)
);

create index shops_owner_idx on public.shops (owner_id);
create index shops_listed_location_idx on public.shops (latitude, longitude) where is_listed;

comment on column public.shops.is_listed is
  'Shown on the client map. Requires a location.';

-- Invite codes let barbers join a salon (phase 2.1). Owner-only.
create table public.shop_invites (
  shop_id     uuid primary key references public.shops (id) on delete cascade,
  code        text not null unique,
  created_at  timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- Barbers (public part + private part)
-- -----------------------------------------------------------------------------

create table public.barbers (
  id              uuid primary key default gen_random_uuid(),
  shop_id         uuid not null references public.shops (id) on delete cascade,
  -- The barber's own account, once they joined with the invite code.
  profile_id      uuid references public.profiles (id) on delete set null,
  name            text not null check (char_length(trim(name)) between 1 and 60),
  specialty       text not null default '' check (char_length(specialty) <= 60),
  is_on_duty      boolean not null default true,
  assigned_chair  int check (assigned_chair >= 1),
  -- Archived instead of deleted: deleting would remove their financial history.
  is_archived     boolean not null default false,
  created_at      timestamptz not null default now(),
  unique (shop_id, profile_id)
);

create index barbers_shop_idx on public.barbers (shop_id);
create index barbers_profile_idx on public.barbers (profile_id);

create table public.barber_private (
  barber_id        uuid primary key references public.barbers (id) on delete cascade,
  phone            text not null default '' check (char_length(phone) <= 30),
  commission_rate  numeric(4, 3) not null default 0.600
                   check (commission_rate between 0 and 1)
);

-- -----------------------------------------------------------------------------
-- Services
-- -----------------------------------------------------------------------------

create table public.services (
  id                uuid primary key default gen_random_uuid(),
  shop_id           uuid not null references public.shops (id) on delete cascade,
  name              text not null check (char_length(trim(name)) between 1 and 60),
  price             numeric(10, 2) not null check (price >= 0),
  duration_minutes  int not null default 30 check (duration_minutes between 1 and 480),
  created_at        timestamptz not null default now()
);

create index services_shop_idx on public.services (shop_id);

-- -----------------------------------------------------------------------------
-- Chairs (public live status + private client details)
-- -----------------------------------------------------------------------------

create table public.chairs (
  shop_id             uuid not null references public.shops (id) on delete cascade,
  chair_number        int not null check (chair_number >= 1),
  status              text not null default 'empty'
                      check (status in ('empty', 'available', 'occupied', 'cleaning')),
  active_barber_id    uuid references public.barbers (id) on delete set null,
  active_ticket_id    uuid,
  service_start_time  timestamptz,
  primary key (shop_id, chair_number),
  constraint chairs_occupied_has_barber
    check (status <> 'occupied' or active_barber_id is not null)
);

-- Who is sitting in the chair: staff only, never shown to clients.
create table public.chair_clients (
  shop_id       uuid not null,
  chair_number  int not null,
  client_name   text not null check (char_length(client_name) <= 80),
  client_phone  text check (char_length(client_phone) <= 30),
  client_id     uuid references public.profiles (id) on delete set null,
  primary key (shop_id, chair_number),
  foreign key (shop_id, chair_number)
    references public.chairs (shop_id, chair_number) on delete cascade
);

-- -----------------------------------------------------------------------------
-- Tickets (completed services: the financial history)
-- -----------------------------------------------------------------------------

create table public.tickets (
  id              uuid primary key default gen_random_uuid(),
  shop_id         uuid not null references public.shops (id) on delete cascade,
  barber_id       uuid not null references public.barbers (id),
  client_id       uuid references public.profiles (id) on delete set null,
  client_name     text not null check (char_length(client_name) <= 80),
  client_phone    text check (char_length(client_phone) <= 30),
  chair_number    int not null,
  service_names   text not null,
  total_price     numeric(10, 2) not null check (total_price >= 0),
  barber_cut      numeric(10, 2) not null check (barber_cut >= 0),
  shop_cut        numeric(10, 2) not null check (shop_cut >= 0),
  tip             numeric(10, 2) not null default 0 check (tip >= 0),
  payment_method  text not null check (payment_method in ('cash', 'card', 'transfer')),
  is_completed    boolean not null default true,
  created_at      timestamptz not null default now(),
  constraint tickets_split_matches_total
    check (barber_cut + shop_cut = total_price)
);

create index tickets_shop_time_idx on public.tickets (shop_id, created_at);
create index tickets_barber_time_idx on public.tickets (barber_id, created_at);
create index tickets_client_idx on public.tickets (client_id) where client_id is not null;

-- -----------------------------------------------------------------------------
-- Queue
-- -----------------------------------------------------------------------------

create table public.queue (
  id                   uuid primary key default gen_random_uuid(),
  shop_id              uuid not null references public.shops (id) on delete cascade,
  -- Set when a client joined from the app; null for walk-ins added by staff.
  client_id            uuid references public.profiles (id) on delete cascade,
  client_name          text not null check (char_length(trim(client_name)) between 1 and 80),
  client_phone         text check (char_length(client_phone) <= 30),
  requested_barber_id  uuid references public.barbers (id) on delete set null,
  notes                text check (char_length(notes) <= 200),
  status               text not null default 'waiting'
                       check (status in ('waiting', 'seated', 'cancelled')),
  created_at           timestamptz not null default now()
);

create index queue_shop_status_idx on public.queue (shop_id, status, created_at);
-- A client can wait in only one line per salon at a time.
create unique index queue_one_active_per_client
  on public.queue (shop_id, client_id)
  where status = 'waiting' and client_id is not null;

-- =============================================================================
-- Helper functions for policies
--
-- `security definer` lets them look up ownership without triggering the RLS of
-- the tables they read (which would otherwise recurse).
-- =============================================================================

create function public.is_shop_owner(p_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.shops
    where id = p_shop_id and owner_id = (select auth.uid())
  );
$$;

create function public.is_shop_barber(p_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.barbers
    where shop_id = p_shop_id
      and profile_id = (select auth.uid())
      and not is_archived
  );
$$;

create function public.is_shop_staff(p_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_shop_owner(p_shop_id) or public.is_shop_barber(p_shop_id);
$$;

create function public.is_listed_shop(p_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.shops where id = p_shop_id and is_listed);
$$;

create function public.current_role_is(p_role public.user_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = p_role
  );
$$;

-- =============================================================================
-- Triggers enforcing business rules
-- =============================================================================

-- New shop: create its chairs and its invite code.
create function public.on_shop_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.chairs (shop_id, chair_number)
  select new.id, n from generate_series(1, new.total_chairs) as n;

  insert into public.shop_invites (shop_id, code)
  values (new.id, upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)));
  return new;
end;
$$;

create trigger shop_created
  after insert on public.shops
  for each row execute function public.on_shop_created();

-- Chair count changed: add chairs, or remove the last ones if nobody is
-- sitting in them (same rule as the local app).
create function public.on_shop_capacity_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  busy text;
begin
  if new.total_chairs > old.total_chairs then
    insert into public.chairs (shop_id, chair_number)
    select new.id, n from generate_series(old.total_chairs + 1, new.total_chairs) as n
    on conflict do nothing;
  elsif new.total_chairs < old.total_chairs then
    select string_agg(chair_number::text, ', ' order by chair_number) into busy
    from public.chairs
    where shop_id = new.id
      and chair_number > new.total_chairs
      and status = 'occupied';

    if busy is not null then
      raise exception 'Chair % is serving a client. Check out the client before removing it.', busy
        using errcode = 'P0001';
    end if;

    update public.barbers set assigned_chair = null
    where shop_id = new.id and assigned_chair > new.total_chairs;

    delete from public.chairs
    where shop_id = new.id and chair_number > new.total_chairs;
  end if;
  return new;
end;
$$;

create trigger shop_capacity_changed
  after update of total_chairs on public.shops
  for each row
  when (old.total_chairs is distinct from new.total_chairs)
  execute function public.on_shop_capacity_changed();

-- Keep `shops.waiting_count` in sync with the queue, so the client map can
-- show how busy a salon is without exposing who is waiting.
create function public.refresh_waiting_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target uuid := coalesce(new.shop_id, old.shop_id);
begin
  update public.shops
  set waiting_count = (
    select count(*) from public.queue
    where shop_id = target and status = 'waiting'
  )
  where id = target;

  if tg_op = 'UPDATE' and new.shop_id is distinct from old.shop_id then
    update public.shops
    set waiting_count = (
      select count(*) from public.queue
      where shop_id = old.shop_id and status = 'waiting'
    )
    where id = old.shop_id;
  end if;
  return null;
end;
$$;

create trigger queue_waiting_count
  after insert or update or delete on public.queue
  for each row execute function public.refresh_waiting_count();

-- References between rows must stay inside the same salon. The trigger
-- argument names the column holding the barber id.
create function public.check_same_shop()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  ref_barber uuid := (to_jsonb(new) ->> tg_argv[0])::uuid;
begin
  if ref_barber is not null and not exists (
    select 1 from public.barbers where id = ref_barber and shop_id = new.shop_id
  ) then
    raise exception 'This barber does not work in this salon.' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger chairs_same_shop before insert or update on public.chairs
  for each row execute function public.check_same_shop('active_barber_id');
create trigger queue_same_shop before insert or update on public.queue
  for each row execute function public.check_same_shop('requested_barber_id');
create trigger tickets_same_shop before insert or update on public.tickets
  for each row execute function public.check_same_shop('barber_id');

-- A barber editing their own row may only switch themselves on or off duty;
-- everything else is the owner's call. (No signed-in user = admin / SQL editor.)
create function public.guard_barber_self_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is not null
     and not public.is_shop_owner(old.shop_id)
     and (new.name, new.specialty, new.assigned_chair, new.is_archived)
         is distinct from (old.name, old.specialty, old.assigned_chair, old.is_archived)
  then
    raise exception 'Only the salon owner can change this.' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger barbers_guard_self_update before update on public.barbers
  for each row execute function public.guard_barber_self_update();

-- A shop's owner cannot be reassigned, and ids never change.
create function public.freeze_shop_owner()
returns trigger
language plpgsql
as $$
begin
  if new.owner_id is distinct from old.owner_id or new.id is distinct from old.id then
    raise exception 'A salon cannot change owner.' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger shops_freeze_owner before update on public.shops
  for each row execute function public.freeze_shop_owner();

-- =============================================================================
-- Column privileges
--
-- RLS decides which rows; these decide which columns users may write.
-- Everything else (role, waiting_count, owner, ids) is server-controlled.
-- =============================================================================

revoke update on public.profiles from anon, authenticated;
grant update (full_name, phone) on public.profiles to authenticated;

revoke update on public.shops from anon, authenticated;
grant update (name, address, phone, total_chairs, latitude, longitude,
              is_open, is_listed, priority_price, min_offer)
  on public.shops to authenticated;

revoke update on public.shop_invites from anon, authenticated;
grant update (code) on public.shop_invites to authenticated;

revoke update on public.barbers from anon, authenticated;
grant update (name, specialty, is_on_duty, assigned_chair, is_archived)
  on public.barbers to authenticated;

revoke update on public.chairs from anon, authenticated;
grant update (status, active_barber_id, active_ticket_id, service_start_time)
  on public.chairs to authenticated;

revoke update on public.queue from anon, authenticated;
grant update (client_name, client_phone, requested_barber_id, notes, status)
  on public.queue to authenticated;

-- Financial history is append-only from the apps.
revoke update, delete on public.tickets from anon, authenticated;

-- Anonymous visitors (not signed in) can only read.
revoke insert, update, delete on all tables in schema public from anon;

-- Helper functions are for policies, not for direct calls from the app.
revoke execute on function
  public.handle_new_user(),
  public.on_shop_created(),
  public.on_shop_capacity_changed(),
  public.refresh_waiting_count(),
  public.check_same_shop(),
  public.guard_barber_self_update(),
  public.freeze_shop_owner()
from public, anon, authenticated;

-- =============================================================================
-- Row-level security
-- =============================================================================

alter table public.profiles       enable row level security;
alter table public.shops          enable row level security;
alter table public.shop_invites   enable row level security;
alter table public.barbers        enable row level security;
alter table public.barber_private enable row level security;
alter table public.services       enable row level security;
alter table public.chairs         enable row level security;
alter table public.chair_clients  enable row level security;
alter table public.tickets        enable row level security;
alter table public.queue          enable row level security;

-- profiles: you see and edit your own.
create policy "profiles: read own" on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

create policy "profiles: update own" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- shops: listed salons are public; owners and their barbers see their own.
create policy "shops: read listed or own" on public.shops
  for select to anon, authenticated
  using (is_listed or public.is_shop_staff(id));

create policy "shops: owners create" on public.shops
  for insert to authenticated
  with check (
    owner_id = (select auth.uid())
    and public.current_role_is('owner')
  );

create policy "shops: owner updates" on public.shops
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "shops: owner deletes" on public.shops
  for delete to authenticated
  using (owner_id = (select auth.uid()));

-- shop_invites: owner only.
create policy "invites: owner reads" on public.shop_invites
  for select to authenticated
  using (public.is_shop_owner(shop_id));

create policy "invites: owner updates" on public.shop_invites
  for update to authenticated
  using (public.is_shop_owner(shop_id))
  with check (public.is_shop_owner(shop_id));

-- barbers: public in listed salons; managed by the owner.
create policy "barbers: read listed or staff" on public.barbers
  for select to anon, authenticated
  using (public.is_listed_shop(shop_id) or public.is_shop_staff(shop_id));

create policy "barbers: owner inserts" on public.barbers
  for insert to authenticated
  with check (public.is_shop_owner(shop_id));

create policy "barbers: owner or self updates" on public.barbers
  for update to authenticated
  using (public.is_shop_owner(shop_id) or profile_id = (select auth.uid()))
  with check (public.is_shop_owner(shop_id) or profile_id = (select auth.uid()));

-- barber_private: the owner, and the barber for their own row.
create policy "barber_private: owner or self reads" on public.barber_private
  for select to authenticated
  using (exists (
    select 1 from public.barbers b
    where b.id = barber_id
      and (public.is_shop_owner(b.shop_id) or b.profile_id = (select auth.uid()))
  ));

create policy "barber_private: owner writes" on public.barber_private
  for all to authenticated
  using (exists (
    select 1 from public.barbers b
    where b.id = barber_id and public.is_shop_owner(b.shop_id)
  ))
  with check (exists (
    select 1 from public.barbers b
    where b.id = barber_id and public.is_shop_owner(b.shop_id)
  ));

-- services: public prices; managed by the owner.
create policy "services: read listed or staff" on public.services
  for select to anon, authenticated
  using (public.is_listed_shop(shop_id) or public.is_shop_staff(shop_id));

create policy "services: owner writes" on public.services
  for all to authenticated
  using (public.is_shop_owner(shop_id))
  with check (public.is_shop_owner(shop_id));

-- chairs: live status is public; staff run the floor. Chairs are created and
-- removed by the capacity trigger only.
create policy "chairs: read listed or staff" on public.chairs
  for select to anon, authenticated
  using (public.is_listed_shop(shop_id) or public.is_shop_staff(shop_id));

create policy "chairs: staff updates" on public.chairs
  for update to authenticated
  using (public.is_shop_staff(shop_id))
  with check (public.is_shop_staff(shop_id));

revoke insert, delete on public.chairs from authenticated;

-- chair_clients: staff only.
create policy "chair_clients: staff" on public.chair_clients
  for all to authenticated
  using (public.is_shop_staff(shop_id))
  with check (public.is_shop_staff(shop_id));

-- tickets: the owner sees all, a barber sees their own, a client sees theirs.
create policy "tickets: owner reads" on public.tickets
  for select to authenticated
  using (public.is_shop_owner(shop_id));

create policy "tickets: barber reads own" on public.tickets
  for select to authenticated
  using (exists (
    select 1 from public.barbers b
    where b.id = barber_id and b.profile_id = (select auth.uid())
  ));

create policy "tickets: client reads own" on public.tickets
  for select to authenticated
  using (client_id = (select auth.uid()));

-- Owner-only for now; barbers will check out through a server function that
-- computes the commission itself (phase 1.3).
create policy "tickets: owner records" on public.tickets
  for insert to authenticated
  with check (public.is_shop_owner(shop_id));

-- queue: staff manage the line; a client joins and cancels their own spot in
-- an open, listed salon.
create policy "queue: staff" on public.queue
  for all to authenticated
  using (public.is_shop_staff(shop_id))
  with check (public.is_shop_staff(shop_id));

create policy "queue: client reads own" on public.queue
  for select to authenticated
  using (client_id = (select auth.uid()));

create policy "queue: client joins" on public.queue
  for insert to authenticated
  with check (
    client_id = (select auth.uid())
    and status = 'waiting'
    and exists (
      select 1 from public.shops s
      where s.id = shop_id and s.is_listed and s.is_open
    )
  );

create policy "queue: client cancels own" on public.queue
  for update to authenticated
  using (client_id = (select auth.uid()) and status = 'waiting')
  with check (client_id = (select auth.uid()) and status = 'cancelled');

-- =============================================================================
-- Realtime: stream the live floor, the line and the map.
-- (Realtime applies the policies above to each subscriber.)
-- =============================================================================

alter publication supabase_realtime add table
  public.shops, public.chairs, public.barbers, public.queue;

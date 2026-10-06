-- =============================================================================
-- BarberFlow cloud schema, roadmap phase 1.4 (sync between devices)
--
-- Run once in Supabase after 0001: SQL Editor → New query → paste → Run.
--
-- Devices keep a local copy and ask the server "what changed since T?".
-- * Every synced row gets `updated_at`, always set by the server clock so a
--   device with a wrong clock cannot hide or replay changes.
-- * Private side tables (barber_private, chair_clients) bump their parent row,
--   so a device only has to follow the parent.
-- * Deleted services and queue entries leave a tombstone in `sync_deletions`.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- updated_at, set by the server
-- -----------------------------------------------------------------------------

alter table public.shops          add column updated_at timestamptz not null default now();
alter table public.barbers        add column updated_at timestamptz not null default now();
alter table public.barber_private add column updated_at timestamptz not null default now();
alter table public.services       add column updated_at timestamptz not null default now();
alter table public.chairs         add column updated_at timestamptz not null default now();
alter table public.chair_clients  add column updated_at timestamptz not null default now();
alter table public.queue          add column updated_at timestamptz not null default now();
alter table public.tickets        add column updated_at timestamptz not null default now();

create function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array['shops', 'barbers', 'barber_private', 'services',
                           'chairs', 'chair_clients', 'queue', 'tickets']
  loop
    execute format(
      'create trigger %I before insert or update on public.%I
         for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t);
  end loop;
end;
$$;

-- Indexes for "changed since" queries.
create index barbers_sync_idx  on public.barbers  (shop_id, updated_at);
create index services_sync_idx on public.services (shop_id, updated_at);
create index chairs_sync_idx   on public.chairs   (shop_id, updated_at);
create index queue_sync_idx    on public.queue    (shop_id, updated_at);
create index tickets_sync_idx  on public.tickets  (shop_id, updated_at);

-- -----------------------------------------------------------------------------
-- Side tables bump their parent
-- -----------------------------------------------------------------------------

create function public.touch_barber_from_private()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.barbers set updated_at = now()
  where id = coalesce(new.barber_id, old.barber_id);
  return null;
end;
$$;

create trigger barber_private_touch_barber
  after insert or update or delete on public.barber_private
  for each row execute function public.touch_barber_from_private();

create function public.touch_chair_from_client()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.chairs set updated_at = now()
  where shop_id = coalesce(new.shop_id, old.shop_id)
    and chair_number = coalesce(new.chair_number, old.chair_number);
  return null;
end;
$$;

create trigger chair_clients_touch_chair
  after insert or update or delete on public.chair_clients
  for each row execute function public.touch_chair_from_client();

-- -----------------------------------------------------------------------------
-- Tombstones for deleted rows
-- -----------------------------------------------------------------------------

create table public.sync_deletions (
  id          bigint generated always as identity primary key,
  shop_id     uuid not null,
  table_name  text not null check (table_name in ('services', 'queue')),
  row_id      uuid not null,
  deleted_at  timestamptz not null default now()
);

create index sync_deletions_shop_idx on public.sync_deletions (shop_id, deleted_at);

create function public.record_deletion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Not when the whole salon is being deleted.
  if exists (select 1 from public.shops where id = old.shop_id) then
    insert into public.sync_deletions (shop_id, table_name, row_id)
    values (old.shop_id, tg_table_name, old.id);
  end if;
  return null;
end;
$$;

create trigger services_record_deletion after delete on public.services
  for each row execute function public.record_deletion();
create trigger queue_record_deletion after delete on public.queue
  for each row execute function public.record_deletion();

-- Tombstones of a deleted salon go with it.
create function public.forget_shop_deletions()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.sync_deletions where shop_id = old.id;
  return null;
end;
$$;

create trigger shops_forget_deletions after delete on public.shops
  for each row execute function public.forget_shop_deletions();

alter table public.sync_deletions enable row level security;

create policy "sync_deletions: staff reads" on public.sync_deletions
  for select to authenticated
  using (public.is_shop_staff(shop_id));

revoke insert, update, delete on public.sync_deletions from anon, authenticated;

revoke execute on function
  public.set_updated_at(),
  public.touch_barber_from_private(),
  public.touch_chair_from_client(),
  public.record_deletion(),
  public.forget_shop_deletions()
from public, anon, authenticated;

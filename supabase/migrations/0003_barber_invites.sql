-- =============================================================================
-- BarberFlow cloud schema, roadmap phase 2.1 (barbers join their salon)
--
-- Run once in Supabase after 0002: SQL Editor → New query → paste → Run.
--
-- The owner creates a code for one barber of the roster; that barber signs
-- up with a barber account and enters it, which links the account to that
-- roster entry (their chair, commission and history). Codes are single-use,
-- expire after 7 days and are created and checked only by the server.
-- =============================================================================

create table public.barber_invites (
  code        text primary key,
  barber_id   uuid not null unique references public.barbers (id) on delete cascade,
  shop_id     uuid not null references public.shops (id) on delete cascade,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '7 days'
);

alter table public.barber_invites enable row level security;

-- Owners see the codes of their salon; codes are written by the functions.
create policy "barber_invites: owner reads" on public.barber_invites
  for select to authenticated
  using (public.is_shop_owner(shop_id));

revoke insert, update, delete on public.barber_invites from anon, authenticated;

-- -----------------------------------------------------------------------------
-- Owner: create (or replace) the code for one barber
-- -----------------------------------------------------------------------------

create function public.create_barber_invite(p_barber_id uuid)
returns table (code text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  target record;
  -- No 0/O or 1/I, so codes can be read out loud.
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  new_code text;
begin
  select b.id, b.shop_id, b.profile_id, b.is_archived into target
  from public.barbers b
  where b.id = p_barber_id;

  if target.id is null or not public.is_shop_owner(target.shop_id) then
    raise exception 'Barber not found.' using errcode = 'P0001';
  end if;
  if target.is_archived then
    raise exception 'This barber is archived.' using errcode = 'P0001';
  end if;
  if target.profile_id is not null then
    raise exception 'This barber is already linked to an account.'
      using errcode = 'P0001';
  end if;

  delete from public.barber_invites where barber_id = p_barber_id;
  loop
    select string_agg(substr(alphabet, 1 + floor(random() * 32)::int, 1), '')
      into new_code
    from generate_series(1, 8);
    exit when not exists (
      select 1 from public.barber_invites i where i.code = new_code
    );
  end loop;

  return query
  insert into public.barber_invites (code, barber_id, shop_id)
  values (new_code, p_barber_id, target.shop_id)
  returning barber_invites.code, barber_invites.expires_at;
end;
$$;

-- -----------------------------------------------------------------------------
-- Barber: join with a code
-- -----------------------------------------------------------------------------

create function public.join_with_invite(p_code text)
returns table (barber_id uuid, shop_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  invite record;
begin
  if me is null then
    raise exception 'Sign in first.' using errcode = 'P0001';
  end if;
  if not public.current_role_is('barber') then
    raise exception 'Only barber accounts can join a salon.' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.barbers b where b.profile_id = me and not b.is_archived
  ) then
    raise exception 'Your account is already linked to a salon.'
      using errcode = 'P0001';
  end if;

  select i.barber_id, i.shop_id into invite
  from public.barber_invites i
  where i.code = upper(btrim(p_code)) and i.expires_at > now();

  if invite.barber_id is null then
    raise exception 'This code is not valid or has expired. Ask your salon for a new one.'
      using errcode = 'P0001';
  end if;

  update public.barbers b set profile_id = me
  where b.id = invite.barber_id and b.profile_id is null;
  if not found then
    raise exception 'This place is already taken. Ask your salon for a new code.'
      using errcode = 'P0001';
  end if;

  delete from public.barber_invites i where i.barber_id = invite.barber_id;
  return query select invite.barber_id, invite.shop_id;
end;
$$;

revoke execute on function public.create_barber_invite(uuid) from public, anon;
revoke execute on function public.join_with_invite(text) from public, anon;
grant execute on function public.create_barber_invite(uuid) to authenticated;
grant execute on function public.join_with_invite(text) to authenticated;

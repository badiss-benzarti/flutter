-- =============================================================================
-- BarberFlow cloud schema, roadmap phase 2.1 (barber onboarding, follow-up)
--
-- Run once in Supabase after 0003: SQL Editor → New query → paste → Run.
--
-- * The code comes first: before creating an account, a barber checks their
--   code and sees the salon and the name the owner registered for them.
-- * The roster name is the owner's: a barber can only ask for a change,
--   which the owner accepts or declines.
-- * A barber can leave the salon: their account stays, the link is removed,
--   and the roster entry with its history stays with the salon.
-- =============================================================================

-- A name the barber asked for, waiting for the owner's answer.
alter table public.barbers
  add column requested_name text
  check (requested_name is null or char_length(trim(requested_name)) between 1 and 60);

-- -----------------------------------------------------------------------------
-- Before sign-up: what does this code open?
-- -----------------------------------------------------------------------------

create function public.preview_invite(p_code text)
returns table (shop_name text, barber_name text, expires_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select s.name, b.name, i.expires_at
  from public.barber_invites i
  join public.barbers b on b.id = i.barber_id
  join public.shops s on s.id = i.shop_id
  where i.code = upper(btrim(p_code))
    and i.expires_at > now()
    and b.profile_id is null
    and not b.is_archived;
$$;

-- -----------------------------------------------------------------------------
-- Name changes: the barber asks, the owner decides
-- -----------------------------------------------------------------------------

create function public.request_name_change(p_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  wanted text := btrim(p_name);
begin
  if char_length(wanted) not between 1 and 60 then
    raise exception 'Enter a name of 1 to 60 characters.' using errcode = 'P0001';
  end if;

  update public.barbers
  set requested_name = case when name = wanted then null else wanted end
  where profile_id = (select auth.uid()) and not is_archived;

  if not found then
    raise exception 'You are not linked to a salon.' using errcode = 'P0001';
  end if;
end;
$$;

create function public.answer_name_change(p_barber_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target record;
begin
  select id, shop_id, requested_name into target
  from public.barbers
  where id = p_barber_id;

  if target.id is null or not public.is_shop_owner(target.shop_id) then
    raise exception 'Barber not found.' using errcode = 'P0001';
  end if;
  if target.requested_name is null then
    raise exception 'There is no name change to answer.' using errcode = 'P0001';
  end if;

  update public.barbers
  set name = case when p_accept then target.requested_name else name end,
      requested_name = null
  where id = p_barber_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- Leaving the salon
-- -----------------------------------------------------------------------------

create function public.leave_salon()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.barbers
  set profile_id = null, requested_name = null
  where profile_id = (select auth.uid()) and not is_archived;

  if not found then
    raise exception 'You are not linked to a salon.' using errcode = 'P0001';
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- Privileges
-- -----------------------------------------------------------------------------

-- Anyone may check a code before signing up; the rest needs an account.
revoke execute on function public.preview_invite(text) from public;
grant execute on function public.preview_invite(text) to anon, authenticated;

revoke execute on function
  public.request_name_change(text),
  public.answer_name_change(uuid, boolean),
  public.leave_salon()
from public, anon;
grant execute on function
  public.request_name_change(text),
  public.answer_name_change(uuid, boolean),
  public.leave_salon()
to authenticated;

-- =============================================================================
-- BarberFlow cloud schema, roadmap phase 2.2 (barbers switch their duty)
--
-- Run once in Supabase after 0004: SQL Editor → New query → paste → Run.
--
-- Going off duty frees the barber's chair, as in the owner app, and is
-- refused while they are serving a client. A barber may now release their
-- own chair, never take one.
-- =============================================================================

create or replace function public.guard_barber_self_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is not null
     and not public.is_shop_owner(old.shop_id)
     and (
       (new.name, new.specialty, new.is_archived)
         is distinct from (old.name, old.specialty, old.is_archived)
       -- Releasing their chair is fine; taking or moving one is not.
       or (new.assigned_chair is distinct from old.assigned_chair
           and new.assigned_chair is not null)
     )
  then
    raise exception 'Only the salon owner can change this.' using errcode = '42501';
  end if;
  return new;
end;
$$;

create function public.set_my_duty(p_on_duty boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  mine record;
begin
  select id, shop_id into mine
  from public.barbers
  where profile_id = (select auth.uid()) and not is_archived;

  if mine.id is null then
    raise exception 'You are not linked to a salon.' using errcode = 'P0001';
  end if;

  if p_on_duty then
    update public.barbers set is_on_duty = true where id = mine.id;
    return;
  end if;

  if exists (
    select 1 from public.chairs
    where active_barber_id = mine.id and status = 'occupied'
  ) then
    raise exception 'Check out your client before going off duty.'
      using errcode = 'P0001';
  end if;

  update public.chairs
  set status = 'empty', active_barber_id = null,
      active_ticket_id = null, service_start_time = null
  where active_barber_id = mine.id;

  update public.barbers
  set is_on_duty = false, assigned_chair = null
  where id = mine.id;
end;
$$;

revoke execute on function public.set_my_duty(boolean) from public, anon;
grant execute on function public.set_my_duty(boolean) to authenticated;

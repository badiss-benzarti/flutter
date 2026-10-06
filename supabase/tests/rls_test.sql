-- Security tests for the schema: each block acts as a given user and checks
-- what they can and cannot see or change. Run after the migrations; any
-- failed check stops the script. Everything is rolled back at the end.
\set ON_ERROR_STOP 1
\set QUIET 1
\o /dev/null

begin;

create schema tests;
grant usage on schema tests to anon, authenticated;

-- Fails unless running `q` raises an error.
create function tests.throws(q text) returns void language plpgsql as $$
begin
  begin
    execute q;
  exception when others then
    return;
  end;
  raise exception 'Expected an error but it succeeded: %', q;
end;
$$;

-- Fails unless `q` returns exactly `expected` rows.
create function tests.rows(q text, expected bigint, label text) returns void
language plpgsql as $$
declare n bigint;
begin
  execute 'select count(*) from (' || q || ') x' into n;
  if n <> expected then
    raise exception '%: expected % rows, got %', label, expected, n;
  end if;
end;
$$;

grant execute on all functions in schema tests to anon, authenticated;

-- Acts as the given user for the following statements (null = signed out).
create function tests.act_as(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(uid::text, ''), true);
  execute format('set local role %I', case when uid is null then 'anon' else 'authenticated' end);
end;
$$;

-- -----------------------------------------------------------------------------
-- Sign-ups
-- -----------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'owner@test',  '{"role":"owner","full_name":"Olfa"}'),
  ('00000000-0000-0000-0000-00000000000b', 'barber@test', '{"role":"barber","full_name":"Sami"}'),
  ('00000000-0000-0000-0000-00000000000c', 'client@test', '{"role":"client","full_name":"Chedi"}'),
  ('00000000-0000-0000-0000-00000000000d', 'rival@test',  '{"role":"owner","full_name":"Rival"}'),
  ('00000000-0000-0000-0000-00000000000e', 'sneaky@test', '{"role":"admin"}');

select tests.rows($$select 1 from profiles where id = '00000000-0000-0000-0000-00000000000e' and role = 'client'$$,
  1, 'unknown sign-up role becomes client');

-- -----------------------------------------------------------------------------
-- Owner sets up a salon
-- -----------------------------------------------------------------------------
select tests.act_as('00000000-0000-0000-0000-00000000000a');

insert into shops (id, owner_id, name, address, phone, total_chairs)
values ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000a',
        'Blade & Crown', 'Centre Ville', '71000000', 8);

select tests.rows($$select 1 from chairs where shop_id = '11111111-1111-1111-1111-111111111111'$$, 8, 'chairs created with the shop');
select tests.rows($$select 1 from shop_invites$$, 1, 'owner sees the invite code');

insert into barbers (id, shop_id, profile_id, name, specialty) values
  ('22222222-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   '00000000-0000-0000-0000-00000000000b', 'Sami', 'Fades'),
  ('22222222-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   null, 'Karim', 'Beards');
insert into barber_private (barber_id, phone, commission_rate) values
  ('22222222-0000-0000-0000-000000000001', '20000001', 0.6),
  ('22222222-0000-0000-0000-000000000002', '20000002', 0.5);
insert into services (shop_id, name, price, duration_minutes)
values ('11111111-1111-1111-1111-111111111111', 'Haircut', 25, 30);

select tests.throws($$update shops set is_listed = true where id = '11111111-1111-1111-1111-111111111111'$$);
update shops set latitude = 36.8, longitude = 10.18, is_listed = true
where id = '11111111-1111-1111-1111-111111111111';

select tests.throws($$update shops set waiting_count = 99$$);
select tests.throws($$update shops set owner_id = '00000000-0000-0000-0000-00000000000d'$$);
select tests.throws($$update profiles set role = 'client'$$);
select tests.throws($$insert into barber_private (barber_id, commission_rate) values ('22222222-0000-0000-0000-000000000003', 1.5)$$);

-- -----------------------------------------------------------------------------
-- A rival owner cannot touch it
-- -----------------------------------------------------------------------------
select tests.act_as('00000000-0000-0000-0000-00000000000d');

insert into shops (id, owner_id, name, total_chairs)
values ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-00000000000d', 'Rival Cuts', 4);
insert into barbers (id, shop_id, name)
values ('44444444-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'Rival barber');

select tests.rows($$select 1 from shop_invites$$, 1, 'rival sees only their own invite');
select tests.rows($$select 1 from barber_private$$, 0, 'rival cannot read phones or commissions');
select tests.throws($$insert into barbers (shop_id, name) values ('11111111-1111-1111-1111-111111111111', 'Spy')$$);
select tests.throws($$insert into shops (owner_id, name) values ('00000000-0000-0000-0000-00000000000a', 'Fake')$$);
update shops set name = 'Hacked' where id = '11111111-1111-1111-1111-111111111111';
update services set price = 0 where shop_id = '11111111-1111-1111-1111-111111111111';

-- -----------------------------------------------------------------------------
-- A client browses and joins the line
-- -----------------------------------------------------------------------------
select tests.act_as('00000000-0000-0000-0000-00000000000c');

select tests.throws($$insert into shops (owner_id, name) values ('00000000-0000-0000-0000-00000000000c', 'Not an owner')$$);
select tests.rows($$select 1 from shops$$, 1, 'client sees listed salons only');
select tests.rows($$select 1 from shops where name = 'Blade & Crown'$$, 1, 'rival could not rename the salon');
select tests.rows($$select 1 from services where price = 25$$, 1, 'rival could not change prices');
select tests.rows($$select 1 from barbers$$, 2, 'client sees the barbers');
select tests.rows($$select 1 from chairs$$, 8, 'client sees the live floor');
select tests.rows($$select 1 from barber_private$$, 0, 'client cannot read barber phones');
select tests.rows($$select 1 from chair_clients$$, 0, 'client cannot see who is seated');
select tests.rows($$select 1 from shop_invites$$, 0, 'client cannot read invite codes');

insert into queue (shop_id, client_id, client_name)
values ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000c', 'Chedi');
select tests.throws($$insert into queue (shop_id, client_id, client_name) values ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000c', 'Again')$$);
select tests.throws($$insert into queue (shop_id, client_id, client_name) values ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000e', 'Someone else')$$);
select tests.throws($$insert into queue (shop_id, client_id, client_name) values ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-00000000000c', 'Unlisted')$$);
select tests.throws($$insert into queue (shop_id, client_id, client_name, status) values ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000c', 'Skip', 'seated')$$);
select tests.rows($$select 1 from shops where waiting_count = 1$$, 1, 'waiting count follows the queue');
select tests.rows($$select 1 from queue$$, 1, 'client sees their own spot');

-- -----------------------------------------------------------------------------
-- Signed-out visitor
-- -----------------------------------------------------------------------------
select tests.act_as(null);

select tests.rows($$select 1 from shops$$, 1, 'visitor sees listed salons');
select tests.rows($$select 1 from queue$$, 0, 'visitor cannot see the line');
select tests.throws($$insert into queue (shop_id, client_name) values ('11111111-1111-1111-1111-111111111111', 'Anon')$$);

-- -----------------------------------------------------------------------------
-- The barber (joined account) runs their chair
-- -----------------------------------------------------------------------------
select tests.act_as('00000000-0000-0000-0000-00000000000b');

select tests.rows($$select 1 from queue$$, 1, 'barber sees the salon line');
select tests.rows($$select 1 from barber_private$$, 1, 'barber sees only their own commission');
select tests.rows($$select 1 from shop_invites$$, 0, 'barber cannot read the invite code');

update chairs set status = 'occupied', active_barber_id = '22222222-0000-0000-0000-000000000001',
                  service_start_time = now()
where shop_id = '11111111-1111-1111-1111-111111111111' and chair_number = 1;
select tests.throws($$update chairs set status = 'occupied', active_barber_id = '44444444-0000-0000-0000-000000000001' where shop_id = '11111111-1111-1111-1111-111111111111' and chair_number = 2$$);
select tests.throws($$update chairs set status = 'occupied' where shop_id = '11111111-1111-1111-1111-111111111111' and chair_number = 3$$);

update barbers set is_on_duty = false where id = '22222222-0000-0000-0000-000000000001';
select tests.throws($$update barbers set name = 'Boss' where id = '22222222-0000-0000-0000-000000000001'$$);
update barbers set is_on_duty = false where id = '22222222-0000-0000-0000-000000000002';
select tests.throws($$insert into tickets (shop_id, barber_id, client_name, chair_number, service_names, total_price, barber_cut, shop_cut, payment_method) values ('11111111-1111-1111-1111-111111111111', '22222222-0000-0000-0000-000000000001', 'X', 1, 'Haircut', 25, 25, 0, 'cash')$$);

-- -----------------------------------------------------------------------------
-- Back to the owner: checkout, capacity, finances
-- -----------------------------------------------------------------------------
select tests.act_as('00000000-0000-0000-0000-00000000000a');

select tests.rows($$select 1 from barbers where is_on_duty$$, 1, 'barber changed only their own duty');
select tests.throws($$insert into tickets (shop_id, barber_id, client_name, chair_number, service_names, total_price, barber_cut, shop_cut, payment_method) values ('11111111-1111-1111-1111-111111111111', '22222222-0000-0000-0000-000000000001', 'X', 1, 'Haircut', 25, 20, 20, 'cash')$$);
select tests.throws($$insert into tickets (shop_id, barber_id, client_name, chair_number, service_names, total_price, barber_cut, shop_cut, payment_method) values ('11111111-1111-1111-1111-111111111111', '44444444-0000-0000-0000-000000000001', 'X', 1, 'Haircut', 25, 15, 10, 'cash')$$);

insert into tickets (shop_id, barber_id, client_id, client_name, chair_number, service_names,
                     total_price, barber_cut, shop_cut, tip, payment_method) values
  ('11111111-1111-1111-1111-111111111111', '22222222-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-00000000000c', 'Chedi', 1, 'Haircut', 25, 15, 10, 2, 'cash'),
  ('11111111-1111-1111-1111-111111111111', '22222222-0000-0000-0000-000000000002',
   null, 'Walk-in', 2, 'Beard Trim', 15, 7.5, 7.5, 0, 'card');
select tests.throws($$update tickets set total_price = 0$$);
select tests.throws($$delete from tickets$$);

update chairs set status = 'occupied', active_barber_id = '22222222-0000-0000-0000-000000000002'
where shop_id = '11111111-1111-1111-1111-111111111111' and chair_number = 6;
select tests.throws($$update shops set total_chairs = 4 where id = '11111111-1111-1111-1111-111111111111'$$);
update chairs set status = 'empty', active_barber_id = null
where shop_id = '11111111-1111-1111-1111-111111111111' and chair_number = 6;
update barbers set assigned_chair = 7 where id = '22222222-0000-0000-0000-000000000002';
update shops set total_chairs = 4 where id = '11111111-1111-1111-1111-111111111111';
select tests.rows($$select 1 from chairs where shop_id = '11111111-1111-1111-1111-111111111111'$$, 4, 'chairs removed with capacity');
select tests.rows($$select 1 from barbers where assigned_chair is not null$$, 0, 'removed chair unassigned');
update shops set total_chairs = 6 where id = '11111111-1111-1111-1111-111111111111';
select tests.rows($$select 1 from chairs where shop_id = '11111111-1111-1111-1111-111111111111'$$, 6, 'chairs added with capacity');
select tests.rows($$select 1 from tickets$$, 2, 'owner sees all salon tickets');

select tests.act_as('00000000-0000-0000-0000-00000000000b');
select tests.rows($$select 1 from tickets$$, 1, 'barber sees only their own tickets');

select tests.act_as('00000000-0000-0000-0000-00000000000c');
select tests.rows($$select 1 from tickets$$, 1, 'client sees only their own visits');
update queue set status = 'cancelled';
select tests.rows($$select 1 from shops where waiting_count = 0$$, 1, 'cancelling frees the spot');
update queue set status = 'waiting';
select tests.rows($$select 1 from queue where status = 'waiting'$$, 0, 'a cancelled spot cannot be reopened');

-- Deleting a salon removes everything that belongs to it.
select tests.act_as('00000000-0000-0000-0000-00000000000a');
delete from shops where id = '11111111-1111-1111-1111-111111111111';
reset role;
select tests.rows($$select 1 from tickets$$, 0, 'tickets removed with the salon');
select tests.rows($$select 1 from chairs where shop_id = '11111111-1111-1111-1111-111111111111'$$, 0, 'chairs removed with the salon');

\o
\echo 'All RLS tests passed.'
rollback;

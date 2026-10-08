-- Tests for barbers switching their duty (migration 0005). Rolled back.
\set ON_ERROR_STOP 1
\set QUIET 1
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'owner@test', '{"role":"owner"}'),
  ('00000000-0000-0000-0000-00000000000b', 'sami@test',  '{"role":"barber"}'),
  ('00000000-0000-0000-0000-00000000000c', 'free@test',  '{"role":"barber"}');

select tests.act_as('00000000-0000-0000-0000-00000000000a');
insert into shops (id, owner_id, name, total_chairs)
values ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000a', 'Blade', 4);
insert into barbers (id, shop_id, profile_id, name, assigned_chair) values
  ('22222222-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   null, 'Sami', 1);
reset role;
update barbers set profile_id = '00000000-0000-0000-0000-00000000000b'
where id = '22222222-0000-0000-0000-000000000001';
update chairs set status = 'occupied', active_barber_id = '22222222-0000-0000-0000-000000000001',
                  service_start_time = now()
where shop_id = '11111111-1111-1111-1111-111111111111' and chair_number = 1;

-- Not while cutting.
select tests.act_as('00000000-0000-0000-0000-00000000000b');
select tests.throws($$select set_my_duty(false)$$);
select tests.rows($$select 1 from barbers where is_on_duty$$, 1, 'still on duty mid-service');

-- Once the client is checked out, going off duty frees the chair.
reset role;
update chairs set status = 'available', service_start_time = null
where shop_id = '11111111-1111-1111-1111-111111111111' and chair_number = 1;
select tests.act_as('00000000-0000-0000-0000-00000000000b');
select set_my_duty(false);
select tests.rows($$select 1 from barbers where not is_on_duty and assigned_chair is null$$,
  1, 'off duty, chair released');
select tests.rows($$select 1 from chairs where chair_number = 1 and status = 'empty' and active_barber_id is null$$,
  1, 'the chair is free on the floor');

-- Back on duty; taking a chair stays the owner's call.
select set_my_duty(true);
select tests.rows($$select 1 from barbers where is_on_duty$$, 1, 'back on duty');
select tests.throws($$update barbers set assigned_chair = 2 where id = '22222222-0000-0000-0000-000000000001'$$);
select tests.throws($$update barbers set name = 'Boss' where id = '22222222-0000-0000-0000-000000000001'$$);

-- Barbers without a salon get a clear refusal.
select tests.act_as('00000000-0000-0000-0000-00000000000c');
select tests.throws($$select set_my_duty(false)$$);
select tests.act_as(null);
select tests.throws($$select set_my_duty(false)$$);

\o
\echo 'All duty tests passed.'
rollback;

-- Tests for code-first onboarding, name changes and leaving (migration
-- 0004). Rolled back at the end.
\set ON_ERROR_STOP 1
\set QUIET 1
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'owner@test', '{"role":"owner"}'),
  ('00000000-0000-0000-0000-00000000000b', 'sami@test',  '{"role":"barber","full_name":"Sami"}'),
  ('00000000-0000-0000-0000-00000000000d', 'rival@test', '{"role":"owner"}');

select tests.act_as('00000000-0000-0000-0000-00000000000a');
insert into shops (id, owner_id, name, total_chairs)
values ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000a', 'Blade & Crown', 4);
insert into barbers (id, shop_id, name) values
  ('22222222-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Sami');
insert into tickets (shop_id, barber_id, client_name, chair_number, service_names,
                     total_price, barber_cut, shop_cut, payment_method) values
  ('11111111-1111-1111-1111-111111111111', '22222222-0000-0000-0000-000000000001',
   'Walk-in', 1, 'Haircut', 25, 15, 10, 'cash');
create temp table codes (code text);
grant all on codes to anon, authenticated;
insert into codes select code from create_barber_invite('22222222-0000-0000-0000-000000000001');

-- Before any account: the code shows the salon and the owner's name for it.
select tests.act_as(null);
select tests.rows($$select 1 from preview_invite(lower((select code from codes)))
                    where shop_name = 'Blade & Crown' and barber_name = 'Sami'$$,
  1, 'a visitor sees what the code opens');
select tests.rows($$select 1 from preview_invite('WRONG234')$$, 0, 'wrong codes show nothing');
select tests.throws($$select request_name_change('Samy')$$);
select tests.throws($$select leave_salon()$$);

-- Sami signs up and joins; the used code no longer previews.
select tests.act_as('00000000-0000-0000-0000-00000000000b');
select join_with_invite((select code from codes));
select tests.rows($$select 1 from preview_invite((select code from codes))$$, 0, 'used code shows nothing');

-- He can ask for another name, not set it.
select tests.throws($$update barbers set name = 'Samy' where id = '22222222-0000-0000-0000-000000000001'$$);
select tests.throws($$update barbers set requested_name = 'Samy' where id = '22222222-0000-0000-0000-000000000001'$$);
select tests.throws($$select request_name_change('   ')$$);
select request_name_change('  Samy ');
select tests.rows($$select 1 from barbers where name = 'Sami' and requested_name = 'Samy'$$,
  1, 'request waits for the owner');

-- Only his owner answers.
select tests.act_as('00000000-0000-0000-0000-00000000000d');
select tests.throws($$select answer_name_change('22222222-0000-0000-0000-000000000001', true)$$);

select tests.act_as('00000000-0000-0000-0000-00000000000a');
select answer_name_change('22222222-0000-0000-0000-000000000001', false);
select tests.rows($$select 1 from barbers where name = 'Sami' and requested_name is null$$,
  1, 'declined: name unchanged');

select tests.act_as('00000000-0000-0000-0000-00000000000b');
select request_name_change('Samy');
select tests.act_as('00000000-0000-0000-0000-00000000000a');
select answer_name_change('22222222-0000-0000-0000-000000000001', true);
select tests.rows($$select 1 from barbers where name = 'Samy' and requested_name is null$$,
  1, 'accepted: name changed');
select tests.throws($$select answer_name_change('22222222-0000-0000-0000-000000000001', true)$$);

-- Leaving: the account stays, the salon's data becomes invisible to him,
-- and the salon keeps the roster entry and its history.
select tests.act_as('00000000-0000-0000-0000-00000000000b');
select tests.rows($$select 1 from tickets$$, 1, 'linked barber sees his sales');
select leave_salon();
select tests.rows($$select 1 from tickets$$, 0, 'after leaving, his old sales are hidden');
select tests.rows($$select 1 from barbers where id = '22222222-0000-0000-0000-000000000001'$$,
  0, 'after leaving, the salon roster is hidden');
select tests.rows($$select 1 from profiles$$, 1, 'his account remains');
select tests.throws($$select leave_salon()$$);

select tests.act_as('00000000-0000-0000-0000-00000000000a');
select tests.rows($$select 1 from barbers where name = 'Samy' and profile_id is null$$,
  1, 'the roster entry stays, unlinked');
select tests.rows($$select 1 from tickets$$, 1, 'the salon keeps the history');

-- He can come back with a new code.
truncate codes;
insert into codes select code from create_barber_invite('22222222-0000-0000-0000-000000000001');
select tests.act_as('00000000-0000-0000-0000-00000000000b');
select tests.rows($$select 1 from join_with_invite((select code from codes))$$, 1, 'can join again');

\o
\echo 'All identity tests passed.'
rollback;

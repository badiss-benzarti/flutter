-- Tests for barber invitations (migration 0003). Rolled back at the end.
\set ON_ERROR_STOP 1
\set QUIET 1
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'owner@test',   '{"role":"owner"}'),
  ('00000000-0000-0000-0000-00000000000b', 'sami@test',    '{"role":"barber"}'),
  ('00000000-0000-0000-0000-00000000000c', 'client@test',  '{"role":"client"}'),
  ('00000000-0000-0000-0000-00000000000d', 'rival@test',   '{"role":"owner"}'),
  ('00000000-0000-0000-0000-00000000000e', 'karim@test',   '{"role":"barber"}');

select tests.act_as('00000000-0000-0000-0000-00000000000a');
insert into shops (id, owner_id, name, total_chairs)
values ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000a', 'Blade', 4);
insert into barbers (id, shop_id, name) values
  ('22222222-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Sami'),
  ('22222222-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Karim');
insert into barber_private (barber_id, phone, commission_rate) values
  ('22222222-0000-0000-0000-000000000001', '20000001', 0.6);
insert into tickets (shop_id, barber_id, client_name, chair_number, service_names,
                     total_price, barber_cut, shop_cut, payment_method) values
  ('11111111-1111-1111-1111-111111111111', '22222222-0000-0000-0000-000000000001',
   'Walk-in', 1, 'Haircut', 25, 15, 10, 'cash');

-- The owner creates a code; creating it again replaces the old one.
create temp table codes (barber text, code text);
grant all on codes to authenticated;
insert into codes select 'sami-old', code from create_barber_invite('22222222-0000-0000-0000-000000000001');
insert into codes select 'sami', code from create_barber_invite('22222222-0000-0000-0000-000000000001');
insert into codes select 'karim', code from create_barber_invite('22222222-0000-0000-0000-000000000002');
select tests.rows($$select 1 from barber_invites$$, 2, 'one live code per barber');
select tests.rows($$select 1 from codes where code ~ '^[A-HJ-NP-Z2-9]{8}$'$$, 3, 'codes are 8 readable characters');
select tests.throws($$insert into barber_invites (code, barber_id, shop_id) values ('AAAAAAAA', '22222222-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111')$$);

-- Nobody else can create codes for this salon, or read them.
select tests.act_as('00000000-0000-0000-0000-00000000000d');
select tests.throws($$select create_barber_invite('22222222-0000-0000-0000-000000000001')$$);
select tests.rows($$select 1 from barber_invites$$, 0, 'rival cannot read the codes');
select tests.act_as(null);
select tests.throws($$select create_barber_invite('22222222-0000-0000-0000-000000000001')$$);

-- A client account cannot use a code.
select tests.act_as('00000000-0000-0000-0000-00000000000c');
select tests.throws($$select join_with_invite((select code from codes where barber = 'sami'))$$);

-- Sami joins: wrong and replaced codes fail, the right one links him.
select tests.act_as('00000000-0000-0000-0000-00000000000b');
select tests.rows($$select 1 from barber_private$$, 0, 'before joining, nothing is visible');
select tests.throws($$select join_with_invite('WRONG234')$$);
select tests.throws($$select join_with_invite((select code from codes where barber = 'sami-old'))$$);
select tests.rows(
  $$select 1 from join_with_invite(lower(' ' || (select code from codes where barber = 'sami') || ' '))
    where barber_id = '22222222-0000-0000-0000-000000000001'$$,
  1, 'code is case and space tolerant, and links the roster entry');
select tests.rows($$select 1 from barber_private where commission_rate = 0.6$$, 1, 'Sami sees his commission');
select tests.rows($$select 1 from tickets$$, 1, 'Sami sees his own sales');
update barbers set is_on_duty = false where id = '22222222-0000-0000-0000-000000000001';
select tests.rows($$select 1 from barbers where id = '22222222-0000-0000-0000-000000000001' and not is_on_duty$$,
  1, 'Sami can switch himself off duty');

-- A linked barber cannot join twice, even with another valid code.
select tests.throws($$select join_with_invite((select code from codes where barber = 'karim'))$$);

-- Codes are single-use, and linked barbers get no new code.
select tests.act_as('00000000-0000-0000-0000-00000000000a');
select tests.rows($$select 1 from barber_invites where barber_id = '22222222-0000-0000-0000-000000000001'$$,
  0, 'used code is gone');
select tests.throws($$select create_barber_invite('22222222-0000-0000-0000-000000000001')$$);

-- Expired codes are refused.
reset role;
update barber_invites set expires_at = now() - interval '1 minute'
where barber_id = '22222222-0000-0000-0000-000000000002';
select tests.act_as('00000000-0000-0000-0000-00000000000e');
select tests.throws($$select join_with_invite((select code from codes where barber = 'karim'))$$);

\o
\echo 'All invite tests passed.'
rollback;

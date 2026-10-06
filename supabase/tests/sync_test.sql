-- Tests for the sync support (migration 0002): server-set timestamps, side
-- tables bumping their parent, and tombstones. Rolled back at the end.
\set ON_ERROR_STOP 1
\set QUIET 1
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'owner@test', '{"role":"owner"}'),
  ('00000000-0000-0000-0000-00000000000d', 'rival@test', '{"role":"owner"}');

select tests.act_as('00000000-0000-0000-0000-00000000000a');

insert into shops (id, owner_id, name, total_chairs)
values ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000a', 'Blade', 4);
insert into barbers (id, shop_id, name) values
  ('22222222-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Sami');
insert into barber_private (barber_id, phone) values
  ('22222222-0000-0000-0000-000000000001', '20000001');
insert into services (id, shop_id, name, price) values
  ('33333333-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Haircut', 25),
  ('33333333-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Beard', 15);
insert into queue (id, shop_id, client_name) values
  ('44444444-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Walk-in');

-- Age every row so changes are visible against "now" (triggers off, as
-- only an administrator can).
reset role;
set local session_replication_role = replica;
update barbers  set updated_at = '2000-01-01';
update services set updated_at = '2000-01-01';
update chairs   set updated_at = '2000-01-01';
set local session_replication_role = origin;

-- A device cannot choose the timestamp: the server clock wins.
select tests.act_as('00000000-0000-0000-0000-00000000000a');
update services set price = 30, updated_at = '2100-01-01'
where id = '33333333-0000-0000-0000-000000000001';
select tests.rows($$select 1 from services where updated_at = now()$$, 1, 'edited service gets the server time');
select tests.rows($$select 1 from services where updated_at = '2000-01-01'$$, 1, 'untouched service keeps its time');

-- Private side tables bump their parent row.
update barber_private set commission_rate = 0.5
where barber_id = '22222222-0000-0000-0000-000000000001';
select tests.rows($$select 1 from barbers where updated_at = now()$$, 1, 'commission change bumps the barber');

insert into chair_clients (shop_id, chair_number, client_name)
values ('11111111-1111-1111-1111-111111111111', 2, 'Chedi');
select tests.rows($$select 1 from chairs where updated_at = now()$$, 1, 'seating a client bumps the chair');

-- Deletions leave tombstones that only the salon's staff can read.
delete from services where id = '33333333-0000-0000-0000-000000000002';
delete from queue where id = '44444444-0000-0000-0000-000000000001';
select tests.rows($$select 1 from sync_deletions$$, 2, 'deletions are recorded');
select tests.rows($$select 1 from sync_deletions where table_name = 'services' and row_id = '33333333-0000-0000-0000-000000000002'$$,
  1, 'tombstone names the deleted row');
select tests.throws($$insert into sync_deletions (shop_id, table_name, row_id) values ('11111111-1111-1111-1111-111111111111', 'services', gen_random_uuid())$$);
select tests.throws($$delete from sync_deletions$$);

select tests.act_as('00000000-0000-0000-0000-00000000000d');
select tests.rows($$select 1 from sync_deletions$$, 0, 'rival cannot read tombstones');

-- Deleting the whole salon works and leaves nothing behind.
select tests.act_as('00000000-0000-0000-0000-00000000000a');
delete from shops where id = '11111111-1111-1111-1111-111111111111';
reset role;
select tests.rows($$select 1 from sync_deletions$$, 0, 'tombstones removed with the salon');
select tests.rows($$select 1 from services$$, 0, 'services removed with the salon');

\o
\echo 'All sync tests passed.'
rollback;

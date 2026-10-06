-- Test helpers shared by the *_test.sql files (see run.sh).

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

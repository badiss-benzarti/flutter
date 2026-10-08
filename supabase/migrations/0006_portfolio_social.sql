-- =============================================================================
-- BarberFlow cloud schema, roadmap 2.4 + social groundwork (phase 5)
--
-- Run once in Supabase after 0005: SQL Editor → New query → paste → Run.
--
-- * Barbers post photos of their cuts with a caption (client consent
--   required); the photos live in the public "portfolio" storage bucket,
--   each barber writing only in their own folder.
-- * Signed-in accounts comment on posts; client accounts rate a photo once
--   (1-5 stars). Each photo shows its own average.
-- * Clients rate a cut they really had (their ticket); only these ratings
--   make the barber's rating.
-- Counters and averages are kept by the server, never sent by the apps.
-- =============================================================================

-- The barber row of the signed-in account, if linked.
create function public.my_barber_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select id from public.barbers
  where profile_id = (select auth.uid()) and not is_archived
  limit 1;
$$;

-- -----------------------------------------------------------------------------
-- Barber rating, from real visits only
-- -----------------------------------------------------------------------------

alter table public.barbers
  add column rating_avg numeric(3, 2) not null default 0,
  add column rating_count int not null default 0;

-- -----------------------------------------------------------------------------
-- Posts
-- -----------------------------------------------------------------------------

create table public.portfolio_posts (
  id              uuid primary key default gen_random_uuid(),
  barber_id       uuid not null references public.barbers (id) on delete cascade,
  shop_id         uuid not null references public.shops (id) on delete cascade,
  image_path      text not null unique check (char_length(image_path) <= 200),
  caption         text not null default '' check (char_length(caption) <= 500),
  client_consent  boolean not null check (client_consent),
  rating_avg      numeric(3, 2) not null default 0,
  rating_count    int not null default 0,
  comment_count   int not null default 0,
  created_at      timestamptz not null default now()
);

create index portfolio_posts_barber_idx on public.portfolio_posts (barber_id, created_at desc);
create index portfolio_posts_shop_idx on public.portfolio_posts (shop_id, created_at desc);

-- The salon and counters come from the server, whatever the app sends.
create function public.prepare_post()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.shop_id := (select shop_id from public.barbers where id = new.barber_id);
  new.rating_avg := 0;
  new.rating_count := 0;
  new.comment_count := 0;
  new.created_at := now();
  return new;
end;
$$;

create trigger portfolio_posts_prepare before insert on public.portfolio_posts
  for each row execute function public.prepare_post();

-- -----------------------------------------------------------------------------
-- Comments
-- -----------------------------------------------------------------------------

create table public.post_comments (
  id           uuid primary key default gen_random_uuid(),
  post_id      uuid not null references public.portfolio_posts (id) on delete cascade,
  author_id    uuid not null references public.profiles (id) on delete cascade,
  author_name  text not null default '',
  body         text not null check (char_length(btrim(body)) between 1 and 500),
  created_at   timestamptz not null default now()
);

create index post_comments_post_idx on public.post_comments (post_id, created_at);

-- Author and name are the signed-in account's, never chosen by the app.
create function public.prepare_comment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.author_id := (select auth.uid());
  if new.author_id is null then
    raise exception 'Sign in to comment.' using errcode = 'P0001';
  end if;
  new.author_name := coalesce(
    nullif(btrim((select full_name from public.profiles where id = new.author_id)), ''),
    'Client'
  );
  new.body := btrim(new.body);
  new.created_at := now();
  return new;
end;
$$;

create trigger post_comments_prepare before insert on public.post_comments
  for each row execute function public.prepare_comment();

-- -----------------------------------------------------------------------------
-- Photo ratings (each photo's own stars)
-- -----------------------------------------------------------------------------

create table public.post_ratings (
  post_id     uuid not null references public.portfolio_posts (id) on delete cascade,
  client_id   uuid not null references public.profiles (id) on delete cascade,
  stars       smallint not null check (stars between 1 and 5),
  created_at  timestamptz not null default now(),
  primary key (post_id, client_id)
);

-- -----------------------------------------------------------------------------
-- Visit ratings (the barber's rating)
-- -----------------------------------------------------------------------------

create table public.visit_ratings (
  ticket_id   uuid primary key references public.tickets (id) on delete cascade,
  barber_id   uuid not null references public.barbers (id) on delete cascade,
  shop_id     uuid not null references public.shops (id) on delete cascade,
  client_id   uuid not null references public.profiles (id) on delete cascade,
  stars       smallint not null check (stars between 1 and 5),
  comment     text check (char_length(comment) <= 500),
  created_at  timestamptz not null default now()
);

create index visit_ratings_barber_idx on public.visit_ratings (barber_id);

-- Only the client of a real, recent cut can rate it; barber and salon come
-- from the ticket.
create function public.prepare_visit_rating()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  t record;
begin
  select id, barber_id, shop_id, client_id, created_at into t
  from public.tickets
  where id = new.ticket_id;

  if t.id is null or t.client_id is distinct from (select auth.uid()) then
    raise exception 'You can only rate a cut you had.' using errcode = 'P0001';
  end if;
  if t.created_at < now() - interval '30 days' then
    raise exception 'This visit is too old to rate.' using errcode = 'P0001';
  end if;

  new.barber_id := t.barber_id;
  new.shop_id := t.shop_id;
  new.client_id := t.client_id;
  new.created_at := now();
  return new;
end;
$$;

create trigger visit_ratings_prepare before insert on public.visit_ratings
  for each row execute function public.prepare_visit_rating();

-- -----------------------------------------------------------------------------
-- Counters and averages
-- -----------------------------------------------------------------------------

create function public.refresh_post_counters()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target uuid := coalesce(new.post_id, old.post_id);
begin
  update public.portfolio_posts p set
    comment_count = (select count(*) from public.post_comments c where c.post_id = target),
    rating_count = (select count(*) from public.post_ratings r where r.post_id = target),
    rating_avg = coalesce(
      (select round(avg(r.stars), 2) from public.post_ratings r where r.post_id = target),
      0
    )
  where p.id = target;
  return null;
end;
$$;

create trigger post_comments_count after insert or delete on public.post_comments
  for each row execute function public.refresh_post_counters();
create trigger post_ratings_count after insert or update or delete on public.post_ratings
  for each row execute function public.refresh_post_counters();

create function public.refresh_barber_rating()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target uuid := coalesce(new.barber_id, old.barber_id);
begin
  update public.barbers b set
    rating_count = (select count(*) from public.visit_ratings v where v.barber_id = target),
    rating_avg = coalesce(
      (select round(avg(v.stars), 2) from public.visit_ratings v where v.barber_id = target),
      0
    )
  where b.id = target;
  return null;
end;
$$;

create trigger visit_ratings_refresh after insert or update or delete on public.visit_ratings
  for each row execute function public.refresh_barber_rating();

-- -----------------------------------------------------------------------------
-- Privileges and row-level security
-- -----------------------------------------------------------------------------

-- Ratings and counters are server-made; barbers' new columns are read-only.
revoke update on public.portfolio_posts from anon, authenticated;
grant update (caption) on public.portfolio_posts to authenticated;
revoke update on public.post_comments from anon, authenticated;
revoke update on public.post_ratings from anon, authenticated;
grant update (stars) on public.post_ratings to authenticated;
revoke update on public.visit_ratings from anon, authenticated;
grant update (stars, comment) on public.visit_ratings to authenticated;
revoke insert, update, delete on
  public.portfolio_posts, public.post_comments, public.post_ratings,
  public.visit_ratings
from anon;

alter table public.portfolio_posts enable row level security;
alter table public.post_comments   enable row level security;
alter table public.post_ratings    enable row level security;
alter table public.visit_ratings   enable row level security;

-- Posts: public in listed salons; the barber manages theirs; the owner may
-- remove any post of the salon.
create policy "posts: read listed or staff" on public.portfolio_posts
  for select to anon, authenticated
  using (public.is_listed_shop(shop_id) or public.is_shop_staff(shop_id));

create policy "posts: barber publishes" on public.portfolio_posts
  for insert to authenticated
  with check (barber_id = public.my_barber_id());

create policy "posts: barber edits caption" on public.portfolio_posts
  for update to authenticated
  using (barber_id = public.my_barber_id())
  with check (barber_id = public.my_barber_id());

create policy "posts: barber or owner deletes" on public.portfolio_posts
  for delete to authenticated
  using (barber_id = public.my_barber_id() or public.is_shop_owner(shop_id));

-- Comments: visible with their post; any signed-in account comments; the
-- author, the post's barber and the salon owner can remove one.
create policy "comments: read with the post" on public.post_comments
  for select to anon, authenticated
  using (exists (select 1 from public.portfolio_posts p where p.id = post_id));

create policy "comments: signed-in accounts write" on public.post_comments
  for insert to authenticated
  with check (exists (select 1 from public.portfolio_posts p where p.id = post_id));

create policy "comments: author, barber or owner deletes" on public.post_comments
  for delete to authenticated
  using (
    author_id = (select auth.uid())
    or exists (
      select 1 from public.portfolio_posts p
      where p.id = post_id
        and (p.barber_id = public.my_barber_id() or public.is_shop_owner(p.shop_id))
    )
  );

-- Photo ratings: client accounts, one per photo, private to their author
-- (everyone sees the average on the post).
create policy "post ratings: own" on public.post_ratings
  for select to authenticated
  using (client_id = (select auth.uid()));

create policy "post ratings: clients rate" on public.post_ratings
  for insert to authenticated
  with check (
    client_id = (select auth.uid())
    and public.current_role_is('client')
    and exists (select 1 from public.portfolio_posts p where p.id = post_id)
  );

create policy "post ratings: change own" on public.post_ratings
  for update to authenticated
  using (client_id = (select auth.uid()))
  with check (client_id = (select auth.uid()));

create policy "post ratings: remove own" on public.post_ratings
  for delete to authenticated
  using (client_id = (select auth.uid()));

-- Visit ratings: the client who had the cut; read by them, the barber and
-- the owner.
create policy "visit ratings: read" on public.visit_ratings
  for select to authenticated
  using (
    client_id = (select auth.uid())
    or barber_id = public.my_barber_id()
    or public.is_shop_owner(shop_id)
  );

create policy "visit ratings: client rates" on public.visit_ratings
  for insert to authenticated
  with check (client_id = (select auth.uid()));

create policy "visit ratings: client edits" on public.visit_ratings
  for update to authenticated
  using (client_id = (select auth.uid()))
  with check (client_id = (select auth.uid()));

revoke execute on function
  public.prepare_post(),
  public.prepare_comment(),
  public.prepare_visit_rating(),
  public.refresh_post_counters(),
  public.refresh_barber_rating()
from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- Photo storage: public bucket, each barber writes in their own folder
-- (<barber id>/<file>), the owner can clean up their salon's files.
-- -----------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('portfolio', 'portfolio', true, 1048576,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- The bucket is public; reading is also needed to delete through the API.
create policy "portfolio: anyone reads" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'portfolio');

create policy "portfolio: barbers upload to their folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'portfolio'
    and (storage.foldername(name))[1] = public.my_barber_id()::text
  );

create policy "portfolio: barbers or owners delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'portfolio'
    and (
      (storage.foldername(name))[1] = public.my_barber_id()::text
      or exists (
        select 1 from public.barbers b
        -- objects.name: barbers has a name column of its own.
        where b.id::text = (storage.foldername(objects.name))[1]
          and public.is_shop_owner(b.shop_id)
      )
    )
  );

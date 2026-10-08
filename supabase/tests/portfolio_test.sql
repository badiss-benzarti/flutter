-- Tests for portfolios, comments and ratings (migration 0006). Rolled back.
\set ON_ERROR_STOP 1
\set QUIET 1
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'owner@test',  '{"role":"owner"}'),
  ('00000000-0000-0000-0000-00000000000b', 'sami@test',   '{"role":"barber"}'),
  ('00000000-0000-0000-0000-00000000000c', 'chedi@test',  '{"role":"client","full_name":"Chedi"}'),
  ('00000000-0000-0000-0000-00000000000e', 'karim@test',  '{"role":"barber"}'),
  ('00000000-0000-0000-0000-00000000000f', 'other@test',  '{"role":"client","full_name":"Other"}');

select tests.act_as('00000000-0000-0000-0000-00000000000a');
insert into shops (id, owner_id, name, total_chairs, latitude, longitude)
values ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000a', 'Blade', 4, 36.8, 10.18);
insert into barbers (id, shop_id, name) values
  ('22222222-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Sami'),
  ('22222222-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Karim');
insert into tickets (id, shop_id, barber_id, client_id, client_name, chair_number,
                     service_names, total_price, barber_cut, shop_cut, payment_method) values
  ('55555555-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   '22222222-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000c',
   'Chedi', 1, 'Haircut', 25, 15, 10, 'cash'),
  ('55555555-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   '22222222-0000-0000-0000-000000000001', null, 'Walk-in', 1, 'Haircut', 25, 15, 10, 'cash');
reset role;
update barbers set profile_id = '00000000-0000-0000-0000-00000000000b' where name = 'Sami';
update barbers set profile_id = '00000000-0000-0000-0000-00000000000e' where name = 'Karim';

-- Sami posts in his own name only, with consent; server fills the rest.
select tests.act_as('00000000-0000-0000-0000-00000000000b');
insert into portfolio_posts (id, barber_id, shop_id, image_path, caption, client_consent, rating_avg, comment_count)
values ('66666666-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000001',
        '33333333-3333-3333-3333-333333333333', '22222222-0000-0000-0000-000000000001/a.jpg',
        'Skin fade', true, 5, 99);
select tests.rows($$select 1 from portfolio_posts
                    where shop_id = '11111111-1111-1111-1111-111111111111'
                      and rating_avg = 0 and comment_count = 0$$,
  1, 'salon and counters come from the server');
select tests.throws($$insert into portfolio_posts (barber_id, shop_id, image_path, client_consent) values ('22222222-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '22222222-0000-0000-0000-000000000001/b.jpg', false)$$);
select tests.throws($$insert into portfolio_posts (barber_id, shop_id, image_path, client_consent) values ('22222222-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', '22222222-0000-0000-0000-000000000002/x.jpg', true)$$);
update portfolio_posts set caption = 'Skin fade, mid' where id = '66666666-0000-0000-0000-000000000001';
select tests.throws($$update portfolio_posts set rating_avg = 5$$);

-- Photos: only in his own folder.
select tests.throws($$insert into storage.objects (bucket_id, name) values ('portfolio', '22222222-0000-0000-0000-000000000002/x.jpg')$$);
insert into storage.objects (bucket_id, name)
values ('portfolio', '22222222-0000-0000-0000-000000000001/a.jpg');

-- Not visible to visitors until the salon is listed.
select tests.act_as(null);
select tests.rows($$select 1 from portfolio_posts$$, 0, 'unlisted salon: posts hidden');
reset role;
update shops set is_listed = true;
select tests.act_as(null);
select tests.rows($$select 1 from portfolio_posts$$, 1, 'listed salon: posts public');
select tests.throws($$insert into post_comments (post_id, body) values ('66666666-0000-0000-0000-000000000001', 'hi')$$);

-- Clients comment (signed with their real name) and rate once.
select tests.act_as('00000000-0000-0000-0000-00000000000c');
insert into post_comments (post_id, author_id, author_name, body)
values ('66666666-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000f', 'Fake', '  Clean work  ');
select tests.rows($$select 1 from post_comments
                    where author_id = '00000000-0000-0000-0000-00000000000c'
                      and author_name = 'Chedi' and body = 'Clean work'$$,
  1, 'the server signs the comment');
insert into post_ratings (post_id, client_id, stars)
values ('66666666-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000c', 5);
select tests.throws($$insert into post_ratings (post_id, client_id, stars) values ('66666666-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000c', 4)$$);
select tests.throws($$insert into post_ratings (post_id, client_id, stars) values ('66666666-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000f', 1)$$);
select tests.throws($$insert into post_ratings (post_id, client_id, stars) values ('66666666-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000c', 6)$$);

select tests.act_as('00000000-0000-0000-0000-00000000000f');
insert into post_ratings (post_id, client_id, stars)
values ('66666666-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000f', 2);
select tests.rows($$select 1 from post_ratings$$, 1, 'a client sees only their own rating');
select tests.rows($$select 1 from portfolio_posts where rating_avg = 3.5 and rating_count = 2 and comment_count = 1$$,
  1, 'photo average and counters');

-- Barbers do not rate photos.
select tests.act_as('00000000-0000-0000-0000-00000000000e');
select tests.throws($$insert into post_ratings (post_id, client_id, stars) values ('66666666-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000e', 5)$$);

-- The barber's rating: only clients of a real cut, which sets his average.
select tests.act_as('00000000-0000-0000-0000-00000000000f');
select tests.throws($$insert into visit_ratings (ticket_id, barber_id, shop_id, client_id, stars) values ('55555555-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000f', 1)$$);
select tests.throws($$insert into visit_ratings (ticket_id, barber_id, shop_id, client_id, stars) values ('55555555-0000-0000-0000-000000000002', '22222222-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000f', 1)$$);
select tests.act_as('00000000-0000-0000-0000-00000000000c');
insert into visit_ratings (ticket_id, barber_id, shop_id, client_id, stars, comment)
values ('55555555-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000002',
        '11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000c', 4, 'Great');
select tests.rows($$select 1 from barbers where name = 'Sami' and rating_avg = 4 and rating_count = 1$$,
  1, 'barber rating from visits (barber taken from the ticket)');
select tests.rows($$select 1 from barbers where name = 'Karim' and rating_count = 0$$,
  1, 'photo ratings do not touch the barber rating');
select tests.throws($$insert into visit_ratings (ticket_id, barber_id, shop_id, client_id, stars) values ('55555555-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000c', 5)$$);
update visit_ratings set stars = 5;
select tests.rows($$select 1 from barbers where name = 'Sami' and rating_avg = 5$$, 1, 'editing updates the average');
select tests.throws($$update barbers set rating_avg = 1$$);

select tests.act_as('00000000-0000-0000-0000-00000000000b');
select tests.rows($$select 1 from visit_ratings$$, 1, 'Sami reads his visit ratings');
select tests.act_as('00000000-0000-0000-0000-00000000000e');
select tests.rows($$select 1 from visit_ratings$$, 0, 'Karim does not read them');

-- Moderation: Sami removes a comment on his post; Karim cannot.
delete from post_comments;
select tests.act_as('00000000-0000-0000-0000-00000000000b');
select tests.rows($$select 1 from post_comments$$, 1, 'Karim could not delete it');
delete from post_comments;
select tests.rows($$select 1 from portfolio_posts where comment_count = 0$$, 1, 'comment count follows');

-- Deleting: Karim cannot remove Sami's post or photo; the owner can.
select tests.act_as('00000000-0000-0000-0000-00000000000e');
delete from portfolio_posts;
delete from storage.objects;
reset role;
select tests.rows($$select 1 from portfolio_posts$$, 1, 'post still there');
select tests.rows($$select 1 from storage.objects$$, 1, 'photo still there');
select tests.act_as('00000000-0000-0000-0000-00000000000a');
delete from storage.objects where name = '22222222-0000-0000-0000-000000000001/a.jpg';
delete from portfolio_posts;
reset role;
select tests.rows($$select 1 from portfolio_posts$$, 0, 'owner removed the post');
select tests.rows($$select 1 from storage.objects$$, 0, 'owner removed the photo');
select tests.rows($$select 1 from post_ratings$$, 0, 'ratings went with the post');

\o
\echo 'All portfolio tests passed.'
rollback;

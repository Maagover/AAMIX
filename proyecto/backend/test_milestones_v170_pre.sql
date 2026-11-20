create temp table qa_people(slot integer primary key,id uuid default gen_random_uuid());
insert into qa_people(slot) values(1),(2),(3);
insert into auth.users(id,aud,role,email,email_confirmed_at,raw_user_meta_data,raw_app_meta_data,created_at,updated_at)
select id,'authenticated','authenticated','qa-milestones-v170-'||id||'@example.invalid',now(),'{"display_name":"Prueba hitos"}','{"provider":"email","providers":["email"]}',now(),now() from qa_people;
insert into public.aamix_rewards_state(user_id) select id from qa_people;
-- A prior canonical redemption must receive its new portrait without new cards.
insert into public.aamix_code_redemptions(user_id,gift_code) select id,'B1G0T3S' from qa_people where slot=3;
insert into public.aamix_collection(user_id,code,quantity) select id,'01b',3 from qa_people where slot=3;
update public.aamix_rewards_state set avatar_code='0112' where user_id=(select id from qa_people where slot=3);

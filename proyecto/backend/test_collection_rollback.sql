-- Real PostgreSQL test. Every fixture and award rolls back; no emails/tokens.
begin;
insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,is_anonymous)
values ('a0900000-0000-4000-8000-000000000001','aamix-qa-a@example.invalid',now(),now()-interval '1 day',now(),false),
       ('a0900000-0000-4000-8000-000000000002','aamix-qa-b@example.invalid',now(),now(),now(),false),
       ('a0900000-0000-4000-8000-000000000003','aamix-qa-c@example.invalid',null,now(),now(),false);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0900000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $$
declare result jsonb; original jsonb;
begin
  result := public.aamix_inventory();
  assert result->'gift' = 'null'::jsonb, 'Old verified account eligible';
  assert result->'collection' = '{}'::jsonb;
  begin perform public.aamix_claim_starter('invented'); raise exception 'Unknown deck accepted'; exception when invalid_parameter_value then null; end;
  result := public.aamix_claim_starter('kajido');
  assert (result->>'already_claimed')::boolean = false;
  assert (select sum(value::integer) from jsonb_each_text(result->'collection')) = 40;
  assert (result->'collection'->>'0100')::integer = 18;
  assert jsonb_array_length(result->'decks') = 1;
  assert result->'decks'->0->>'id' = 'kajido';
  original := result - 'already_claimed';
  for i in 1..20 loop
    result := public.aamix_claim_starter('flaan');
    assert result->>'already_claimed' = 'true';
    assert result - 'already_claimed' = original, 'Retries changed award';
  end loop;
  assert public.aamix_inventory() = original, 'Re-entry inventory differs';
  begin insert into public.aamix_collection values ('a0900000-0000-4000-8000-000000000001','0100',999); raise exception 'Direct award accepted'; exception when insufficient_privilege then null; end;
  begin update public.aamix_owned_decks set name='forged'; raise exception 'Direct deck update accepted'; exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claims','{"sub":"a0900000-0000-4000-8000-000000000002","role":"authenticated"}',true);
  result := public.aamix_inventory();
  assert result->'collection' = '{}'::jsonb, 'Cross UUID inventory leak';
  assert (select count(*) from public.aamix_collection) = 0, 'Direct SELECT bypassed RLS';
  result := public.aamix_claim_starter('papito');
  assert result->'decks'->0->>'id' = 'papito';
  assert (select sum(value::integer) from jsonb_each_text(result->'collection')) = 40;
  assert (result->'collection'->>'0100')::integer = 18;
  perform set_config('request.jwt.claims','{"sub":"a0900000-0000-4000-8000-000000000003","role":"authenticated"}',true);
  begin perform public.aamix_claim_starter('flaan'); raise exception 'Unconfirmed email accepted'; exception when invalid_authorization_specification then null; end;
  perform set_config('request.jwt.claims','{}',true);
  begin perform public.aamix_inventory(); raise exception 'Missing UUID accepted'; exception when invalid_authorization_specification then null; end;
end $$;
reset role;
update auth.users set email_confirmed_at=now() where id='a0900000-0000-4000-8000-000000000003';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0900000-0000-4000-8000-000000000003","role":"authenticated"}',true);
do $$
declare result jsonb;
begin
  result := public.aamix_claim_starter('flaan');
  assert result->'decks'->0->>'id' = 'flaan';
  assert (select sum(value::integer) from jsonb_each_text(result->'collection')) = 40;
  assert (result->'collection'->>'0100')::integer = 18;
end $$;
reset role;
do $$
declare row record;
begin
  for row in select d.cards,t.cards as expected from public.aamix_owned_decks d join aamix_private.base_decks t on t.id=d.deck_id where d.user_id::text like 'a0900000-%' loop
    assert row.cards = row.expected, 'Deck contents changed';
  end loop;
  for row in select d.user_id,d.cards from public.aamix_owned_decks d where d.user_id::text like 'a0900000-%' loop
    assert (select jsonb_object_agg(code,quantity) from public.aamix_collection c where c.user_id=row.user_id) = (select jsonb_object_agg(e->>'codigo',(e->>'cantidad')::integer) from jsonb_array_elements(row.cards) e), 'Collection quantities differ from exact saved deck';
  end loop;
  assert not has_function_privilege('anon','public.aamix_claim_starter(text)','execute');
  assert not has_function_privilege('anon','public.aamix_inventory()','execute');
  assert not has_table_privilege('authenticated','aamix_private.base_decks','select');
  assert (select count(*) from public.aamix_starter_gifts where user_id::text like 'a0900000-%')=3;
end $$;
rollback;
select 'PASS: exact three decks, 20 retries, reentry, RLS, denied writes, email verification, no committed test data' as validation;

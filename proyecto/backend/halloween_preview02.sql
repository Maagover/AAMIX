-- Additive revision of the already-authorized isolated Halloween service only.
-- No official AAMIX tables, identities, balances or existing preview rewards reset.
alter table aamix_hw01_private.hw_wallet alter column halloween_packs set default 0;
alter table aamix_hw01.aamix_pack_openings add column pack_count integer not null default 1 check(pack_count between 1 and 10000);
alter table aamix_hw01.aamix_pack_openings drop constraint aamix_opening_new_indices;
alter table aamix_hw01.aamix_pack_openings add constraint aamix_opening_new_indices check(new_card_indices is not null and array_position(new_card_indices,null) is null and 0<=all(new_card_indices) and jsonb_array_length(cards)>all(new_card_indices));

create function aamix_hw01_private.draw_halloween_card() returns jsonb language sql volatile set search_path='' as $$
 select jsonb_build_array(case when ticket>=9500 then 'H05' else 'H0'||(ticket/2375+1)::text end)
 from(select floor(random()*10000)::integer ticket)s
$$;
revoke all on function aamix_hw01_private.draw_halloween_card() from public,anon,authenticated;

create function aamix_hw01_private.open_pack_bundle(p_request_id uuid,p_kind text) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare uid uuid:=aamix_hw01_private.lock_rewards();opening aamix_hw01.aamix_pack_openings%rowtype;amount integer;drawn jsonb;indices integer[];
begin
 if p_request_id is null or p_kind is null or p_kind not in('tc','normal_card','halloween') then raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023';end if;
 select o.* into opening from aamix_hw01.aamix_pack_requests r join aamix_hw01.aamix_pack_openings o on o.opening_id=r.opening_id where r.user_id=uid and r.request_id=p_request_id and o.user_id=uid;
 if not found then
  select * into opening from aamix_hw01.aamix_pack_openings where user_id=uid and revealed_at is null;
  if not found then
   if p_kind='halloween' then
    select halloween_packs into amount from aamix_hw01_private.hw_wallet where user_id=uid for update;
   else
    select case when p_kind='tc' then packs else normal_packs end into amount from aamix_hw01.aamix_rewards_state where user_id=uid;
   end if;
   if amount is null or amount<=0 then raise exception 'AAMIX_NO_PACKS' using errcode='22023';end if;
   -- Large inventories can be consumed in groups; ordinary balances open all.
   amount:=least(amount,10000);
   select jsonb_agg(c.value order by p.i,c.ordinality) into drawn from generate_series(1,amount)p(i)
    cross join lateral jsonb_array_elements(case when p.i>0 then case p_kind when 'tc' then aamix_hw01_private.draw_pack() when 'normal_card' then aamix_hw01_private.draw_normal_card() else aamix_hw01_private.draw_halloween_card() end else '[]'::jsonb end) with ordinality c(value,ordinality);
   select coalesce(array_agg(first_index order by first_index),'{}'::integer[]) into indices from(
    select distinct on(c.code)c.code,(c.ord-1)::integer first_index from jsonb_array_elements_text(drawn) with ordinality c(code,ord)
    where not exists(select 1 from aamix_hw01.aamix_collection owned where owned.user_id=uid and owned.code=c.code and quantity>0)
    order by c.code,c.ord
   )first_copies;
   if p_kind='halloween' then update aamix_hw01_private.hw_wallet set halloween_packs=halloween_packs-amount where user_id=uid;
   elsif p_kind='tc' then update aamix_hw01.aamix_rewards_state set packs=packs-amount where user_id=uid;
   else update aamix_hw01.aamix_rewards_state set normal_packs=normal_packs-amount where user_id=uid;end if;
   insert into aamix_hw01.aamix_pack_openings(user_id,request_id,kind,cards,rules_version,new_card_indices,pack_count)
    values(uid,p_request_id,p_kind,drawn,'halloween-preview2-bundle',indices,amount) returning * into opening;
   insert into aamix_hw01.aamix_collection(user_id,code,quantity)
    select uid,code,count(*)::integer from jsonb_array_elements_text(drawn)c(code) group by code order by code
    on conflict(user_id,code) do update set quantity=aamix_hw01.aamix_collection.quantity+excluded.quantity;
  end if;
 end if;
 insert into aamix_hw01.aamix_pack_requests(user_id,request_id,opening_id) values(uid,p_request_id,opening.opening_id) on conflict do nothing;
 return aamix_hw01.aamix_inventory()||jsonb_build_object('opening',jsonb_build_object('opening_id',opening.opening_id,'kind',opening.kind,'cards',opening.cards,'pack_count',opening.pack_count,'new_card_indices',to_jsonb(opening.new_card_indices),'opened_at',opening.opened_at,'revealed_at',opening.revealed_at));
end$$;
create function aamix_hw01.aamix_open_all_packs(p_request_id uuid,p_kind text) returns jsonb language sql security invoker set search_path='' as $$select aamix_hw01_private.open_pack_bundle(p_request_id,p_kind)$$;
revoke all on function aamix_hw01_private.open_pack_bundle(uuid,text),aamix_hw01.aamix_open_all_packs(uuid,text) from public,anon,authenticated;
grant execute on function aamix_hw01_private.open_pack_bundle(uuid,text),aamix_hw01.aamix_open_all_packs(uuid,text) to authenticated;

-- Include batch metadata in inventory and in all legacy single-pack resume replies.
do $$declare f record;definition text;patched text;begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where(n.nspname='aamix_hw01' and p.proname='aamix_inventory') or(n.nspname='aamix_hw01_private' and p.proname in('open_pack_kind','open_halloween_pack')) loop
  definition:=pg_get_functiondef(f.oid);
  if definition like '%opening.pack_count%' or definition like '%''pack_count'',pack_count%' then raise exception 'Batch metadata already applied';end if;
  patched:=replace(definition,'''kind'',kind,''cards'',cards','''kind'',kind,''pack_count'',pack_count,''cards'',cards');
  patched:=replace(patched,'''kind'',opening.kind,','''kind'',opening.kind,''pack_count'',opening.pack_count,');
  if patched=definition then raise exception 'Opening response signature changed; review required';end if;
  execute patched;
 end loop;
 select pg_get_functiondef('aamix_hw01_private.halloween_definition()'::regprocedure) into definition;
 patched:=replace(definition,'"card_code": "0128"','"card_code": "H05", "featured_cards": ["H02", "H05"]');
 if patched=definition then raise exception 'Event headliner changed; review required';end if;execute patched;
 select pg_get_functiondef('aamix_hw01_private.halloween_deck()'::regprocedure) into definition;
 patched:=replace(definition,'"portada": "custom_restos"','"portada": "halloween"');
 if patched=definition then raise exception 'Event cover changed; review required';end if;execute patched;
end$$;

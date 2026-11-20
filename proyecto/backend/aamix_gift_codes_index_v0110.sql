-- AAMIX 0.11.0: follow-up index after 20261018031742.
-- Separate from the already-applied gift-code migration; changes no player rows.
create index aamix_gift_code_deck_idx on aamix_private.gift_code_rewards(deck_id);

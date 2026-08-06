-- OPERATIONAL override — launch bridge (approved 2026-08-06).
--
-- Not structure: this raises the global default limits while the user base is
-- small, so early users can exercise the AI features freely. Canonical free
-- tier stays 3/2/10 (the 20260806000000 seed). Revert = UPDATE back; SQL and
-- the standing procedure live in docs/quota-operacio.md. It ships as a
-- migration (not an ad-hoc UPDATE) because migrations are Claude Code's only
-- SQL channel to the linked database; the Studio SQL editor remains the
-- zero-migration path for future operational changes.

update public.quota_defaults set monthly_limit = 20
  where quota_key = 'dish_assistant';
update public.quota_defaults set monthly_limit = 10
  where quota_key = 'menu_wizard';
update public.quota_defaults set monthly_limit = 50
  where quota_key = 'stock_photos';

-- Executable verification, same transaction: the rows hold the bridge values
-- AND the resolution chain serves them (a fresh uuid has no entitlement row,
-- so effective_quota_limit must fall through to quota_defaults).
do $$
begin
  assert (select monthly_limit from public.quota_defaults
            where quota_key = 'dish_assistant') = 20,
    'dish_assistant bridge limit not applied';
  assert (select monthly_limit from public.quota_defaults
            where quota_key = 'menu_wizard') = 10,
    'menu_wizard bridge limit not applied';
  assert (select monthly_limit from public.quota_defaults
            where quota_key = 'stock_photos') = 50,
    'stock_photos bridge limit not applied';
  assert public.effective_quota_limit(gen_random_uuid(), 'dish_assistant') = 20,
    'effective_quota_limit does not resolve the dish_assistant default';
  assert public.effective_quota_limit(gen_random_uuid(), 'menu_wizard') = 10,
    'effective_quota_limit does not resolve the menu_wizard default';
  assert public.effective_quota_limit(gen_random_uuid(), 'stock_photos') = 50,
    'effective_quota_limit does not resolve the stock_photos default';
end $$;

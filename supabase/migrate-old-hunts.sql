-- Copy hunts saved by earlier versions of the app into duck_hunts. Safe to re-run.

-- 1. Hunts uploaded by the first accounts version (hunt_log table)
do $$ begin
  if to_regclass('public.hunt_log') is not null then
    insert into public.duck_hunts (id, user_id, data, updated_at)
    select id, user_id, data, updated_at from public.hunt_log
    on conflict (id) do nothing;
  end if;
end $$;

-- 2. Hunts from the old crew-code shared log (hunts table) have no owner.
--    Put the email of the account that should own them below, then run.
do $$ declare owner uuid; begin
  select id into owner from auth.users where email = lower('YOUR-EMAIL@example.com');
  if owner is not null and to_regclass('public.hunts') is not null then
    insert into public.duck_hunts (id, user_id, data, updated_at)
    select id, owner, data, updated_at from public.hunts
    on conflict (id) do nothing;
  end if;
end $$;

-- 3. Check: hunts per person
select p.display_name, count(h.id) as hunts
from public.duck_profiles p left join public.duck_hunts h on h.user_id = p.id
group by p.display_name;

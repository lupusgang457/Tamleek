alter table public.onchain_deposit_verifications
  drop constraint onchain_deposit_verifications_status_check;

alter table public.onchain_deposit_verifications
  add column credited_at timestamptz not null default now();

update public.onchain_deposit_verifications
set status = 'credited'
where status = 'verified_pending_review';

alter table public.onchain_deposit_verifications
  alter column status set default 'credited';

alter table public.onchain_deposit_verifications
  add constraint onchain_deposit_verifications_status_check
  check (status = 'credited');

create or replace function public.get_my_usdt_balance_scaled()
returns text
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(
    sum(
      amount_raw::numeric *
      power(10::numeric, (18 - token_decimals)::numeric)
    ),
    0
  )::text
  from public.onchain_deposit_verifications
  where user_id = (select auth.uid())
    and status = 'credited';
$$;

revoke all on function public.get_my_usdt_balance_scaled()
from public, anon, authenticated;
grant execute on function public.get_my_usdt_balance_scaled()
to authenticated;

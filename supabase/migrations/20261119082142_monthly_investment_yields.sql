create table if not exists public.investment_monthly_yields (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  product_id text not null references public.investment_products (product_id),
  period_start date not null,
  amount_raw numeric(78, 0) not null check (amount_raw > 0),
  actual_receipt_reference text not null
    check (length(btrim(actual_receipt_reference)) between 1 and 250),
  credited_at timestamptz not null default now(),
  constraint investment_monthly_yields_period_start
    check (extract(day from period_start) = 1),
  constraint investment_monthly_yields_user_product_period
    unique (user_id, product_id, period_start)
);

alter table public.investment_monthly_yields enable row level security;
revoke all on table public.investment_monthly_yields
from public, anon, authenticated;
grant select on table public.investment_monthly_yields to authenticated;
grant all on table public.investment_monthly_yields to service_role;

create policy "Users read their own monthly investment yields"
on public.investment_monthly_yields for select to authenticated
using (
  (select auth.uid()) = user_id
  or (select public.is_tamleek_admin())
);

create or replace function public.set_investment_monthly_yield_amount()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invested_cost_raw numeric := 0;
  v_purchased_units numeric := 0;
  v_redeemed_units numeric := 0;
  v_remaining_units numeric := 0;
  v_remaining_cost_raw numeric := 0;
begin
  if new.period_start >= date_trunc('month', now())::date then
    raise exception 'Only completed investment months can be credited.';
  end if;

  new.actual_receipt_reference := btrim(new.actual_receipt_reference);
  if length(new.actual_receipt_reference) not between 1 and 250 then
    raise exception 'A valid actual receipt reference is required.';
  end if;

  select
    coalesce(sum(o.amount_raw::numeric), 0),
    coalesce(sum(o.units_raw::numeric), 0)
  into v_invested_cost_raw, v_purchased_units
  from public.investment_orders o
  where o.user_id = new.user_id
    and o.product_id = new.product_id
    and o.status = 'approved'
    and o.reviewed_at < new.period_start::timestamptz;

  if v_purchased_units <= 0 then
    raise exception 'No approved investment was held for this month.';
  end if;

  select coalesce(sum(r.units_raw::numeric), 0)
  into v_redeemed_units
  from public.investment_redemption_orders r
  where r.user_id = new.user_id
    and r.product_id = new.product_id
    and r.status = 'approved'
    and r.reviewed_at < new.period_start::timestamptz;

  v_remaining_units := greatest(v_purchased_units - v_redeemed_units, 0);
  if v_remaining_units <= 0 then
    raise exception 'No investment units remained for this month.';
  end if;

  v_remaining_cost_raw := trunc(
    v_invested_cost_raw * v_remaining_units / v_purchased_units
  );
  new.amount_raw := trunc(v_remaining_cost_raw * 20 / 100);
  if new.amount_raw <= 0 then
    raise exception 'The monthly yield amount is below the supported minimum.';
  end if;

  new.credited_at := coalesce(new.credited_at, now());
  return new;
end;
$$;

revoke all on function public.set_investment_monthly_yield_amount()
from public, anon, authenticated;

create trigger set_investment_monthly_yield_amount
before insert on public.investment_monthly_yields
for each row
execute function public.set_investment_monthly_yield_amount();

create or replace function public.get_my_usdt_balance_scaled()
returns text
language sql
stable
security invoker
set search_path = ''
as $$
  select (
    coalesce(
      (
        select sum(
          amount_raw::numeric *
          power(10::numeric, (18 - token_decimals)::numeric)
        )
        from public.onchain_deposit_verifications
        where user_id = (select auth.uid())
          and status = 'credited'
      ),
      0
    ) +
    coalesce(
      (
        select sum(amount_usdt * 1000000000000000000)
        from public.deposit_requests
        where user_id = (select auth.uid())
          and status = 'credited'
      ),
      0
    ) +
    coalesce(
      (
        select sum(amount_raw)
        from public.investment_monthly_yields
        where user_id = (select auth.uid())
      ),
      0
    ) -
    coalesce(
      (
        select sum(amount_raw::numeric)
        from public.investment_orders
        where user_id = (select auth.uid())
          and status in ('pending', 'approved')
      ),
      0
    ) +
    coalesce(
      (
        select sum(amount_raw::numeric)
        from public.investment_redemption_orders
        where user_id = (select auth.uid())
          and status = 'approved'
      ),
      0
    ) -
    coalesce(
      (
        select sum(amount_raw::numeric)
        from public.withdrawal_requests
        where user_id = (select auth.uid())
          and status in ('pending', 'paid')
      ),
      0
    )
  )::numeric(78, 0)::text;
$$;;

alter table public.investment_monthly_yields
  alter column actual_receipt_reference drop not null;

alter table public.investment_monthly_yields
  add column credit_method text not null default 'manual_confirmed'
    check (credit_method in ('manual_confirmed', 'scheduled_fixed_20'));

alter table public.investment_monthly_yields
  drop constraint if exists investment_monthly_yields_actual_receipt_reference_check;

alter table public.investment_monthly_yields
  add constraint investment_monthly_yields_receipt_reference
  check (
    (credit_method = 'manual_confirmed'
      and length(btrim(actual_receipt_reference)) between 1 and 250)
    or (credit_method = 'scheduled_fixed_20'
      and actual_receipt_reference is null)
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

  if new.credit_method = 'manual_confirmed'
    and length(btrim(new.actual_receipt_reference)) not between 1 and 250 then
    raise exception 'A valid actual receipt reference is required.';
  end if;
  if new.credit_method = 'scheduled_fixed_20'
    and new.actual_receipt_reference is not null then
    raise exception 'Scheduled credits cannot contain a receipt reference.';
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

create or replace function public.credit_completed_monthly_investment_yields(
  p_period_start date
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inserted_count integer;
begin
  if p_period_start is null
    or extract(day from p_period_start) <> 1
    or p_period_start >= date_trunc('month', now())::date then
    raise exception 'A completed calendar month is required.';
  end if;

  with invested as (
    select
      user_id,
      product_id,
      sum(units_raw::numeric) as purchased_units
    from public.investment_orders
    where status = 'approved'
      and reviewed_at < p_period_start::timestamptz
    group by user_id, product_id
  ),
  redeemed as (
    select
      user_id,
      product_id,
      sum(units_raw::numeric) as redeemed_units
    from public.investment_redemption_orders
    where status = 'approved'
      and reviewed_at < p_period_start::timestamptz
    group by user_id, product_id
  )
  insert into public.investment_monthly_yields (
    user_id,
    product_id,
    period_start,
    credit_method
  )
  select
    invested.user_id,
    invested.product_id,
    p_period_start,
    'scheduled_fixed_20'
  from invested
  left join redeemed
    on redeemed.user_id = invested.user_id
    and redeemed.product_id = invested.product_id
  where invested.purchased_units > coalesce(redeemed.redeemed_units, 0)
  on conflict (user_id, product_id, period_start) do nothing;

  get diagnostics v_inserted_count = row_count;
  return v_inserted_count;
end;
$$;

revoke all on function public.credit_completed_monthly_investment_yields(date)
from public, anon, authenticated;

create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule(
  'tamleek-monthly-investment-yields',
  '5 0 1 * *',
  $job$
    select public.credit_completed_monthly_investment_yields(
      date_trunc('month', now() - interval '1 month')::date
    );
  $job$
);;

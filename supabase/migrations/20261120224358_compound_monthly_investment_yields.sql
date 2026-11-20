alter table public.investment_monthly_yields
  drop constraint if exists investment_monthly_yields_credit_method_check;

alter table public.investment_monthly_yields
  add constraint investment_monthly_yields_credit_method_check
  check (
    credit_method in (
      'manual_confirmed',
      'scheduled_fixed_20',
      'scheduled_compound_90'
    )
  );

alter table public.investment_monthly_yields
  drop constraint if exists investment_monthly_yields_receipt_reference;

alter table public.investment_monthly_yields
  add constraint investment_monthly_yields_receipt_reference
  check (
    (credit_method = 'manual_confirmed'
      and length(btrim(actual_receipt_reference)) between 1 and 250)
    or (credit_method in ('scheduled_fixed_20', 'scheduled_compound_90')
      and actual_receipt_reference is null)
  );

alter table public.investment_redemption_orders
  add column if not exists compound_yield_raw text not null default '0';

alter table public.investment_redemption_orders
  add constraint investment_redemption_orders_compound_yield_raw_check
  check (compound_yield_raw ~ '^(0|[1-9][0-9]{0,77})$');

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
  v_compound_yield_raw numeric := 0;
  v_released_yield_raw numeric := 0;
begin
  if new.period_start >= date_trunc('month', now())::date then
    raise exception 'Only completed investment months can be credited.';
  end if;

  if new.credit_method = 'manual_confirmed'
    and length(btrim(new.actual_receipt_reference)) not between 1 and 250 then
    raise exception 'A valid actual receipt reference is required.';
  end if;
  if new.credit_method in ('scheduled_fixed_20', 'scheduled_compound_90')
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

  select coalesce(sum(y.amount_raw::numeric), 0)
  into v_compound_yield_raw
  from public.investment_monthly_yields y
  where y.user_id = new.user_id
    and y.product_id = new.product_id
    and y.credit_method = 'scheduled_compound_90'
    and y.period_start < new.period_start;

  select coalesce(sum(r.compound_yield_raw::numeric), 0)
  into v_released_yield_raw
  from public.investment_redemption_orders r
  where r.user_id = new.user_id
    and r.product_id = new.product_id
    and r.status = 'approved';

  new.amount_raw := trunc(
    (
      v_remaining_cost_raw +
      greatest(v_compound_yield_raw - v_released_yield_raw, 0)
    ) * 90 / 100
  );
  if new.amount_raw <= 0 then
    raise exception 'The monthly yield amount is below the supported minimum.';
  end if;
  if new.amount_raw >= power(10::numeric, 78) then
    raise exception 'The monthly yield amount exceeds the supported range.';
  end if;

  new.credited_at := coalesce(new.credited_at, now());
  return new;
end;
$$;

revoke all on function public.set_investment_monthly_yield_amount()
from public, anon, authenticated;

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
    'scheduled_compound_90'
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

select cron.unschedule(jobid)
from cron.job
where jobname = 'tamleek-monthly-investment-yields';

select cron.schedule(
  'tamleek-monthly-investment-yields',
  '5 0 1 * *',
  $job$
    select public.credit_completed_monthly_investment_yields(
      date_trunc('month', now() - interval '1 month')::date
    );
  $job$
);

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
          and credit_method <> 'scheduled_compound_90'
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
$$;

create or replace function public.review_investment_redemption(
  p_redemption_id uuid,
  p_status text,
  p_review_note text default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_redemption public.investment_redemption_orders%rowtype;
  v_user_id uuid := (select auth.uid());
  v_owned_units numeric := 0;
  v_redeemed_units numeric := 0;
  v_remaining_units numeric := 0;
  v_total_compound_yield_raw numeric := 0;
  v_released_compound_yield_raw numeric := 0;
  v_redemption_compound_yield_raw numeric := 0;
  v_total_amount_raw numeric := 0;
begin
  if v_user_id is null or not public.is_tamleek_admin() then
    raise exception 'Administrator access required.';
  end if;
  if p_status is null or p_status not in ('approved', 'rejected') then
    raise exception 'Invalid redemption status.';
  end if;
  if p_review_note is null or length(p_review_note) > 500 then
    raise exception 'Review note is invalid.';
  end if;
  if p_status = 'rejected' and btrim(p_review_note) = '' then
    raise exception 'A rejection reason is required.';
  end if;

  select *
  into v_redemption
  from public.investment_redemption_orders
  where id = p_redemption_id
  for update;
  if not found or v_redemption.status <> 'pending' then
    raise exception 'Only pending redemption requests can be reviewed.';
  end if;

  if p_status = 'approved' then
    perform pg_advisory_xact_lock(
      hashtextextended(v_redemption.user_id::text, 0)
    );

    select coalesce(sum(o.units_raw::numeric), 0)
    into v_owned_units
    from public.investment_orders o
    where o.user_id = v_redemption.user_id
      and o.product_id = v_redemption.product_id
      and o.status = 'approved';

    select coalesce(sum(r.units_raw::numeric), 0)
    into v_redeemed_units
    from public.investment_redemption_orders r
    where r.user_id = v_redemption.user_id
      and r.product_id = v_redemption.product_id
      and r.status = 'approved';

    v_remaining_units := v_owned_units - v_redeemed_units;
    if v_remaining_units <= 0
      or v_redemption.units_raw::numeric > v_remaining_units then
      raise exception 'Investment units are no longer available.';
    end if;

    select coalesce(sum(y.amount_raw::numeric), 0)
    into v_total_compound_yield_raw
    from public.investment_monthly_yields y
    where y.user_id = v_redemption.user_id
      and y.product_id = v_redemption.product_id
      and y.credit_method = 'scheduled_compound_90';

    select coalesce(sum(r.compound_yield_raw::numeric), 0)
    into v_released_compound_yield_raw
    from public.investment_redemption_orders r
    where r.user_id = v_redemption.user_id
      and r.product_id = v_redemption.product_id
      and r.status = 'approved';

    if v_redemption.units_raw::numeric = v_remaining_units then
      v_redemption_compound_yield_raw := greatest(
        v_total_compound_yield_raw - v_released_compound_yield_raw,
        0
      );
    else
      v_redemption_compound_yield_raw := trunc(
        greatest(
          v_total_compound_yield_raw - v_released_compound_yield_raw,
          0
        ) * v_redemption.units_raw::numeric / v_remaining_units
      );
    end if;
    v_total_amount_raw :=
      v_redemption.amount_raw::numeric + v_redemption_compound_yield_raw;
    if v_total_amount_raw >= power(10::numeric, 78) then
      raise exception 'Redemption amount exceeds the supported range.';
    end if;
  end if;

  update public.investment_redemption_orders
  set status = p_status,
      amount_raw = case
        when p_status = 'approved'
          then v_total_amount_raw::numeric(78, 0)::text
        else amount_raw
      end,
      compound_yield_raw = case
        when p_status = 'approved'
          then v_redemption_compound_yield_raw::numeric(78, 0)::text
        else compound_yield_raw
      end,
      review_note = btrim(p_review_note),
      reviewed_by = v_user_id,
      reviewed_at = now()
  where id = p_redemption_id;
end;
$$;

revoke all on function public.review_investment_redemption(uuid, text, text)
from public, anon, authenticated;
grant execute on function public.review_investment_redemption(uuid, text, text)
to authenticated;

create or replace function public.get_my_investment_positions()
returns table (
  product_id text,
  units_raw text,
  unit_price_raw text,
  value_raw text,
  cost_basis_raw text,
  first_purchase_at text
)
language sql
stable
security invoker
set search_path = ''
as $$
  with purchased_positions as (
    select
      o.product_id,
      sum(o.units_raw::numeric) as purchased_units,
      sum(o.amount_raw::numeric) as total_cost_raw,
      min(o.created_at) as first_purchase_at
    from public.investment_orders o
    where o.user_id = (select auth.uid())
      and o.status = 'approved'
    group by o.product_id
  ),
  positions as (
    select
      purchased_positions.product_id,
      purchased_positions.purchased_units - coalesce(
        redemptions.reserved_units,
        0
      ) as units,
      trunc(
        purchased_positions.total_cost_raw *
        (purchased_positions.purchased_units - coalesce(
          redemptions.reserved_units,
          0
        )) /
        purchased_positions.purchased_units
      ) as cost_basis_raw,
      purchased_positions.first_purchase_at
    from purchased_positions
    left join lateral (
      select sum(r.units_raw::numeric) as reserved_units
      from public.investment_redemption_orders r
      where r.user_id = (select auth.uid())
        and r.product_id = purchased_positions.product_id
        and r.status in ('pending', 'approved')
    ) redemptions on true
  ),
  compound_yields as (
    select y.product_id, sum(y.amount_raw::numeric) as amount_raw
    from public.investment_monthly_yields y
    where y.user_id = (select auth.uid())
      and y.credit_method = 'scheduled_compound_90'
    group by y.product_id
  ),
  released_yields as (
    select
      r.product_id,
      sum(r.compound_yield_raw::numeric) as amount_raw
    from public.investment_redemption_orders r
    where r.user_id = (select auth.uid())
      and r.status = 'approved'
    group by r.product_id
  )
  select
    positions.product_id,
    positions.units::numeric(78, 0)::text,
    products.unit_price_raw,
    (
      trunc(
        positions.units * products.unit_price_raw::numeric /
        1000000000000000000::numeric
      ) +
      greatest(
        coalesce(compound_yields.amount_raw, 0) -
        coalesce(released_yields.amount_raw, 0),
        0
      )
    )::numeric(78, 0)::text,
    positions.cost_basis_raw::numeric(78, 0)::text,
    positions.first_purchase_at::text
  from positions
  join public.investment_products products
    on products.product_id = positions.product_id
  left join compound_yields
    on compound_yields.product_id = positions.product_id
  left join released_yields
    on released_yields.product_id = positions.product_id
  where positions.units > 0;
$$;

revoke all on function public.get_my_investment_positions()
from public, anon, authenticated;
grant execute on function public.get_my_investment_positions()
to authenticated;

create table public.tamleek_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.tamleek_admins enable row level security;
revoke all on table public.tamleek_admins from anon, authenticated;
grant all on table public.tamleek_admins to service_role;

create or replace function public.is_tamleek_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.tamleek_admins
    where user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_tamleek_admin()
from public, anon, authenticated;
grant execute on function public.is_tamleek_admin() to authenticated;

create table public.investment_products (
  product_id text primary key check (product_id ~ '^[a-z0-9:_-]{1,120}$'),
  unit_price_raw text not null
    check (unit_price_raw ~ '^[1-9][0-9]{0,77}$'),
  is_active boolean not null default false,
  updated_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.investment_products enable row level security;
revoke all on table public.investment_products from anon, authenticated;
grant select on table public.investment_products to authenticated;
grant all on table public.investment_products to service_role;

create policy "Authenticated users read investment product NAVs"
on public.investment_products for select to authenticated
using (true);

create table public.investment_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  product_id text not null references public.investment_products (product_id),
  client_request_id uuid not null,
  amount_raw text not null check (amount_raw ~ '^[1-9][0-9]{0,77}$'),
  unit_price_raw text not null
    check (unit_price_raw ~ '^[1-9][0-9]{0,77}$'),
  units_raw text not null check (units_raw ~ '^[1-9][0-9]{0,77}$'),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  review_note text not null default '',
  reviewed_by uuid references auth.users (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint investment_orders_user_request_unique
    unique (user_id, client_request_id)
);

alter table public.investment_orders enable row level security;
revoke all on table public.investment_orders from anon, authenticated;
grant select on table public.investment_orders to authenticated;
grant all on table public.investment_orders to service_role;

create policy "Users read their own investment orders"
on public.investment_orders for select to authenticated
using (
  (select auth.uid()) = user_id
  or (select public.is_tamleek_admin())
);

create index investment_orders_user_status_idx
on public.investment_orders (user_id, status, created_at desc);

create index investment_orders_pending_idx
on public.investment_orders (created_at)
where status = 'pending';

create or replace function public.get_my_usdt_balance_scaled()
returns text
language sql
stable
security invoker
set search_path = ''
as $$
  select trunc(
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
    ) -
    coalesce(
      (
        select sum(amount_raw::numeric)
        from public.investment_orders
        where user_id = (select auth.uid())
          and status in ('pending', 'approved')
      ),
      0
    )
  )::numeric(78, 0)::text;
$$;

revoke all on function public.get_my_usdt_balance_scaled()
from public, anon, authenticated;
grant execute on function public.get_my_usdt_balance_scaled()
to authenticated;

create or replace function public.save_investment_product(
  p_product_id text,
  p_unit_price_raw text,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.is_tamleek_admin() then
    raise exception 'Administrator access required.';
  end if;
  if p_product_id is null or p_product_id !~ '^[a-z0-9:_-]{1,120}$' then
    raise exception 'Invalid product.';
  end if;
  if p_unit_price_raw is null
    or p_unit_price_raw !~ '^[1-9][0-9]{0,77}$' then
    raise exception 'Invalid unit price.';
  end if;
  if p_is_active is null then
    raise exception 'Product state is required.';
  end if;

  insert into public.investment_products (
    product_id,
    unit_price_raw,
    is_active,
    updated_by,
    updated_at
  )
  values (
    p_product_id,
    p_unit_price_raw,
    p_is_active,
    (select auth.uid()),
    now()
  )
  on conflict (product_id) do update
  set unit_price_raw = excluded.unit_price_raw,
      is_active = excluded.is_active,
      updated_by = excluded.updated_by,
      updated_at = excluded.updated_at;
end;
$$;

revoke all on function public.save_investment_product(text, text, boolean)
from public, anon, authenticated;
grant execute on function public.save_investment_product(text, text, boolean)
to authenticated;

create or replace function public.request_investment_order(
  p_product_id text,
  p_amount_raw text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_amount numeric;
  v_balance numeric;
  v_unit_price numeric;
  v_units numeric;
  v_existing public.investment_orders%rowtype;
  v_order public.investment_orders%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication required.';
  end if;
  if p_product_id is null or p_product_id !~ '^[a-z0-9:_-]{1,120}$' then
    raise exception 'Invalid product.';
  end if;
  if p_amount_raw is null or p_amount_raw !~ '^[1-9][0-9]{0,77}$' then
    raise exception 'Invalid investment amount.';
  end if;
  if p_request_id is null then
    raise exception 'Request identifier is required.';
  end if;

  v_amount := p_amount_raw::numeric;
  if v_amount < 10000000000000000000::numeric then
    raise exception 'Minimum investment is 10 USDT.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  select *
  into v_existing
  from public.investment_orders
  where user_id = v_user_id
    and client_request_id = p_request_id
  for update;
  if found then
    if v_existing.product_id <> p_product_id
      or v_existing.amount_raw <> p_amount_raw then
      raise exception 'Request identifier was already used.';
    end if;
    return to_jsonb(v_existing);
  end if;

  if v_amount > 5000::numeric * 1000000000000000000::numeric
    and not exists (
      select 1
      from public.kyc_submissions
      where user_id = v_user_id
        and status = 'verified'
    ) then
    raise exception 'Verified KYC is required for investments above 5000 USDT.';
  end if;

  select unit_price_raw::numeric
  into v_unit_price
  from public.investment_products
  where product_id = p_product_id
    and is_active
  for share;
  if not found then
    raise exception 'This investment product is not available.';
  end if;

  v_balance := public.get_my_usdt_balance_scaled()::numeric;
  if v_amount > v_balance then
    raise exception 'Insufficient available USDT balance.';
  end if;

  v_units := trunc(
    v_amount * 1000000000000000000::numeric / v_unit_price
  );
  if v_units < 1 then
    raise exception 'Investment amount is below one minimum unit fraction.';
  end if;
  if v_units >= power(10::numeric, 78) then
    raise exception 'Investment unit quantity exceeds the supported range.';
  end if;

  insert into public.investment_orders (
    user_id,
    product_id,
    client_request_id,
    amount_raw,
    unit_price_raw,
    units_raw
  )
  values (
    v_user_id,
    p_product_id,
    p_request_id,
    p_amount_raw,
    v_unit_price::numeric(78, 0)::text,
    v_units::numeric(78, 0)::text
  )
  returning * into v_order;

  return to_jsonb(v_order);
end;
$$;

revoke all on function public.request_investment_order(text, text, uuid)
from public, anon, authenticated;
grant execute on function public.request_investment_order(text, text, uuid)
to authenticated;

create or replace function public.review_investment_order(
  p_order_id uuid,
  p_status text,
  p_review_note text default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.investment_orders%rowtype;
begin
  if (select auth.uid()) is null or not public.is_tamleek_admin() then
    raise exception 'Administrator access required.';
  end if;
  if p_status not in ('approved', 'rejected') then
    raise exception 'Invalid review status.';
  end if;
  if p_review_note is null or length(p_review_note) > 500 then
    raise exception 'Review note is invalid.';
  end if;
  if p_status = 'rejected' and btrim(p_review_note) = '' then
    raise exception 'A rejection reason is required.';
  end if;

  select *
  into v_order
  from public.investment_orders
  where id = p_order_id
  for update;
  if not found then
    raise exception 'Investment order not found.';
  end if;
  if v_order.status <> 'pending' then
    raise exception 'Only pending investment orders can be reviewed.';
  end if;
  if p_status = 'approved' and not exists (
    select 1
    from public.investment_products
    where product_id = v_order.product_id
      and is_active
  ) then
    raise exception 'This investment product is no longer active.';
  end if;

  update public.investment_orders
  set status = p_status,
      review_note = btrim(p_review_note),
      reviewed_by = (select auth.uid()),
      reviewed_at = now()
  where id = p_order_id;
end;
$$;

revoke all on function public.review_investment_order(uuid, text, text)
from public, anon, authenticated;
grant execute on function public.review_investment_order(uuid, text, text)
to authenticated;

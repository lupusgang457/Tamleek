create table if not exists public.user_deposit_addresses (
  user_id uuid not null references auth.users (id) on delete cascade,
  network text not null check (
    network in (
      'Polygon',
      'BNB Smart Chain',
      'Ethereum (ERC-20)',
      'Solana',
      'TRON (TRC-20)'
    )
  ),
  recipient_address text not null check (
    length(recipient_address) <= 128
    and (
      (
        network in ('Polygon', 'BNB Smart Chain', 'Ethereum (ERC-20)')
        and recipient_address ~ '^0x[a-fA-F0-9]{40}$'
      ) or (
        network = 'Solana'
        and recipient_address ~ '^[1-9A-HJ-NP-Za-km-z]{32,44}$'
      ) or (
        network = 'TRON (TRC-20)'
        and recipient_address ~ '^T[1-9A-HJ-NP-Za-km-z]{33}$'
      )
    )
  ),
  created_at timestamptz not null default now(),
  primary key (user_id, network),
  unique (network, recipient_address)
);

alter table public.user_deposit_addresses enable row level security;
revoke all on table public.user_deposit_addresses from anon, authenticated;
grant select on table public.user_deposit_addresses to authenticated;
grant all on table public.user_deposit_addresses to service_role;

create policy "Users read their own deposit addresses"
on public.user_deposit_addresses for select to authenticated
using ((select auth.uid()) = user_id);

create unique index if not exists user_deposit_addresses_evm_unique_idx
on public.user_deposit_addresses (network, lower(recipient_address))
where network in ('Polygon', 'BNB Smart Chain', 'Ethereum (ERC-20)');

create or replace function public.submit_kyc(
  p_first_name text,
  p_last_name text,
  p_birth_year integer,
  p_birth_place text,
  p_city text,
  p_department text,
  p_country text,
  p_identity_number text,
  p_document_path text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_existing_status text;
begin
  if v_user_id is null then
    raise exception 'Authentication required.';
  end if;
  if p_first_name is null or length(btrim(p_first_name)) not between 1 and 100
    or p_last_name is null or length(btrim(p_last_name)) not between 1 and 100
    or p_birth_year is null or p_birth_year not between 1900 and extract(year from now())::integer
    or p_birth_place is null or length(btrim(p_birth_place)) not between 1 and 120
    or p_city is null or length(btrim(p_city)) not between 1 and 120
    or p_department is null or length(btrim(p_department)) not between 1 and 120
    or p_country is null or length(btrim(p_country)) not between 1 and 120
    or p_identity_number is null
    or length(btrim(p_identity_number)) not between 1 and 120 then
    raise exception 'KYC information is invalid.';
  end if;
  if p_document_path is null
    or p_document_path !~ (
      '^' || v_user_id::text ||
      '/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$'
    ) then
    raise exception 'Identity document path is invalid.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 1));
  select status
  into v_existing_status
  from public.kyc_submissions
  where user_id = v_user_id
  for update;
  if found and v_existing_status <> 'rejected' then
    raise exception 'A KYC submission is already pending or verified.';
  end if;

  insert into public.kyc_submissions (
    user_id,
    first_name,
    last_name,
    birth_year,
    birth_place,
    city,
    department,
    country,
    identity_number,
    document_path,
    status,
    submitted_at,
    updated_at
  )
  values (
    v_user_id,
    btrim(p_first_name),
    btrim(p_last_name),
    p_birth_year,
    btrim(p_birth_place),
    btrim(p_city),
    btrim(p_department),
    btrim(p_country),
    btrim(p_identity_number),
    p_document_path,
    'pending',
    now(),
    now()
  )
  on conflict (user_id) do update
  set first_name = excluded.first_name,
      last_name = excluded.last_name,
      birth_year = excluded.birth_year,
      birth_place = excluded.birth_place,
      city = excluded.city,
      department = excluded.department,
      country = excluded.country,
      identity_number = excluded.identity_number,
      document_path = excluded.document_path,
      status = 'pending',
      submitted_at = now(),
      updated_at = now();

  return 'pending';
end;
$$;

revoke all on function public.submit_kyc(
  text, text, integer, text, text, text, text, text, text
) from public, anon, authenticated;
grant execute on function public.submit_kyc(
  text, text, integer, text, text, text, text, text, text
) to authenticated;

create table if not exists public.withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  client_request_id uuid not null,
  amount_raw text not null check (amount_raw ~ '^[1-9][0-9]{0,77}$'),
  network text not null check (
    network in (
      'Polygon',
      'BNB Smart Chain',
      'Ethereum (ERC-20)',
      'Solana',
      'TRON (TRC-20)'
    )
  ),
  recipient_address text not null,
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'rejected')),
  payout_transaction_hash text,
  review_note text not null default '',
  reviewed_by uuid references auth.users (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint withdrawal_requests_user_request_unique
    unique (user_id, client_request_id)
);

alter table public.withdrawal_requests enable row level security;
revoke all on table public.withdrawal_requests from anon, authenticated;
grant select on table public.withdrawal_requests to authenticated;
grant all on table public.withdrawal_requests to service_role;

create policy "Users read their own withdrawal requests"
on public.withdrawal_requests for select to authenticated
using (
  (select auth.uid()) = user_id
  or (select public.is_tamleek_admin())
);

create index if not exists withdrawal_requests_user_status_idx
on public.withdrawal_requests (user_id, status, created_at desc);

create table if not exists public.investment_redemption_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  product_id text not null references public.investment_products (product_id),
  client_request_id uuid not null,
  units_raw text not null check (units_raw ~ '^[1-9][0-9]{0,77}$'),
  unit_price_raw text not null
    check (unit_price_raw ~ '^[1-9][0-9]{0,77}$'),
  amount_raw text not null check (amount_raw ~ '^[1-9][0-9]{0,77}$'),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  review_note text not null default '',
  reviewed_by uuid references auth.users (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint investment_redemptions_user_request_unique
    unique (user_id, client_request_id)
);

alter table public.investment_redemption_orders enable row level security;
revoke all on table public.investment_redemption_orders from anon, authenticated;
grant select on table public.investment_redemption_orders to authenticated;
grant all on table public.investment_redemption_orders to service_role;

create policy "Users read their own redemption orders"
on public.investment_redemption_orders for select to authenticated
using (
  (select auth.uid()) = user_id
  or (select public.is_tamleek_admin())
);

create index if not exists investment_redemptions_user_status_idx
on public.investment_redemption_orders (user_id, product_id, status);

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

revoke all on function public.get_my_usdt_balance_scaled()
from public, anon, authenticated;
grant execute on function public.get_my_usdt_balance_scaled()
to authenticated;

create or replace function public.request_withdrawal(
  p_amount_raw text,
  p_network text,
  p_recipient_address text,
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
  v_existing public.withdrawal_requests%rowtype;
  v_request public.withdrawal_requests%rowtype;
  v_address text := btrim(coalesce(p_recipient_address, ''));
begin
  if v_user_id is null then
    raise exception 'Authentication required.';
  end if;
  if p_amount_raw is null or p_amount_raw !~ '^[1-9][0-9]{0,77}$' then
    raise exception 'Invalid withdrawal amount.';
  end if;
  if p_network is null or p_network not in (
    'Polygon',
    'BNB Smart Chain',
    'Ethereum (ERC-20)',
    'Solana',
    'TRON (TRC-20)'
  ) then
    raise exception 'Unsupported withdrawal network.';
  end if;
  if length(v_address) > 128 or not (
    (
      p_network in ('Polygon', 'BNB Smart Chain', 'Ethereum (ERC-20)')
      and v_address ~ '^0x[a-fA-F0-9]{40}$'
    ) or (
      p_network = 'Solana'
      and v_address ~ '^[1-9A-HJ-NP-Za-km-z]{32,44}$'
    ) or (
      p_network = 'TRON (TRC-20)'
      and v_address ~ '^T[1-9A-HJ-NP-Za-km-z]{33}$'
    )
  ) then
    raise exception 'Invalid recipient address for the selected network.';
  end if;
  if p_request_id is null then
    raise exception 'Request identifier is required.';
  end if;

  v_amount := p_amount_raw::numeric;
  if v_amount < 10000000000000000000::numeric then
    raise exception 'Minimum withdrawal is 10 USDT.';
  end if;
  if not exists (
    select 1
    from public.kyc_submissions
    where user_id = v_user_id
      and status = 'verified'
  ) then
    raise exception 'Verified KYC is required for withdrawals.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  select *
  into v_existing
  from public.withdrawal_requests
  where user_id = v_user_id
    and client_request_id = p_request_id
  for update;
  if found then
    if v_existing.amount_raw <> p_amount_raw
      or v_existing.network <> p_network
      or v_existing.recipient_address <> v_address then
      raise exception 'Request identifier was already used.';
    end if;
    return to_jsonb(v_existing);
  end if;

  v_balance := public.get_my_usdt_balance_scaled()::numeric;
  if v_amount > v_balance then
    raise exception 'Insufficient available USDT balance.';
  end if;

  insert into public.withdrawal_requests (
    user_id,
    client_request_id,
    amount_raw,
    network,
    recipient_address
  )
  values (
    v_user_id,
    p_request_id,
    p_amount_raw,
    p_network,
    v_address
  )
  returning * into v_request;

  return to_jsonb(v_request);
end;
$$;

revoke all on function public.request_withdrawal(text, text, text, uuid)
from public, anon, authenticated;
grant execute on function public.request_withdrawal(text, text, text, uuid)
to authenticated;

create or replace function public.review_withdrawal_request(
  p_request_id uuid,
  p_status text,
  p_review_note text default '',
  p_payout_transaction_hash text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.withdrawal_requests%rowtype;
  v_hash text := btrim(coalesce(p_payout_transaction_hash, ''));
begin
  if (select auth.uid()) is null or not public.is_tamleek_admin() then
    raise exception 'Administrator access required.';
  end if;
  if p_status is null or p_status not in ('paid', 'rejected') then
    raise exception 'Invalid withdrawal status.';
  end if;
  if p_review_note is null or length(p_review_note) > 500 then
    raise exception 'Review note is invalid.';
  end if;
  if p_status = 'rejected' and btrim(p_review_note) = '' then
    raise exception 'A rejection reason is required.';
  end if;

  select *
  into v_request
  from public.withdrawal_requests
  where id = p_request_id
  for update;
  if not found or v_request.status <> 'pending' then
    raise exception 'Only pending withdrawal requests can be reviewed.';
  end if;
  if p_status = 'paid' then
    if length(v_hash) > 100 or not (
      (
        v_request.network in ('Polygon', 'BNB Smart Chain', 'Ethereum (ERC-20)')
        and v_hash ~ '^0x[a-fA-F0-9]{64}$'
      ) or (
        v_request.network = 'Solana'
        and v_hash ~ '^[1-9A-HJ-NP-Za-km-z]{80,100}$'
      ) or (
        v_request.network = 'TRON (TRC-20)'
        and v_hash ~ '^[a-fA-F0-9]{64}$'
      )
    ) then
      raise exception 'A valid payout transaction hash is required.';
    end if;
  end if;

  update public.withdrawal_requests
  set status = p_status,
      payout_transaction_hash = case
        when p_status = 'paid' then v_hash
        else null
      end,
      review_note = btrim(p_review_note),
      reviewed_by = (select auth.uid()),
      reviewed_at = now()
  where id = p_request_id;
end;
$$;

revoke all on function public.review_withdrawal_request(uuid, text, text, text)
from public, anon, authenticated;
grant execute on function public.review_withdrawal_request(uuid, text, text, text)
to authenticated;

create or replace function public.request_investment_redemption(
  p_product_id text,
  p_units_raw text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_units numeric;
  v_owned_units numeric;
  v_unit_price numeric;
  v_amount numeric;
  v_existing public.investment_redemption_orders%rowtype;
  v_redemption public.investment_redemption_orders%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication required.';
  end if;
  if p_product_id is null or p_product_id !~ '^[a-z0-9:_-]{1,120}$' then
    raise exception 'Invalid investment product.';
  end if;
  if p_units_raw is null or p_units_raw !~ '^[1-9][0-9]{0,77}$' then
    raise exception 'Invalid unit quantity.';
  end if;
  if p_request_id is null then
    raise exception 'Request identifier is required.';
  end if;

  v_units := p_units_raw::numeric;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  select *
  into v_existing
  from public.investment_redemption_orders
  where user_id = v_user_id
    and client_request_id = p_request_id
  for update;
  if found then
    if v_existing.product_id <> p_product_id
      or v_existing.units_raw <> p_units_raw then
      raise exception 'Request identifier was already used.';
    end if;
    return to_jsonb(v_existing);
  end if;

  select unit_price_raw::numeric
  into v_unit_price
  from public.investment_products
  where product_id = p_product_id
  for share;
  if not found then
    raise exception 'This investment product is not available.';
  end if;

  select coalesce(sum(units_raw::numeric), 0)
  into v_owned_units
  from public.investment_orders
  where user_id = v_user_id
    and product_id = p_product_id
    and status = 'approved';

  v_owned_units := v_owned_units - coalesce((
    select sum(units_raw::numeric)
    from public.investment_redemption_orders
    where user_id = v_user_id
      and product_id = p_product_id
      and status in ('pending', 'approved')
  ), 0);

  if v_units > v_owned_units then
    raise exception 'Insufficient available investment units.';
  end if;

  v_amount := trunc(
    v_units * v_unit_price / 1000000000000000000::numeric
  );
  if v_amount < 1 then
    raise exception 'Redemption amount is below the supported precision.';
  end if;
  if v_amount >= power(10::numeric, 78) then
    raise exception 'Redemption amount exceeds the supported range.';
  end if;

  insert into public.investment_redemption_orders (
    user_id,
    product_id,
    client_request_id,
    units_raw,
    unit_price_raw,
    amount_raw
  )
  values (
    v_user_id,
    p_product_id,
    p_request_id,
    p_units_raw,
    v_unit_price::numeric(78, 0)::text,
    v_amount::numeric(78, 0)::text
  )
  returning * into v_redemption;

  return to_jsonb(v_redemption);
end;
$$;

revoke all on function public.request_investment_redemption(text, text, uuid)
from public, anon, authenticated;
grant execute on function public.request_investment_redemption(text, text, uuid)
to authenticated;

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
begin
  if (select auth.uid()) is null or not public.is_tamleek_admin() then
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

  update public.investment_redemption_orders
  set status = p_status,
      review_note = btrim(p_review_note),
      reviewed_by = (select auth.uid()),
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
  )
  select
    positions.product_id,
    positions.units::numeric(78, 0)::text,
    products.unit_price_raw,
    trunc(
      positions.units * products.unit_price_raw::numeric /
      1000000000000000000::numeric
    )::numeric(78, 0)::text,
    positions.cost_basis_raw::numeric(78, 0)::text,
    positions.first_purchase_at::text
  from positions
  join public.investment_products products
    on products.product_id = positions.product_id
  where positions.units > 0;
$$;

revoke all on function public.get_my_investment_positions()
from public, anon, authenticated;
grant execute on function public.get_my_investment_positions()
to authenticated;

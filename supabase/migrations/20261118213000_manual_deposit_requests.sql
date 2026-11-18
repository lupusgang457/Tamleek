create table if not exists public.deposit_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  client_request_id uuid not null,
  network text not null check (
    network in (
      'Polygon',
      'BNB Smart Chain',
      'Ethereum (ERC-20)',
      'Solana',
      'TRON (TRC-20)'
    )
  ),
  transaction_hash text not null,
  amount_usdt numeric(78, 18) not null check (amount_usdt > 0),
  status text not null default 'pending'
    check (status in ('pending', 'credited', 'rejected')),
  review_note text not null default '',
  reviewed_by uuid references auth.users (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint deposit_requests_user_request_unique
    unique (user_id, client_request_id),
  constraint deposit_requests_network_transaction_unique
    unique (network, transaction_hash),
  constraint deposit_requests_transaction_hash_format check (
    (
      network in ('Polygon', 'BNB Smart Chain', 'Ethereum (ERC-20)')
      and transaction_hash ~ '^0x[a-f0-9]{64}$'
    ) or (
      network = 'TRON (TRC-20)'
      and transaction_hash ~ '^[a-f0-9]{64}$'
    ) or (
      network = 'Solana'
      and length(transaction_hash) between 80 and 100
      and transaction_hash ~ '^[1-9A-HJ-NP-Za-km-z]+$'
    )
  )
);

alter table public.deposit_requests enable row level security;
revoke all on table public.deposit_requests from public, anon, authenticated;
grant select on table public.deposit_requests to authenticated;
grant all on table public.deposit_requests to service_role;

create policy "Users read their own deposit requests"
on public.deposit_requests for select to authenticated
using (
  (select auth.uid()) = user_id
  or (select public.is_tamleek_admin())
);

create index if not exists deposit_requests_user_created_idx
on public.deposit_requests (user_id, created_at desc);

create or replace function public.stamp_deposit_request_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if old.status <> 'pending' or new.status not in ('credited', 'rejected') then
      raise exception 'Only pending deposit requests can be reviewed.';
    end if;
    new.reviewed_at := now();
    new.reviewed_by := (select auth.uid());
  end if;
  return new;
end;
$$;

revoke all on function public.stamp_deposit_request_review()
from public, anon, authenticated;

create trigger stamp_deposit_request_review
before update of status on public.deposit_requests
for each row
execute function public.stamp_deposit_request_review();

create or replace function public.request_manual_deposit(
  p_request_id uuid,
  p_amount_raw text,
  p_network text,
  p_transaction_hash text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_transaction_hash text := btrim(p_transaction_hash);
  v_existing public.deposit_requests%rowtype;
  v_request_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required.';
  end if;
  if p_request_id is null then
    raise exception 'Request identifier is required.';
  end if;
  if p_network not in (
    'Polygon',
    'BNB Smart Chain',
    'Ethereum (ERC-20)',
    'Solana',
    'TRON (TRC-20)'
  ) then
    raise exception 'Unsupported deposit network.';
  end if;
  if p_amount_raw is null
    or p_amount_raw !~ '^[1-9][0-9]{0,77}$'
    or p_amount_raw::numeric < 10000000000000000000 then
    raise exception 'Deposit amount must be at least 10 USDT.';
  end if;
  if p_network in ('Polygon', 'BNB Smart Chain', 'Ethereum (ERC-20)')
    or p_network = 'TRON (TRC-20)' then
    v_transaction_hash := lower(v_transaction_hash);
  end if;
  if not (
    (
      p_network in ('Polygon', 'BNB Smart Chain', 'Ethereum (ERC-20)')
      and v_transaction_hash ~ '^0x[a-f0-9]{64}$'
    ) or (
      p_network = 'TRON (TRC-20)'
      and v_transaction_hash ~ '^[a-f0-9]{64}$'
    ) or (
      p_network = 'Solana'
      and length(v_transaction_hash) between 80 and 100
      and v_transaction_hash ~ '^[1-9A-HJ-NP-Za-km-z]+$'
    )
  ) then
    raise exception 'Transaction hash does not match the selected network.';
  end if;

  select *
  into v_existing
  from public.deposit_requests
  where user_id = v_user_id
    and client_request_id = p_request_id
  for update;
  if found then
    if v_existing.network <> p_network
      or v_existing.transaction_hash <> v_transaction_hash
      or v_existing.amount_usdt <> p_amount_raw::numeric / 1000000000000000000 then
      raise exception 'Request identifier was already used for another deposit.';
    end if;
    return v_existing.id;
  end if;

  insert into public.deposit_requests (
    user_id,
    client_request_id,
    network,
    transaction_hash,
    amount_usdt
  )
  values (
    v_user_id,
    p_request_id,
    p_network,
    v_transaction_hash,
    p_amount_raw::numeric / 1000000000000000000
  )
  returning id into v_request_id;

  return v_request_id;
end;
$$;

revoke all on function public.request_manual_deposit(uuid, text, text, text)
from public, anon, authenticated;
grant execute on function public.request_manual_deposit(uuid, text, text, text)
to authenticated;

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

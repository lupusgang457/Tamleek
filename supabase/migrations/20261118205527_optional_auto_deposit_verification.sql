alter table public.deposit_requests
  add column if not exists verification_source text not null default 'manual',
  add column if not exists token_address text,
  add column if not exists sender_address text,
  add column if not exists recipient_address text,
  add column if not exists block_number numeric(78, 0),
  add column if not exists confirmations integer,
  add column if not exists verified_at timestamptz;

alter table public.deposit_requests
  add constraint deposit_requests_verification_source_check
  check (verification_source in ('manual', 'automatic'));

create table if not exists public.deposit_verification_settings (
  id text primary key check (id = 'global'),
  auto_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.deposit_verification_settings enable row level security;
revoke all on table public.deposit_verification_settings
from public, anon, authenticated;
grant all on table public.deposit_verification_settings to service_role;

insert into public.deposit_verification_settings (id, auto_enabled)
values ('global', false)
on conflict (id) do nothing;

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
  where network = p_network
    and transaction_hash = v_transaction_hash
  for update;
  if found then
    if v_existing.user_id <> v_user_id then
      raise exception 'This transaction has already been submitted.';
    end if;
    if v_existing.amount_usdt <> p_amount_raw::numeric / 1000000000000000000 then
      raise exception 'This transaction was submitted with a different amount.';
    end if;
    return v_existing.id;
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
    amount_usdt,
    verification_source
  )
  values (
    v_user_id,
    p_request_id,
    p_network,
    v_transaction_hash,
    p_amount_raw::numeric / 1000000000000000000,
    'manual'
  )
  returning id into v_request_id;

  return v_request_id;
end;
$$;;

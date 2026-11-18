create table if not exists public.onchain_deposit_verifications (
  id uuid primary key default gen_random_uuid(),
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
  transaction_hash text not null,
  token_address text not null,
  sender_address text,
  recipient_address text not null,
  amount_raw numeric(78, 0) not null check (amount_raw > 0),
  token_decimals smallint not null check (token_decimals between 0 and 18),
  block_number numeric(78, 0) not null check (block_number > 0),
  confirmations integer not null check (confirmations > 0),
  status text not null default 'verified_pending_review'
    check (status = 'verified_pending_review'),
  verified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint onchain_deposit_verifications_network_tx_unique
    unique (network, transaction_hash)
);

alter table public.onchain_deposit_verifications enable row level security;

revoke all on table public.onchain_deposit_verifications from anon, authenticated;
grant select on table public.onchain_deposit_verifications to authenticated;

drop policy if exists "Users read their own on-chain deposits"
on public.onchain_deposit_verifications;
create policy "Users read their own on-chain deposits"
on public.onchain_deposit_verifications
for select to authenticated
using ((select auth.uid()) = user_id);

create index if not exists onchain_deposit_verifications_user_created_idx
on public.onchain_deposit_verifications (user_id, created_at desc);

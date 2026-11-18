alter table public.onchain_deposit_verifications
  drop constraint onchain_deposit_verifications_amount_raw_check;

alter table public.onchain_deposit_verifications
  alter column amount_raw type text using amount_raw::text;

alter table public.onchain_deposit_verifications
  add constraint onchain_deposit_verifications_amount_raw_check
  check (amount_raw ~ '^[1-9][0-9]*$');

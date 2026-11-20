alter table public.onchain_deposit_verifications
  add column if not exists review_note text not null default '',
  add column if not exists reviewed_by uuid references auth.users (id) on delete set null,
  add column if not exists reviewed_at timestamptz;

alter table public.onchain_deposit_verifications
  alter column status set default 'pending',
  alter column credited_at drop not null;

alter table public.onchain_deposit_verifications
  drop constraint if exists onchain_deposit_verifications_status_check;

update public.onchain_deposit_verifications
set status = 'pending',
    credited_at = null,
    review_note = '',
    reviewed_by = null,
    reviewed_at = null;

alter table public.onchain_deposit_verifications
  add constraint onchain_deposit_verifications_status_check
  check (status in ('pending', 'credited', 'rejected'));

alter table public.onchain_deposit_verifications
  add constraint onchain_deposit_verifications_manual_review_check
  check (
    (status = 'pending' and review_note = '' and reviewed_at is null and credited_at is null)
    or (
      status = 'credited'
      and review_note = 'Approuver'
      and reviewed_at is not null
      and credited_at is not null
    )
    or (
      status = 'rejected'
      and review_note = 'Refuser'
      and reviewed_at is not null
      and credited_at is null
    )
  );

create or replace function public.enforce_manual_onchain_deposit_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'pending' then
      raise exception 'New on-chain deposits must start pending manual review.';
    end if;
    new.credited_at := null;
    new.review_note := '';
    new.reviewed_by := null;
    new.reviewed_at := null;
    return new;
  end if;

  if new.status is distinct from old.status then
    if old.status <> 'pending' or new.status not in ('credited', 'rejected') then
      raise exception 'Only pending on-chain deposits can be reviewed.';
    end if;
    new.reviewed_at := now();
    new.reviewed_by := (select auth.uid());
    new.review_note := case new.status
      when 'credited' then 'Approuver'
      else 'Refuser'
    end;
    new.credited_at := case
      when new.status = 'credited' then now()
      else null
    end;
  elsif new.credited_at is distinct from old.credited_at
    or new.review_note is distinct from old.review_note
    or new.reviewed_by is distinct from old.reviewed_by
    or new.reviewed_at is distinct from old.reviewed_at then
    raise exception 'On-chain deposit review fields are managed by the review action.';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_manual_onchain_deposit_review()
from public, anon, authenticated;

drop trigger if exists enforce_manual_onchain_deposit_review
on public.onchain_deposit_verifications;

create trigger enforce_manual_onchain_deposit_review
before insert or update of status, credited_at, review_note, reviewed_by, reviewed_at
on public.onchain_deposit_verifications
for each row
execute function public.enforce_manual_onchain_deposit_review();

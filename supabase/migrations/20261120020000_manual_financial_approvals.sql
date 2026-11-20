update public.deposit_verification_settings
set auto_enabled = false,
    updated_at = now()
where id = 'global';

alter table public.deposit_verification_settings
  drop constraint if exists deposit_verification_settings_manual_only_check;

alter table public.deposit_verification_settings
  add constraint deposit_verification_settings_manual_only_check
  check (auto_enabled = false);

update public.deposit_requests
set review_note = case status
  when 'credited' then 'Approuver'
  when 'rejected' then 'Refuser'
  else ''
end;

alter table public.deposit_requests
  drop constraint if exists deposit_requests_review_note_check;

alter table public.deposit_requests
  add constraint deposit_requests_review_note_check
  check (
    (status = 'pending' and review_note = '')
    or (status = 'credited' and review_note = 'Approuver')
    or (status = 'rejected' and review_note = 'Refuser')
  );

update public.withdrawal_requests
set review_note = case status
  when 'paid' then 'Approuver'
  when 'rejected' then 'Refuser'
  else ''
end;

alter table public.withdrawal_requests
  drop constraint if exists withdrawal_requests_review_note_check;

alter table public.withdrawal_requests
  add constraint withdrawal_requests_review_note_check
  check (
    (status = 'pending' and review_note = '')
    or (status = 'paid' and review_note = 'Approuver')
    or (status = 'rejected' and review_note = 'Refuser')
  );

create or replace function public.prevent_automatic_deposit_requests()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.verification_source = 'automatic'
    and (tg_op = 'INSERT'
      or old.verification_source is distinct from new.verification_source) then
    raise exception
      'Automatic deposit crediting is disabled; manual review is required.';
  end if;
  return new;
end;
$$;

revoke all on function public.prevent_automatic_deposit_requests()
from public, anon, authenticated;

drop trigger if exists prevent_automatic_deposit_requests
on public.deposit_requests;

create trigger prevent_automatic_deposit_requests
before insert or update of verification_source on public.deposit_requests
for each row
execute function public.prevent_automatic_deposit_requests();

create or replace function public.set_manual_review_note()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'pending' then
      raise exception 'New financial requests must start pending manual review.';
    end if;
    new.review_note := '';
    return new;
  end if;

  if new.status is distinct from old.status then
    if old.status <> 'pending' then
      raise exception 'Only pending financial requests can be reviewed.';
    end if;
    new.reviewed_at := now();
    new.reviewed_by := (select auth.uid());
  end if;

  new.review_note := case new.status
    when 'credited' then 'Approuver'
    when 'approved' then 'Approuver'
    when 'paid' then 'Approuver'
    when 'rejected' then 'Refuser'
    else ''
  end;
  return new;
end;
$$;

revoke all on function public.set_manual_review_note()
from public, anon, authenticated;

drop trigger if exists stamp_deposit_request_review
on public.deposit_requests;

create trigger set_manual_review_note
before insert or update of status on public.deposit_requests
for each row
execute function public.set_manual_review_note();

create trigger set_manual_review_note
before insert or update of status on public.withdrawal_requests
for each row
execute function public.set_manual_review_note();

create trigger set_manual_review_note
before insert or update of status on public.investment_orders
for each row
execute function public.set_manual_review_note();

create trigger set_manual_review_note
before insert or update of status on public.investment_redemption_orders
for each row
execute function public.set_manual_review_note();
